"""Synthetic RGB fixture: no patient photographs or adjudicated labels."""
import base64
import json
from pathlib import Path
import cv2
import numpy as np
from runtime_pad_features import mean_pad_hsv,normalize_pad_hsv

ROOT=Path(__file__).resolve().parents[1]
def main():
    rng=np.random.default_rng(20261011);cases=[]
    for i in range(30):
        width=19+(i%5)*11;height=23+(i%4)*9
        image=rng.integers(0,256,(height,width,3),dtype=np.uint8)
        if i==0:
            image[:]=[12,0,255];image[:,::2]=[0,12,255] # hues on either side of zero
        elif i==1:image[:]=[80,160,205] # yellow/brown pH-like color
        elif i==2:image[:]=[30,110,65] # green SG-like color
        elif i==3:image[:]=[180,180,180]
        gains=[1.+(i%3)*.12,1.-(i%4)*.07,1.+(i%2)*.2]
        roi=[2,3,width-4,height-6]
        value=mean_pad_hsv(image,roi,gains)
        cases.append(dict(id=i,png_base64=base64.b64encode(cv2.imencode('.png',image)[1]).decode(),roi=roi,
                          gains_rgb=list(reversed(gains)),expected_hsv=value.tolist()))
    raw=np.array([case['expected_hsv'] for case in cases[:10]])
    fixture=dict(cases=cases,normalized_first_ten=normalize_pad_hsv(raw).tolist(),
                 scope='Feature-math parity on identical supplied RGB pixels, ROI and gains; not detector/decoder/resize/AWB parity')
    path=ROOT/'uritect_app/test/fixtures/runtime_pad_color_parity.json';path.write_text(json.dumps(fixture,indent=2)+'\n')
    print(path)

if __name__=='__main__':main()
