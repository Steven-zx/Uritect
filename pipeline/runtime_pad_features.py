"""Runtime-compatible color math on an explicitly supplied RGB frame and ROI.

Matches Dart's float RGB correction, circular hue mean and sampling stride.
This does not claim decoder, detector, resize or AWB-estimation parity.
"""
import numpy as np


def rgb_to_hsv(rgb):
    values = np.asarray(rgb,dtype=float)/255.
    maximum = values.max(axis=-1); minimum = values.min(axis=-1)
    delta = maximum-minimum
    hue = np.zeros_like(maximum)
    nonzero = delta != 0
    r,g,b = np.moveaxis(values,-1,0)
    red = nonzero & (maximum==r)
    green = nonzero & ~red & (maximum==g)
    blue = nonzero & ~red & ~green
    hue[red] = 60*((g[red]-b[red])/delta[red] % 6)
    hue[green] = 60*((b[green]-r[green])/delta[green]+2)
    hue[blue] = 60*((r[blue]-g[blue])/delta[blue]+4)
    saturation = np.divide(delta,maximum,out=np.zeros_like(delta),where=maximum!=0)
    return np.stack([hue%360,saturation,maximum],axis=-1)


def mean_pad_hsv(image_bgr,roi,gains_bgr=(1.,1.,1.),dense=False):
    x,y,w,h = map(int,roi)
    if x<0 or y<0 or w<1 or h<1 or x+w>image_bgr.shape[1] or y+h>image_bgr.shape[0]:
        raise ValueError('ROI must be fully inside the image')
    step = 1 if dense else max(1,min(w,h)//12)
    rgb = np.clip(image_bgr[y:y+h:step,x:x+w:step].astype(float)*np.array(gains_bgr),0,255)[...,::-1]
    hsv = rgb_to_hsv(rgb).reshape(-1,3)
    radians = np.radians(hsv[:,0])
    hue = np.degrees(np.arctan2(np.sin(radians).sum(),np.cos(radians).sum()))%360
    return np.array([hue,hsv[:,1].mean(),hsv[:,2].mean()])


def normalize_pad_hsv(values):
    values = np.asarray(values,dtype=float)
    radians = np.radians(values[:,0])
    anchor = np.degrees(np.arctan2(np.sin(radians).sum(),np.cos(radians).sum()))%360
    return np.column_stack([(values[:,0]-anchor)%360,
                            np.clip(.5+values[:,1]-values[:,1].mean(),0,1),
                            np.clip(.5+values[:,2]-values[:,2].mean(),0,1)])
