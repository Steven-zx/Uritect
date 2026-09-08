#!/usr/bin/env python3
"""Production training entry point.

The legacy non-semiquant training pipeline has been retired. Production training
is ten-analyte semiquant only and uses specimen-grouped evaluation before
freezing the final model.
"""

from __future__ import annotations

from freeze_production_semiquant import main


if __name__ == "__main__":
    main()
