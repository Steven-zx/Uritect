# URITECT Dataset Validation Report

- Source: pipeline\dataset\URITECT_DATASET.csv
- Clean output: pipeline\dataset\URITECT_DATASET_clean.csv
- Non-empty rows: 175
- Unique IDs: 175
- Missing IDs in 001-170: 0
- Extra IDs >170: 5
- Extra IDs list: 171, 172, 173, 174, 175

## Issue Counts
- canonicalized: 1
- invalid_value: 1

## First 20 Issues
- {'line': 70, 'id': '069', 'column': 'Leukocytes', 'issue': 'canonicalized', 'from': 'Moderate', 'to': 'Moderate 125'}
- {'line': 98, 'id': '097', 'column': 'Nitrite', 'issue': 'invalid_value', 'value': 'Large'}