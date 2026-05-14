#!/usr/bin/env python3
"""
Bayesian decision fusion for urinalysis risk scoring.

Fuses:
- k-NN abnormal probability
- 8-bit binary symptom vector

Outputs posterior abnormal probability P and risk bucket.
"""

from __future__ import annotations

from dataclasses import dataclass
from math import exp, log
from typing import Sequence


@dataclass(frozen=True)
class BayesianFusionConfig:
    prior_abnormal: float = 0.5
    symptom_likelihood_if_abnormal: tuple[float, ...] = (
        0.70,
        0.68,
        0.62,
        0.66,
        0.74,
        0.58,
        0.64,
        0.72,
    )
    symptom_likelihood_if_normal: tuple[float, ...] = (
        0.22,
        0.24,
        0.20,
        0.26,
        0.30,
        0.18,
        0.21,
        0.25,
    )

    def validate(self) -> None:
        if not 0.0 < self.prior_abnormal < 1.0:
            raise ValueError("prior_abnormal must be between 0 and 1 (exclusive).")

        if len(self.symptom_likelihood_if_abnormal) != 8:
            raise ValueError("symptom_likelihood_if_abnormal must contain exactly 8 values.")

        if len(self.symptom_likelihood_if_normal) != 8:
            raise ValueError("symptom_likelihood_if_normal must contain exactly 8 values.")

        for value in self.symptom_likelihood_if_abnormal + self.symptom_likelihood_if_normal:
            if not 0.0 < value < 1.0:
                raise ValueError("All symptom likelihood values must be in (0, 1).")


class BayesianFusionEngine:
    def __init__(self, config: BayesianFusionConfig | None = None) -> None:
        self.config = config or BayesianFusionConfig()
        self.config.validate()

    @staticmethod
    def _clip_probability(probability: float, epsilon: float = 1e-6) -> float:
        return min(max(float(probability), epsilon), 1.0 - epsilon)

    def posterior_probability(
        self,
        knn_prob_abnormal: float,
        symptom_vector: Sequence[int],
    ) -> float:
        if len(symptom_vector) != 8:
            raise ValueError("symptom_vector must contain exactly 8 binary values.")

        p_knn = self._clip_probability(knn_prob_abnormal)
        prior = self._clip_probability(self.config.prior_abnormal)

        log_odds = log(prior / (1.0 - prior)) + log(p_knn / (1.0 - p_knn))

        for symptom, p_if_abnormal, p_if_normal in zip(
            symptom_vector,
            self.config.symptom_likelihood_if_abnormal,
            self.config.symptom_likelihood_if_normal,
            strict=True,
        ):
            s = 1 if int(symptom) > 0 else 0
            if s == 1:
                log_odds += log(p_if_abnormal / p_if_normal)
            else:
                log_odds += log((1.0 - p_if_abnormal) / (1.0 - p_if_normal))

        posterior = 1.0 / (1.0 + exp(-log_odds))
        return float(self._clip_probability(posterior))

    @staticmethod
    def risk_bucket(posterior_probability: float) -> str:
        probability = float(posterior_probability)
        if probability < 0.30:
            return "Low"
        if probability <= 0.70:
            return "Moderate"
        return "High"
