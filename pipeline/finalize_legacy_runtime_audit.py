"""Finalize the source audit with current-app geometry, retaining first-pass records."""
import json
import csv
import html
from collections import Counter
from pathlib import Path
from types import SimpleNamespace
import cv2
import numpy as np
from audit_legacy_dataset import DEFAULT_OUT, ROOT, dump, geometry_quality, file_digest
from semiquant_schema import ANALYTE_ORDER
from vision_pipeline import feature_columns_for_analyte


def run(out=DEFAULT_OUT):
    manifest=json.loads((out/'RUNTIME_MANIFEST.json').read_text())
    assert manifest['app_detector_sha256']==file_digest(ROOT/'uritect_app/lib/services/local_scan_analysis_service.dart')
    inventory=json.loads((out/'INVENTORY.json').read_text())
    first=json.loads((out/'PHOTO_AUDIT.json').read_text())
    by_hash={r['image_sha256']:r for r in first}
    records=[]
    for p in inventory['photos']:
        record=dict(by_hash[p['image_sha256']])
        record['first_pass_status']=record['status']
        if not p['eligible_labels']:
            record['status']='excluded_reference_conflict' if p['reference_conflict'] else record['status']
            records.append(record);continue
        path=out/'runtime_detector'/f'{p["image_sha256"]}.json'
        assert path.exists(),f'Unfinished runtime audit: {p["image_sha256"]}'
        native=json.loads(path.read_text())
        assert native.get('app_preflight_checked') is True
        record['original_photo_runtime_passed']=native['geometry_passed']
        alternate=out/'runtime_context_crop_detector'/path.name
        if not native['geometry_passed'] and alternate.exists():
            crop_native=json.loads(alternate.read_text())
            assert crop_native.get('app_preflight_checked') is True
            if crop_native['geometry_passed']:
                record['original_photo_runtime_error']=native['error']
                native=crop_native;path=alternate
        if not native['geometry_passed']:
            record.update(status='excluded_app_quality_or_geometry',reason=native['error'],localization_method='unchanged_app_detector')
            records.append(record);continue
        image=cv2.imread(str(path.with_name(f'{p["image_sha256"]}.frame.png')))
        assert image is not None
        try:
            quality=geometry_quality(image,SimpleNamespace(pad_rois={a:tuple(native['rois'][a]) for a in ANALYTE_ORDER}))
        except Exception as error:
            record.update(status='excluded_sampling_boundary_or_quality',reason=str(error),localization_method=native['variant'])
            records.append(record);continue
        rois=native['rois'];folder=out/'cleaned'/p['image_sha256'];folder.mkdir(exist_ok=True)
        xs=[r[0] for r in rois.values()];ys=[r[1] for r in rois.values()]
        right=max(r[0]+r[2] for r in rois.values());bottom=max(r[1]+r[3] for r in rois.values())
        size=max(r[2] for r in rois.values());gap=float(np.median(np.diff([r[1]+r[3]/2 for r in rois.values()])))
        x0,y0=max(0,min(xs)-int(size*1.5)),max(0,min(ys)-int(gap*.65))
        x1,y1=min(image.shape[1],right+int(size*1.5)),min(image.shape[0],bottom+int(gap*4.5))
        strip=image[y0:y1,x0:x1].copy(); overlay=strip.copy()
        for a,(x,y,w,h) in rois.items():
            crop=image[y:y+h,x:x+w]
            assert crop.shape[:2]==(h,w)
            cv2.imwrite(str(folder/f'{a.replace(" ","_")}.png'),crop)
            cv2.rectangle(overlay,(x-x0,y-y0),(x+w-x0,y+h-y0),(170,110,0),1)
        cv2.imwrite(str(folder/'strip.png'),strip);cv2.imwrite(str(folder/'overlay.png'),overlay)
        record.update(status='accepted_training',reason='',features=native['features'],raw_features=native['raw_features'],
            rois=rois,quality=quality,native_quality=native['quality'],feature_recipe='unchanged_Dart_runtime_normalized_hsv',
            localization_method=native['variant'],feature_frame_width=image.shape[1],feature_frame_height=image.shape[0],
            runtime_input_kind=native.get('input_kind','original_photo'),runtime_input_sha256=native.get('input_sha256',p['image_sha256']),
            strip=f'cleaned/{p["image_sha256"]}/strip.png',overlay=f'cleaned/{p["image_sha256"]}/overlay.png')
        records.append(record)
    supplementary=out/'UNPACKED_PHOTO_AUDIT.json'
    if supplementary.exists(): records.extend(json.loads(supplementary.read_text()))
    # Deduplicate identical decoded pixels as well as archive bytes. Conflicting
    # references remain excluded; do not select whichever label aids prediction.
    seen={}
    for record in records:
        if record['status']!='accepted_training':continue
        pixel=record.get('decoded_pixel_sha256',record['image_sha256'])
        if pixel in seen:
            prior=seen[pixel]
            if prior['labels']!=record['labels']:
                prior.update(status='excluded_reference_conflict',reason='Identical pixels with conflicting references')
                record.update(status='excluded_reference_conflict',reason='Identical pixels with conflicting references')
            else:record.update(status='excluded_duplicate_pixels',reason=f'Duplicate of {prior["image_sha256"]}')
        else:seen[pixel]=record
    records.sort(key=lambda r:(r.get('family',''),r.get('group',''),r['image_sha256']))
    dump(out/'FINAL_PHOTO_AUDIT.json',records)
    accepted=[r for r in records if r['status']=='accepted_training']
    fields=['image_sha256','family','group','subject_alias','analyte','level','source_member']+[c for a in ANALYTE_ORDER for c in feature_columns_for_analyte(a,'normalized_hsv')]
    with (out/'CLEAN_FEATURES.csv').open('w',encoding='utf-8',newline='') as f:
        writer=csv.DictWriter(f,fieldnames=fields);writer.writeheader()
        for r in accepted:
            features={c:v for a in ANALYTE_ORDER for c,v in zip(feature_columns_for_analyte(a,'normalized_hsv'),r['features'][a])}
            for a in ANALYTE_ORDER:writer.writerow(dict(image_sha256=r['image_sha256'],family=r['family'],group=r['group'],
                subject_alias=r['subject_alias'],analyte=a,level=r['labels'][a],source_member=r['source_member'],**features))
    columns=['image_sha256','family','group','status','reason','source_member','label_status','feature_recipe','localization_method','strip','overlay']
    with (out/'FINAL_PHOTO_AUDIT.csv').open('w',encoding='utf-8',newline='') as f:
        writer=csv.DictWriter(f,fieldnames=columns,extrasaction='ignore');writer.writeheader();writer.writerows(records)
    summary=dict(unique_photos=len(records),archive_occurrences=inventory['occurrences'],
        unique_archive_photos=len(inventory['photos']),
        byte_duplicate_export_occurrences=inventory['occurrences']-len(inventory['photos']),
        additional_unpacked_photos=len(records)-len(inventory['photos']),
        statuses=dict(Counter(r['status'] for r in records)),
        training_photos=len(accepted),training_reference_groups=len({r['group'] for r in accepted}),
        training_photos_requiring_archive_crop=sum(not r.get('original_photo_runtime_passed',False) for r in accepted),
        families={family:dict(Counter(r['status'] for r in records if r.get('family')==family)) for family in sorted({r.get('family','') for r in records})},
        native_detector_source_sha256=manifest['app_detector_sha256'],
        feature_recipe='Exact source-derived current Dart image decoder, resize, orientation, acquisition checks, detector and normalized feature math; no model confidence used for dataset inclusion',
        reference_status='Owner-supplied categories preserved; no new medtech adjudication or IFU validation',
        identity_status='Within-batch supplied IDs and exact byte/pixel duplicate consolidation; cross-batch global identity remains unverified',
        originals_modified=False,reference_categories_changed=False,classification_model_changed=False)
    dump(out/'FINAL_SUMMARY.json',summary)
    cards=[]
    for r in records:
        preview=r.get('overlay') if r['status']=='accepted_training' else r.get('original_preview','')
        cards.append('<article data-status="'+r['status']+'"><h3>'+html.escape(f'{r.get("family","")} {r.get("group","")} {r["status"]}')+'</h3><img loading="lazy" src="'+html.escape(preview or '')+'"><p>'+html.escape(r.get('reason',''))+'</p><small>'+r['image_sha256']+'</small>'+''.join('<span>'+html.escape(a+': '+str(r.get('labels',{}).get(a,'')))+'</span>' for a in ANALYTE_ORDER)+'</article>')
    page='''<!doctype html><meta charset="utf-8"><title>URITECT complete photo audit</title><style>body{font:15px Arial;background:#f5f8fa;margin:24px}main{display:grid;grid-template-columns:repeat(auto-fill,minmax(240px,1fr));gap:16px}article{background:white;padding:14px;border:1px solid #ddd;border-radius:10px}img{max-width:100%;height:360px;object-fit:contain}span{display:block}small{overflow-wrap:anywhere}h3{font-size:14px}</style><h1>Complete photo and pad audit</h1><p>Originals preserved. Exact current-app acquisition and geometry checks plus sampling-boundary checks determine the training pool. Confidence predictions never select images. Supplied categories are not newly clinically adjudicated. Printed chart/cyclic and unsupported binary-conversion references do not enter training.</p><label>Filter <select onchange="document.querySelectorAll('article').forEach(a=>a.hidden=this.value&&a.dataset.status!==this.value)"><option value="">All</option>'''+''.join(f'<option>{s}</option>' for s in summary['statuses'])+'</select></label><main>'+''.join(cards)+'</main>'
    (out/'PHOTO_REVIEW.html').write_text(page,encoding='utf-8')
    print(json.dumps(summary,indent=2))


if __name__=='__main__':run()
