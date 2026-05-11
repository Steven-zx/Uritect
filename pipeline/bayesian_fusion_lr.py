"""Bayesian Likelihood Ratio fusion engine for clinical symptoms + visual evidence."""
from __future__ import annotations

import json
import logging
from dataclasses import dataclass
from pathlib import Path
from typing import Optional

import numpy as np
from scipy.special import expit

logger = logging.getLogger(__name__)


@dataclass
class ClinicalSymptomLR:
    """Bayesian LR for a single clinical symptom."""
    id: str
    label: str
    category: str  # 'lut' or 'renal'
    lr_positive: float  # LR+ when symptom present
    lr_negative: float  # LR- when symptom absent


CLINICAL_SYMPTOMS_LR = [
    # Category 1: Lower Urinary Tract Symptoms
    ClinicalSymptomLR('dysuria', 'Burning sensation while urinating', 'lut', 2.8, 0.35),
    ClinicalSymptomLR('frequency', 'Frequent urination', 'lut', 2.2, 0.42),
    ClinicalSymptomLR('suprapubic', 'Lower abdominal pain', 'lut', 2.0, 0.45),
    ClinicalSymptomLR('hematuria', 'Visible hematuria', 'lut', 5.8, 0.92),
    # Category 2: Renal & Systemic Red Flags
    ClinicalSymptomLR('flank', 'Back pain', 'renal', 4.3, 0.62),
    ClinicalSymptomLR('fever', 'Fever', 'renal', 3.8, 0.60),
    ClinicalSymptomLR('edema', 'Peripheral edema', 'renal', 2.5, 0.72),
    ClinicalSymptomLR('nausea', 'Nausea / Vomiting', 'renal', 2.2, 0.55),
]


class BayesianFusionLREngine:
    """Fuse KNN visual evidence + clinical symptoms via Bayesian LR."""

    def __init__(self, prior_abnormal: float = 0.5):
        """Initialize fusion engine.

        Args:
            prior_abnormal: Prior probability of abnormality (pre-test).
        """
        self.prior_abnormal = prior_abnormal

    @staticmethod
    def _log_odds_from_probability(prob: float) -> float:
        """Convert probability to log-odds."""
        prob = np.clip(prob, 1e-6, 1.0 - 1e-6)
        return np.log(prob / (1.0 - prob))

    @staticmethod
    def _probability_from_log_odds(log_odds: float) -> float:
        """Convert log-odds back to probability."""
        return expit(log_odds)  # = 1 / (1 + exp(-log_odds))

    def fuse(
        self,
        knn_abnormal_prob: float,
        pad_labels: Optional[dict[str, str]] = None,
        selected_symptoms: Optional[dict[str, bool]] = None,
    ) -> dict:
        """Fuse KNN evidence + clinical symptoms into posterior.

        Args:
            knn_abnormal_prob: Visual evidence probability from KNN (0-1).
            pad_labels: Optional dict of pad->analyte labels for reporting.
            selected_symptoms: Dict of symptom_id -> selected (bool).

        Returns:
            Dict with posterior_probability, risk_bucket, and log_odds breakdown.
        """
        if selected_symptoms is None:
            selected_symptoms = {s.id: False for s in CLINICAL_SYMPTOMS_LR}

        # Start with prior
        log_odds = self._log_odds_from_probability(self.prior_abnormal)

        # Visual evidence from KNN
        knn_abnormal_prob = np.clip(knn_abnormal_prob, 1e-6, 1.0 - 1e-6)
        log_odds += self._log_odds_from_probability(knn_abnormal_prob)

        # Clinical evidence via LR
        clinical_log_odds = 0.0
        for symptom in CLINICAL_SYMPTOMS_LR:
            is_selected = selected_symptoms.get(symptom.id, False)
            lr = symptom.lr_positive if is_selected else symptom.lr_negative
            lr = np.clip(lr, 1e-6, 1e6)
            clinical_log_odds += np.log(lr)

        log_odds += clinical_log_odds

        posterior = self._probability_from_log_odds(log_odds)
        posterior = np.clip(posterior, 0.0, 1.0)

        risk_bucket = 'Low' if posterior < 0.35 else 'Moderate' if posterior <= 0.70 else 'High'

        return {
            'posterior_probability': float(posterior),
            'risk_bucket': risk_bucket,
            'log_odds_total': float(log_odds),
            'log_odds_visual': float(self._log_odds_from_probability(knn_abnormal_prob)),
            'log_odds_clinical': float(clinical_log_odds),
            'selected_symptoms_count': sum(1 for v in selected_symptoms.values() if v),
            'total_symptoms': len(CLINICAL_SYMPTOMS_LR),
        }

    def export_config(self, path: Path) -> None:
        """Export LR config and clinical symptom definitions to JSON."""
        config = {
            'prior_abnormal': self.prior_abnormal,
            'clinical_symptoms': [
                {
                    'id': s.id,
                    'label': s.label,
                    'category': s.category,
                    'lr_positive': s.lr_positive,
                    'lr_negative': s.lr_negative,
                }
                for s in CLINICAL_SYMPTOMS_LR
            ],
        }
        path.write_text(json.dumps(config, indent=2))
        logger.info(f'Exported Bayesian LR config to {path}')


if __name__ == '__main__':
    # Example usage
    engine = BayesianFusionLREngine(prior_abnormal=0.5)

    # Example: KNN evidence + selected symptoms
    example_symptoms = {
        'dysuria': True,
        'frequency': True,
        'suprapubic': False,
        'hematuria': False,
        'flank': False,
        'fever': False,
        'edema': False,
        'nausea': False,
    }

    result = engine.fuse(
        knn_abnormal_prob=0.62,
        selected_symptoms=example_symptoms,
    )

    print(json.dumps(result, indent=2))
