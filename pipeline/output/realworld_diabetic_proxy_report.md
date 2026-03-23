# Real-world proxy test (diabetic user scenario)

Using fresh retest from semiquant_gold_holdout_eval_retest_diabetic_proxy.json.

## Overall performance

|Metric|Value|
|---|---:|
|Samples|250|
|Evaluated|250|
|Coverage|1.0000|
|Accuracy|0.2320|
|F1 macro|0.1744|
|Cohen kappa|0.2157|

## Diabetes-relevant analytes

|Analyte|Accuracy|F1 macro|Kappa|
|---|---:|---:|---:|
|Glucose|0.1600|0.1171|-0.0038|
|Ketone|0.2000|0.1609|0.0476|

## Glucose confusion matrix

|True\Pred|Neg|Trace 5|15 +|30 ++|60 +++|110 ++++|
|---|---|---|---|---|---|---|
|Neg|1|2|0|0|1|1|
|Trace 5|0|1|0|1|2|0|
|15 +|1|1|0|0|2|0|
|30 ++|0|2|0|0|2|0|
|60 +++|0|1|0|0|2|1|
|110 ++++|0|1|0|0|3|0|

## Ketone confusion matrix

|True\Pred|Neg|Trace 0.5|Small 1.5|Moderate 4.0|8.0|Large 16|
|---|---|---|---|---|---|---|
|Neg|0|1|0|0|3|1|
|Trace 0.5|0|2|0|0|2|0|
|Small 1.5|0|2|0|0|1|1|
|Moderate 4.0|0|0|0|1|2|1|
|8.0|0|0|0|1|2|1|
|Large 16|0|0|0|1|3|0|

## Practical interpretation

- Current baseline is not yet clinically reliable for diabetic decision support.
- Glucose and Ketone both show substantial misclassification across levels.
- Treat output as screening guidance only until diabetic-analyte performance improves.