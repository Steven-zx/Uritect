#!/usr/bin/env python3
"""Resolve audit events to package photos and prepare traceable research crops.

No labels are changed. A successful crop is not a clinical adjudication.
"""
import argparse
import csv
import hashlib
import io
import json
import pathlib
import re
import zipfile
from collections import defaultdict
import numpy as np
import cv2
from PIL import Image, ImageOps, ImageDraw
from audit_abnormal_detection import RULES, write_csv
from scan_dipstick import _process_best_orientation, _iter_bgr_orientation_variants
from vision_pipeline import VisionPipelineConfig

BASE = pathlib.Path(__file__).resolve().parent
ROOT = BASE.parent

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--audit-dir',type=pathlib.Path,default=BASE/'output'/'abnormal_error_audit_2026-10-05')
    parser.add_argument('--evidence-name',default='image_evidence_spacing_checked')
    parser.add_argument('--packages-dir',type=pathlib.Path,default=pathlib.Path.home()/'Documents'/'uritect_training_dataset'/'packages')
    args=parser.parse_args()
    with (args.audit_dir/'abnormal_error_review.csv').open(encoding='utf-8',newline='') as f:
        rows=list(csv.DictReader(f))
    package_candidates = [args.packages_dir/'LAUAAN_20260730_ID_CLEANED_2026-07-30.zip',
        *sorted((BASE/'dataset'/'cabatuan_cleaned').glob('*/*holdout_package.zip'))]
    lookup={}
    for path in package_candidates:
        if not path.exists():
            continue
        with zipfile.ZipFile(path) as archive:
            index=list(csv.DictReader(io.StringIO(archive.read('training_index.csv').decode('utf-8-sig'))))
            for record in index:
                event=record['event_id']
                lookup[(path.name,event)]=(path,record)
    evidence=args.audit_dir/args.evidence_name
    if evidence.resolve().parent != args.audit_dir.resolve():
        raise ValueError('Evidence output must stay directly within the audit directory')
    evidence.mkdir(parents=True,exist_ok=True)
    resolved={}
    missing=[]
    for row in rows:
        key=(row['source_zip'],row['event_id'])
        if key in resolved:
            continue
        found=lookup.get(key)
        if found is None:
            missing.append(key)
            continue
        path,record=found
        entry=record['relative_image_path']
        with zipfile.ZipFile(path) as archive:
            data=archive.read(entry)
        image_hash=hashlib.sha256(data).hexdigest()
        # Safe filename chosen by us, not an archive extraction path.
        token=re.sub(r'[^A-Za-z0-9_-]','_',row['event_id'])
        destination=evidence/(token+pathlib.Path(entry).suffix.lower())
        if not destination.exists():
            destination.write_bytes(data)
        resolved[key]={'image_path':str(destination.resolve()),'image_sha256':image_hash,
                       'package_path':str(path.resolve()),'package_entry':entry,
                       'reference_source':'processed package training_index.csv; medtech adjudication pending'}
    targets=defaultdict(list)
    for row in rows:
        positive_rules=RULES.get(row['analyte'],{})
        missed=any(row['reference_label'] in levels and row['predicted_label'] not in levels for levels in positive_rules.values())
        if row['analyte'] in {'Leukocytes','Nitrite','Protein','Glucose'} and missed:
            targets[(row['source_zip'],row['event_id'])].append(row)
    index=[]
    for number,(key,records) in enumerate(targets.items(),1):
        if key not in resolved:
            continue
        source=pathlib.Path(resolved[key]['image_path'])
        token=source.stem
        record=dict(resolved[key],event_id=key[1],requested_analytes=[r['analyte'] for r in records])
        try:
            extraction,variant,score=_process_best_orientation(source,VisionPipelineConfig(feature_space='normalized_hsv'))
            image_bgr=next(frame for name,frame in _iter_bgr_orientation_variants(source) if 'markerless_'+name==variant)
            rgb=cv2.cvtColor(image_bgr,cv2.COLOR_BGR2RGB)
            image=Image.fromarray(rgb)
            overlay=image.copy(); draw=ImageDraw.Draw(overlay)
            crops={}
            for analyte,(x,y,w,h) in extraction.pad_rois.items():
                draw.rectangle((x,y,x+w-1,y+h-1),outline='#ff3344',width=max(2,image.width//700))
                draw.text((x+w+3,y),analyte,fill='#ff3344')
                crop_path=evidence/(token+'_'+analyte.replace(' ','_')+'_pad.png')
                image.crop((x,y,x+w,y+h)).save(crop_path)
                crops[analyte]=str(crop_path.resolve())
            overlay.thumbnail((700,1000))
            overlay_path=evidence/(token+'_roi_overlay.png'); overlay.save(overlay_path)
            centers=[xywh[1]+xywh[3]/2 for xywh in extraction.pad_rois.values()]
            gaps=np.diff(centers)
            gap_cv=float(np.std(gaps)/np.median(gaps))
            record.update(crop_status='extracted_requires_review',orientation=variant,quality=score,pad_gap_cv=gap_cv,
                          overlay_path=str(overlay_path.resolve()),pad_crops=crops,pad_rois=extraction.pad_rois,
                          extracted_features=extraction.features_by_pad)
        except Exception as error:
            record.update(crop_status='extraction_failed_requires_review',error=str(error))
        index.append(record)
        print(f'{number}/{len(targets)} {key[1]}: {record["crop_status"]}',flush=True)
    by_event={r['event_id']:r for r in index}
    for row in rows:
        key=(row['source_zip'],row['event_id'])
        if key in resolved and not row['image_path']:
            row['image_path']=resolved[key]['image_path']
        match=by_event.get(row['event_id'],{})
        if not row['pad_crop_path']:
            row['pad_crop_path']=match.get('pad_crops',{}).get(row['analyte'],'')
    write_csv(args.audit_dir/'abnormal_error_review.csv',rows)
    report={'scope':'technical image/crop recovery; reference labels unchanged',
            'resolved_events':len(resolved),'unresolved_events':missing,'review_rows':len(rows),
            'priority_events':len(targets),'crop_successes':sum(r['crop_status']=='extracted_requires_review' for r in index),
            'crop_failures':sum(r['crop_status']!='extracted_requires_review' for r in index),
            'clinical_adjudication':'pending','image_sources':list(resolved.values()),'priority_evidence':index}
    (args.audit_dir/(args.evidence_name+'_index.json')).write_text(json.dumps(report,indent=2),encoding='utf-8')
    print(json.dumps({k:v for k,v in report.items() if k not in {'image_sources','priority_evidence'}},indent=2))

if __name__=='__main__':
    main()
