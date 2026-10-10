import unittest
import cv2
import numpy as np
from runtime_pad_features import mean_pad_hsv,normalize_pad_hsv
from focused_pad_geometry import audit_pad

class FocusedAuditTests(unittest.TestCase):
    def test_circular_red_wrap_is_not_green(self):
        image=np.zeros((20,20,3),np.uint8);image[:]=[12,0,255];image[:,::2]=[0,12,255]
        value=mean_pad_hsv(image,(0,0,20,20))
        self.assertTrue(value[0]<1 or value[0]>359)
        arithmetic=cv2.cvtColor(image,cv2.COLOR_BGR2HSV)[...,0].mean()*2
        self.assertGreater(arithmetic,100)

    def test_normalization_couples_other_pads_but_absolute_color_does_not(self):
        values=np.array([[40,.6,.8]]*10,dtype=float);before=normalize_pad_hsv(values)
        changed=values.copy();changed[1:]=[120,.2,.5]
        after=normalize_pad_hsv(changed)
        np.testing.assert_array_equal(changed[0],values[0])
        self.assertGreater(abs(after[0,0]-before[0,0]),20)

    def test_refinement_stays_with_current_pad_between_neighbor_centers(self):
        image=np.full((180,120,3),220,np.uint8)
        image[60:96,40:76]=[30,120,180];image[10:45,40:80]=[120,60,30];image[120:160,40:80]=[20,160,100]
        result=audit_pad(image,(44,64,25,25),55)
        self.assertEqual(result['boundary_status'],'color_boundary_supported')
        x,y,w,h=result['refined_roi'];self.assertGreaterEqual(y,60);self.assertLessEqual(y+h,100)
        self.assertGreaterEqual(x,40);self.assertLessEqual(x+w,80)

    def test_weak_color_boundary_does_not_invent_pad_geometry(self):
        image=np.full((180,120,3),220,np.uint8);roi=(44,64,25,25)
        result=audit_pad(image,roi,55)
        self.assertEqual(result['boundary_status'],'uncertain');self.assertEqual(result['refined_roi'],list(roi))

    def test_tinted_backing_joined_to_pad_does_not_recenter(self):
        image=np.full((180,120,3),[60,100,140],np.uint8)
        image[60:100,40:80]=[30,120,180];roi=(44,64,25,25)
        result=audit_pad(image,roi,55)
        self.assertEqual(result['boundary_status'],'uncertain')
        self.assertEqual(result['refined_roi'],list(roi))

if __name__=='__main__':unittest.main()
