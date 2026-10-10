import hashlib
import json
import unittest
from pathlib import Path
import numpy as np
from scipy.spatial.distance import cdist
from build_training_support_policy import build_policy

class TrainingSupportTests(unittest.TestCase):
    def test_reproducible_artifact_and_training_support(self):
        root=Path(__file__).resolve().parents[1]
        raw=(root/'uritect_app/assets/production_semiquant_model.json').read_bytes()
        artifact=json.loads((root/'uritect_app/assets/training_support_policy.json').read_text())
        self.assertEqual(build_policy(raw),artifact)
        self.assertEqual(artifact['model_sha256'],hashlib.sha256(raw).hexdigest())
        for name,spec in json.loads(raw)['analytes'].items():
            vectors=np.unique(np.asarray(spec['train_vectors']),axis=0)
            metric={'manhattan':'cityblock','chebyshev':'chebyshev','euclidean':'euclidean'}[spec['metric']]
            distances=cdist(vectors,vectors,metric)
            np.fill_diagonal(distances,np.inf)
            self.assertTrue(np.all(distances.min(axis=1)<=artifact['analytes'][name]['maximum_distance']))
            # A remote query has full vote agreement if labels agree, yet no support.
            remote=np.full((1,vectors.shape[1]),100000.0)
            self.assertGreater(cdist(remote,vectors,metric).min(),artifact['analytes'][name]['maximum_distance'])

    def test_duplicate_vectors_do_not_collapse_radius(self):
        spec={'train_vectors':[[0,0],[0,0],[3,4]],'metric':'euclidean'}
        policy=build_policy(json.dumps({'analytes':{'test':spec}}).encode())
        self.assertEqual(policy['analytes']['test']['maximum_distance'],5)
        self.assertEqual(policy['analytes']['test']['distinct_vectors'],2)

    def test_degenerate_and_nonfinite_training_rejected(self):
        for vectors in [[[1,1],[1,1]],[[1,1],[float('nan'),2]]]:
            with self.assertRaises(ValueError):
                build_policy(json.dumps({'analytes':{'x':{'train_vectors':vectors,'metric':'euclidean'}}}).encode())

if __name__=='__main__':unittest.main()
