"""Training-only engineering rejection envelope; not a clinically validated cutoff.

Uses transformed production vectors and their configured metric. Exact duplicate
vectors are removed before leave-one-vector-out nearest-neighbour distances.
No test images, outcome labels or held-out results select the radius.
"""
import argparse
import hashlib
import json
from pathlib import Path
import numpy as np
from scipy.spatial.distance import cdist


def build_policy(model_bytes):
    model = json.loads(model_bytes)
    entries = {}
    metrics = {"euclidean": "euclidean", "manhattan": "cityblock", "chebyshev": "chebyshev"}
    for name, spec in model["analytes"].items():
        vectors = np.asarray(spec["train_vectors"], dtype=float)
        if vectors.ndim != 2 or not np.isfinite(vectors).all():
            raise ValueError(f"Invalid vectors: {name}")
        unique = np.unique(vectors, axis=0)
        if len(unique) < 2:
            raise ValueError(f"Insufficient distinct training support: {name}")
        nearest = []
        for start in range(0, len(unique), 256):
            distances = cdist(unique[start:start+256], unique, metric=metrics[spec["metric"]])
            for offset in range(len(distances)):
                distances[offset, start+offset] = np.inf
            nearest.extend(distances.min(axis=1).tolist())
        radius = max(nearest)
        if not np.isfinite(radius) or radius <= 0:
            raise ValueError(f"Invalid support radius: {name}")
        entries[name] = {"metric": spec["metric"], "dimensions": vectors.shape[1],
                         "training_vectors": len(vectors), "distinct_vectors": len(unique),
                         "maximum_distance": radius}
    return {"schema": 1, "model_sha256": hashlib.sha256(model_bytes).hexdigest(),
            "method": "max_leave_one_distinct_training_vector_out_nearest_distance",
            "status": "training_only_engineering_guard_not_clinically_validated",
            "analytes": entries}


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--model", type=Path, default=Path("uritect_app/assets/production_semiquant_model.json"))
    parser.add_argument("--output", type=Path, default=Path("uritect_app/assets/training_support_policy.json"))
    args = parser.parse_args()
    policy = build_policy(args.model.read_bytes())
    args.output.write_text(json.dumps(policy, indent=2)+"\n", encoding="utf-8")
    print(json.dumps(policy, indent=2))
