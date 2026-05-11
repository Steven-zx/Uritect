import json
with open('pipeline/output/semiquant_evaluation_metrics.json') as f:
    data = json.load(f)
print('Current Evaluation Metrics:')
print(f'  Accuracy: {data.get("accuracy", "N/A")}')
print(f'  F1-score: {data.get("f1_score", "N/A")}')
print(f'  Cohen Kappa: {data.get("cohen_kappa", "N/A")}')
print(f'\nComparison to Centered HSV Baseline:')
print(f'  HSV Acc: 0.3219, F1: 0.1865, Kappa: 0.3031')
lab_acc = data.get("accuracy", 0)
hsv_acc = 0.3219
change = ((lab_acc - hsv_acc) / hsv_acc * 100) if hsv_acc else 0
print(f'  LAB vs HSV Change: {change:+.2f}%')
