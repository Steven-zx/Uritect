"""Bundle only the fonts used by the app, pinned to google_fonts 7.1.0 hashes."""
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
import hashlib
import json
from urllib.request import urlopen
ROOT = Path(__file__).resolve().parents[1]
FOLDER = ROOT / 'uritect_app/assets/fonts'
FILES = {
    'Inter-Regular.ttf': ('15b294b67f2f8bbc04d990023ef4aec66502b87dc9040d84abe5f896ccb693de', 324796),
    'Inter-Medium.ttf': ('36a36ff7ac46dc2aeceac3a80a87a67e7b844b8fc936699259aac8fba9bcf734', 325280),
    'Inter-SemiBold.ttf': ('334bb2c51aeba5f566abac8d03a7e75ab3234d6926b52e92a85dc704129258b5', 326024),
    'Poppins-Medium.ttf': ('c0ba5609d6562c76ab7db73fa9c9b283d210598cb318a45d4085f540e4753d60', 152860),
    'Poppins-SemiBold.ttf': ('ec23e010878cf0841f910ef94f62294e40c7d77ce99be250dba2911d0a1a61cd', 151516),
    'Poppins-Bold.ttf': ('ed709f2ba2be295030614990104cb4c9c62bc2a2445c25ccb19a1500158a5a8b', 150292),
}
def download(item):
    name, (digest, length) = item
    url = 'https://fonts.gstatic.com/s/a/' + digest + '.ttf'
    data = urlopen(url, timeout=90).read()
    if len(data) != length or hashlib.sha256(data).hexdigest() != digest:
        raise ValueError('Font checksum/length mismatch: ' + name)
    (FOLDER / name).write_bytes(data)
    return {'path': 'assets/fonts/' + name, 'source': url, 'bytes': length, 'sha256': digest.upper()}
def main():
    FOLDER.mkdir(parents=True, exist_ok=True)
    with ThreadPoolExecutor(max_workers=6) as pool:
        fonts = list(pool.map(download, FILES.items()))
    licenses = []
    for family in ['inter', 'poppins']:
        url = 'https://raw.githubusercontent.com/google/fonts/main/ofl/' + family + '/OFL.txt'
        data = urlopen(url, timeout=90).read()
        (FOLDER / (family.upper() + '_OFL.txt')).write_bytes(data)
        licenses.append({'family': family, 'source': url, 'sha256': hashlib.sha256(data).hexdigest().upper()})
    (FOLDER / 'FONT_SOURCES.json').write_text(json.dumps({'package': 'google_fonts 7.1.0',
        'license': 'SIL Open Font License 1.1; full notices included', 'fonts': fonts,
        'license_sources': licenses}, indent=2) + '\n', encoding='utf-8')
    print('Bundled and checksum-verified', len(fonts), 'fonts.')
if __name__ == '__main__':
    main()
