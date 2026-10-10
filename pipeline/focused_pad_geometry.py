"""Development-only local color-boundary audit. Never uses reference labels."""
import cv2
import numpy as np


def audit_pad(image,roi,gap):
    x,y,w,h = map(int,roi); cx,cy = x+w/2,y+h/2
    half_y = max(h/2,min(gap*.43,h*1.3))
    x0,x1 = max(0,int(cx-w*1.4)),min(image.shape[1],int(cx+w*1.4)+1)
    y0,y1 = max(0,int(cy-half_y)),min(image.shape[0],int(cy+half_y)+1)
    patch = image[y0:y1,x0:x1]
    hsv = cv2.cvtColor(patch,cv2.COLOR_BGR2HSV).astype(float)/255.
    original = cv2.cvtColor(image[y:y+h,x:x+w],cv2.COLOR_BGR2HSV).astype(float)/255.
    threshold = max(.12,float(np.median(original[...,1]))*.35)
    mask = ((hsv[...,1]>=threshold)&(hsv[...,2]>.08)).astype(np.uint8)
    mask = cv2.morphologyEx(mask,cv2.MORPH_CLOSE,np.ones((3,3),np.uint8))
    count,labels,stats,centers = cv2.connectedComponentsWithStats(mask)
    candidates = []
    for i in range(1,count):
        bx,by,bw,bh,area = stats[i]
        # A component reaching the search edge is not a complete pad boundary.
        # Tinted backing can join the reagent mask; never recenter from that.
        if bx == 0 or by == 0 or bx+bw >= patch.shape[1] or by+bh >= patch.shape[0]:
            continue
        if not (.65*w <= bw <= 2.6*w and .65*h <= bh <= 2.6*h and area>=.5*w*h):
            continue
        distance = np.linalg.norm(centers[i]-np.array([cx-x0,cy-y0]))
        if distance > .75*max(w,h): continue
        candidates.append((distance,i))
    information = dict(neutral_fraction=float((original[...,1]<.12).mean()),
                       dark_fraction=float((original[...,2]<.15).mean()),
                       saturation_std=float(original[...,1].std()),
                       value_range=float(np.quantile(original[...,2],.95)-np.quantile(original[...,2],.05)),
                       boundary_status='uncertain',original_color_support=None,
                       refined_roi=list(roi),pad_bbox=None,center_shift_pixels=0.)
    if not candidates:return information
    _,i = min(candidates)
    bx,by,bw,bh,_ = stats[i]; bbox=(int(x0+bx),int(y0+by),int(bw),int(bh))
    physical = labels==i
    support = physical[y-y0:y-y0+h,x-x0:x-x0+w].mean()
    size = max(3,int(round(min(bw,bh)*.58)))
    rx,ry = int(round(bbox[0]+bw/2-size/2)),int(round(bbox[1]+bh/2-size/2))
    refined=(rx,ry,size,size)
    new_support = physical[ry-y0:ry-y0+size,rx-x0:rx-x0+size].mean()
    if new_support < .95:return information
    information.update(boundary_status='color_boundary_supported',original_color_support=float(support),
                       refined_roi=list(refined),pad_bbox=list(bbox),
                       center_shift_pixels=float(np.linalg.norm(np.array([rx+size/2,ry+size/2])-np.array([cx,cy]))))
    return information
