"""Recover traceable development photographs with genuine high-resolution context."""
import json
import math
import numpy as np
import cv2
from audit_legacy_dataset import ROOT, read_photo, dump, file_digest
from evaluate_legacy_expansion import baseline_data, tokens
from evaluate_runtime_metric_knn import link_identity_tokens, conservative_group
from prepare_legacy_runtime_audit import WRAPPER
from semiquant_schema import ANALYTE_ORDER

OLD=ROOT/'pipeline/output/legacy_dataset_audit_2026-10-13'
OUT=ROOT/'pipeline/output/knn_exhaustive_2026-10-14'


def main():
    inventory={r['image_sha256']:r for r in json.loads((OLD/'INVENTORY.json').read_text())['photos']}
    refs=json.loads((OLD/'FINAL_PHOTO_AUDIT.json').read_text());by_hash={r['image_sha256']:r for r in refs}
    original=baseline_data()
    for r in original:r['subject_alias']=by_hash.get(r['image_sha256'],{}).get('subject_alias','')
    link_identity_tokens(original+refs)
    confirmation=[r for r in original if r['split']=='confirmation'];forbidden={conservative_group(r) for r in confirmation};held_tokens=tokens(confirmation)
    raw=OUT/'PRIVATE_CONTEXT_INPUTS';raw.mkdir(exist_ok=True)
    result=OUT/'PRIVATE_CONTEXT_RUNTIME';result.mkdir(exist_ok=True)
    items=[];provenance=[]
    previous=ROOT/'pipeline/output/knn_runtime_metric_2026-10-13/runtime_detector'
    for audit in json.loads((OLD/'PHOTO_AUDIT.json').read_text()):
        if audit['status']!='accepted_training':continue
        key=audit['image_sha256'];photo=inventory[key];ref=by_hash[key]
        if not photo['eligible_labels'] or photo['reference_conflict']:continue
        if conservative_group(ref) in forbidden or tokens([ref])&held_tokens:continue
        existing=previous/(key+'.json')
        if existing.exists() and json.loads(existing.read_text()).get('geometry_passed'):continue
        image,_=read_photo(photo)
        turns=audit['rotation_ccw_degrees']//90
        if turns:image=np.rot90(image,k=turns).copy()
        rois=[audit['rois'][a] for a in ANALYTE_ORDER]
        offset=0
        if audit['localization_method'].startswith('measured_lateral_window:'):
            offset=int(audit['localization_method'].split(':')[1])
        scale=audit['processing_scale']
        if scale<=0:continue
        width=float(np.median([r[2] for r in rois]));gap=float(np.median(np.diff([r[1]+r[3]/2 for r in rois])))
        x0=max(0,int(math.floor((min(r[0] for r in rois)+offset-6*width)/scale)))
        x1=min(image.shape[1],int(math.ceil((max(r[0]+r[2] for r in rois)+offset+6*width)/scale)))
        y0=max(0,int(math.floor((rois[0][1]-2*gap)/scale)))
        y1=min(image.shape[0],int(math.ceil((rois[-1][1]+rois[-1][3]+6*gap)/scale)))
        if x1<=x0 or y1<=y0:continue
        path=raw/(key+'.png')
        assert cv2.imwrite(str(path),image[y0:y1,x0:x1]), 'Lossless crop write failed'
        checksum=file_digest(path)
        items.append(dict(image_sha256=key,input_sha256=checksum,input_kind='high_resolution_context_crop',image_path=str(path.resolve()),output_directory=str(result.resolve())))
        provenance.append(dict(image_sha256=key,original_sha256=key,cropped_sha256=checksum,exif_baked=True,rotation_ccw=audit['rotation_ccw_degrees'],original_pixel_bounds=[x0,y0,x1-x0,y1-y0],crop_has_genuine_background=True,padding_added=False,reference_labels_changed=False))
    source=ROOT/'uritect_app/lib/services/local_scan_analysis_service.dart';text=source.read_text(encoding='utf-8').replace("import '../models/", "import 'package:uritect_app/models/")
    for name in ['training_support_policy','runtime_pad_features','photo_quality_check','pad_presence_check']:
        text=text.replace(f"import '{name}.dart';",f"import 'package:uritect_app/services/{name}.dart';")
    harness=ROOT/'tmp/high_resolution_context_detector_test.dart'
    harness.write_text("import 'package:flutter_test/flutter_test.dart';\nimport 'package:crypto/crypto.dart' as crypto;\n"+text+WRAPPER,encoding='utf-8')
    dump(OUT/'PRIVATE_CONTEXT_MANIFEST.json',dict(photos=items))
    dump(OUT/'PRIVATE_CONTEXT_PROVENANCE.json',provenance)
    dump(OUT/'CONTEXT_RECOVERY_PLAN.json',dict(photos=len(items),bounds='Independent label-free first-pass physical ROI envelope, six pad widths of genuine lateral context, two tip gaps and six handle gaps; crop at original resolution before runtime resizing.',
        confirmation_groups_excluded=True,originals_untouched=True,labels_unchanged=True,detector_sha256=file_digest(source),harness_sha256=file_digest(harness)))
    print('Prepared',len(items),'previously unaccepted, traceable development context crops.')


if __name__=='__main__':main()
