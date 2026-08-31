from __future__ import annotations

import numpy as np


def hsv_to_circular_features(X):
    """Convert [h, s, v] rows into [cos(h), sin(h), s, v]."""
    array = np.asarray(X, dtype=float)
    hue_rad = np.radians(array[:, 0])
    return np.column_stack([np.cos(hue_rad), np.sin(hue_rad), array[:, 1], array[:, 2]])
