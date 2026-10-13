"""Guard meaningful leakage and metric-selection properties of the experiment."""
import unittest
import numpy as np
from evaluate_runtime_metric_knn import link_identity_tokens, conservative_group, rules_nonregression, predict_config


class RuntimeMetricTests(unittest.TestCase):
    def test_known_aliases_are_linked_transitively_across_batches(self):
        rows = [dict(group='A|1', subject_alias='2'), dict(group='B|2', subject_alias='3'), dict(group='C|3')]
        link_identity_tokens(rows)
        self.assertEqual(len({conservative_group(r) for r in rows}), 1)

    def test_higher_sensitivity_cannot_hide_lower_rule_specificity(self):
        base = dict(reference_label_thresholds={'positive': dict(sensitivity=.8, specificity=.95)})
        bad = dict(reference_label_thresholds={'positive': dict(sensitivity=.9, specificity=.9)})
        self.assertFalse(rules_nonregression(base, bad))
        self.assertTrue(rules_nonregression(base, base))

    def test_unrelated_validation_rows_do_not_change_scaling_or_predictions(self):
        def row(h, label):
            f = np.tile([h, .5, .6], (10, 1))
            return dict(features=f, raw_features=f, labels={'Leukocytes': label})
        train = [row(359, 'A'), row(1, 'A'), row(178, 'B'), row(182, 'B')]
        val = [row(0, 'NEVER_TRAIN_ON_THIS_LABEL')]
        config = dict(recipe='raw', geometry='within_class', k=3, metric='euclidean')
        first = predict_config(train, val, config, 0)
        second = predict_config(train, val + [row(89, 'ANOTHER_UNKNOWN_LABEL')], config, 0)
        self.assertEqual(first[0].tolist(), ['A'])
        self.assertEqual(first[0].tolist(), second[0][:1].tolist())
        np.testing.assert_allclose(first[1], second[1][:1])

    def test_ordinal_prediction_never_uses_an_unseen_training_category(self):
        def row(level, h):
            f = np.tile([h, .5, .6], (10, 1))
            return dict(features=f, raw_features=f, labels={'Leukocytes': level})
        train = [row('5.0', 30), row('5.0', 31), row('7.0', 32)]
        config = dict(recipe='raw', geometry='scaled', k=3, metric='euclidean', aggregation='ordinal_mean')
        prediction, confidence, _ = predict_config(train, [row('6.0', 31.5)], config, 0)
        self.assertIn(prediction[0], {'5.0', '7.0'})
        self.assertGreaterEqual(confidence[0], 0)
        self.assertLessEqual(confidence[0], 1)


if __name__ == '__main__':
    unittest.main()
