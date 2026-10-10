import pathlib
import sys
import unittest
sys.path.insert(0,str(pathlib.Path(__file__).resolve().parent))
from markerless_strip import _select_consecutive_pad_centers

class PadSequenceTests(unittest.TestCase):
    def candidates(self,centers):
        return [(float(c),20.0,.5,False,False) for c in centers]
    def test_regular_ten_pad_sequence_remains_accepted(self):
        centers=[100+40*i for i in range(10)]
        self.assertEqual(_select_consecutive_pad_centers(self.candidates(centers),10),centers)
    def test_ten_boxes_with_missing_pads_and_background_are_rejected(self):
        centers=[250,408,566,722,1140,1522,1906,2288,2571,2826]
        self.assertIsNone(_select_consecutive_pad_centers(self.candidates(centers),10))
    def test_regular_lower_window_wins_over_irregular_top_background(self):
        pads=[200+40*i for i in range(10)]
        self.assertEqual(_select_consecutive_pad_centers(self.candidates([10,25]+pads),10),pads)
    def test_one_compressed_gap_is_not_hidden_by_low_overall_variance(self):
        centers=[100,120,160,200,240,280,320,360,400,440]
        self.assertIsNone(_select_consecutive_pad_centers(self.candidates(centers),10))
    def test_incomplete_strip_does_not_synthesize_a_tenth_pad(self):
        self.assertIsNone(_select_consecutive_pad_centers(self.candidates([100+40*i for i in range(9)]),10))

if __name__=='__main__':
    unittest.main()
