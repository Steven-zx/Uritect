"""Trace all 51 requested crop references and render spatial contact sheets."""
import csv
import json
import math
from pathlib import Path
import cv2
import numpy as np
from PIL import Image, ImageDraw, ImageFont
import pandas as pd
from audit_legacy_dataset import ROOT, safe_id, dump, file_digest
from clean_cabatuan_dataset import _read_labels, _level
from semiquant_schema import canonicalize_level, ANALYTE_ORDER
from focused_pad_geometry import audit_pad

OLD = ROOT / 'pipeline/output/legacy_dataset_audit_2026-10-13'
RUNTIME = ROOT / 'pipeline/output/knn_runtime_metric_2026-10-13/runtime_detector'
REVIEW = ROOT / 'pipeline/output/knn_runtime_metric_2026-10-13_ordinal'
OUT = ROOT / 'pipeline/output/knn_exhaustive_2026-10-14'


def main():
    OUT.mkdir(exist_ok=True)
    images = OUT / 'image_evidence'; images.mkdir(exist_ok=True)
    inventory = {r['image_sha256']: r for r in json.loads((OLD / 'INVENTORY.json').read_text())['photos']}
    rows = list(csv.DictReader((REVIEW / 'PRIVATE_ERROR_REVIEW.csv').open(encoding='utf-8')))
    tables = {}; evidence = []; cards = []
    font_path = Path('C:/Windows/Fonts/arial.ttf')
    font = ImageFont.truetype(str(font_path), 15)
    for index, row in enumerate(rows):
        primary = inventory[row['image_sha256']]['primary']
        path = Path(primary['source_label_file'])
        if path not in tables:
            if path.suffix.lower() == '.csv':
                records = list(csv.DictReader(path.open(encoding='utf-8-sig')))
                tables[path] = {safe_id(r['ID']): r for r in records}
            else:
                frame, _, columns = _read_labels(path)
                tables[path] = {safe_id(r['_clean_id']): {a: _level(r, columns[a]) for a in ANALYTE_ORDER} for _, r in frame.iterrows()}
        source = tables[path][safe_id(primary['participant'])]
        reference = canonicalize_level(row['analyte'], str(source[row['analyte']]))
        runtime = json.loads((RUNTIME / (row['image_sha256'] + '.json')).read_text())
        bgr = cv2.imread(str(RUNTIME / (row['image_sha256'] + '.frame.png')))
        roi = runtime['rois'][row['analyte']]
        ordered = [runtime['rois'][a] for a in ANALYTE_ORDER]
        gap = float(np.median(np.diff([r[1] + r[3] / 2 for r in ordered])))
        geometry = audit_pad(bgr, roi, gap)
        x, y, w, h = roi
        patch = bgr[y:y+h, x:x+w]
        clipping = float((patch.max(axis=2) >= 250).mean())
        item = dict(index=index + 1, **row, source_label_file=str(path),
                    source_file_sha256=file_digest(path), source_value=str(source[row['analyte']]),
                    canonical_source_reference=reference, reference_matches_original=reference == row['reference'],
                    roi=roi, geometry=geometry, bright_clipping_fraction=clipping,
                    bottle_chart_verified=False, label_changed=False)
        evidence.append(item)
        context = bgr[max(0, y-int(gap*.7)):min(bgr.shape[0],y+h+int(gap*.7)), max(0,x-w):min(bgr.shape[1],x+2*w)].copy()
        cx = x - max(0, x-w); cy = y - max(0, y-int(gap*.7))
        cv2.rectangle(context, (cx,cy), (cx+w,cy+h), (0,0,255), 1)
        pic = Image.fromarray(cv2.cvtColor(context, cv2.COLOR_BGR2RGB))
        pic.thumbnail((285,230))
        card = Image.new('RGB',(320,330),'white'); card.paste(pic,((320-pic.width)//2,8))
        draw = ImageDraw.Draw(card)
        draw.text((10,245),f"#{index+1} {row['analyte']}: reference {reference}",fill='black',font=font)
        draw.text((10,268),f"Baseline {row['baseline']} / candidate {row['candidate']}",fill='black',font=font)
        draw.text((10,291),geometry['boundary_status'],fill='black',font=font)
        cards.append(card)
    for page in range(math.ceil(len(cards)/9)):
        canvas = Image.new('RGB',(960,990),'#e7eeee')
        for j, card in enumerate(cards[page*9:(page+1)*9]):canvas.paste(card,((j%3)*320,(j//3)*330))
        canvas.save(images / f'review_{page+1:02d}.png')
    dump(OUT / 'PRIVATE_CROP_AUDIT.json', evidence)
    summary = dict(crops_checked=len(rows), reference_matches=sum(r['reference_matches_original'] for r in evidence),
                   reference_mismatches=sum(not r['reference_matches_original'] for r in evidence),
                   color_boundary_supported=sum(r['geometry']['boundary_status']=='color_boundary_supported' for r in evidence),
                   measured_roi_support_below_95=sum(r['geometry']['original_color_support'] is not None and r['geometry']['original_color_support'] < .95 for r in evidence),
                   bright_clipping_above_5_percent=sum(r['bright_clipping_fraction']>.05 for r in evidence),
                   visual_contact_sheets=math.ceil(len(cards)/9), bottle_chart_verified=False, original_labels_changed=False,
                   chart_search='No owner-supplied exact-bottle chart image found. Manuscript cites a manufacturer but current physical bottle has no identified manufacturer; no substitute chart treated as verified.')
    dump(OUT / 'CROP_AUDIT_SUMMARY.json', summary)
    print(summary)


if __name__ == '__main__':
    main()
