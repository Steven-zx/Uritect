#!/usr/bin/env python3
"""Markerless strip localization for Laua-an style dipstick images.

The older Uritect pipeline used a black/white macro-marker for perspective,
scale, and white balance. The Laua-an dataset does not include that marker, so
this module localizes the strip directly and extracts the 10 semiquant pad
features from the detected strip geometry.
"""

from __future__ import annotations

from dataclasses import dataclass

import cv2
import numpy as np

try:
    from .vision_pipeline import ANALYTE_ORDER
except ImportError:
    from vision_pipeline import ANALYTE_ORDER


@dataclass(frozen=True)
class MarkerlessStripConfig:
    feature_space: str = "normalized_hsv"
    strip_width_padding: float = 0.18
    pad_inner_fraction: float = 0.58
    min_strip_aspect: float = 3.0
    max_strip_width_ratio: float = 0.22
    min_col_coverage: float = 0.08


@dataclass(frozen=True)
class MarkerlessStripResult:
    features_by_pad: dict[str, tuple[float, float, float]]
    pad_rois: dict[str, tuple[int, int, int, int]]
    orientation: str
    quality_score: float
    awb_gains_bgr: tuple[float, float, float]
    strip_bbox: tuple[int, int, int, int]
    frames_total: int = 1
    frames_used: int = 1
    frames_skipped: int = 0
    frame_errors: tuple[str, ...] = ()


def _normalize_hue(hue: float) -> float:
    normalized = hue % 360.0
    return normalized + 360.0 if normalized < 0 else normalized


def _clip_01(value: float) -> float:
    return min(max(value, 0.0), 1.0)


def _circular_mean_deg(values: list[float]) -> float:
    if not values:
        return 0.0
    radians = np.radians(np.asarray(values, dtype=np.float32))
    sin_sum = float(np.sum(np.sin(radians)))
    cos_sum = float(np.sum(np.cos(radians)))
    if abs(sin_sum) < 1e-12 and abs(cos_sum) < 1e-12:
        return _normalize_hue(values[0])
    return _normalize_hue(float(np.degrees(np.arctan2(sin_sum, cos_sum))))


def _border_background_lab(image_bgr: np.ndarray) -> np.ndarray:
    h, w = image_bgr.shape[:2]
    margin = max(8, int(round(min(h, w) * 0.05)))
    border = np.concatenate(
        [
            image_bgr[:margin, :, :].reshape(-1, 3),
            image_bgr[-margin:, :, :].reshape(-1, 3),
            image_bgr[:, :margin, :].reshape(-1, 3),
            image_bgr[:, -margin:, :].reshape(-1, 3),
        ],
        axis=0,
    ).astype(np.uint8)
    lab = cv2.cvtColor(border.reshape(-1, 1, 3), cv2.COLOR_BGR2LAB).reshape(-1, 3)
    return np.median(lab.astype(np.float32), axis=0)


def _foreground_mask(image_bgr: np.ndarray) -> np.ndarray:
    lab = cv2.cvtColor(image_bgr, cv2.COLOR_BGR2LAB).astype(np.float32)
    bg = _border_background_lab(image_bgr)
    delta = lab - bg.reshape(1, 1, 3)
    diff = np.linalg.norm(delta, axis=2)
    threshold = max(10.0, float(np.percentile(diff, 86)))
    mask = (diff >= threshold).astype(np.uint8) * 255
    kernel = cv2.getStructuringElement(cv2.MORPH_RECT, (5, 17))
    mask = cv2.morphologyEx(mask, cv2.MORPH_CLOSE, kernel, iterations=2)
    mask = cv2.morphologyEx(mask, cv2.MORPH_OPEN, np.ones((3, 3), dtype=np.uint8), iterations=1)
    return mask


def _smooth_projection(values: np.ndarray, window: int) -> np.ndarray:
    window = max(3, int(window) | 1)
    kernel = np.ones(window, dtype=np.float32) / float(window)
    return np.convolve(values.astype(np.float32), kernel, mode="same")


def _longest_true_run(flags: np.ndarray) -> tuple[int, int] | None:
    best: tuple[int, int] | None = None
    start: int | None = None
    for index, flag in enumerate(flags.tolist() + [False]):
        if flag and start is None:
            start = index
        elif not flag and start is not None:
            end = index - 1
            if best is None or (end - start) > (best[1] - best[0]):
                best = (start, end)
            start = None
    return best


def _detect_strip_bbox(image_bgr: np.ndarray, config: MarkerlessStripConfig) -> tuple[int, int, int, int, float]:
    h, w = image_bgr.shape[:2]
    max_detection_dim = 1400
    max_dim = max(h, w)
    if max_dim > max_detection_dim:
        scale = max_detection_dim / float(max_dim)
        resized = cv2.resize(
            image_bgr,
            (max(1, int(round(w * scale))), max(1, int(round(h * scale)))),
            interpolation=cv2.INTER_AREA,
        )
        rx0, ry0, rx1, ry1, quality = _detect_strip_bbox(resized, config)
        inv_scale = 1.0 / scale
        x0 = max(0, int(round(rx0 * inv_scale)))
        y0 = max(0, int(round(ry0 * inv_scale)))
        x1 = min(w - 1, int(round((rx1 + 1) * inv_scale)) - 1)
        y1 = min(h - 1, int(round((ry1 + 1) * inv_scale)) - 1)
        return x0, y0, x1, y1, quality

    hough_bbox = _detect_strip_bbox_from_edges(image_bgr, config)
    if hough_bbox is not None:
        return hough_bbox

    saturation_bbox = _detect_strip_bbox_from_saturation(image_bgr, config)
    if saturation_bbox is not None:
        return saturation_bbox

    mask = _foreground_mask(image_bgr)
    col_projection = _smooth_projection(mask.mean(axis=0) / 255.0, max(9, w // 80))
    col_threshold = max(config.min_col_coverage, float(np.percentile(col_projection, 94)) * 0.45)
    col_run = _longest_true_run(col_projection >= col_threshold)
    if col_run is None:
        raise ValueError("Markerless strip localization failed: no vertical strip candidate.")

    x0, x1 = col_run
    strip_width = max(1, x1 - x0 + 1)
    pad = int(round(strip_width * config.strip_width_padding))
    x0 = max(0, x0 - pad)
    x1 = min(w - 1, x1 + pad)
    strip_width = max(1, x1 - x0 + 1)

    if strip_width / max(1, w) > config.max_strip_width_ratio:
        raise ValueError("Markerless strip localization failed: strip candidate is too wide.")

    strip_mask = mask[:, x0 : x1 + 1]
    row_projection = _smooth_projection(strip_mask.mean(axis=1) / 255.0, max(9, h // 120))
    row_threshold = max(0.025, float(np.percentile(row_projection, 82)) * 0.35)
    rows = np.where(row_projection >= row_threshold)[0]
    if rows.size == 0:
        raise ValueError("Markerless strip localization failed: no pad row signal.")

    y0 = int(rows.min())
    y1 = int(rows.max())
    strip_height = max(1, y1 - y0 + 1)
    if strip_height / strip_width < config.min_strip_aspect:
        raise ValueError("Markerless strip localization failed: strip candidate is not tall enough.")

    quality = float(strip_height / max(1, h)) + float(np.max(col_projection)) + float(np.max(row_projection))
    return x0, y0, x1, y1, quality


def _detect_strip_bbox_from_saturation(
    image_bgr: np.ndarray,
    config: MarkerlessStripConfig,
) -> tuple[int, int, int, int, float] | None:
    h, w = image_bgr.shape[:2]
    hsv = cv2.cvtColor(image_bgr, cv2.COLOR_BGR2HSV).astype(np.float32)
    sat = hsv[:, :, 1] / 255.0
    val = hsv[:, :, 2] / 255.0
    activity = ((sat > 0.18) & (val > 0.12) & (val < 0.98)).astype(np.uint8) * 255

    col_projection = _smooth_projection(activity.mean(axis=0) / 255.0, max(9, w // 100))
    col_threshold = max(0.04, float(np.percentile(col_projection, 95)) * 0.40)

    runs: list[tuple[int, int, float, float]] = []
    start: int | None = None
    flags = (col_projection >= col_threshold).tolist() + [False]
    for index, flag in enumerate(flags):
        if flag and start is None:
            start = index
        elif not flag and start is not None:
            end = index - 1
            width = end - start + 1
            if 20 <= width <= int(round(w * config.max_strip_width_ratio)):
                mean_score = float(np.mean(col_projection[start : end + 1]))
                max_score = float(np.max(col_projection[start : end + 1]))
                runs.append((start, end, mean_score, max_score))
            start = None

    if not runs:
        return None

    for raw_x0, raw_x1, mean_col, max_col in sorted(runs, key=lambda item: (item[3], item[2]), reverse=True):
        x0, x1 = raw_x0, raw_x1
        strip_width = max(1, x1 - x0 + 1)
        pad = int(round(strip_width * config.strip_width_padding))
        x0 = max(0, x0 - pad)
        x1 = min(w - 1, x1 + pad)
        strip_width = max(1, x1 - x0 + 1)

        if strip_width / max(1, w) > config.max_strip_width_ratio:
            continue

        strip_activity = activity[:, x0 : x1 + 1]
        row_projection = _smooth_projection(strip_activity.mean(axis=1) / 255.0, max(21, h // 120))
        row_threshold = max(0.025, float(np.percentile(row_projection, 82)) * 0.35)
        rows = np.where(row_projection >= row_threshold)[0]
        if rows.size == 0:
            continue

        y0 = int(rows.min())
        y1 = int(rows.max())
        strip_height = max(1, y1 - y0 + 1)
        if strip_height / strip_width < config.min_strip_aspect:
            continue

        quality = 2.0 + float(strip_height / max(1, h)) + mean_col + max_col + float(np.max(row_projection))
        return x0, y0, x1, y1, float(quality)

    return None


def _detect_strip_bbox_from_edges(
    image_bgr: np.ndarray,
    config: MarkerlessStripConfig,
) -> tuple[int, int, int, int, float] | None:
    h, w = image_bgr.shape[:2]
    gray = cv2.cvtColor(image_bgr, cv2.COLOR_BGR2GRAY)
    gray = cv2.GaussianBlur(gray, (5, 5), 0)
    edges = cv2.Canny(gray, 30, 100)
    vertical_lines = cv2.HoughLinesP(
        edges,
        1,
        np.pi / 180.0,
        threshold=max(60, h // 40),
        minLineLength=max(80, h // 8),
        maxLineGap=max(20, h // 50),
    )
    horizontal_lines = cv2.HoughLinesP(
        edges,
        1,
        np.pi / 180.0,
        threshold=60,
        minLineLength=max(60, w // 40),
        maxLineGap=max(16, w // 120),
    )
    if vertical_lines is None:
        return None

    vertical: list[tuple[float, int, int]] = []
    horizontal: list[tuple[int, int, int]] = []
    for x1, y1, x2, y2 in vertical_lines[:, 0, :]:
        dx = abs(int(x2) - int(x1))
        dy = abs(int(y2) - int(y1))
        if dy >= max(120, h * 0.12) and dx <= max(12, w * 0.02):
            vertical.append(((float(x1) + float(x2)) / 2.0, min(int(y1), int(y2)), max(int(y1), int(y2))))

    if horizontal_lines is not None:
        for x1, y1, x2, y2 in horizontal_lines[:, 0, :]:
            dx = abs(int(x2) - int(x1))
            dy = abs(int(y2) - int(y1))
            if dx < max(60, w * 0.025) or dy > max(10, h * 0.008):
                continue
            horizontal.append((min(int(x1), int(x2)), max(int(x1), int(x2)), int(round((int(y1) + int(y2)) / 2.0))))

    if not vertical:
        return None

    # The left edge of the Laua-an strip is usually the longest sharp vertical
    # line. Use the median x of vertical detections to avoid one noisy segment.
    left_edge = int(round(float(np.median([item[0] for item in vertical]))))
    crossing_segments = [
        item for item in horizontal
        if item[0] - 80 <= left_edge <= item[1] + 80
    ]

    if crossing_segments:
        lefts = np.asarray([item[0] for item in crossing_segments], dtype=np.float32)
        rights = np.asarray([item[1] for item in crossing_segments], dtype=np.float32)
        line_widths = rights - lefts
        pad_width = int(round(float(np.median(line_widths))))
        x0 = int(round(float(np.percentile(lefts, 20)))) - max(2, pad_width // 20)
        x1 = int(round(float(np.percentile(rights, 80)))) + max(2, pad_width // 20)
        ys = np.asarray([item[2] for item in crossing_segments], dtype=np.float32)
        y_min_from_pads = int(round(float(np.min(ys)))) - pad_width
        y_max_from_pads = int(round(float(np.max(ys)))) + pad_width
    else:
        pad_width = max(40, int(round(w * 0.07)))
        x0 = left_edge - max(4, pad_width // 10)
        x1 = left_edge + pad_width
        y_min_from_pads = 0
        y_max_from_pads = h - 1

    if pad_width <= 0:
        return None

    x0 = max(0, x0)
    x1 = min(w - 1, x1)
    if crossing_segments:
        vertical_y0 = min(item[1] for item in vertical)
        y1 = y_max_from_pads
        estimated_stack_width = max(1, x1 - x0 + 1)
        estimated_full_stack_y0 = y1 - int(round(estimated_stack_width * 13.5))
        y0 = min(vertical_y0, y_min_from_pads, estimated_full_stack_y0)
    else:
        strip_slice = image_bgr[:, x0 : x1 + 1]
        hsv = cv2.cvtColor(strip_slice, cv2.COLOR_BGR2HSV).astype(np.float32)
        sat = hsv[:, :, 1] / 255.0
        val = hsv[:, :, 2] / 255.0
        row_activity = _smooth_projection(
            ((sat > 0.35) & (val > 0.12) & (val < 0.98)).mean(axis=1),
            max(21, h // 80),
        )
        active_threshold = max(0.08, float(np.percentile(row_activity, 75)) * 0.45)
        active_rows = np.where(row_activity >= active_threshold)[0]
        if active_rows.size:
            y0 = int(active_rows.min()) - max(4, pad_width // 5)
            y1 = int(active_rows.max()) + max(4, pad_width // 3)
        else:
            vertical_y0 = min(item[1] for item in vertical)
            vertical_y1 = max(item[2] for item in vertical)
            y0 = min(vertical_y0, y_min_from_pads)
            y1 = max(vertical_y1, y_max_from_pads)

    y0 = max(0, y0)
    y1 = min(h - 1, y1)
    strip_width = x1 - x0 + 1
    strip_height = y1 - y0 + 1
    if strip_width <= 0 or strip_height <= 0:
        return None
    if strip_width / max(1, w) > config.max_strip_width_ratio:
        return None
    if strip_height / strip_width < config.min_strip_aspect:
        return None

    quality = (
        4.0
        + min(len(vertical), 8) * 0.18
        + min(len(crossing_segments), 12) * 0.12
        + min(strip_height / max(1, h), 1.0)
    )
    return x0, y0, x1, y1, float(quality)


def _apply_gray_world_awb(image_bgr: np.ndarray, strip_bbox: tuple[int, int, int, int]) -> tuple[np.ndarray, tuple[float, float, float]]:
    x0, y0, x1, y1 = strip_bbox
    h, w = image_bgr.shape[:2]
    strip_w = x1 - x0 + 1
    strip_h = y1 - y0 + 1
    margin_x = max(4, int(round(strip_w * 0.15)))
    margin_y = max(8, int(round(strip_h * 0.04)))
    roi = image_bgr[
        max(0, y0 - margin_y) : min(h, y1 + margin_y + 1),
        max(0, x0 - margin_x) : min(w, x1 + margin_x + 1),
    ]

    hsv = cv2.cvtColor(roi, cv2.COLOR_BGR2HSV).astype(np.float32)
    sat = hsv[:, :, 1] / 255.0
    val = hsv[:, :, 2] / 255.0
    neutral_mask = (sat < 0.28) & (val > 0.35) & (val < 0.98)
    neutral_pixels = roi[neutral_mask]
    if neutral_pixels.size < 60:
        neutral_pixels = roi.reshape(-1, 3)

    means = neutral_pixels.reshape(-1, 3).mean(axis=0).astype(np.float32)
    means = np.clip(means, 1.0, None)
    target = float(np.mean(means))
    gains = target / means
    corrected = np.clip(image_bgr.astype(np.float32) * gains.reshape(1, 1, 3), 0, 255).astype(np.uint8)
    return corrected, (float(gains[0]), float(gains[1]), float(gains[2]))


def _mean_hsv(crop_bgr: np.ndarray) -> tuple[float, float, float]:
    hsv = cv2.cvtColor(crop_bgr, cv2.COLOR_BGR2HSV).astype(np.float32)
    h = float(np.mean(hsv[:, :, 0]) * 2.0)
    s = float(np.mean(hsv[:, :, 1]) / 255.0)
    v = float(np.mean(hsv[:, :, 2]) / 255.0)
    return round(h, 6), round(s, 6), round(v, 6)


def _mean_lab(crop_bgr: np.ndarray) -> tuple[float, float, float]:
    lab = cv2.cvtColor(crop_bgr, cv2.COLOR_BGR2LAB).astype(np.float32)
    l_value = float(np.mean(lab[:, :, 0]) / 255.0 * 100.0)
    a_value = float(np.mean(lab[:, :, 1]) - 128.0)
    b_value = float(np.mean(lab[:, :, 2]) - 128.0)
    return round(l_value, 6), round(a_value, 6), round(b_value, 6)


def _normalize_features(features_by_pad: dict[str, tuple[float, float, float]]) -> dict[str, tuple[float, float, float]]:
    hues = [h for h, _, _ in features_by_pad.values()]
    sats = [s for _, s, _ in features_by_pad.values()]
    vals = [v for _, _, v in features_by_pad.values()]
    hue_anchor = _circular_mean_deg(hues)
    sat_anchor = float(np.mean(np.asarray(sats, dtype=np.float32))) if sats else 0.0
    val_anchor = float(np.mean(np.asarray(vals, dtype=np.float32))) if vals else 0.0

    normalized: dict[str, tuple[float, float, float]] = {}
    for analyte, (h, s, v) in features_by_pad.items():
        normalized[analyte] = (
            round(_normalize_hue(h - hue_anchor), 6),
            round(_clip_01(0.5 + (s - sat_anchor)), 6),
            round(_clip_01(0.5 + (v - val_anchor)), 6),
        )
    return normalized


def _find_runs(flags: np.ndarray, min_length: int = 1) -> list[tuple[int, int]]:
    runs: list[tuple[int, int]] = []
    start: int | None = None
    for index, flag in enumerate(flags.tolist() + [False]):
        if flag and start is None:
            start = index
        elif not flag and start is not None:
            end = index - 1
            if end - start + 1 >= min_length:
                runs.append((start, end))
            start = None
    return runs


def _split_wide_runs(
    runs: list[tuple[int, int]],
    expected_width: float,
    expected_gap: float,
) -> list[tuple[int, int]]:
    if expected_width <= 0 or expected_gap <= 0:
        return runs

    split_runs: list[tuple[int, int]] = []
    expected_pitch = expected_width + expected_gap
    for start, end in runs:
        length = end - start + 1
        estimated_count = int(round(length / expected_pitch))
        if estimated_count <= 1:
            split_runs.append((start, end))
            continue

        estimated_count = min(estimated_count, 4)
        segment_length = length / float(estimated_count)
        for index in range(estimated_count):
            seg_start = int(round(start + index * segment_length))
            seg_end = int(round(start + (index + 1) * segment_length)) - 1
            split_runs.append((seg_start, max(seg_start, seg_end)))
    return split_runs


def _select_consecutive_pad_centers(
    candidates: list[tuple[float, float, float, bool, bool]],
    required_count: int,
) -> list[float] | None:
    if len(candidates) < required_count:
        return None
    if len(candidates) == required_count:
        border_touches = sum(1 for _, _, _, touches_top, touches_bottom in candidates if touches_top or touches_bottom)
        if border_touches <= 1:
            return [center for center, *_rest in candidates]

    best: tuple[float, list[float]] | None = None
    for start in range(0, len(candidates) - required_count + 1):
        window = candidates[start : start + required_count]
        centers = [item[0] for item in window]
        if len(centers) < 2:
            continue
        gaps = np.diff(np.asarray(centers, dtype=np.float32))
        median_gap = float(np.median(gaps))
        if median_gap <= 0:
            continue
        gap_cv = float(np.std(gaps) / median_gap)
        mean_strength = float(np.mean([item[2] for item in window]))
        mean_width = float(np.mean([item[1] for item in window]))
        border_penalty = sum(1 for item in window if item[3] or item[4]) * 0.55
        score = mean_strength + min(mean_width / median_gap, 1.0) - (gap_cv * 2.0) - border_penalty
        if best is None or score > best[0]:
            best = (score, centers)

    if best is None or best[0] < -0.25:
        return None
    return best[1]


def _detect_pad_centers(
    image_bgr: np.ndarray,
    strip_bbox: tuple[int, int, int, int],
    pad_size: int,
    required_count: int,
) -> list[float] | None:
    x0, _y0, x1, _y1 = strip_bbox
    h, w = image_bgr.shape[:2]
    strip_width = x1 - x0 + 1
    center_x = int(round((x0 + x1) / 2.0))
    half_width = max(4, int(round(strip_width * 0.42)))
    sx0 = max(0, center_x - half_width)
    sx1 = min(w - 1, center_x + half_width)
    if sx1 <= sx0:
        return None

    strip = image_bgr[:, sx0 : sx1 + 1]
    hsv = cv2.cvtColor(strip, cv2.COLOR_BGR2HSV).astype(np.float32)
    sat = hsv[:, :, 1] / 255.0
    val = hsv[:, :, 2] / 255.0
    lab = cv2.cvtColor(strip, cv2.COLOR_BGR2LAB).astype(np.float32)
    chroma = np.sqrt(np.square(lab[:, :, 1] - 128.0) + np.square(lab[:, :, 2] - 128.0))

    sat_score = sat.mean(axis=1)
    chroma_score = chroma.mean(axis=1)
    chroma_score = chroma_score / max(1.0, float(np.percentile(chroma_score, 98)))
    value_score = 1.0 - np.abs(val.mean(axis=1) - 0.55)
    row_score = (0.52 * sat_score) + (0.34 * chroma_score) + (0.14 * np.clip(value_score, 0.0, 1.0))
    row_score = _smooth_projection(row_score, max(11, pad_size // 4))

    min_length = max(10, int(round(pad_size * 0.20)))
    threshold = max(0.10, float(np.percentile(row_score, 70)) * 0.50)
    runs = _find_runs(row_score >= threshold, min_length=min_length)
    if not runs:
        return None

    widths = np.asarray([end - start + 1 for start, end in runs], dtype=np.float32)
    reasonable = widths[(widths >= min_length) & (widths <= max(min_length + 1, pad_size * 1.45))]
    expected_width = float(np.median(reasonable)) if reasonable.size else float(np.median(widths))
    centers_for_gap = np.asarray([(start + end) / 2.0 for start, end in runs], dtype=np.float32)
    gaps = np.diff(centers_for_gap)
    reasonable_gaps = gaps[(gaps >= pad_size * 0.65) & (gaps <= pad_size * 2.4)]
    expected_gap = float(np.median(reasonable_gaps)) if reasonable_gaps.size else max(float(pad_size), expected_width)
    runs = _split_wide_runs(runs, expected_width=expected_width, expected_gap=expected_gap - expected_width)

    candidates: list[tuple[float, float, float, bool, bool]] = []
    for start, end in runs:
        width = end - start + 1
        if width < min_length:
            continue
        center = (start + end) / 2.0
        strength = float(np.mean(row_score[start : end + 1]))
        touches_top = start <= int(round(pad_size * 0.18))
        touches_bottom = end >= h - int(round(pad_size * 0.18))
        candidates.append((center, float(width), strength, touches_top, touches_bottom))

    candidates.sort(key=lambda item: item[0])
    return _select_consecutive_pad_centers(candidates, required_count)


def extract_markerless_features(
    image_bgr: np.ndarray,
    *,
    orientation: str = "unknown",
    config: MarkerlessStripConfig | None = None,
) -> MarkerlessStripResult:
    config = config or MarkerlessStripConfig()
    x0, y0, x1, y1, quality = _detect_strip_bbox(image_bgr, config)
    corrected, gains = _apply_gray_world_awb(image_bgr, (x0, y0, x1, y1))

    strip_width = x1 - x0 + 1
    strip_height = y1 - y0 + 1
    pad_size = max(4, int(round(strip_width * config.pad_inner_fraction)))
    crop_x0 = int(round((x0 + x1) / 2.0 - pad_size / 2.0))
    crop_x0 = max(0, min(corrected.shape[1] - pad_size, crop_x0))

    centers = _detect_pad_centers(corrected, (x0, y0, x1, y1), pad_size, len(ANALYTE_ORDER))
    if centers is None:
        # Fallback for low-contrast strips where individual row segments are
        # not reliable enough to replace the detected stack geometry.
        centers = np.linspace(y0 + (strip_height * 0.045), y1 - (strip_height * 0.045), len(ANALYTE_ORDER)).tolist()
    features: dict[str, tuple[float, float, float]] = {}
    rois: dict[str, tuple[int, int, int, int]] = {}
    for analyte, center_y in zip(ANALYTE_ORDER, centers, strict=True):
        crop_y0 = int(round(float(center_y) - pad_size / 2.0))
        crop_y0 = max(0, min(corrected.shape[0] - pad_size, crop_y0))
        crop = corrected[crop_y0 : crop_y0 + pad_size, crop_x0 : crop_x0 + pad_size]
        features[analyte] = _mean_lab(crop) if config.feature_space == "lab" else _mean_hsv(crop)
        rois[analyte] = (crop_x0, crop_y0, pad_size, pad_size)

    if config.feature_space == "normalized_hsv":
        features = _normalize_features(features)

    return MarkerlessStripResult(
        features_by_pad=features,
        pad_rois=rois,
        orientation=orientation,
        quality_score=quality,
        awb_gains_bgr=gains,
        strip_bbox=(x0, y0, x1, y1),
    )
