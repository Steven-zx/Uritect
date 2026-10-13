"""Generate a diagnostic harness from the exact current Dart detector source.

Private detector functions remain in an unchanged generated library. The app is
not modified. ZIP originals are copied byte-for-byte into private audit scratch.
"""
import argparse
import json
import re
import zipfile
from pathlib import Path
import cv2
import numpy as np
from audit_legacy_dataset import DEFAULT_OUT, ROOT, dump, digest, file_digest, read_photo

WRAPPER = r'''
Map<String,dynamic> extractLegacyRuntime(Map<String,dynamic> item) {
  final output = <String,dynamic>{'image_sha256': item['image_sha256'], 'app_preflight_checked':true,
    'input_sha256':item['input_sha256'] ?? item['image_sha256'],
    'input_kind':item['input_kind'] ?? 'original_photo'};
  final directory = item['output_directory'] as String;
  final key = item['image_sha256'] as String;
  try {
    final bytes = File(item['image_path'] as String).readAsBytesSync();
    if (crypto.sha256.convert(bytes).toString() != output['input_sha256']) throw StateError('Source digest changed');
    final decoded = img.decodeImage(bytes);
    if (decoded == null) throw StateError('Image decode failed');
    final service = const LocalScanAnalysisService();
    final prepared = service._imageForAnalysis(img.bakeOrientation(decoded));
    PhotoQualityCheck.validate(prepared);
    final result = service._extractBestPadFeatures(prepared);
    final frame = result.variantName.startsWith('rot90_cw') ? img.copyRotate(prepared,angle:90)
      : result.variantName.startsWith('rot90_ccw') ? img.copyRotate(prepared,angle:-90)
      : result.variantName.startsWith('rot180') ? img.copyRotate(prepared,angle:180) : prepared;
    File('$directory/$key.frame.png').writeAsBytesSync(img.encodePng(frame));
    output.addAll({'geometry_passed':true,'variant':result.variantName,
      'features':result.featuresByAnalyte,'raw_features':result.rawFeaturesByAnalyte,
      'rois':{for(final entry in result.padRois.entries) entry.key:[entry.value.left,entry.value.top,entry.value.width,entry.value.height]},
      'quality':{'pad_gap_cv':result.padGapCv,'quality_score':result.qualityScore,
        'hue_std':result.hueStd,'saturation_mean':result.saturationMean,'value_std':result.valueStd},
      'frame_width':frame.width,'frame_height':frame.height});
  } catch(error) { output.addAll({'geometry_passed':false,'error':error.toString()}); }
  File('$directory/$key.json').writeAsStringSync(jsonEncode(output));
  return output;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const manifestPath = String.fromEnvironment('LEGACY_RUNTIME_MANIFEST');
  test('audit pending source photographs with the current app detector',() async {
    final manifest = jsonDecode(File(manifestPath).readAsStringSync()) as Map<String,dynamic>;
    final items = (manifest['photos'] as List).cast<Map<String,dynamic>>();
    var passed=0;
    for(var start=0;start<items.length;start+=3) {
      final end=math.min(items.length,start+3);
      final output=await Future.wait([for(final item in items.sublist(start,end))
        Isolate.run(()=>extractLegacyRuntime(item))]);
      passed+=output.where((r)=>r['geometry_passed']==true).length;
      if(end%30==0 || end==items.length) {
        // ignore: avoid_print
        print('Runtime detector: $end/${items.length}; $passed geometric passes');
      }
    }
    expect(items,isNotEmpty);
  },skip:manifestPath.isEmpty,timeout:const Timeout(Duration(hours:3)));
}
'''


def prepare(out, limit=0, only_group=None, crop_fallback=False, context_crop=False):
    inventory=json.loads((out/'INVENTORY.json').read_text())
    records=json.loads((out/'PHOTO_AUDIT.json').read_text())
    by_hash={r['image_sha256']:r for r in records}
    raw=out/'runtime_originals';raw.mkdir(exist_ok=True)
    kind='context_crop' if context_crop else 'crop'
    crop_inputs=out/f'runtime_{kind}_originals'
    if crop_fallback:crop_inputs.mkdir(exist_ok=True)
    result=out/(f'runtime_{kind}_detector' if crop_fallback else 'runtime_detector');result.mkdir(exist_ok=True)
    selected=[]
    for p in inventory['photos']:
        r=by_hash[p['image_sha256']]
        if not p['eligible_labels']:continue
        if only_group and r['group']!=only_group:continue
        if crop_fallback:
            if r['status']!='accepted_training':continue
            full=out/'runtime_detector'/f'{p["image_sha256"]}.json'
            if full.exists() and json.loads(full.read_text()).get('geometry_passed'):continue
        cached=result/f'{p["image_sha256"]}.json'
        if cached.exists() and json.loads(cached.read_text()).get('app_preflight_checked') is True:continue
        source=p['primary']
        path=crop_inputs/(p['image_sha256']+'.png') if crop_fallback else raw/(p['image_sha256']+Path(source['member']).suffix.lower())
        if crop_fallback and not path.exists():
            if not context_crop:path.write_bytes((out/r['strip']).read_bytes())
            else:
                image,_=read_photo(p)
                scale=min(1.,1100/max(image.shape[:2]))
                if scale<1:image=cv2.resize(image,(round(image.shape[1]*scale),round(image.shape[0]*scale)),interpolation=cv2.INTER_AREA)
                turns=r['rotation_ccw_degrees']//90
                if turns:image=np.rot90(image,k=turns).copy()
                if r['localization_method'].startswith('measured_lateral_window:'):
                    _,left,right=r['localization_method'].split(':');image=image[:,int(left):int(right)].copy()
                xs=[roi[0] for roi in r['rois'].values()];width=max(roi[2] for roi in r['rois'].values())
                # Retain genuine background, the complete handle and detector
                # scale context. Never pad the image with invented white pixels.
                left=max(0,min(xs)-10*width);right=min(image.shape[1],max(xs)+11*width)
                cv2.imwrite(str(path),image[:,left:right])
        if not crop_fallback and not path.exists():
            with zipfile.ZipFile(source['archive']) as z:content=z.read(source['member'])
            assert digest(content)==p['image_sha256']
            path.write_bytes(content)
        assert path.exists()
        selected.append(dict(image_sha256=p['image_sha256'],input_sha256=file_digest(path),
            input_kind=f'geometry_checked_lossless_processing_scale_{kind}' if crop_fallback else 'original_photo',
            image_path=str(path.resolve()),output_directory=str(result.resolve())))
        if limit and len(selected)>=limit:break
    source=ROOT/'uritect_app/lib/services/local_scan_analysis_service.dart'
    text=source.read_text(encoding='utf-8')
    text=text.replace("import '../models/", "import 'package:uritect_app/models/")
    for name in ['training_support_policy','runtime_pad_features','photo_quality_check','pad_presence_check']:
        text=text.replace(f"import '{name}.dart';",f"import 'package:uritect_app/services/{name}.dart';")
    text="import 'package:flutter_test/flutter_test.dart';\nimport 'package:crypto/crypto.dart' as crypto;\n"+text+WRAPPER
    harness=ROOT/'tmp'/(f'legacy_runtime_{kind}_detector_test.dart' if crop_fallback else 'legacy_runtime_detector_test.dart')
    harness.write_text(text,encoding='utf-8')
    name=f'RUNTIME_{kind.upper()}_MANIFEST.json' if crop_fallback else 'RUNTIME_SMOKE_MANIFEST.json' if limit or only_group else 'RUNTIME_MANIFEST.json'
    manifest=out/name
    dump(manifest,dict(app_detector_sha256=file_digest(source),generated_harness_sha256=file_digest(harness),
        scope='Unchanged app detector/geometry checks only; no classification confidence or clinical use inferred',photos=selected))
    print('Prepared',len(selected),'photos:',manifest)


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--out',type=Path,default=DEFAULT_OUT)
    parser.add_argument('--limit',type=int,default=0)
    parser.add_argument('--group')
    parser.add_argument('--crop-fallback',action='store_true',help='Recheck independently located strip crops; never change the original photograph')
    parser.add_argument('--context-crop',action='store_true',help='Keep original background context in the proposed strip crop')
    args=parser.parse_args();prepare(args.out,args.limit,args.group,args.crop_fallback or args.context_crop,args.context_crop)
