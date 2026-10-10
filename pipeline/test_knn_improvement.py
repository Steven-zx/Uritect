"""Leakage and evidence guards for the retrospective improvement experiment."""
import unittest
from unittest.mock import patch
import numpy as np
from specimen_grouping import specimen_group
from freeze_production_semiquant import _specimen_group
from improve_direction_verified_knn import crop_bounds, fit_predict, measure


class ImprovementTests(unittest.TestCase):
    def test_laua_an_kelvin_events_share_identity_even_with_stale_group(self):
        rows = [dict(event_id=f'LAUAAN-P001-L{k}', batch_id='LAUAAN_20260730', specimen_group=f'old-L{k}') for k in (2700,4000,5500)]
        self.assertEqual(len({_specimen_group(r) for r in rows}),1)

    def test_cabatuan_lighting_shares_identity(self):
        groups = {specimen_group(dict(event_id=f'uritect_2026-7-15_Cabatuan_013_{light}',batch_id='July15')) for light in ('Cool','Warm','Daylight')}
        self.assertEqual(len(groups),1)

    def test_unknown_identity_fails_instead_of_grouping_each_photo(self):
        with self.assertRaises(ValueError):
            specimen_group(dict(event_id='unknown_photo',batch_id='batch'))

    def test_jitter_stays_inside_pad_roi(self):
        for fraction in (1.,.75,.5):
            for dx,dy in ((-1,-1),(1,1),(0,0)):
                x,y,w,h = crop_bounds((7,13,19,19),fraction,dx,dy)
                self.assertGreaterEqual(x,7); self.assertGreaterEqual(y,13)
                self.assertLessEqual(x+w,26); self.assertLessEqual(y+h,32)

    def test_augmentation_ignores_validation_pixels_and_labels(self):
        # Lab variant avoids hue conversion. Validation augmentations are NaN:
        # fitting would fail if those records leaked into the training set.
        features = np.zeros((18,4,3)); features[2] = [[10,2,3],[12,2,3],[40,2,3],[11,2,3]]
        aug = np.zeros((18,4,4,3)); aug[2,:3] = features[2,:3,None,:] + np.array([.1,.2,.3,.4])[None,:,None]; aug[:,3] = np.nan
        config = dict(variant=2,scale=True,k=3,metric='euclidean',weights='distance',augmentation=True)
        y = np.array(['A','A','B','SECRET'])
        p,c,model = fit_predict(features,aug,y,np.array([0,1,2]),np.array([3]),config)
        self.assertNotIn('SECRET',model.classes_)
        self.assertTrue(np.isfinite(c).all())
        self.assertEqual(model[-1]._fit_X.shape[0],15)

    def test_absent_nitrite_positives_do_not_become_perfect_sensitivity(self):
        v = measure(np.array(['Neg','Neg']),np.array(['Neg','Neg']),np.array(['P1','P2']),'Nitrite')
        self.assertIsNone(v['reference_label_thresholds']['nitrite_positive']['sensitivity'])
        self.assertIsNone(v['cohens_kappa'])

    def test_uniform_knn_accepts_string_categories(self):
        features = np.zeros((18,4,3)); features[2] = [[10,2,3],[12,2,3],[40,2,3],[11,2,3]]
        config = dict(variant=2,scale=False,k=3,metric='euclidean',weights='uniform',augmentation=False)
        p,c,_ = fit_predict(features,np.zeros((18,4,4,3)),np.array(['Neg','Neg','Small 70','Neg']),np.array([0,1,2]),np.array([3]),config)
        self.assertEqual(p[0],'Neg')


if __name__ == '__main__':
    unittest.main()
