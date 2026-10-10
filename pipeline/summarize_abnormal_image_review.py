"""Link technical image evidence without overwriting clinical review fields."""
import csv
import json
import pathlib
from collections import defaultdict
from audit_abnormal_detection import write_csv

BASE=pathlib.Path(__file__).resolve().parent
AUDIT=BASE/'output'/'abnormal_error_audit_2026-10-05'

def main():
    old=json.loads((AUDIT/'image_evidence_index.json').read_text())
    new=json.loads((AUDIT/'image_evidence_geometry_checked_index.json').read_text())
    old_by={r['event_id']:r for r in old['priority_evidence']}
    new_by={r['event_id']:r for r in new['priority_evidence']}
    rows=list(csv.DictReader((AUDIT/'abnormal_error_review.csv').open(newline='',encoding='utf-8')))
    quarantine=[]
    for row in rows:
        checked=new_by.get(row['event_id'])
        row['checked_crop_status']=checked['crop_status'] if checked else 'not_priority_crop_review'
        row['checked_pad_crop_path']=(checked or {}).get('pad_crops',{}).get(row['analyte'],'')
        row['checked_overlay_path']=(checked or {}).get('overlay_path','')
        row['checked_pad_gap_cv']=(checked or {}).get('pad_gap_cv','')
        row['cached_features_need_review']='yes' if checked and (checked['crop_status'].startswith('extraction_failed') or checked.get('pad_rois')!=old_by[row['event_id']].get('pad_rois')) else 'not_established'
        if row['event_id']=='LAUAAN-P018-L2700' and row['localization_issue']=='unreviewed':
            row['localization_issue']='yes'
            row['review_notes']=(row['review_notes']+' Technical review 2026-10-05: historical first boxes include background above the physical strip; spacing-only revision still includes a plastic gap/handle. Full geometry guard rejects this image. Clinical category and IFU timing remain unverified.').strip()
    write_csv(AUDIT/'abnormal_error_review.csv',rows)
    for event,record in new_by.items():
        if record['crop_status'].startswith('extraction_failed') or record.get('pad_rois')!=old_by[event].get('pad_rois'):
            quarantine.append(dict(event_id=event,reason='geometry_rejected' if record['crop_status'].startswith('extraction_failed') else 'pad_locations_changed',image_path=record['image_path'],source_package=record['package_path'],action='Review full image and pad sequence; re-extract all ten features only after technical validation; keep labels unchanged pending medtech adjudication.'))
    write_csv(AUDIT/'cached_feature_review_queue.csv',quarantine)
    summary={'resolved_source_events':new['resolved_events'],'linked_review_records':len(rows),
             'priority_events':new['priority_events'],'geometry_extractions_requiring_review':new['crop_successes'],
             'geometry_rejections':new['crop_failures'],'cached_feature_review_events':len(quarantine),
             'clinical_labels_changed':0,'production_models_changed':False,
             'note':'A passed geometric check does not establish correct anatomical pad identity, timing or clinical reference. Review remains pending.'}
    (AUDIT/'technical_review_summary.json').write_text(json.dumps(summary,indent=2),encoding='utf-8')
    assert all(pathlib.Path(r['image_path']).exists() for r in rows)
    print(json.dumps(summary,indent=2))

if __name__=='__main__':
    main()
