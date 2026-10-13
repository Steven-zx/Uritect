"""Label-independent reagent features from exact current-Dart decoded frames."""
import json
import argparse
from pathlib import Path
import numpy as np
import cv2
from audit_legacy_dataset import ROOT, dump, file_digest
from evaluate_legacy_expansion import baseline_data, tokens
from evaluate_runtime_metric_knn import link_identity_tokens, conservative_group
from runtime_pad_features import rgb_to_hsv
from semiquant_schema import ANALYTE_ORDER

OLD = ROOT / 'pipeline/output/legacy_dataset_audit_2026-10-13'
RUNTIME = ROOT / 'pipeline/output/knn_runtime_metric_2026-10-13/runtime_detector'
OUT = ROOT / 'pipeline/output/knn_exhaustive_2026-10-14'
FRACTIONS = [1., .7, .45]
KINDS = ['raw_lab', 'backing_lab', 'backing_logrgb', 'backing_chroma',
         'raw_hsv_vector', 'backing_hsv_vector', 'raw_lab_quantiles',
         'backing_lab_quantiles', 'backing_spatial_lab']


def development_records(recovered=False):
    refs = json.loads((OLD / 'FINAL_PHOTO_AUDIT.json').read_text())
    ref_map = {r['image_sha256']: r for r in refs}
    original = baseline_data()
    for row in original:
        row['subject_alias'] = ref_map.get(row['image_sha256'], {}).get('subject_alias', '')
    link_identity_tokens(original + refs)
    for row in original: row['evaluation_group'] = conservative_group(row)
    confirmation = [r for r in original if r['split'] == 'confirmation']
    forbidden_groups = {r['evaluation_group'] for r in confirmation}
    forbidden_tokens = tokens(confirmation)
    pool = []
    for ref in refs:
        if ref['status'] != 'accepted_training' and not recovered:continue
        group = conservative_group(ref)
        if group in forbidden_groups or tokens([ref]) & forbidden_tokens:continue
        directory = RUNTIME
        path = directory / (ref['image_sha256'] + '.json')
        r = json.loads(path.read_text()) if path.exists() and ref['status']=='accepted_training' else {}
        if not r.get('geometry_passed') and recovered:
            directory = OUT/'PRIVATE_CONTEXT_RUNTIME'
            path = directory / (ref['image_sha256']+'.json')
            r = json.loads(path.read_text()) if path.exists() else {}
        if not r.get('geometry_passed'):continue
        row = dict(ref, evaluation_group=group)
        row['runtime_directory'] = str(directory)
        row['features'] = np.array([r['features'][a] for a in ANALYTE_ORDER])
        row['raw_features'] = np.array([r['raw_features'][a] for a in ANALYTE_ORDER])
        pool.append(row)
    lookup = {r['image_sha256']: i for i,r in enumerate(pool)}
    targets = [lookup[r['image_sha256']] for r in original if r['split']=='development' and r['image_sha256'] in lookup and r['labels']==pool[lookup[r['image_sha256']]]['labels']]
    old_train = [r for r in original if r['split']=='development' and r['evaluation_group'] not in forbidden_groups and not tokens([r]) & forbidden_tokens]
    return pool, np.array(targets), old_train


def linear_rgb(rgb):
    v = np.asarray(rgb, dtype=float) / 255.
    return np.where(v <= .04045, v / 12.92, ((v + .055) / 1.055) ** 2.4)


def rgb_lab(rgb):
    v = linear_rgb(rgb)
    xyz = v @ np.array([[.4124564,.2126729,.0193339], [.3575761,.7151522,.1191920], [.1804375,.0721750,.9503041]])
    xyz /= np.array([.95047, 1., 1.08883])
    delta = 6 / 29
    f = np.where(xyz > delta**3, np.cbrt(xyz), xyz / (3 * delta**2) + 4/29)
    return np.column_stack([116*f[:,1]-16, 500*(f[:,0]-f[:,1]), 200*(f[:,1]-f[:,2])])


def backing_reference(rgb, rois):
    parts = []
    ordered = [rois[a] for a in ANALYTE_ORDER]
    for first,second in zip(ordered[:-1],ordered[1:]):
        x = int(round((first[0]+first[2]/2+second[0]+second[2]/2)/2))
        y = int(round((first[1]+first[3]/2+second[1]+second[3]/2)/2))
        half = max(2,int(min(first[2],second[2])*.22))
        parts.append(rgb[max(0,y-2):min(rgb.shape[0],y+3),max(0,x-half):min(rgb.shape[1],x+half+1)].reshape(-1,3))
    x,y,w,h = ordered[-1]
    cx = int(round(x+w/2));start = int(round(y+h+.5*w))
    parts.append(rgb[start:min(rgb.shape[0],start+int(3*w)),max(0,cx-int(.22*w)):min(rgb.shape[1],cx+int(.22*w)+1)].reshape(-1,3))
    samples = np.vstack([p for p in parts if len(p)])
    hsv = rgb_to_hsv(samples)
    neutral = samples[(hsv[:,1]<.28)&(samples.min(axis=1)>40)&(samples.max(axis=1)<250)]
    valid = len(neutral)>=12
    # A failed neutral reference falls back explicitly; no chemical pad is used.
    white = np.median(neutral,axis=0) if valid else np.array([200.,200.,200.])
    return white, dict(neutral_samples=len(neutral), verified_geometry_reference=valid)


def feature_values(patch, white, kind):
    pixels = patch.reshape(-1,3).astype(float)
    corrected = np.clip(pixels * (200. / np.maximum(white,1)),0,255)
    if kind == 'backing_logrgb':
        value = np.log(np.maximum(linear_rgb(pixels),1e-5)/np.maximum(linear_rgb(white),1e-5))
        return np.median(value,axis=0)
    if kind == 'backing_chroma':
        lin = linear_rgb(pixels)/np.maximum(linear_rgb(white),1e-5)
        chroma = lin/np.maximum(lin.sum(axis=1,keepdims=True),1e-5)
        return np.median(chroma[:,:2],axis=0)
    if kind.endswith('hsv_vector'):
        hsv = rgb_to_hsv(corrected if kind.startswith('backing') else pixels)
        hue = np.radians(hsv[:,0]);s=hsv[:,1]
        return np.array([np.mean(s*np.cos(hue)),np.mean(s*np.sin(hue)),np.median(s),np.median(hsv[:,2])])
    colors = corrected if kind.startswith('backing') else pixels
    lab = rgb_lab(colors)
    if kind.endswith('quantiles'):
        return np.quantile(lab,[.25,.5,.75],axis=0).reshape(-1)
    if kind.endswith('spatial_lab'):
        cube = lab.reshape(patch.shape[0],patch.shape[1],3)
        h,w = cube.shape[:2]
        return np.concatenate([np.median(p.reshape(-1,3),axis=0) for p in [cube[:h//2,:w//2],cube[:h//2,w//2:],cube[h//2:,:w//2],cube[h//2:,w//2:]]])
    return np.median(lab,axis=0)


def crop_inside(rgb,roi,fraction,dx=0,dy=0):
    x,y,w,h = map(int,roi)
    size = max(4,int(round(min(w,h)*fraction)))
    cx=min(x+w-size,max(x,x+(w-size)//2+dx));cy=min(y+h-size,max(y,y+(h-size)//2+dy))
    return rgb[cy:cy+size,cx:cx+size]


def main():
    parser=argparse.ArgumentParser();parser.add_argument('--recovered',action='store_true');args=parser.parse_args()
    output=OUT/'PRIVATE_EXPANDED' if args.recovered else OUT
    output.mkdir(exist_ok=True)
    assert not (output/'PRIVATE_COLOR_FEATURES.npz').exists(), 'Preserve extracted feature evidence'
    pool,targets,old = development_records(args.recovered)
    data = {};refs=[]
    for fraction in FRACTIONS:
        for kind in KINDS:
            key=f'{kind}_{fraction:g}'
            data[key]=[];data[key+'__aug']=[]
    for row in pool:
        directory=Path(row['runtime_directory'])
        r=json.loads((directory/(row['image_sha256']+'.json')).read_text())
        rgb=cv2.cvtColor(cv2.imread(str(directory/(row['image_sha256']+'.frame.png'))),cv2.COLOR_BGR2RGB)
        white,quality=backing_reference(rgb,r['rois']);refs.append(dict(image_sha256=row['image_sha256'],white=white.tolist(),**quality))
        for fraction in FRACTIONS:
            for kind in KINDS:
                key=f'{kind}_{fraction:g}';base=[];aug=[]
                for a in ANALYTE_ORDER:
                    patch=crop_inside(rgb,r['rois'][a],fraction)
                    base.append(feature_values(patch,white,kind))
                    variants=[]
                    for factor in [.97,1.03]:
                        # Skip clipping; labels never inferred from generated colors.
                        changed=patch.astype(float)*factor
                        variants.append(feature_values(changed,white*factor,kind) if changed.max()<=255 else base[-1])
                    for shift in [-1,1]:
                        variants.append(feature_values(crop_inside(rgb,r['rois'][a],fraction,shift,shift),white,kind))
                    aug.append(variants)
                data[key].append(base);data[key+'__aug'].append(aug)
    arrays={k:np.asarray(v) for k,v in data.items()}
    assert all(np.isfinite(a).all() for a in arrays.values())
    np.savez_compressed(output/'PRIVATE_COLOR_FEATURES.npz',**arrays)
    dump(output/'PRIVATE_FEATURE_IDENTITIES.json',dict(hashes=[r['image_sha256'] for r in pool],target_indices=targets.tolist(),backing=refs))
    dump(output/'FEATURE_RECIPE.json',dict(fractions=FRACTIONS,kinds=KINDS,safe_development_photos=len(pool),paired_targets=len(targets),
        neutral_backing_available=sum(r['verified_geometry_reference'] for r in refs),augmentation='Training only: unclipped neutral ±3% exposure, matching backing exposure; ±1 pixel central-crop shifts constrained inside the existing ROI. No chemical category or new specimen fabricated.',
        feature_source_sha256=file_digest(Path(__file__)),cache_sha256=file_digest(output/'PRIVATE_COLOR_FEATURES.npz')))
    print('Extracted',len(KINDS)*len(FRACTIONS),'pixel-level recipes for',len(pool),'development photos;',sum(r['verified_geometry_reference'] for r in refs),'neutral backing references.')


if __name__=='__main__':main()
