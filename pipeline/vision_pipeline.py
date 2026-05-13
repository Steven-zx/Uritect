#!/usr/bin/env python3
"""
Vision pipeline for urinalysis burst processing.

Implements the sequence:
1) Geometric rectification (Macro-Marker contour + perspective transform)
2) Radiometric normalization (AWB using 10x10 marker-center patch)
3) Spatial segmentation (fixed pad grid via marker-calibrated px/mm)
4) Signal cleaning (temporal median across burst)
5) Feature extraction (mean HSV per pad)
"""

from __future__ import annotations

from dataclasses import dataclass
from typing import Iterable

import cv2
import numpy as np

ANALYTE_ORDER: tuple[str, ...] = (
    "Leukocytes",
    "Nitrite",
    "Urobilinogen",
    "Protein",
    "pH",
    "Blood",
    "Specific Gravity",
    "Ketone",    "Bilirubin",
    "Glucose",
)

_DEFAULT_PAD_OFFSETS_MM: tuple[tuple[float, float], ...] = (
    (32.0, 5.0),
    (32.0, 12.5),
    (32.0, 20.0),
    (32.0, 27.5),
    (32.0, 35.0),
    (32.0, 42.5),
    (32.0, 50.0),
    (32.0, 57.5),
    (32.0, 65.0),
    (32.0, 72.5),
)


def analyte_to_key(analyte_name: str) -> str:
    return analyte_name.lower().replace(" ", "_")


def feature_columns_for_analyte(analyte_name: str, feature_space: str = "hsv") -> tuple[str, str, str]:
    key = analyte_to_key(analyte_name)
    if feature_space in {"hsv", "normalized_hsv"}:
        return f"{key}_h", f"{key}_s", f"{key}_v"
    if feature_space == "lab":
        return f"{key}_l", f"{key}_a", f"{key}_b"
    # Fallback to generic triple
    return f"{key}_x1", f"{key}_x2", f"{key}_x3"


def all_feature_columns(analytes: Iterable[str] = ANALYTE_ORDER, feature_space: str = "hsv") -> list[str]:
    columns: list[str] = []
    for analyte in analytes:
        columns.extend(feature_columns_for_analyte(analyte, feature_space=feature_space))
    return columns


def _normalize_hue(hue: float) -> float:
    normalized = hue % 360.0
    if normalized < 0:
        normalized += 360.0
    return normalized


def _clip_01(value: float) -> float:
    return min(max(value, 0.0), 1.0)


def _circular_mean_deg(values: list[float]) -> float:
    if not values:
        return 0.0
    sin_sum = float(np.sum(np.sin(np.radians(np.asarray(values, dtype=np.float32)))))
    cos_sum = float(np.sum(np.cos(np.radians(np.asarray(values, dtype=np.float32)))))
    if abs(sin_sum) < 1e-12 and abs(cos_sum) < 1e-12:
        return _normalize_hue(float(values[0]))
    return _normalize_hue(float(np.degrees(np.arctan2(sin_sum, cos_sum))))


@dataclass(frozen=True)
class VisionPipelineConfig:
    marker_size_mm: float = 20.0
    marker_size_px: int = 200
    marker_anchor_x_px: int = 80
    marker_anchor_y_px: int = 80
    output_width_px: int = 1400
    output_height_px: int = 1800
    center_patch_px: int = 10
    pad_width_mm: float = 5.0
    pad_height_mm: float = 5.0
    pad_offsets_mm: tuple[tuple[float, float], ...] = _DEFAULT_PAD_OFFSETS_MM
    analyte_order: tuple[str, ...] = ANALYTE_ORDER
    min_marker_area_px: float = 1200.0
    max_marker_area_ratio: float = 0.25
    border_reject_margin_ratio: float = 0.005
    max_quad_side_ratio: float = 3.5
    adaptive_grid_enabled: bool = True
    adaptive_x_search_px: int = 220
    adaptive_x_step_px: int = 10
    adaptive_y_search_px: int = 60
    adaptive_y_step_px: int = 4
    per_pad_localization_enabled: bool = True
    per_pad_y_refine_px: int = 6
    per_pad_y_step_px: int = 2
    per_pad_max_step_deviation_px: int = 8
    feature_space: str = "hsv"

    def validate(self) -> None:
        if len(self.pad_offsets_mm) != len(self.analyte_order):
            raise ValueError(
                "pad_offsets_mm must match analyte_order length "
                f"({len(self.pad_offsets_mm)} != {len(self.analyte_order)})"
            )
        if self.marker_size_mm <= 0:
            raise ValueError("marker_size_mm must be > 0")
        if self.marker_size_px <= 0:
            raise ValueError("marker_size_px must be > 0")
        if self.output_width_px <= 0 or self.output_height_px <= 0:
            raise ValueError("output dimensions must be > 0")
        if self.center_patch_px <= 0:
            raise ValueError("center_patch_px must be > 0")
        if not 0.0 < self.max_marker_area_ratio <= 1.0:
            raise ValueError("max_marker_area_ratio must be in (0, 1]")
        if not 0.0 <= self.border_reject_margin_ratio <= 0.1:
            raise ValueError("border_reject_margin_ratio must be in [0, 0.1]")
        if self.max_quad_side_ratio <= 1.0:
            raise ValueError("max_quad_side_ratio must be > 1")
        if self.adaptive_x_search_px < 0:
            raise ValueError("adaptive_x_search_px must be >= 0")
        if self.adaptive_x_step_px <= 0:
            raise ValueError("adaptive_x_step_px must be > 0")
        if self.adaptive_y_search_px < 0:
            raise ValueError("adaptive_y_search_px must be >= 0")
        if self.adaptive_y_step_px <= 0:
            raise ValueError("adaptive_y_step_px must be > 0")
        if self.per_pad_y_refine_px < 0:
            raise ValueError("per_pad_y_refine_px must be >= 0")
        if self.per_pad_y_step_px <= 0:
            raise ValueError("per_pad_y_step_px must be > 0")
        if self.per_pad_max_step_deviation_px < 0:
            raise ValueError("per_pad_max_step_deviation_px must be >= 0")
        if self.feature_space not in {"hsv", "normalized_hsv", "lab"}:
            raise ValueError("feature_space must be one of: hsv, normalized_hsv, lab")


@dataclass
class RectificationResult:
    rectified_bgr: np.ndarray
    marker_corners_src: np.ndarray
    marker_corners_dst: np.ndarray
    homography: np.ndarray


@dataclass
class AwbResult:
    awb_bgr: np.ndarray
    gain_b: float
    gain_g: float
    gain_r: float
    center_patch_mean_bgr: tuple[float, float, float]


@dataclass
class BurstProcessingResult:
    features_by_pad: dict[str, tuple[float, float, float]]
    flat_feature_vector: list[float]
    frames_total: int
    frames_used: int
    frames_skipped: int
    frame_errors: list[str]


@dataclass
class PadLocalizationResult:
    analyte_name: str
    base_x: int
    base_y: int
    final_x: int
    final_y: int
    width: int
    height: int
    local_dx: int
    local_dy: int
    local_score: float


class MacroMarkerRectifier:
    def __init__(self, config: VisionPipelineConfig) -> None:
        self.config = config

    def _destination_marker_corners(self) -> np.ndarray:
        x0 = float(self.config.marker_anchor_x_px)
        y0 = float(self.config.marker_anchor_y_px)
        size = float(self.config.marker_size_px)
        return np.array(
            [
                [x0, y0],
                [x0 + size, y0],
                [x0 + size, y0 + size],
                [x0, y0 + size],
            ],
            dtype=np.float32,
        )

    def _order_corners(self, points: np.ndarray) -> np.ndarray:
        pts = points.astype(np.float32)
        sums = pts.sum(axis=1)
        diffs = np.diff(pts, axis=1).reshape(-1)

        top_left = pts[np.argmin(sums)]
        bottom_right = pts[np.argmax(sums)]
        top_right = pts[np.argmin(diffs)]
        bottom_left = pts[np.argmax(diffs)]

        return np.array([top_left, top_right, bottom_right, bottom_left], dtype=np.float32)

    def _touches_image_border(
        self,
        points: np.ndarray,
        image_width: int,
        image_height: int,
        margin_px: float,
    ) -> bool:
        min_x = float(np.min(points[:, 0]))
        min_y = float(np.min(points[:, 1]))
        max_x = float(np.max(points[:, 0]))
        max_y = float(np.max(points[:, 1]))

        return (
            min_x <= margin_px
            or min_y <= margin_px
            or max_x >= (image_width - 1 - margin_px)
            or max_y >= (image_height - 1 - margin_px)
        )

    def _quad_side_ratio(self, points: np.ndarray) -> float:
        side_lengths = [
            float(np.linalg.norm(points[(index + 1) % 4] - points[index]))
            for index in range(4)
        ]
        shortest = min(side_lengths)
        if shortest <= 1e-6:
            return float("inf")
        return max(side_lengths) / shortest

    def _marker_pattern_score(self, image_bgr: np.ndarray, quad: np.ndarray) -> float:
        ordered = self._order_corners(quad)
        size = 120
        dst = np.array(
            [[0, 0], [size - 1, 0], [size - 1, size - 1], [0, size - 1]],
            dtype=np.float32,
        )
        homography = cv2.getPerspectiveTransform(ordered, dst)
        patch = cv2.warpPerspective(image_bgr, homography, (size, size), flags=cv2.INTER_LINEAR)
        gray = cv2.cvtColor(patch, cv2.COLOR_BGR2GRAY).astype(np.float32) / 255.0

        border = np.concatenate(
            [
                gray[:24, :].reshape(-1),
                gray[-24:, :].reshape(-1),
                gray[:, :24].reshape(-1),
                gray[:, -24:].reshape(-1),
            ]
        )
        center = gray[42:78, 42:78].reshape(-1)
        if center.size == 0 or border.size == 0:
            return -float("inf")

        border_median = float(np.median(border))
        center_median = float(np.median(center))
        return ((1.0 - border_median) * 1.2) + (center_median * 0.9) + ((center_median - border_median) * 1.8)

    def _detect_marker_by_dark_square_pattern(self, image_bgr: np.ndarray, gray: np.ndarray) -> np.ndarray | None:
        image_height, image_width = gray.shape
        image_area = float(image_width * image_height)
        border_margin_px = max(
            1.0,
            min(float(image_width), float(image_height)) * float(self.config.border_reject_margin_ratio) * 0.5,
        )
        min_area = max(180.0, min(self.config.min_marker_area_px * 0.5, image_area * 0.00008))
        max_area = image_area * min(0.45, float(self.config.max_marker_area_ratio) * 1.8)

        blur = cv2.GaussianBlur(gray, (5, 5), 0)
        percentile_threshold = int(np.percentile(blur, 18))
        percentile_threshold = max(35, min(150, percentile_threshold))
        _, dark_percentile = cv2.threshold(blur, percentile_threshold, 255, cv2.THRESH_BINARY_INV)
        _, dark_otsu = cv2.threshold(blur, 0, 255, cv2.THRESH_BINARY_INV + cv2.THRESH_OTSU)
        adaptive_dark = cv2.adaptiveThreshold(
            blur,
            255,
            cv2.ADAPTIVE_THRESH_GAUSSIAN_C,
            cv2.THRESH_BINARY_INV,
            41,
            7,
        )

        kernel = cv2.getStructuringElement(cv2.MORPH_RECT, (5, 5))
        best_quad: np.ndarray | None = None
        best_score = -float("inf")

        for binary_map in (dark_percentile, dark_otsu, adaptive_dark):
            closed = cv2.morphologyEx(binary_map, cv2.MORPH_CLOSE, kernel, iterations=2)
            contours, _ = cv2.findContours(closed, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)

            for contour in sorted(contours, key=cv2.contourArea, reverse=True)[:160]:
                contour_area = float(cv2.contourArea(contour))
                if contour_area < min_area:
                    continue

                rect = cv2.minAreaRect(contour)
                (_, _), (width_px, height_px), _ = rect
                if width_px <= 4.0 or height_px <= 4.0:
                    continue

                rect_area = float(width_px * height_px)
                if rect_area < min_area or rect_area > max_area:
                    continue

                aspect_ratio = max(width_px, height_px) / max(1.0, min(width_px, height_px))
                if aspect_ratio > self.config.max_quad_side_ratio:
                    continue

                box = cv2.boxPoints(rect).astype(np.float32)
                ordered = self._order_corners(box)
                if self._touches_image_border(
                    ordered,
                    image_width=image_width,
                    image_height=image_height,
                    margin_px=border_margin_px,
                ):
                    continue

                fill_ratio = contour_area / max(rect_area, 1.0)
                if fill_ratio < 0.18:
                    continue

                pattern_score = self._marker_pattern_score(image_bgr, ordered)
                if pattern_score < 1.15:
                    continue

                area_score = min(rect_area / max(image_area * 0.035, 1.0), 1.5)
                score = pattern_score + area_score - (abs(1.0 - aspect_ratio) * 0.35)
                if score > best_score:
                    best_score = score
                    best_quad = ordered

        return best_quad

    def detect_marker_corners(self, image_bgr: np.ndarray) -> np.ndarray:
        gray = cv2.cvtColor(image_bgr, cv2.COLOR_BGR2GRAY)
        image_height, image_width = gray.shape
        image_area = float(image_width * image_height)
        max_allowed_area = image_area * float(self.config.max_marker_area_ratio)
        border_margin_px = max(
            2.0,
            min(float(image_width), float(image_height)) * float(self.config.border_reject_margin_ratio),
        )

        blur = cv2.GaussianBlur(gray, (5, 5), 0)

        edges = cv2.Canny(blur, 50, 160)
        adaptive = cv2.adaptiveThreshold(
            blur,
            255,
            cv2.ADAPTIVE_THRESH_GAUSSIAN_C,
            cv2.THRESH_BINARY,
            31,
            5,
        )

        best_quad: np.ndarray | None = None
        best_area = 0.0

        def consider_quad(candidate_quad: np.ndarray, area: float) -> None:
            nonlocal best_quad, best_area
            if area < self.config.min_marker_area_px or area > max_allowed_area:
                return

            quad = self._order_corners(candidate_quad.astype(np.float32))
            if self._touches_image_border(
                quad,
                image_width=image_width,
                image_height=image_height,
                margin_px=border_margin_px,
            ):
                return

            if self._quad_side_ratio(quad) > self.config.max_quad_side_ratio:
                return

            if area > best_area:
                best_area = area
                best_quad = quad

        for binary_map in (edges, adaptive):
            contours, _ = cv2.findContours(binary_map, cv2.RETR_LIST, cv2.CHAIN_APPROX_SIMPLE)
            for contour in sorted(contours, key=cv2.contourArea, reverse=True)[:120]:
                area = float(cv2.contourArea(contour))
                if area < self.config.min_marker_area_px:
                    continue
                if area > max_allowed_area:
                    continue

                peri = cv2.arcLength(contour, True)
                approx = cv2.approxPolyDP(contour, 0.02 * peri, True)
                if len(approx) != 4:
                    continue
                if not cv2.isContourConvex(approx):
                    continue

                consider_quad(approx.reshape(4, 2).astype(np.float32), area)

            if best_quad is not None:
                break

        # Fallback: if strict detection failed, try relaxed thresholds
        if best_quad is None:
            relaxed_edges = cv2.Canny(blur, 30, 100)  # Lower thresholds
            contours, _ = cv2.findContours(relaxed_edges, cv2.RETR_LIST, cv2.CHAIN_APPROX_SIMPLE)
            for contour in sorted(contours, key=cv2.contourArea, reverse=True)[:50]:
                area = float(cv2.contourArea(contour))
                if area < self.config.min_marker_area_px * 0.7:  # Relaxed min area
                    continue
                if area > max_allowed_area * 1.5:  # Relaxed max area
                    continue

                peri = cv2.arcLength(contour, True)
                approx = cv2.approxPolyDP(contour, 0.03 * peri, True)  # Relaxed DP epsilon
                if len(approx) != 4:
                    continue
                if not cv2.isContourConvex(approx):
                    continue

                quad = self._order_corners(approx.reshape(4, 2).astype(np.float32))
                if self._touches_image_border(
                    quad,
                    image_width=image_width,
                    image_height=image_height,
                    margin_px=border_margin_px * 0.5,  # Relaxed border margin
                ):
                    continue

                if self._quad_side_ratio(quad) > self.config.max_quad_side_ratio * 1.2:  # Relaxed ratio
                    continue

                if area > best_area:
                    best_area = area
                    best_quad = quad

        if best_quad is None:
            inverted = cv2.bitwise_not(gray)
            _, otsu = cv2.threshold(inverted, 0, 255, cv2.THRESH_BINARY + cv2.THRESH_OTSU)
            kernel = cv2.getStructuringElement(cv2.MORPH_RECT, (5, 5))
            closed = cv2.morphologyEx(otsu, cv2.MORPH_CLOSE, kernel, iterations=2)
            contours, _ = cv2.findContours(closed, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)

            for contour in sorted(contours, key=cv2.contourArea, reverse=True)[:40]:
                area = float(cv2.contourArea(contour))
                if area < self.config.min_marker_area_px * 0.6:
                    continue

                rect = cv2.minAreaRect(contour)
                (_, _), (width_px, height_px), _ = rect
                if width_px <= 1.0 or height_px <= 1.0:
                    continue

                rect_area = float(width_px * height_px)
                if rect_area <= 0.0:
                    continue

                fill_ratio = area / rect_area
                aspect_ratio = max(width_px, height_px) / min(width_px, height_px)
                if fill_ratio < 0.35:
                    continue
                if aspect_ratio > self.config.max_quad_side_ratio * 1.6:
                    continue

                box = cv2.boxPoints(rect).astype(np.float32)
                consider_quad(box, max(area, rect_area * 0.75))

        if best_quad is None:
            best_quad = self._detect_marker_by_dark_square_pattern(image_bgr, gray)

        if best_quad is None:
            raise ValueError("Macro-Marker with 4-corner contour was not detected. Check marker visibility, lighting, and focus.")

        return best_quad

    def rectify(self, image_bgr: np.ndarray) -> RectificationResult:
        src = self.detect_marker_corners(image_bgr)
        dst = self._destination_marker_corners()

        homography = cv2.getPerspectiveTransform(src, dst)
        rectified = cv2.warpPerspective(
            image_bgr,
            homography,
            (self.config.output_width_px, self.config.output_height_px),
            flags=cv2.INTER_LINEAR,
        )

        return RectificationResult(
            rectified_bgr=rectified,
            marker_corners_src=src,
            marker_corners_dst=dst,
            homography=homography,
        )


class AdaptiveWhiteBalancer:
    def __init__(self, config: VisionPipelineConfig) -> None:
        self.config = config

    def _marker_center_patch(self, image_bgr: np.ndarray, marker_corners_dst: np.ndarray) -> np.ndarray:
        center = np.mean(marker_corners_dst, axis=0)
        cx = int(round(float(center[0])))
        cy = int(round(float(center[1])))

        patch_size = int(self.config.center_patch_px)
        half = patch_size // 2

        x0 = max(0, cx - half)
        y0 = max(0, cy - half)
        x1 = min(image_bgr.shape[1], x0 + patch_size)
        y1 = min(image_bgr.shape[0], y0 + patch_size)

        patch = image_bgr[y0:y1, x0:x1]
        if patch.size == 0:
            raise ValueError("AWB center patch is empty; marker center is out of image bounds.")
        return patch

    def apply(self, rectified_bgr: np.ndarray, marker_corners_dst: np.ndarray) -> AwbResult:
        patch = self._marker_center_patch(rectified_bgr, marker_corners_dst)

        means_bgr = patch.reshape(-1, 3).mean(axis=0).astype(np.float32)
        means_bgr = np.clip(means_bgr, 1.0, None)
        target = float(np.max(means_bgr))

        gains = target / means_bgr
        corrected = np.clip(rectified_bgr.astype(np.float32) * gains.reshape(1, 1, 3), 0, 255).astype(np.uint8)

        return AwbResult(
            awb_bgr=corrected,
            gain_b=float(gains[0]),
            gain_g=float(gains[1]),
            gain_r=float(gains[2]),
            center_patch_mean_bgr=(float(means_bgr[0]), float(means_bgr[1]), float(means_bgr[2])),
        )


class GridSlicer:
    def __init__(self, config: VisionPipelineConfig) -> None:
        self.config = config
        self.last_global_x_shift_px: int = 0
        self.last_global_y_shift_px: int = 0
        self.last_pad_localization: dict[str, PadLocalizationResult] = {}

    def pixels_per_mm(self) -> float:
        return float(self.config.marker_size_px) / float(self.config.marker_size_mm)

    def _crop(self, image_bgr: np.ndarray, x: int, y: int, w: int, h: int) -> np.ndarray:
        x0 = max(0, x)
        y0 = max(0, y)
        x1 = min(image_bgr.shape[1], x + w)
        y1 = min(image_bgr.shape[0], y + h)

        if x1 <= x0 or y1 <= y0:
            raise ValueError("Computed pad ROI is outside image bounds.")

        return image_bgr[y0:y1, x0:x1].copy()

    def _compute_pad_geometry(self) -> tuple[int, int, int, int, float]:
        ppm = self.pixels_per_mm()
        pad_w = max(1, int(round(self.config.pad_width_mm * ppm)))
        pad_h = max(1, int(round(self.config.pad_height_mm * ppm)))
        marker_x = int(round(self.config.marker_anchor_x_px))
        marker_y = int(round(self.config.marker_anchor_y_px))
        return marker_x, marker_y, pad_w, pad_h, ppm

    def _pad_roi(
        self,
        marker_x: int,
        marker_y: int,
        ppm: float,
        offset_x_mm: float,
        offset_y_mm: float,
        global_x_shift_px: int = 0,
        global_y_shift_px: int = 0,
        local_dy_px: int = 0,
    ) -> tuple[int, int]:
        x = int(round(marker_x + offset_x_mm * ppm)) + int(global_x_shift_px)
        y = int(round(marker_y + offset_y_mm * ppm)) + int(global_y_shift_px) + int(local_dy_px)
        return x, y

    def _slice_pads_with_shift(
        self,
        awb_bgr: np.ndarray,
        x_shift_px: int,
        y_shift_px: int,
        per_pad_y_offset: dict[str, int] | None = None,
    ) -> dict[str, np.ndarray]:
        marker_x, marker_y, pad_w, pad_h, ppm = self._compute_pad_geometry()
        crops: dict[str, np.ndarray] = {}
        for analyte_name, (offset_x_mm, offset_y_mm) in zip(
            self.config.analyte_order,
            self.config.pad_offsets_mm,
            strict=True,
        ):
            local_dy = 0
            if per_pad_y_offset is not None:
                local_dy = int(per_pad_y_offset.get(analyte_name, 0))
            x, y = self._pad_roi(
                marker_x=marker_x,
                marker_y=marker_y,
                ppm=ppm,
                offset_x_mm=offset_x_mm,
                offset_y_mm=offset_y_mm,
                global_x_shift_px=x_shift_px,
                global_y_shift_px=y_shift_px,
                local_dy_px=local_dy,
            )
            crops[analyte_name] = self._crop(awb_bgr, x, y, pad_w, pad_h)
        return crops

    def _single_pad_lock_score(self, crop_bgr: np.ndarray) -> float:
        hsv = cv2.cvtColor(crop_bgr, cv2.COLOR_BGR2HSV).astype(np.float32)
        gray = cv2.cvtColor(crop_bgr, cv2.COLOR_BGR2GRAY)

        hue_std = float(np.std(hsv[:, :, 0]) * 2.0)
        sat = hsv[:, :, 1] / 255.0
        val = hsv[:, :, 2] / 255.0
        sat_std = float(np.std(sat))
        mean_val = float(np.mean(hsv[:, :, 2]) / 255.0)
        mean_sat = float(np.mean(sat))
        edges = cv2.Canny(gray, 30, 100)
        edge_density = float(np.mean(edges > 0))

        texture_signal = (hue_std * 0.1) + (mean_sat * 25.0) + (mean_val * 5.0) - (sat_std * 20.0)
        structure_penalty = edge_density * 35.0
        clipping_penalty = 0.0
        if mean_val >= 0.995:
            clipping_penalty += 0.5
        return texture_signal - structure_penalty - clipping_penalty

    def _refine_single_pad_y(
        self,
        awb_bgr: np.ndarray,
        analyte_name: str,
        offset_x_mm: float,
        offset_y_mm: float,
        marker_x: int,
        marker_y: int,
        pad_w: int,
        pad_h: int,
        ppm: float,
        global_x_shift_px: int,
        global_y_shift_px: int,
        prev_expected_y: int | None,
        prev_final_y: int | None,
    ) -> tuple[np.ndarray, PadLocalizationResult]:
        base_x, base_y = self._pad_roi(
            marker_x=marker_x,
            marker_y=marker_y,
            ppm=ppm,
            offset_x_mm=offset_x_mm,
            offset_y_mm=offset_y_mm,
            global_x_shift_px=global_x_shift_px,
            global_y_shift_px=global_y_shift_px,
        )

        search_px = int(self.config.per_pad_y_refine_px)
        step_px = int(self.config.per_pad_y_step_px)

        best_crop = self._crop(awb_bgr, base_x, base_y, pad_w, pad_h)
        best_dy = 0
        best_score = self._single_pad_lock_score(best_crop)

        for dy in range(-search_px, search_px + 1, step_px):
            y = base_y + dy

            if prev_expected_y is not None and prev_final_y is not None:
                expected_step = int(base_y - prev_expected_y)
                actual_step = int(y - prev_final_y)
                if abs(actual_step - expected_step) > int(self.config.per_pad_max_step_deviation_px):
                    continue

            try:
                candidate = self._crop(awb_bgr, base_x, y, pad_w, pad_h)
            except ValueError:
                continue

            score = self._single_pad_lock_score(candidate) - (abs(dy) * 0.05)
            if score > best_score:
                best_crop = candidate
                best_dy = dy
                best_score = score

        localization = PadLocalizationResult(
            analyte_name=analyte_name,
            base_x=base_x,
            base_y=base_y,
            final_x=base_x,
            final_y=base_y + best_dy,
            width=pad_w,
            height=pad_h,
            local_dx=0,
            local_dy=best_dy,
            local_score=float(best_score),
        )
        return best_crop, localization

    def _alignment_score(self, pad_crops: dict[str, np.ndarray]) -> float:
        hue_means: list[float] = []
        sat_means: list[float] = []
        val_means: list[float] = []
        clipped_count = 0
        edge_density_list: list[float] = []

        for analyte_name in self.config.analyte_order:
            crop = pad_crops[analyte_name]
            hsv = cv2.cvtColor(crop, cv2.COLOR_BGR2HSV).astype(np.float32)
            gray = cv2.cvtColor(crop, cv2.COLOR_BGR2GRAY)
            h = float(np.mean(hsv[:, :, 0]) * 2.0)
            s = float(np.mean(hsv[:, :, 1]) / 255.0)
            v = float(np.mean(hsv[:, :, 2]) / 255.0)
            hue_means.append(h)
            sat_means.append(s)
            val_means.append(v)
            edge_density_list.append(float(np.mean(cv2.Canny(gray, 30, 100) > 0)))
            if v >= 0.995:
                clipped_count += 1

        hue_std = float(np.std(np.array(hue_means, dtype=np.float32)))
        sat_std = float(np.std(np.array(sat_means, dtype=np.float32)))
        val_std = float(np.std(np.array(val_means, dtype=np.float32)))
        sat_mean = float(np.mean(np.array(sat_means, dtype=np.float32)))
        edge_density_mean = float(np.mean(np.array(edge_density_list, dtype=np.float32)))

        color_separation = hue_std + (sat_std * 100.0) + (val_std * 100.0)
        clipping_penalty = clipped_count * 0.75
        return color_separation + (sat_mean * 20.0) - clipping_penalty - (edge_density_mean * 30.0)

    def slice_pads(self, awb_bgr: np.ndarray) -> dict[str, np.ndarray]:
        if not self.config.adaptive_grid_enabled:
            self.last_global_x_shift_px = 0
            self.last_global_y_shift_px = 0
            self.last_pad_localization = {}
            return self._slice_pads_with_shift(awb_bgr, x_shift_px=0, y_shift_px=0)

        search_px = int(self.config.adaptive_x_search_px)
        step_px = int(self.config.adaptive_x_step_px)
        search_y_px = int(self.config.adaptive_y_search_px)
        step_y_px = int(self.config.adaptive_y_step_px)

        best_crops: dict[str, np.ndarray] | None = None
        best_score = -float("inf")
        best_x_shift = 0
        best_y_shift = 0

        for x_shift in range(-search_px, search_px + 1, step_px):
            for y_shift in range(-search_y_px, search_y_px + 1, step_y_px):
                try:
                    candidate = self._slice_pads_with_shift(
                        awb_bgr,
                        x_shift_px=x_shift,
                        y_shift_px=y_shift,
                    )
                except ValueError:
                    continue

                score = self._alignment_score(candidate)
                if score > best_score:
                    best_score = score
                    best_crops = candidate
                    best_x_shift = x_shift
                    best_y_shift = y_shift

        if best_crops is None:
            raise ValueError("Adaptive grid localization failed to produce valid pad crops.")

        self.last_global_x_shift_px = int(best_x_shift)
        self.last_global_y_shift_px = int(best_y_shift)

        if not self.config.per_pad_localization_enabled:
            self.last_pad_localization = {}
            return best_crops

        marker_x, marker_y, pad_w, pad_h, ppm = self._compute_pad_geometry()
        refined: dict[str, np.ndarray] = {}
        localization: dict[str, PadLocalizationResult] = {}
        prev_expected_y: int | None = None
        prev_final_y: int | None = None

        for analyte_name, (offset_x_mm, offset_y_mm) in zip(
            self.config.analyte_order,
            self.config.pad_offsets_mm,
            strict=True,
        ):
            crop, result = self._refine_single_pad_y(
                awb_bgr=awb_bgr,
                analyte_name=analyte_name,
                offset_x_mm=offset_x_mm,
                offset_y_mm=offset_y_mm,
                marker_x=marker_x,
                marker_y=marker_y,
                pad_w=pad_w,
                pad_h=pad_h,
                ppm=ppm,
                global_x_shift_px=best_x_shift,
                global_y_shift_px=best_y_shift,
                prev_expected_y=prev_expected_y,
                prev_final_y=prev_final_y,
            )
            refined[analyte_name] = crop
            localization[analyte_name] = result
            prev_expected_y = result.base_y
            prev_final_y = result.final_y

        self.last_pad_localization = localization
        return refined


class TemporalMedianCleaner:
    def clean(self, burst_pad_crops: dict[str, list[np.ndarray]]) -> dict[str, np.ndarray]:
        cleaned: dict[str, np.ndarray] = {}

        for analyte_name, frames in burst_pad_crops.items():
            if not frames:
                raise ValueError(f"No burst frames available for pad '{analyte_name}'.")

            target_h, target_w = frames[0].shape[:2]
            aligned: list[np.ndarray] = []
            for frame in frames:
                if frame.shape[:2] != (target_h, target_w):
                    frame = cv2.resize(frame, (target_w, target_h), interpolation=cv2.INTER_AREA)
                aligned.append(frame)

            stack = np.stack(aligned, axis=0).astype(np.float32)
            median_frame = np.median(stack, axis=0).astype(np.uint8)
            cleaned[analyte_name] = median_frame

        return cleaned


class HSVFeatureExtractor:
    def __init__(self, config: VisionPipelineConfig) -> None:
        self.config = config

    def _raw_pad_feature(self, pad_bgr: np.ndarray) -> tuple[float, float, float]:
        hsv = cv2.cvtColor(pad_bgr, cv2.COLOR_BGR2HSV).astype(np.float32)
        h = float(np.mean(hsv[:, :, 0]) * 2.0)  # OpenCV H is 0..179
        s = float(np.mean(hsv[:, :, 1]) / 255.0)
        v = float(np.mean(hsv[:, :, 2]) / 255.0)
        return round(h, 6), round(s, 6), round(v, 6)

    def _normalize_feature_space(self, features_by_pad: dict[str, tuple[float, float, float]]) -> dict[str, tuple[float, float, float]]:
        hue_values = [h for h, _, _ in features_by_pad.values()]
        sat_values = [s for _, s, _ in features_by_pad.values()]
        val_values = [v for _, _, v in features_by_pad.values()]

        hue_anchor = _circular_mean_deg(hue_values)
        sat_anchor = float(np.mean(np.array(sat_values, dtype=np.float32))) if sat_values else 0.0
        val_anchor = float(np.mean(np.array(val_values, dtype=np.float32))) if val_values else 0.0

        normalized: dict[str, tuple[float, float, float]] = {}
        for analyte_name, (h, s, v) in features_by_pad.items():
            normalized[analyte_name] = (
                round(_normalize_hue(h - hue_anchor), 6),
                round(_clip_01(0.5 + (s - sat_anchor)), 6),
                round(_clip_01(0.5 + (v - val_anchor)), 6),
            )
        return normalized

    def extract_pad_feature(self, pad_bgr: np.ndarray) -> tuple[float, float, float]:
        return self._raw_pad_feature(pad_bgr)

    def extract(self, cleaned_pads: dict[str, np.ndarray]) -> dict[str, tuple[float, float, float]]:
        features_by_pad = {
            analyte_name: self.extract_pad_feature(pad_bgr)
            for analyte_name, pad_bgr in cleaned_pads.items()
        }

        if self.config.feature_space == "normalized_hsv":
            return self._normalize_feature_space(features_by_pad)

        return features_by_pad

    def flatten(
        self,
        features_by_pad: dict[str, tuple[float, float, float]],
        analyte_order: Iterable[str],
    ) -> list[float]:
        flat: list[float] = []
        for analyte_name in analyte_order:
            h, s, v = features_by_pad[analyte_name]
            flat.extend([h, s, v])
        return flat


class LABFeatureExtractor:
    def __init__(self, config: VisionPipelineConfig) -> None:
        self.config = config

    def _raw_pad_feature(self, pad_bgr: np.ndarray) -> tuple[float, float, float]:
        lab = cv2.cvtColor(pad_bgr, cv2.COLOR_BGR2LAB).astype(np.float32)
        # OpenCV L: 0..255, a: 0..255 (128 center), b: 0..255 (128 center)
        L = float(np.mean(lab[:, :, 0]) / 255.0 * 100.0)
        a = float(np.mean(lab[:, :, 1]) - 128.0)
        b = float(np.mean(lab[:, :, 2]) - 128.0)
        return round(L, 6), round(a, 6), round(b, 6)

    def extract_pad_feature(self, pad_bgr: np.ndarray) -> tuple[float, float, float]:
        return self._raw_pad_feature(pad_bgr)

    def extract(self, cleaned_pads: dict[str, np.ndarray]) -> dict[str, tuple[float, float, float]]:
        features_by_pad = {
            analyte_name: self.extract_pad_feature(pad_bgr)
            for analyte_name, pad_bgr in cleaned_pads.items()
        }
        return features_by_pad

    def flatten(
        self,
        features_by_pad: dict[str, tuple[float, float, float]],
        analyte_order: Iterable[str],
    ) -> list[float]:
        flat: list[float] = []
        for analyte_name in analyte_order:
            L, a, b = features_by_pad[analyte_name]
            flat.extend([L, a, b])
        return flat


class BurstFeaturePipeline:
    def __init__(self, config: VisionPipelineConfig | None = None) -> None:
        self.config = config or VisionPipelineConfig()
        self.config.validate()
        self.rectifier = MacroMarkerRectifier(self.config)
        self.awb = AdaptiveWhiteBalancer(self.config)
        self.slicer = GridSlicer(self.config)
        self.cleaner = TemporalMedianCleaner()
        if self.config.feature_space == "lab":
            self.extractor = LABFeatureExtractor(self.config)
        else:
            self.extractor = HSVFeatureExtractor(self.config)

    def process_burst(self, frames_bgr: list[np.ndarray]) -> BurstProcessingResult:
        if not frames_bgr:
            raise ValueError("Burst must contain at least one frame.")

        burst_pad_crops: dict[str, list[np.ndarray]] = {
            analyte_name: [] for analyte_name in self.config.analyte_order
        }

        frame_errors: list[str] = []
        used = 0
        marker_detection_failures = 0
        other_failures = 0

        for index, frame_bgr in enumerate(frames_bgr):
            try:
                rectified = self.rectifier.rectify(frame_bgr)
                awb = self.awb.apply(rectified.rectified_bgr, rectified.marker_corners_dst)
                pad_crops = self.slicer.slice_pads(awb.awb_bgr)

                for analyte_name, crop in pad_crops.items():
                    burst_pad_crops[analyte_name].append(crop)

                used += 1
            except ValueError as error:
                message = str(error)
                if "Macro-Marker" in message:
                    marker_detection_failures += 1
                    label = "marker"
                else:
                    other_failures += 1
                    label = "processing"
                frame_errors.append(f"frame_{index + 1} [{label}]: {message[:90]}")
            except Exception as error:  # Other errors
                other_failures += 1
                frame_errors.append(f"frame_{index + 1} [other]: {str(error)[:60]}")

        if used == 0:
            error_summary = f"Marker: {marker_detection_failures}, Other: {other_failures}"
            raise ValueError(
                f"No valid frames processed. {error_summary}. "
                f"Ensure marker is visible, well-lit, and in focus. Check dipstick orientation."
            )

        cleaned_pads = self.cleaner.clean(burst_pad_crops)
        features_by_pad = self.extractor.extract(cleaned_pads)
        flat_vector = self.extractor.flatten(features_by_pad, self.config.analyte_order)

        return BurstProcessingResult(
            features_by_pad=features_by_pad,
            flat_feature_vector=flat_vector,
            frames_total=len(frames_bgr),
            frames_used=used,
            frames_skipped=len(frames_bgr) - used,
            frame_errors=frame_errors,
        )


def decode_image_bytes(encoded_bytes: bytes) -> np.ndarray:
    np_buffer = np.frombuffer(encoded_bytes, dtype=np.uint8)
    decoded = cv2.imdecode(np_buffer, cv2.IMREAD_COLOR)
    if decoded is None:
        raise ValueError("Failed to decode image bytes using OpenCV.")
    return decoded
