"""Meaningful guard/metric tests; no clinical performance assertions."""
import pathlib
import sys
import unittest
sys.path.insert(0,str(pathlib.Path(__file__).resolve().parent))
from audit_abnormal_detection import RULES, binary_counts, inferred_identity, metrics, cluster_intervals, validate_final_manifest

class AbnormalAuditTests(unittest.TestCase):
    def test_positive_category_error_preserves_binary_decision(self):
        v=metrics(['0.3'],['1.0'],['P1'],'Protein')
        self.assertEqual(v['accuracy'],0)
        self.assertEqual(v['reference_label_thresholds']['renal_protein_0_3_or_higher']['sensitivity'],1)

    def test_small70_to_negative_is_missed_female_and_male(self):
        for name in ('female_le_small_or_higher','male_le_trace_or_higher'):
            self.assertEqual(binary_counts(['Small 70'],['Neg'],RULES['Leukocytes'][name])['fn'],1)

    def test_male_trace_and_female_trace_differ(self):
        self.assertIn('Trace 15',RULES['Leukocytes']['male_le_trace_or_higher'])
        self.assertNotIn('Trace 15',RULES['Leukocytes']['female_le_small_or_higher'])

    def test_nonhemolyzed_blood_is_not_app_female_threshold(self):
        self.assertNotIn('Non-hemolyzed 10',RULES['Blood']['female_blood_study_positive'])
        self.assertIn('Non-hemolyzed 10',RULES['Blood']['analytical_any_nonnegative'])

    def test_absent_class_is_undefined_not_zero(self):
        v=metrics(['Neg'],['Neg'],['P1'],'Nitrite')
        self.assertIsNone(v['class_metrics']['Positive']['sensitivity'])
        self.assertEqual(v['confusion']['labels'],['Neg','Positive'])

    def test_lighting_variants_share_provisional_group(self):
        for left,right in [('LAUAAN-P001-L2700','LAUAAN-P001-L5500'),('site_001_Cool','site_001_Daylight'),('D1-P001-S1-L2700','D1-P001-S2-L4000')]:
            self.assertEqual(inferred_identity(dict(event_id=left,batch_id='batch')),inferred_identity(dict(event_id=right,batch_id='batch')))

    def test_repeated_positive_images_do_not_add_independent_support(self):
        v=cluster_intervals(['Positive']*3,['Neg']*3,['P1']*3,{'Positive'},repeats=20)
        self.assertEqual(v['sensitivity']['provisional_support_groups'],1)
        self.assertIsNone(v['sensitivity']['ci95'])

    def records(self):
        return [dict(capture_id=f'C{i}',participant_id=f'P{i}',specimen_id=f'S{i}',image_sha256=f'{i:064x}',split=split,identity_verified='yes',reference_adjudicated='yes',previously_reviewed='no') for i,split in enumerate(('train','validation','test'),1)]

    def contract(self):
        return dict(status='approved',clinical_adviser='Advisor',statistician='Statistician',signed_at='2026-10-05',minimum_sensitivity=.95,minimum_specificity=.9,maximum_retake_rate=.1,maximum_ci_width=.1,independent_specimens_per_threshold={'nitrite_positive':{'positive':100,'negative':100}},locked_model_sha256='a'*64,locked_analysis_plan_sha256='b'*64)

    def test_reviewed_test_rejected(self):
        rows=self.records(); rows[-1]['previously_reviewed']='yes'
        with self.assertRaisesRegex(ValueError,'Reviewed data'):
            validate_final_manifest(rows,self.contract())

    def test_participant_cross_split_rejected(self):
        rows=self.records(); rows[-1]['participant_id']=rows[0]['participant_id']
        with self.assertRaisesRegex(ValueError,'participant_id'):
            validate_final_manifest(rows,self.contract())

    def test_duplicate_image_cross_split_rejected(self):
        rows=self.records(); rows[-1]['image_sha256']=rows[0]['image_sha256']
        with self.assertRaisesRegex(ValueError,'image_sha256'):
            validate_final_manifest(rows,self.contract())

    def test_unapproved_contract_rejected(self):
        contract=self.contract(); contract['status']='pending'
        with self.assertRaisesRegex(ValueError,'approval'):
            validate_final_manifest(self.records(),contract)

    def test_invalid_independent_sample_targets_rejected(self):
        contract=self.contract(); contract["independent_specimens_per_threshold"]={"nitrite_positive":{"positive":0,"negative":100}}
        with self.assertRaisesRegex(ValueError,"sample targets"):
            validate_final_manifest(self.records(),contract)

    def test_metadata_validation_is_not_final_performance(self):
        self.assertEqual(validate_final_manifest(self.records(),self.contract())['status'],'metadata_checks_passed')

if __name__=='__main__':
    unittest.main()
