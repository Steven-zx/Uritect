"""Report apparent training fit and reproduce historical development metrics.

No production model, dataset, APK, or existing evaluation is overwritten.
"""
from __future__ import annotations

import hashlib
import json
from datetime import datetime, timezone
from pathlib import Path
from statistics import mean

import numpy as np
from sklearn import __version__ as sklearn_version
from sklearn.metrics import accuracy_score, cohen_kappa_score, confusion_matrix, f1_score
from sklearn.model_selection import GroupShuffleSplit

from evaluate_final_production_metrics import one_vs_rest_metrics
from freeze_production_semiquant import (
    DEFAULT_DEDUPED, DEFAULT_OPT, MODEL_VERSION, _load_rows, _make_model, _rows_for_analyte,
)
from semiquant_schema import ANALYTE_ORDER

OUTPUT = Path(__file__).parent / 'output' / 'knn_five_metric_evaluation_2026-10-10'
KEYS = ('accuracy', 'macro_f1', 'macro_sensitivity', 'macro_specificity', 'cohen_kappa')


def measure(truth, predicted):
    labels = sorted(set(truth) | set(predicted))
    ovsr = one_vs_rest_metrics(truth, predicted, labels)
    matrix = confusion_matrix(truth, predicted, labels=labels)
    return {
        'accuracy': float(accuracy_score(truth, predicted)),
        'macro_f1': float(f1_score(truth, predicted, labels=labels, average='macro', zero_division=0)),
        'macro_sensitivity': ovsr['macro_sensitivity'],
        'macro_specificity': ovsr['macro_specificity'],
        'cohen_kappa': float(cohen_kappa_score(truth, predicted, labels=labels)),
        'predictions': len(truth),
        'correct': sum(a == b for a, b in zip(truth, predicted)),
        'class_metrics': ovsr['per_class'],
        'confusion_matrix': {'labels': labels, 'matrix': matrix.tolist()},
    }


def main():
    rows = _load_rows(DEFAULT_DEDUPED)
    configuration = json.loads(DEFAULT_OPT.read_text(encoding='utf-8'))
    historical = json.loads((Path(__file__).parent / 'output' / 'production_grouped_metrics_complete.json').read_text())
    reports = {name: {} for name in ('production_training_resubstitution', 'historical_split_training_resubstitution', 'historical_split_development_test')}
    predictions = []
    for analyte in ANALYTE_ORDER:
        x, y, groups, events = _rows_for_analyte(rows, analyte)
        assert np.isfinite(np.asarray(x, dtype=float)).all(), analyte
        parameters = configuration[analyte]
        k = int(parameters.get('best_k', parameters.get('k', 5)))
        metric = str(parameters.get('best_metric', parameters.get('metric', 'euclidean')))
        transform = str(parameters.get('feature_transform', 'raw'))
        train, test = next(GroupShuffleSplit(n_splits=1, test_size=.2, random_state=42).split(x, y, groups))
        assert set(groups[i] for i in train).isdisjoint(groups[i] for i in test)
        split_model = _make_model(k, metric, transform).fit([x[i] for i in train], [y[i] for i in train])
        full_model = _make_model(k, metric, transform).fit(x, y)
        partitions = (
            ('production_training_resubstitution', range(len(y)), full_model),
            ('historical_split_training_resubstitution', train, split_model),
            ('historical_split_development_test', test, split_model),
        )
        for name, indices, model in partitions:
            truth = [y[i] for i in indices]
            predicted = model.predict([x[i] for i in indices]).tolist()
            result = measure(truth, predicted)
            result['model'] = {'k': k, 'metric': metric, 'feature_transform': transform, 'weights': 'distance'}
            result['represented_groups'] = len(set(groups[i] for i in indices))
            reports[name][analyte] = result
            assert sum(map(sum, result['confusion_matrix']['matrix'])) == len(truth)
            if name == 'historical_split_development_test':
                for key in KEYS:
                    assert abs(result[key] - historical['per_analyte'][analyte][key]) < 1e-12, (analyte, key)
            predictions.extend({'partition': name, 'analyte': analyte, 'feature_index': int(i), 'event': events[i], 'actual': actual, 'predicted': pred} for i, actual, pred in zip(indices, truth, predicted))
    output = {
        'generated_at': datetime.now(timezone.utc).isoformat(),
        'report_date_Asia_Manila': '2026-10-10',
        'model_version': MODEL_VERSION,
        'sklearn_version': sklearn_version,
        'inputs': {str(path): hashlib.sha256(path.read_bytes()).hexdigest() for path in (DEFAULT_DEDUPED, DEFAULT_OPT)},
        'design': {
            'production_training_resubstitution': 'Fit each classifier to all constructed feature rows, then predict those same rows. Self-neighbors are included. Apparent fit only.',
            'historical_split_training_resubstitution': 'Fit to historical 80% grouped partition, then predict those same training rows.',
            'historical_split_development_test': 'Predict historical 20% grouped partition. GroupShuffleSplit, specimen_group, random_state=42. Reproduces prior report, but related-capture grouping is imperfect and configurations were tuned on this split.',
            'sensitivity_specificity': 'Unweighted means of per-category one-vs-rest TP/(TP+FN) and TN/(TN+FP). Labels are union of actual and predicted categories within each partition. Undefined denominators use zero to reproduce the historical convention. Not clinical positive-versus-negative sensitivity/specificity.',
            'kappa': 'Unweighted Cohen kappa, not ordinal weighted kappa.',
            'scope': 'Cached-feature classification only. No image-detector, confidence-abstention or new distance-rejection filtering. No independent clinical validation.',
        },
        'per_partition': reports,
        'macro_across_analytes': {name: {key: mean(values[key] for values in table.values()) for key in KEYS} for name, table in reports.items()},
        'verification': 'All 50 historical per-analyte metric values reproduced within 1e-12; confusion matrix totals reconciled.',
    }
    OUTPUT.mkdir(parents=True, exist_ok=True)
    (OUTPUT / 'metrics.json').write_text(json.dumps(output, indent=2, allow_nan=False)+'\n', encoding='utf-8')
    (OUTPUT / 'predictions.json').write_text(json.dumps(predictions, indent=2)+'\n', encoding='utf-8')
    markdown = ['# URITECT per-analyte k-NN evaluation', '', 'Evaluated 10 October 2026. Frozen production settings; constructed normalized-HSV feature dataset. No production artifacts changed.', '']
    for name, table in reports.items():
        markdown.extend(['## '+name.replace('_', ' '), '', output['design'][name], '', '| Analyte | n | Accuracy | Macro F1 | Macro sensitivity | Macro specificity | Cohen kappa |', '| --- | ---: | ---: | ---: | ---: | ---: | ---: |'])
        for analyte, values in table.items():
            markdown.append(f"| {analyte} | {values['predictions']} | {values['accuracy']:.2%} | {values['macro_f1']:.2%} | {values['macro_sensitivity']:.2%} | {values['macro_specificity']:.2%} | {values['cohen_kappa']:.4f} |")
        markdown.append('')
    markdown.extend(['## Interpretation', '', *[value+'\n' for key, value in output['design'].items() if key in ('sensitivity_specificity', 'kappa', 'scope')], 'Distance-weighted k-NN can obtain perfect apparent training fit because each training row is its own zero-distance neighbor. This does not establish generalization. Use the development test results to discuss observed weaknesses, and a new specimen-independent test set for final claims.', '', output['verification'], '', 'Run: `.venv/Scripts/python.exe pipeline/evaluate_knn_training_metrics.py`', ''])
    (OUTPUT / 'REPORT.md').write_text('\n'.join(markdown), encoding='utf-8')
    print(json.dumps(output['macro_across_analytes'], indent=2))
    print('Report:', OUTPUT / 'REPORT.md')


if __name__ == '__main__':
    main()
