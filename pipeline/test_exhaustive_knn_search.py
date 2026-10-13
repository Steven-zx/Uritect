"""Verify metric parity, group safeguards, and label-free color calibration."""
import unittest
import numpy as np
from exhaustive_knn_search import fast_metrics, votes, transformed_neighbors
from exhaustive_color_features import feature_values, crop_inside, rgb_lab
from improve_direction_verified_knn import measure
from semiquant_schema import ANALYTE_LEVEL_SCHEMA


class ExhaustiveSearchTests(unittest.TestCase):
    def test_fast_metrics_match_reference_definitions(self):
        for analyte in ['pH','Specific Gravity','Nitrite','Leukocytes','Blood']:
            schema=ANALYTE_LEVEL_SCHEMA[analyte]
            truth=np.array([0,1,0,1,0,min(2,len(schema)-1)])
            pred=np.array([0,0,1,1,0,min(2,len(schema)-1)])
            fast=fast_metrics(truth,pred,analyte)
            full=measure(np.array(schema)[truth],np.array(schema)[pred],np.array(['a','b','c','d','e','f']),analyte)
            for key in ['accuracy','macro_f1_supported_reference_classes','macro_sensitivity','macro_specificity','cohens_kappa']:
                self.assertAlmostEqual(fast[key],full[key],places=12)
            for key,r in fast['reference_label_thresholds'].items():
                self.assertEqual(r['sensitivity'],full['reference_label_thresholds'][key]['sensitivity'])
                self.assertEqual(r['specificity'],full['reference_label_thresholds'][key]['specificity'])

    def test_backing_correction_removes_a_shared_unclipped_color_cast(self):
        patch=np.tile([60.,100.,80.],(10,10,1));white=np.array([180.,190.,200.]);gain=np.array([1.1,.95,1.05])
        np.testing.assert_allclose(feature_values(patch,white,'backing_lab'),feature_values(patch*gain,white*gain,'backing_lab'),rtol=1e-12,atol=1e-12)

    def test_crop_jitter_never_samples_outside_original_pad(self):
        image=np.zeros((20,20,3));image[5:15,5:15]=100
        for shift in [-100,-1,0,1,100]:
            self.assertTrue((crop_inside(image,[5,5,10,10],.7,shift,shift)==100).all())

    def test_repeated_neighbors_cannot_count_as_separate_groups(self):
        d=np.ones((1,5));y=np.array([[0,0,0,1,1]]);g=np.array([['a','a','a','b','c']]);counts=np.ones(2)
        ordinary=votes(d,y,g,counts,5,'uniform',False,0,2)[0]
        grouped=votes(d,y,g,counts,5,'uniform',True,0,2)[0]
        self.assertEqual(ordinary[0],0);self.assertEqual(grouped[0],1)

    def test_validation_rows_do_not_fit_scaling_and_group_radius(self):
        x=np.array([[0.,0.],[1.,1.],[3.,3.],[4.,4.],[2.,2.],[900.,900.]])
        aug=np.repeat(x[:,None,:],4,axis=1);y=np.array([0,0,1,1,0,0]);g=np.array(['a','a','b','b','c','d'])
        first=transformed_neighbors(x,aug,y,g,np.arange(4),np.array([4]),'standard',True,'euclidean')
        second=transformed_neighbors(x,aug,y,g,np.arange(4),np.array([4,5]),'standard',True,'euclidean')
        np.testing.assert_allclose(first[0],second[0][:1]);self.assertEqual(first[4][0],second[4][0])

    def test_unrepresented_categories_do_not_create_votes_or_crash(self):
        p,c=votes(np.array([[.1,.2]]),np.array([[0,1]]),np.array([['a','b']]),np.array([1.,1.]),3,'distance',False,.5,6)
        self.assertEqual(p[0],0);self.assertLessEqual(c[0],1.)


if __name__=='__main__':unittest.main()
