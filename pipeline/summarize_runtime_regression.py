"""Report before/after development image regression without hiding abstentions."""
import json
import pathlib
from audit_abnormal_detection import RULES, metrics
from semiquant_schema import ANALYTE_ORDER, canonicalize_level

AUDIT=pathlib.Path(__file__).resolve().parent/'output'/'abnormal_error_audit_2026-10-05'
def main():
    raw=json.loads((AUDIT/'runtime_before_after_regression.json').read_text())
    cases=raw['cases']; report={'scope':raw['scope'],'attempted_images':len(cases),'stages':{}}
    for stage in ('before','after'):
        accepted=[r for r in cases if r[stage]['accepted']]
        per_analyte={}
        for analyte in ANALYTE_ORDER:
            truth=[r['reference_labels'][analyte] for r in accepted]
            pred=[canonicalize_level(analyte,r[stage]['predictions'][analyte]) for r in accepted]
            assert all(p is not None for p in pred)
            per_analyte[analyte]=metrics(truth,pred,[r['source_zip']+'|'+r['event_id'] for r in accepted],analyte)
            per_analyte[analyte]['retaken_reference_positive_captures']={name:sum(not r[stage]['accepted'] and r['reference_labels'][analyte] in levels for r in cases) for name,levels in RULES.get(analyte,{}).items()}
        whole_correct=sum(all(canonicalize_level(a,r[stage]['predictions'][a])==r['reference_labels'][a] for a in ANALYTE_ORDER) for r in accepted)
        report['stages'][stage]={'accepted':len(accepted),'retaken':len(cases)-len(accepted),'all_ten_exact_correct':whole_correct,'per_analyte_accepted_reference_comparisons':per_analyte}
    report['recovered_capture_ids']=[r['event_id'] for r in cases if not r['before']['accepted'] and r['after']['accepted']]
    report['regressed_capture_ids']=[r['event_id'] for r in cases if r['before']['accepted'] and not r['after']['accepted']]
    report['shared_accepted_prediction_changes']=[r['event_id'] for r in cases if r['before']['accepted'] and r['after']['accepted'] and r['before']['predictions']!=r['after']['predictions']]
    report['limitations']='18 purposively selected development photos, correlated captures, inspected labels, unverified clinical references. No final-test or classifier-improvement claim. Retakes are not counted as negative predictions.'
    assert not report['regressed_capture_ids']
    assert not report['shared_accepted_prediction_changes']
    (AUDIT/'runtime_regression_summary.json').write_text(json.dumps(report,indent=2,allow_nan=False),encoding='utf-8')
    print(json.dumps({k:v for k,v in report.items() if k!='stages'},indent=2))
    print({stage:{k:v for k,v in value.items() if k!='per_analyte_accepted_reference_comparisons'} for stage,value in report['stages'].items()})
if __name__=='__main__':
    main()
