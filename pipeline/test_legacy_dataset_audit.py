import io
import json
import tempfile
import unittest
import zipfile
from pathlib import Path
from unittest.mock import patch

import numpy as np
from PIL import Image

import audit_legacy_dataset as audit
from evaluate_legacy_expansion import cluster_delta, screen, tokens
from improve_direction_verified_knn import measure
from semiquant_schema import ANALYTE_ORDER


class LegacyAuditTests(unittest.TestCase):
    def test_background_box_cannot_be_accepted_as_a_pad(self):
        image=np.full((100,200,3),160,dtype=np.uint8)
        image[40:60,90:110]=[50,160,220]
        self.assertEqual(audit.background_support(image,(90,40,20,20)),1.)
        self.assertEqual(audit.background_support(image,(90,10,20,20)),0.)
        # A black macro-marker on one side is not evidence for a pad.
        image[10:30,10:50]=0
        self.assertEqual(audit.background_support(image,(90,10,20,20)),0.)

    def test_duplicate_exports_are_one_photo_and_conflicting_references_are_blocked(self):
        with tempfile.TemporaryDirectory() as folder:
            root=Path(folder); old=root/'old';old.mkdir();(root/'new_uritect_dataset').mkdir()
            raw=b'original bytes unchanged'
            header='relative_image_path,participant_id,'+','.join(audit.ANALYTE_OUTPUT_COLUMNS.values())+'\n'
            labels={a:('5.0' if a=='pH' else '1.025' if a=='Specific Gravity' else '16' if a=='Urobilinogen' else 'Neg') for a in ANALYTE_ORDER}
            table=header+'images/one.jpg,P001,'+','.join(labels.values())+'\n'+'images/two.jpg,P002,'+','.join(labels.values())+'\n'
            path=old/'RHU175_copy.zip'
            with zipfile.ZipFile(path,'w') as z:
                z.writestr('training_index.csv',table); z.writestr('images/one.jpg',raw);z.writestr('images/two.jpg',raw)
            changed=dict(labels,pH='6.5')
            before=path.read_bytes()
            with patch.object(audit,'ROOT',root),patch.object(audit,'read_source_labels',return_value=({}, {'1':labels,'2':changed},[])):
                result=audit.inventory(root/'out',old)
            self.assertEqual(len(result['photos']),1)
            self.assertEqual(result['occurrences'],2)
            self.assertTrue(result['photos'][0]['reference_conflict'])
            self.assertFalse(result['photos'][0]['eligible_labels'])
            self.assertEqual(path.read_bytes(),before)
            with self.assertRaises(RuntimeError):audit.inventory(root/'out',old)

    def test_chart_decodes_but_cannot_enter_specimen_training(self):
        with tempfile.TemporaryDirectory() as folder:
            root=Path(folder); (root/'thumbnails').mkdir()
            stream=io.BytesIO();Image.fromarray(np.full((200,200,3),180,dtype=np.uint8)).save(stream,format='PNG')
            raw=stream.getvalue();zpath=root/'COLORWHEEL.zip'
            with zipfile.ZipFile(zpath,'w') as z:z.writestr('chart.png',raw)
            photo={'image_sha256':audit.digest(raw),'eligible_labels':True,'reference_conflict':False,
                'primary':{'archive':str(zpath),'member':'chart.png','family':'COLORWHEEL','group':'chart|1',
                           'labels':{},'subject_alias':'','label_status':'cyclic'}}
            result=audit.process_photo((photo,str(root)))
            self.assertEqual(result['status'],'reference_only')
            self.assertNotIn('features',result)

    def test_corrupt_original_is_preserved_and_rejected(self):
        with tempfile.TemporaryDirectory() as folder:
            root=Path(folder);(root/'thumbnails').mkdir();raw=b'not an image';zpath=root/'RHU.zip'
            with zipfile.ZipFile(zpath,'w') as z:z.writestr('broken.jpg',raw)
            before=zpath.read_bytes()
            photo={'image_sha256':audit.digest(raw),'eligible_labels':True,'reference_conflict':False,
                'primary':{'archive':str(zpath),'member':'broken.jpg','family':'RHU175','group':'RHU175|1',
                    'labels':{},'subject_alias':'','label_status':'supplied'}}
            result=audit.process_photo((photo,str(root)))
            self.assertEqual(result['status'],'excluded_decode_or_size')
            self.assertEqual(zpath.read_bytes(),before)

    def test_numeric_aliases_are_conservatively_excluded_across_batches(self):
        self.assertEqual(tokens([{'group':'batch|001','subject_alias':'163'},{'group':'batch2|A','subject_alias':''}]),{'1','163'})

    def test_perfect_negative_only_nitrite_is_not_an_abnormal_detection_improvement(self):
        truth=np.array(['Neg']*6); groups=np.array(list('abcdef'))
        value=measure(truth,truth,groups,'Nitrite')
        gate=screen(value,value,{'low':.02})
        self.assertFalse(gate['passed'])
        self.assertIn('No abnormal/category diversity in the evaluation references',gate['reasons'])

    def test_bootstrap_respects_grouped_repeat_photos(self):
        truth=np.array(['a','a','b','b']);groups=np.array(['one','one','two','two'])
        delta=cluster_delta(truth,np.array(['b','b','a','a']),truth,groups)
        self.assertEqual(delta['point'],1.)
        self.assertEqual(delta['low'],1.)
        self.assertEqual(delta['high'],1.)


if __name__=='__main__':unittest.main()
