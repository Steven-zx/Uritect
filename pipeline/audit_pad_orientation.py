"""Re-extract existing labeled events with handle verification; never replace gold labels or historical files."""
import argparse,csv,json,re,zipfile
from pathlib import Path
from concurrent.futures import ProcessPoolExecutor, as_completed
import cv2,numpy as np
from markerless_strip import extract_markerless_features,MarkerlessStripConfig
from vision_pipeline import ANALYTE_ORDER,feature_columns_for_analyte
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'pipeline/output/orientation_audit_2026-10-11_v3'

def process(item):
    event,row=item
    source=row['source_zip'];data=None
    if source.startswith('LAUAAN'):
        m=re.match(r'LAUAAN-P(\d+)-L(\d+)',event)
        light={'4000':'Cool','2700':'Warm','5500':'Daylight'}[m[2]]
        folder=ROOT/'new_uritect_dataset/uritect_2026-7-30_Laua-an/_extracted/uritect_2026-7-30_Laua-an_RHU'/str(int(m[1]))
        path=next((p for p in folder.glob('*') if light.lower() in p.name.lower()),None)
        if path:data=path.read_bytes()
    else:
        m=re.search(r'_([^_]+)_(Cool|Warm|Daylight)$',event)
        package=next((ROOT/'pipeline/dataset/cabatuan_cleaned').rglob(source))
        with zipfile.ZipFile(package) as z:
            wanted=f'images/{m[1]}/{m[1]}-{m[2]}.jpg'
            name=next((n for n in z.namelist() if n.lower()==wanted.lower()),None)
            if name:data=z.read(name)
    if data is None:return {'event_id':event,'status':'source_missing'}
    image=cv2.imdecode(np.frombuffer(data,np.uint8),cv2.IMREAD_COLOR)
    h,w=image.shape[:2]
    if max(h,w)>1100:image=cv2.resize(image,(round(w*1100/max(h,w)),round(h*1100/max(h,w))),interpolation=cv2.INTER_AREA)
    errors=[]
    for name,oriented in [('exif',image),('rot90_cw',cv2.rotate(image,cv2.ROTATE_90_CLOCKWISE)),('rot180',cv2.rotate(image,cv2.ROTATE_180)),('rot90_ccw',cv2.rotate(image,cv2.ROTATE_90_COUNTERCLOCKWISE))]:
        try:
            result=extract_markerless_features(oriented,orientation=name,config=MarkerlessStripConfig(feature_space='normalized_hsv'))
            values={c:v for a in ANALYTE_ORDER for c,v in zip(feature_columns_for_analyte(a,feature_space='normalized_hsv'),result.features_by_pad[a])}
            def distance(reverse):
                diffs=[]
                for a,b in zip(ANALYTE_ORDER, list(reversed(ANALYTE_ORDER)) if reverse else ANALYTE_ORDER):
                    old=[float(row[c]) for c in feature_columns_for_analyte(a,feature_space='normalized_hsv')];new=result.features_by_pad[b]
                    delta=abs(old[0]-new[0]);diffs.extend([min(delta,360-delta)/180,abs(old[1]-new[1]),abs(old[2]-new[2])])
                return float(np.mean(diffs))
            forward,reverse=distance(False),distance(True)
            return {'event_id':event,'source_zip':source,'status':'direction_verified','orientation':name,'old_forward_distance':forward,'old_reversed_distance':reverse,'old_features_likely_reversed':reverse<forward*.8 and reverse<.15,'features':values}
        except Exception as e:errors.append(str(e)[:160])
    return {'event_id':event,'source_zip':source,'status':'rejected_direction_or_geometry','errors':errors}

def main():
    OUT.mkdir(parents=True,exist_ok=True)
    with (ROOT/'pipeline/dataset/features_normalized_hsv.csv').open(newline='',encoding='utf-8-sig') as f:
        reader=csv.DictReader(f);columns=reader.fieldnames;rows=list(reader)
    events={}
    for row in rows:events.setdefault(row['event_id'],row)
    results=[]
    with ProcessPoolExecutor(max_workers=3) as pool:
        futures={pool.submit(process,item):item[0] for item in events.items()}
        for future in as_completed(futures):
            try:record=future.result()
            except Exception as error:record={'event_id':futures[future],'status':'audit_error','error':str(error)}
            results.append(record)
            if len(results)%25==0:print(f'Audited {len(results)}/{len(events)}',flush=True)
    by_id={r['event_id']:r for r in results}
    corrected=[]
    for row in rows:
        evidence=by_id[row['event_id']]
        if evidence['status']=='direction_verified':corrected.append(dict(row,**evidence['features']))
    with (OUT/'features_direction_verified_candidate.csv').open('w',newline='',encoding='utf-8') as f:
        writer=csv.DictWriter(f,fieldnames=columns);writer.writeheader();writer.writerows(corrected)
    summary={'scope':'Engineering orientation audit, not clinical label/timing validation','events':len(events),'verified_events':sum(r['status']=='direction_verified' for r in results),'likely_reversed_old_features':sum(r.get('old_features_likely_reversed',False) for r in results),'candidate_rows':len(corrected),'gold_labels_changed':False,'historical_inputs_overwritten':False,'production_model_replaced':False}
    (OUT/'SUMMARY.json').write_text(json.dumps(summary,indent=2)+'\n')
    (OUT/'EVENT_AUDIT.json').write_text(json.dumps(sorted(results,key=lambda r:r['event_id']),indent=2)+'\n')
    print(json.dumps(summary),flush=True)
if __name__=='__main__':main()
