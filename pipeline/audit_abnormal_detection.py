#!/usr/bin/env python3
"""Retrospective error audit and development comparison; never exports a model.

Historical predictions reproduce the old split for traceability, NOT final-test
claims. Filename-derived identity is explicitly provisional. A prospective
identity manifest must be verified before a final evaluation is designed.
"""
from __future__ import annotations
import argparse
import csv
import hashlib
import json
import pathlib
import re
from collections import defaultdict
import numpy as np
from sklearn.metrics import confusion_matrix, f1_score
from sklearn.model_selection import GroupShuffleSplit
from freeze_production_semiquant import DEFAULT_DEDUPED, DEFAULT_OPT, MODEL_VERSION, _load_rows, _make_model, _rows_for_analyte
from semiquant_schema import ANALYTE_ORDER, ANALYTE_LEVEL_SCHEMA

BASE = pathlib.Path(__file__).resolve().parent
# Current app decision boundaries, plus explicitly analytical non-negative
# comparisons. These are reference-label comparisons, not disease diagnosis.
RULES = {
    "Leukocytes": {
        "female_le_small_or_higher": {"Small 70", "Moderate 125", "Large 500"},
        "male_le_trace_or_higher": {"Trace 15", "Small 70", "Moderate 125", "Large 500"},
        "analytical_any_nonnegative": {"Trace 15", "Small 70", "Moderate 125", "Large 500"}},
    "Nitrite": {"nitrite_positive": {"Positive"}},
    "Protein": {
        "renal_protein_0_3_or_higher": {"0.3", "1.0", "3.0", ">=20.0"},
        "analytical_any_nonnegative": {"Trace", "0.3", "1.0", "3.0", ">=20.0"}},
    "Blood": {"female_blood_study_positive": {"Hemolyzed 10", "Small 25", "Moderate 80", "Large 200"},
              "analytical_any_nonnegative": {"Non-hemolyzed 10", "Hemolyzed 10", "Small 25", "Moderate 80", "Large 200"}},
    "Ketone": {"analytical_any_nonnegative": {"Trace 0.5", "Small 1.5", "Moderate 4.0", "8.0", "Large 16"}},
    "Bilirubin": {"analytical_any_nonnegative": {"Small 17", "Moderate 50", "Large 100"}},
    "Urobilinogen": {"analytical_above_baseline_category": {"16", "32", "64", "128"}},
    "Glucose": {"analytical_any_nonnegative": {"Trace 5", "15 +", "30 ++", "60 +++", "110 ++++"}},
}


def inferred_identity(row):
    # Conservatively group every capture of a named specimen/participant.
    # Batch is provenance namespace, NOT proof of cross-batch independence.
    event = row["event_id"].strip()
    stripped = re.sub(r"(?i)(?:[-_\s](?:L?(?:2700|4000|5500)K?|cool|warm|daylight))+$", "", event)
    participant = re.sub(r"(?i)[-_]S\d+$", "", stripped)
    return f"{row['batch_id']}|{participant}"


def rate(numerator, denominator):
    return numerator / denominator if denominator else None


def binary_counts(truth, prediction, positives):
    pairs = [(a in positives, p in positives) for a, p in zip(truth, prediction)]
    tp = sum(a and p for a, p in pairs)
    fn = sum(a and not p for a, p in pairs)
    fp = sum(not a and p for a, p in pairs)
    tn = sum(not a and not p for a, p in pairs)
    return dict(tp=tp, fn=fn, fp=fp, tn=tn, positive_support=tp+fn,
                negative_support=tn+fp, sensitivity=rate(tp,tp+fn), specificity=rate(tn,tn+fp))


def cluster_intervals(truth, prediction, groups, positives, repeats=500):
    """Percentile cluster bootstrap. Inferential unit is provisional identity.

    With <2 supporting groups the CI is withheld. Undefined draws are reported,
    never converted to zero. This is exploratory, not confirmatory precision.
    """
    blocks = defaultdict(list)
    for i, group in enumerate(groups):
        blocks[group].append(i)
    keys = sorted(blocks)
    support = {
        "sensitivity": len({g for a,g in zip(truth,groups) if a in positives}),
        "specificity": len({g for a,g in zip(truth,groups) if a not in positives})}
    draws = {"sensitivity": [], "specificity": []}
    rng = np.random.default_rng(42)
    for _ in range(repeats):
        indices = [i for key in rng.choice(keys, size=len(keys), replace=True) for i in blocks[key]]
        values = binary_counts([truth[i] for i in indices], [prediction[i] for i in indices], positives)
        for key in draws:
            if values[key] is not None:
                draws[key].append(values[key])
    return {key: {"provisional_support_groups": support[key],
                  "ci95": np.quantile(values,[.025,.975]).tolist() if support[key] >= 2 and values and min(values) != max(values) else None,
                  "defined_bootstrap_draws": len(values), "total_draws": repeats,
                  "limitation": "CI withheld for fewer than two supporting identities or degenerate draws. Small/imbalanced cohorts and unverified identity preclude confirmatory inference.",
                  "method": "exploratory inferred-identity cluster percentile bootstrap"}
            for key,values in draws.items()}


def metrics(truth, prediction, groups, analyte, intervals=False):
    labels = ANALYTE_LEVEL_SCHEMA[analyte]
    supported = [label for label in labels if label in truth]
    exact = {label: binary_counts(truth, prediction, {label}) for label in labels}
    thresholds = {}
    for name,positive in RULES.get(analyte,{}).items():
        result = binary_counts(truth, prediction, positive)
        result["positive_levels"] = sorted(positive)
        if intervals:
            result["uncertainty"] = cluster_intervals(truth, prediction, groups, positive)
        thresholds[name] = result
    return {"n": len(truth), "accuracy": rate(sum(a==p for a,p in zip(truth,prediction)),len(truth)),
            "macro_f1_supported_reference_classes": float(f1_score(truth,prediction,labels=supported,average="macro",zero_division=0)) if supported else None,
            "unsupported_reference_classes": [x for x in labels if x not in supported],
            "class_metrics": exact, "confusion": {"labels":labels,"matrix":confusion_matrix(truth,prediction,labels=labels).tolist()},
            "reference_label_thresholds": thresholds}


def validate_final_manifest(records, contract):
    """Fail closed on missing approval, reviewed test data, or identity leakage.

    The caller supplies the entire train/validation/test inventory. This checks
    metadata, not authenticity of a medtech signature or image bytes.
    """
    if not records:
        raise ValueError("Empty manifest")
    required = ("capture_id", "participant_id", "specimen_id", "image_sha256", "split", "identity_verified", "reference_adjudicated", "previously_reviewed")
    seen = {field:{} for field in ("capture_id","participant_id","specimen_id","image_sha256")}
    splits = set()
    for row in records:
        if any(not str(row.get(key,"")).strip() for key in required):
            raise ValueError("Missing required capture, identity, provenance or review fields")
        split = row["split"]
        if split not in {"train","validation","test"}:
            raise ValueError("Unknown split")
        splits.add(split)
        if row["identity_verified"] != "yes" or row["reference_adjudicated"] != "yes":
            raise ValueError("Identity and reference labels must be verified")
        if row["previously_reviewed"] not in {"yes","no"}:
            raise ValueError("Review status must be explicit")
        if split == "test" and row["previously_reviewed"] != "no":
            raise ValueError("Reviewed data cannot be an untouched final test")
        if not re.fullmatch(r"[0-9a-fA-F]{64}", row["image_sha256"]):
            raise ValueError("Image SHA256 must identify the actual captured file")
        for field in seen:
            value = row[field]
            if field == "image_sha256":
                value = value.lower()
            previous = seen[field].get(value)
            if previous is not None and (previous != split or field == "capture_id"):
                raise ValueError(f"Duplicate capture or cross-split {field}: {value}")
            seen[field][value] = split
    if splits != {"train","validation","test"}:
        raise ValueError("Supply complete train/validation/test inventory")
    if contract.get("status") != "approved" or not contract.get("clinical_adviser") or not contract.get("statistician") or not contract.get("signed_at"):
        raise ValueError("Acceptance contract needs clinical adviser and statistician approval")
    for field in ("minimum_sensitivity", "minimum_specificity", "maximum_retake_rate", "maximum_ci_width"):
        value = contract.get(field)
        if not isinstance(value,(float,int)) or isinstance(value,bool) or not 0 <= value <= 1:
            raise ValueError(f"Acceptance contract missing valid {field}")
    if not isinstance(contract.get("independent_specimens_per_threshold"),dict) or not contract["independent_specimens_per_threshold"]:
        raise ValueError("Statistician must specify independent sample sizes by threshold")
    for threshold, counts in contract["independent_specimens_per_threshold"].items():
        if not isinstance(counts, dict) or any(not isinstance(counts.get(side), int) or isinstance(counts.get(side), bool) or counts[side] < 1 for side in ("positive", "negative")):
            raise ValueError(f"Specify positive and negative independent sample targets for {threshold}")
    for name in ("locked_model_sha256", "locked_analysis_plan_sha256"):
        if not re.fullmatch(r"[0-9a-fA-F]{64}",str(contract.get(name,""))):
            raise ValueError(f"Missing lock: {name}")
    return {"status":"metadata_checks_passed", "captures":len(records),
            "note":"This validates metadata only; it does not run or approve a final evaluation."}


def write_csv(path, records):
    if not records:
        return
    with path.open('w',newline='',encoding='utf-8') as file:
        writer = csv.DictWriter(file,fieldnames=list(records[0]))
        writer.writeheader()
        writer.writerows(records)


def usable_rows(rows, analyte):
    subset = [row for row in rows if row['analyte']==analyte]
    x,y,g,events = _rows_for_analyte(rows,analyte)
    # Fail instead of silently aligning a filtered feature vector to wrong row.
    if len(subset) != len(x):
        raise ValueError(f"Invalid feature/label rows for {analyte}; resolve before audit")
    return subset,x,y,g,events


def historical_audit(rows, optimization):
    report = {"purpose":"retrospective development error review; not untouched test performance",
              "model_version": MODEL_VERSION, "identity_status":"filename-inferred; not independently verified",
              "selection_bias":"Configurations were selected using this split; results are not an independent model evaluation.",
              "per_analyte":{}}
    predictions = []
    review = []
    for analyte in ANALYTE_ORDER:
        subset,x,y,groups,events = usable_rows(rows,analyte)
        train,test = next(GroupShuffleSplit(n_splits=1,test_size=.2,random_state=42).split(x,y,groups))
        params = optimization[analyte]
        model = _make_model(min(int(params['best_k']),len(train)), params['best_metric'],params.get('feature_transform','raw'))
        model.fit([x[i] for i in train],[y[i] for i in train])
        probabilities = model.predict_proba([x[i] for i in test])
        pred = model.classes_[np.argmax(probabilities,axis=1)].tolist()
        confidence = np.max(probabilities,axis=1).tolist()
        provisional = [inferred_identity(subset[i]) for i in test]
        overlaps = sorted({inferred_identity(subset[i]) for i in train} & set(provisional))
        result = metrics([y[i] for i in test],pred,provisional,analyte,True)
        result['historical_split_related_identity_overlap'] = overlaps
        accepted = [j for j,c in enumerate(confidence) if c >= .45]
        result['feature_stage_abstention'] = {
            'confidence_threshold':.45, 'accepted':len(accepted), 'retakes':len(test)-len(accepted),
            'retake_rate':rate(len(test)-len(accepted),len(test)),
            'accepted_scan_metrics':metrics([y[test[j]] for j in accepted],[pred[j] for j in accepted],[provisional[j] for j in accepted],analyte) if accepted else None,
            'limitation':'Reconstructed kNN vote confidence on extracted features only. Missing detection/timing/image failures are not represented; not measured app retake rate.'}
        report['per_analyte'][analyte] = result
        for j,i in enumerate(test):
            row = subset[i]
            crossings = [name for name,positive in RULES.get(analyte,{}).items() if (y[i] in positive)!=(pred[j] in positive)]
            record = dict(event_key=events[i],event_id=row['event_id'],source_zip=row['source_zip'],batch_id=row['batch_id'],
                          provisional_identity=provisional[j],light_kelvin=row['light_kelvin'],analyte=analyte,
                          reference_label=y[i],predicted_label=pred[j],exact_correct=y[i]==pred[j],confidence=confidence[j],
                          feature_stage_accepted=confidence[j]>=.45,threshold_crossings=';'.join(crossings),
                          related_identity_in_training=provisional[j] in overlaps)
            predictions.append(record)
            abnormal = any(y[i] in levels for levels in RULES.get(analyte,{}).values())
            if abnormal or y[i]!=pred[j]:
                review.append(dict(record, image_path='',pad_crop_path='',strip_brand_lot='',ifu_revision='',
                                   dip_time='',capture_time='',pad_read_time='',reviewer_1='',reviewer_1_label='',
                                   reviewer_2='',reviewer_2_label='',adjudicated_label='',
                                   label_issue='unreviewed',timing_issue='unreviewed',localization_issue='unreviewed',
                                   lighting_issue='unreviewed',classification_issue='unreviewed',root_cause='unresolved',
                                   review_status='pending',review_notes=''))
    events = defaultdict(list)
    for row in predictions:
        events[row['event_key']].append(row)
    complete = [rs for rs in events.values() if len(rs)==10 and len({r['analyte'] for r in rs})==10]
    accepted = [rs for rs in complete if all(r['feature_stage_accepted'] for r in rs)]
    report['summary'] = dict(individual_correct=sum(r['exact_correct'] for r in predictions),individual_total=len(predictions),
                            complete_events=len(complete),all_10_correct=sum(all(r['exact_correct'] for r in rs) for rs in complete),
                            feature_stage_accepted_events=len(accepted),feature_stage_retake_events=len(complete)-len(accepted),
                            accepted_all_10_correct=sum(all(r['exact_correct'] for r in rs) for rs in accepted),
                            unrepresented_input_failures='unknown; capture logs and failed images required')
    return report,predictions,review


def development_benchmark(rows):
    """One provisional participant split shared by every analyte. No final test.

    Class balancing reweights votes by TRAINING class support only; no duplicate
    specimens are manufactured. Results remain validation diagnostics.
    """
    identities = sorted({inferred_identity(r) for r in rows})
    train,test = next(GroupShuffleSplit(n_splits=1,test_size=.25,random_state=20261005).split(identities,groups=identities))
    train_groups = {identities[i] for i in train}
    validation_groups = {identities[i] for i in test}
    results = {'purpose':'development validation only; no final test or model promotion',
               'identity_status':'provisional filename identities; confirm repeated participants across batches',
               'train_groups':len(train_groups),'validation_groups':len(validation_groups),'per_analyte':{}}
    for analyte in ANALYTE_ORDER:
        subset,x,y,_,_ = usable_rows(rows,analyte)
        tr = [i for i,r in enumerate(subset) if inferred_identity(r) in train_groups]
        va = [i for i,r in enumerate(subset) if inferred_identity(r) in validation_groups]
        candidates = []
        for k in (3,5,11):
            for transform in ('raw','scaled'):
                model = _make_model(min(k,len(tr)),'euclidean',transform)
                model.fit([x[i] for i in tr],[y[i] for i in tr])
                probs = model.predict_proba([x[i] for i in va])
                counts = np.array([sum(y[i]==label for i in tr) for label in model.classes_])
                for balanced in (False,True):
                    votes = probs/counts if balanced else probs
                    pred = model.classes_[np.argmax(votes,axis=1)].tolist()
                    value = metrics([y[i] for i in va],pred,[inferred_identity(subset[i]) for i in va],analyte)
                    rulevalues = list(value['reference_label_thresholds'].values())
                    sens = [v['sensitivity'] for v in rulevalues if v['sensitivity'] is not None]
                    spec = [v['specificity'] for v in rulevalues if v['specificity'] is not None]
                    value.update(k=k,transform=transform,balanced_training_prior_votes=balanced,
                                 mean_threshold_sensitivity=float(np.mean(sens)) if sens else None,
                                 mean_threshold_specificity=float(np.mean(spec)) if spec else None)
                    candidates.append(value)
        # Explicit diagnostic ranking; specificity remains visible. A clinician's
        # approved specificity constraint is required before accepting a choice.
        candidates.sort(key=lambda c:(c['mean_threshold_sensitivity'] if c['mean_threshold_sensitivity'] is not None else -1,
                                      c['macro_f1_supported_reference_classes'],
                                      c['mean_threshold_specificity'] if c['mean_threshold_specificity'] is not None else -1), reverse=True)
        results['per_analyte'][analyte] = {'ranked_candidates':candidates,'selected_model':None,
            'reason':'No approved sensitivity/specificity tradeoff or verified independent final cohort.'}
    results['split_assignments'] = {identity: ('train' if identity in train_groups else 'validation') for identity in identities}
    return results


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--features',type=pathlib.Path,default=DEFAULT_DEDUPED)
    parser.add_argument('--output-dir',type=pathlib.Path,default=BASE/'output'/'abnormal_error_audit_2026-10-05')
    parser.add_argument('--benchmark',action='store_true')
    parser.add_argument('--final-manifest',type=pathlib.Path)
    parser.add_argument('--acceptance-contract',type=pathlib.Path)
    args = parser.parse_args()
    if args.final_manifest:
        if not args.acceptance_contract:
            parser.error('--acceptance-contract is required with --final-manifest')
        print(json.dumps(validate_final_manifest(_load_rows(args.final_manifest),json.loads(args.acceptance_contract.read_text())),indent=2))
        return
    rows = _load_rows(args.features)
    optimization = json.loads(DEFAULT_OPT.read_text())
    report,predictions,review = historical_audit(rows,optimization)
    report['features_sha256'] = hashlib.sha256(args.features.read_bytes()).hexdigest()
    args.output_dir.mkdir(parents=True,exist_ok=True)
    (args.output_dir/'retrospective_audit.json').write_text(json.dumps(report,indent=2,allow_nan=False),encoding='utf-8')
    write_csv(args.output_dir/'historical_predictions.csv',predictions)
    # Preserve a teammate's manual review entries on subsequent runs.
    review_path = args.output_dir/'abnormal_error_review.csv'
    if not review_path.exists():
        write_csv(review_path,review)
    else:
        print('Existing manual review preserved; use a new output directory for a fresh seed.')
    plan = []
    for analyte,rules in RULES.items():
        for name,levels in rules.items():
            matching = [r for r in rows if r['analyte']==analyte and r['level'] in levels]
            test = report['per_analyte'][analyte]['reference_label_thresholds'][name]
            plan.append(dict(analyte=analyte,threshold=name,positive_levels=';'.join(sorted(levels)),
                             existing_positive_captures=len(matching),existing_provisional_positive_identities=len({inferred_identity(r) for r in matching}),
                             historical_positive_test_captures=test['positive_support'],historical_missed_positive_captures=test['fn'],
                             required_new_independent_positive_specimens='',required_new_independent_negative_specimens='',
                             final_cohort_target='',clinical_adviser_approval='',statistician_approval='',
                             priority='urgent' if analyte in {'Nitrite','Leukocytes','Protein','Glucose'} else 'review',
                             notes='Repeated lighting photographs count as repeatability only; verify identity and medtech reference. Targets require precision/sample-size approval.'))
    # Collection must support exact abnormal categories as well as thresholds.
    for analyte in ('Leukocytes','Nitrite','Protein','Glucose'):
        for level in ANALYTE_LEVEL_SCHEMA[analyte]:
            if level == 'Neg':
                continue
            matching = [r for r in rows if r['analyte']==analyte and r['level']==level]
            test = report['per_analyte'][analyte]['class_metrics'][level]
            plan.append(dict(analyte=analyte,threshold='exact_category:'+level,positive_levels=level,
                             existing_positive_captures=len(matching),existing_provisional_positive_identities=len({inferred_identity(r) for r in matching}),
                             historical_positive_test_captures=test['positive_support'],historical_missed_positive_captures=test['fn'],
                             required_new_independent_positive_specimens='',required_new_independent_negative_specimens='',final_cohort_target='',
                             clinical_adviser_approval='',statistician_approval='',priority='urgent',
                             notes='Exact-category errors are not all threshold misses. Confirm labels and recruit independent specimens; repeats do not meet sample targets.'))
    write_csv(args.output_dir/'targeted_collection_plan.csv',plan)
    if args.benchmark:
        benchmark = development_benchmark(rows)
        (args.output_dir/'development_candidate_comparison.json').write_text(json.dumps(benchmark,indent=2,allow_nan=False),encoding='utf-8')
    print(json.dumps(report['summary'],indent=2))
    print(f'Artifacts: {args.output_dir}')


if __name__ == '__main__':
    main()
