"""Read-only source audit; derived, lossless crops and a versioned training pool.

No raw archive, supplied label, current model or APK is overwritten. Category
canonicalization is vocabulary-only. Engineering geometry is not clinical
label/IFU verification. Duplicate exports contribute one physical photo.
"""
from __future__ import annotations
import argparse
import csv
import hashlib
import html
import io
import json
import re
import zipfile
from collections import Counter, defaultdict
from concurrent.futures import ProcessPoolExecutor, as_completed
from pathlib import Path

import cv2
import numpy as np
from PIL import Image, ImageOps

from clean_cabatuan_dataset import ANALYTE_OUTPUT_COLUMNS, _read_labels, _level
from focused_pad_geometry import audit_pad
from markerless_strip import extract_markerless_features, verify_handle_direction
from semiquant_schema import ANALYTE_ORDER, canonicalize_level
from vision_pipeline import feature_columns_for_analyte

ROOT = Path(__file__).resolve().parents[1]
OLD = Path('C:/Users/acer/Documents/uritect_training_dataset')
DEFAULT_OUT = ROOT / 'pipeline/output/legacy_dataset_audit_2026-10-13'
EXT = {'.jpg', '.jpeg', '.png', '.webp', '.bmp'}


def digest(data):
    return hashlib.sha256(data).hexdigest()


def file_digest(path):
    value = hashlib.sha256()
    with Path(path).open('rb') as source:
        for block in iter(lambda: source.read(1024 * 1024), b''):
            value.update(block)
    return value.hexdigest()


def dump(path, data):
    path.write_text(json.dumps(data, indent=2, allow_nan=False) + '\n', encoding='utf-8')


def canonical_labels(row):
    return {a: canonicalize_level(a, str(row.get(c, '') or '').strip())
            for a, c in ANALYTE_OUTPUT_COLUMNS.items()}


def safe_id(value):
    value = str(value).strip()
    if value.endswith('.0') and value[:-2].isdigit():
        value = value[:-2]
    return str(int(value)) if value.isdigit() else value


def read_source_labels():
    sources, refs = {}, []
    for folder in sorted((ROOT / 'new_uritect_dataset').iterdir()):
        if not folder.is_dir():
            continue
        batch = folder.name
        supplied = {}
        if 'Laua' in batch:
            path = folder / f'{batch}_Labels_cleaned.csv'
            rows = list(csv.DictReader(path.open(encoding='utf-8-sig', newline='')))
            for row in rows:
                sid = safe_id(row['ID'])
                supplied[sid] = dict(labels={a: canonicalize_level(a, row.get(a, '')) for a in ANALYTE_ORDER},
                    subject_alias=safe_id(row.get('Name', '')), source_label_file=str(path))
        else:
            path = next(folder.glob('*Labels*.xlsx'))
            frame, _, columns = _read_labels(path)
            for _, row in frame.iterrows():
                sid = safe_id(row['_clean_id'])
                value = dict(labels={a: canonicalize_level(a, _level(row, columns[a])) for a in ANALYTE_ORDER},
                             subject_alias='', source_label_file=str(path))
                if sid in supplied and supplied[sid]['labels'] != value['labels']:
                    supplied[sid]['label_conflict'] = True
                else:
                    supplied[sid] = value
        sources[batch] = supplied
        refs.append(dict(path=str(path), sha256=file_digest(path)))
    # Immutable, owner-supplied semiquant record; no conversion from binary labels.
    path = ROOT / 'pipeline/dataset/URITECT_DATASET_locked_v1.csv'
    supplied = {safe_id(r['ID']): {a: canonicalize_level(a, r.get(a, '')) for a in ANALYTE_ORDER}
                for r in csv.DictReader(path.open(encoding='utf-8-sig', newline=''))}
    refs.append(dict(path=str(path), sha256=file_digest(path)))
    return sources, supplied, refs


def inventory(out, old_root=OLD):
    out.mkdir(parents=True, exist_ok=True)
    if (out / 'INVENTORY.json').exists():
        raise RuntimeError('Inventory already exists. Reuse it or choose a new output directory.')
    supplied, rhu, refs = read_source_labels()
    photos, archives, errors = {}, [], []
    paths = sorted((ROOT / 'new_uritect_dataset').rglob('*.zip'))
    paths += sorted(old_root.rglob('*.zip'))
    for archive_path in paths:
        family = ('RHU175' if archive_path.name.startswith('RHU175') else
                  'COLORWHEEL' if archive_path.name.startswith('COLORWHEEL') else
                  'BINARY_BATCH' if archive_path.name.startswith('BATCH') else archive_path.parent.name)
        try:
            with zipfile.ZipFile(archive_path) as archive:
                infos = [i for i in archive.infolist() if not i.is_dir() and Path(i.filename).suffix.lower() in EXT]
                indexes = {}
                for index in archive.namelist():
                    if index.lower().endswith('training_index.csv'):
                        for row in csv.DictReader(io.StringIO(archive.read(index).decode('utf-8-sig'))):
                            indexes[row.get('relative_image_path', '').replace('\\', '/')] = row
                archives.append(dict(path=str(archive_path), sha256=file_digest(archive_path), images=len(infos), family=family))
                for info in infos:
                    try:
                        data = archive.read(info)
                    except Exception as error:
                        errors.append(dict(archive=str(archive_path), member=info.filename, reason=str(error)))
                        continue
                    key = digest(data)
                    row = indexes.get(info.filename.replace('\\', '/'), {})
                    labels, sid, alias, label_file = {}, '', '', ''
                    label_conflict = False
                    if family in supplied:
                        sid = safe_id(Path(info.filename).parent.name)
                        ref = supplied[family].get(sid, {})
                        labels = ref.get('labels', {})
                        alias = ref.get('subject_alias', '')
                        label_file = ref.get('source_label_file', '')
                        label_conflict = ref.get('label_conflict', False)
                        label_status = 'supplied_specimen_reference' if labels else 'missing_reference'
                    elif family == 'RHU175':
                        sid = safe_id(row.get('participant_id', '').lstrip('P'))
                        labels = canonical_labels(row) if row else {}
                        if sid in rhu and labels != rhu[sid]:
                            label_conflict = True
                        label_status = 'supplied_specimen_reference' if sid in rhu and labels else 'missing_reference'
                        label_file = str(ROOT / 'pipeline/dataset/URITECT_DATASET_locked_v1.csv')
                    elif family == 'COLORWHEEL':
                        label_status = 'reference_chart_cyclic_labels_not_specimens'
                        labels = canonical_labels(row) if row else {}
                    else:
                        label_status = 'binary_batch_category_provenance_unverified'
                        labels = canonical_labels(row) if row else {}
                    occurrence = dict(archive=str(archive_path), member=info.filename, family=family,
                        participant=sid, group=f'{family}|{sid}' if sid else '', subject_alias=alias,
                        labels=labels, label_status=label_status, source_label_file=label_file,
                        label_conflict=label_conflict, event_id=row.get('event_id', ''))
                    if key not in photos:
                        photos[key] = dict(image_sha256=key, bytes=len(data), occurrences=[])
                    photos[key]['occurrences'].append(occurrence)
            print(f'Indexed {archive_path.name}: {len(infos)} images; {len(photos)} unique so far', flush=True)
        except Exception as error:
            errors.append(dict(archive=str(archive_path), reason=str(error)))
    # Hash grouping merges every repeated package export before any split.
    for photo in photos.values():
        valid = [o for o in photo['occurrences'] if o['label_status'] == 'supplied_specimen_reference']
        unique = {json.dumps(o['labels'], sort_keys=True) for o in valid}
        photo['reference_conflict'] = len(unique) > 1 or any(o['label_conflict'] for o in valid)
        photo['primary'] = (valid or photo['occurrences'])[0]
        photo['eligible_labels'] = bool(valid) and not photo['reference_conflict'] and all(photo['primary']['labels'].get(a) for a in ANALYTE_ORDER)
        photo['known_groups'] = sorted({o['group'] for o in valid if o['group']})
    data = dict(scope='Available raw research archives, including duplicate exports. Originals and supplied labels preserved.',
        clinical_labels_adjudicated=False, archives=archives, references=refs, read_errors=errors,
        occurrences=sum(len(p['occurrences']) for p in photos.values()), photos=list(photos.values()))
    dump(out / 'INVENTORY.json', data)
    return data


def read_photo(photo):
    source = photo['primary']
    if source.get('source_path'):
        data = Path(source['source_path']).read_bytes()
    else:
        with zipfile.ZipFile(source['archive']) as archive:
            data = archive.read(source['member'])
    if digest(data) != photo['image_sha256']:
        raise ValueError('Source bytes changed since inventory')
    # OpenCV honours JPEG orientation by default. Lossless derived PNGs record
    # both EXIF-transposed orientation and subsequent quarter-turn rotation.
    with Image.open(io.BytesIO(data)) as original:
        exif_orientation = original.getexif().get(274, 1)
        rgb = np.asarray(ImageOps.exif_transpose(original).convert('RGB'))
    return rgb[..., ::-1].copy(), exif_orientation


def background_support(image, roi, lab=None):
    """Reject sampled background; no analyte category or prediction is used.

    Side references stay separate so a macro-marker on one side cannot make
    ordinary background appear to be a reagent pad. Pale unresolved patches
    enter the review queue rather than being assumed to be a negative pad.
    """
    x,y,w,h=map(int,roi)
    if lab is None:lab=cv2.cvtColor(image,cv2.COLOR_BGR2LAB).astype(float)
    patch=lab[y:y+h,x:x+w]
    sides=[lab[y:y+h,max(0,x-4*w):max(0,x-2*w)],
           lab[y:y+h,min(image.shape[1],x+3*w):min(image.shape[1],x+5*w)]]
    distances=[np.linalg.norm(patch-np.median(side.reshape(-1,3),axis=0),axis=2)
               for side in sides if side.size]
    if not distances:raise ValueError('No real background context available for pad verification')
    return float((np.minimum.reduce(distances)>3.).mean())


def geometry_quality(image, result, check_background=True):
    rois = result.pad_rois
    if tuple(rois) != ANALYTE_ORDER or len(rois) != 10:
        raise ValueError('Exact ten-pad identity contract failed')
    centers = np.array([y + h / 2 for x, y, w, h in rois.values()])
    gaps = np.diff(centers)
    if np.any(gaps <= 0) or np.std(gaps) / np.mean(gaps) > .20:
        raise ValueError('Pad spacing is inconsistent')
    if any(h >= gaps.min() * .8 for x, y, w, h in rois.values()):
        raise ValueError('Sampling regions are too large for the pad spacing')
    first = next(iter(rois.values()))
    direction = verify_handle_direction(image, centers.tolist(), first[0], first[2])
    gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
    lab = cv2.cvtColor(image, cv2.COLOR_BGR2LAB).astype(float)
    audits = {}
    for analyte, roi in rois.items():
        x, y, w, h = roi
        if min(x, y) < 0 or min(w, h) < 8 or x+w > image.shape[1] or y+h > image.shape[0]:
            raise ValueError('Pad crop is outside the frame or too small')
        audits[analyte] = audit_pad(image, roi, float(np.median(gaps)))
        if check_background:
            presence=background_support(image,roi,lab)
            audits[analyte]['background_separated_fraction']=presence
            # A conservative dataset-only engineering screen in 8-bit Lab space,
            # not a clinical threshold or a change to the production detector.
            if presence<.95:
                raise ValueError(f'{analyte}: sampled background or unconfirmed pale pad boundary')
        patch = image[y:y+h, x:x+w]
        clipped = (patch.min(axis=2) >= 250).mean()
        audits[analyte]['white_clipping_fraction'] = float(clipped)
        support = audits[analyte]['original_color_support']
        if support is not None and support < .95:
            raise ValueError(f'{analyte}: sampling region crosses a supported color boundary')
    # A single negative pad may legitimately be almost white, and some positive
    # categories are dark. Only widespread clipping/darkness fails this screen.
    if sum(p['white_clipping_fraction']>.65 for p in audits.values()) >= 7:
        raise ValueError('Widespread clipping across reagent pad crops')
    if sum(p['dark_fraction']>.60 for p in audits.values()) >= 7:
        raise ValueError('Widespread darkness across reagent pad crops')
    x = max(0, first[0]-first[2]); right = min(image.shape[1], first[0]+2*first[2])
    focus = float(cv2.Laplacian(gray[max(0,int(centers[0]-first[2])):int(centers[-1]+first[2]),x:right], cv2.CV_64F).var())
    # An engineering acquisition screen, not a clinical acceptance threshold.
    if focus < 12:
        raise ValueError('Very low strip-region sharpness')
    return dict(pad_gap_cv=float(np.std(gaps)/np.mean(gaps)), strip_focus_variance=focus,
                direction=direction, pads=audits)


def process_photo(item):
    photo, directory = item
    out = Path(directory)
    key = photo['image_sha256']
    cv2.setNumThreads(1)
    record = dict(image_sha256=key, group=photo['primary']['group'], family=photo['primary']['family'],
        source_member=photo['primary']['member'], labels=photo['primary']['labels'],
        subject_alias=photo['primary']['subject_alias'], label_status=photo['primary']['label_status'],
        eligible_labels=photo['eligible_labels'], reference_conflict=photo['reference_conflict'])
    try:
        image, exif = read_photo(photo)
        h, w = image.shape[:2]
        record.update(original_width=w, original_height=h, exif_orientation=exif)
        record['decoded_pixel_sha256'] = digest(image.tobytes())
        if min(h,w) < 150:
            raise ValueError('Image dimensions too small')
        scale = min(1., 1100/max(h,w))
        image = cv2.resize(image, (round(w*scale),round(h*scale)), interpolation=cv2.INTER_AREA) if scale<1 else image
        thumb = cv2.resize(image, (round(image.shape[1]*360/max(image.shape[:2])),round(image.shape[0]*360/max(image.shape[:2]))))
        cv2.imwrite(str(out/'thumbnails'/f'{key}.jpg'), thumb)
        record['original_preview'] = f'thumbnails/{key}.jpg'
        if record['family'] == 'COLORWHEEL':
            record.update(status='reference_only', reason='Printed color chart with cyclic/unverified labels, not a specimen strip')
            return record
        attempts = []
        selected = None
        for turns in (0,2,1,3):
            frame = np.rot90(image, k=turns).copy() if turns else image
            try:
                result = extract_markerless_features(frame, orientation=f'ccw_{turns*90}')
                # First-pass locations are proposals. Native feature extraction
                # and the stricter background audit determine final admission.
                quality = geometry_quality(frame, result, check_background=False)
                selected = (frame,result,quality,turns,'full_frame')
                break
            except Exception as error:
                attempts.append(str(error)[:240])
        if selected is None:
            # Propose lateral windows from measured long edge components. This
            # removes nearby macro-markers without drawing or inventing pads.
            for turns in (0,2,1,3):
                frame = np.rot90(image, k=turns).copy() if turns else image
                gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
                edges = cv2.Canny(gray, 30, 100)
                lines = cv2.HoughLinesP(edges,1,np.pi/180,threshold=40,minLineLength=int(frame.shape[0]*.28),maxLineGap=15)
                candidates=[]
                if lines is not None:
                    for line in lines[:,0]:
                        x1,y1,x2,y2=map(int,line)
                        if abs(y2-y1)>.28*frame.shape[0] and abs(x2-x1)<.08*abs(y2-y1):
                            cx=(x1+x2)//2
                            if not any(abs(cx-v)<frame.shape[1]*.10 for v in candidates): candidates.append(cx)
                for cx in candidates[:4]:
                    x0=max(0,cx-int(frame.shape[1]*.22)); x1=min(frame.shape[1],cx+int(frame.shape[1]*.22))
                    cropped=frame[:,x0:x1].copy()
                    try:
                        result=extract_markerless_features(cropped,orientation=f'ccw_{turns*90}')
                        quality=geometry_quality(cropped,result,check_background=False)
                        selected=(cropped,result,quality,turns,f'measured_lateral_window:{x0}:{x1}')
                        break
                    except Exception as error: attempts.append(str(error)[:240])
                if selected is not None: break
        if selected is None:
            record.update(status='excluded_geometry_or_quality',reason='; '.join(dict.fromkeys(attempts))[:2400])
            return record
        frame,result,quality,turns,method=selected
        folder=out/'cleaned'/key
        folder.mkdir(parents=True,exist_ok=True)
        # Lossless crop at the audited processing scale, no synthesis or recolouring.
        # Keep the handle and neutral backing for orientation review.
        rois=result.pad_rois
        x,y,w,h=rois[ANALYTE_ORDER[0]]; bottom=rois[ANALYTE_ORDER[-1]][1]+h
        gap=float(np.median(np.diff([r[1]+r[3]/2 for r in rois.values()])))
        sx,sy=max(0,x-int(w*1.5)),max(0,y-int(gap*.65))
        ex,ey=min(frame.shape[1],x+int(w*2.5)),min(frame.shape[0],bottom+int(gap*4.5))
        strip=frame[sy:ey,sx:ex].copy()
        cv2.imwrite(str(folder/'strip.png'),strip)
        overlay=strip.copy()
        for a,(px,py,pw,ph) in rois.items():
            cv2.imwrite(str(folder/f'{a.replace(" ","_")}.png'),frame[py:py+ph,px:px+pw])
            cv2.rectangle(overlay,(px-sx,py-sy),(px-sx+pw,py-sy+ph),(180,100,0),1)
        cv2.imwrite(str(folder/'overlay.png'),overlay)
        record.update(status='accepted_training' if record['eligible_labels'] else 'geometry_only_not_training',
            reason='' if record['eligible_labels'] else 'Missing, conflicting or unsupported specimen-category references',
            rotation_ccw_degrees=turns*90, localization_method=method,
            feature_frame_crop=[sx,sy,ex,ey], processing_scale=scale,
            feature_frame_width=frame.shape[1], feature_frame_height=frame.shape[0],
            rois=rois, awb_gains_bgr=result.awb_gains_bgr, quality=quality,
            features=result.features_by_pad, strip=f'cleaned/{key}/strip.png', overlay=f'cleaned/{key}/overlay.png')
        return record
    except Exception as error:
        record.update(status='excluded_decode_or_size',reason=f'{type(error).__name__}: {error}')
        return record


def audit(out, workers):
    data=json.loads((out/'INVENTORY.json').read_text())
    for name in ['cleaned','thumbnails','audit_records']: (out/name).mkdir(exist_ok=True)
    records=[]
    tasks=[]
    for photo in data['photos']:
        cached=out/'audit_records'/f'{photo["image_sha256"]}.json'
        if cached.exists(): records.append(json.loads(cached.read_text()))
        else: tasks.append((photo,str(out)))
    with ProcessPoolExecutor(max_workers=workers) as pool:
        futures={pool.submit(process_photo,item):item[0]['image_sha256'] for item in tasks}
        for future in as_completed(futures):
            key=futures[future]
            try: record=future.result()
            except Exception as error: record=dict(image_sha256=key,status='audit_error',reason=str(error))
            dump(out/'audit_records'/f'{key}.json',record)
            records.append(record)
            if len(records)%25==0: print(f'Audited {len(records)}/{len(data["photos"])} unique photos: {dict(Counter(r["status"] for r in records))}',flush=True)
    records.sort(key=lambda r:(r.get('family',''),r.get('group',''),r['image_sha256']))
    pixels = defaultdict(list)
    for r in records:
        if r.get('decoded_pixel_sha256'):
            pixels[r['decoded_pixel_sha256']].append(r)
    for same in pixels.values():
        if len(same) < 2: continue
        usable = [r for r in same if r['status']=='accepted_training']
        if len({json.dumps(r['labels'],sort_keys=True) for r in usable}) > 1:
            for r in usable:
                r.update(status='excluded_reference_conflict',reason='Identical decoded pixels have conflicting supplied references')
        elif usable:
            keep = usable[0]
            for r in usable[1:]:
                r.update(status='excluded_duplicate_pixels',reason=f'Duplicate of {keep["image_sha256"]}',duplicate_of=keep['image_sha256'])
    dump(out/'PHOTO_AUDIT.json',records)
    summary=dict(unique_photos=len(records),archive_occurrences=data['occurrences'],
        exact_duplicate_export_occurrences=data['occurrences']-len(records),
        statuses=dict(Counter(r['status'] for r in records)),
        families={f:dict(Counter(r['status'] for r in records if r.get('family')==f)) for f in sorted({r.get('family','') for r in records})},
        original_archives_modified=False,supplied_labels_modified=False,current_app_model_modified=False,
        clinical_reference_adjudication=False,
        scope='First-pass geometric proposals only, not the final training pool. Final admission requires current-app extraction and stricter boundary checks. Sampled manual visual review is recorded separately.')
    dump(out/'SUMMARY.json',summary)
    fields=['image_sha256','family','group','status','reason','source_member','label_status','rotation_ccw_degrees','localization_method','strip','overlay']
    with (out/'PHOTO_AUDIT.csv').open('w',encoding='utf-8',newline='') as f:
        writer=csv.DictWriter(f,fieldnames=fields,extrasaction='ignore');writer.writeheader();writer.writerows(records)
    columns=['image_sha256','family','group','subject_alias','analyte','level','source_member']+[c for a in ANALYTE_ORDER for c in feature_columns_for_analyte(a,'normalized_hsv')]
    rows=[]
    for r in records:
        if r['status']!='accepted_training':continue
        values={c:v for a in ANALYTE_ORDER for c,v in zip(feature_columns_for_analyte(a,'normalized_hsv'),r['features'][a])}
        for a in ANALYTE_ORDER:
            rows.append(dict(image_sha256=r['image_sha256'],family=r['family'],group=r['group'],subject_alias=r['subject_alias'],
                analyte=a,level=r['labels'][a],source_member=r['source_member'],**values))
    with (out/'CLEAN_FEATURES.csv').open('w',encoding='utf-8',newline='') as f:
        writer=csv.DictWriter(f,fieldnames=columns);writer.writeheader();writer.writerows(rows)
    cards=[]
    for r in records:
        primary=html.escape(f'{r.get("family","")} {r.get("group","")} {r["status"]}')
        image=r.get('overlay',r.get('original_preview',''))
        cards.append(f'<article data-status="{r["status"]}"><h3>{primary}</h3><img loading="lazy" src="{html.escape(image)}"><p>{html.escape(r.get("reason",""))}</p><small>{r["image_sha256"]}</small>'+(''.join(f'<span>{html.escape(a)}: {html.escape(str(r.get("labels",{}).get(a,"")))}</span>' for a in ANALYTE_ORDER))+'</article>')
    page='''<!doctype html><meta charset="utf-8"><title>URITECT source photo audit</title><style>body{font:15px Arial;background:#f5f8fa;margin:24px}main{display:grid;grid-template-columns:repeat(auto-fill,minmax(240px,1fr));gap:16px}article{background:white;padding:14px;border:1px solid #ddd;border-radius:10px}img{max-width:100%;height:360px;object-fit:contain}span{display:block}small{overflow-wrap:anywhere}h3{font-size:14px}</style><h1>Legacy and current photo audit</h1><p>Every unique photo has an automated engineering disposition. Original photos and labels are preserved. Category references are supplied data, not newly adjudicated clinical truth. Color charts and unsupported converted labels do not enter training.</p><label>Filter <select onchange="document.querySelectorAll('article').forEach(a=>a.hidden=this.value&&a.dataset.status!==this.value)"><option value="">All</option>'''+''.join(f'<option>{s}</option>' for s in summary['statuses'])+'</select></label><main>'+''.join(cards)+'</main>'
    (out/'PHOTO_REVIEW.html').write_text(page,encoding='utf-8')
    print(json.dumps(summary,indent=2),flush=True)


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--out',type=Path,default=DEFAULT_OUT)
    parser.add_argument('--old-root',type=Path,default=OLD)
    parser.add_argument('--phase',choices=['inventory','audit','all'],default='all')
    parser.add_argument('--workers',type=int,default=2)
    args=parser.parse_args()
    if args.phase in ('inventory','all'):inventory(args.out,args.old_root)
    if args.phase in ('audit','all'):audit(args.out,args.workers)
