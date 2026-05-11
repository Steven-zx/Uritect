$ErrorActionPreference = 'Stop'

$steps = @(
    @{ Name = 'Ingest LAB features'; Cmd = '.\.venv\Scripts\python.exe .\pipeline\ingest.py --feature-space lab --output .\pipeline\dataset\features_lab.csv' },
    @{ Name = 'Train LAB map'; Cmd = '.\.venv\Scripts\python.exe .\pipeline\train.py --features .\pipeline\dataset\features_lab.csv --enforce-readiness --event-center-hsv --event-center-mode per-light --semiquant-prototype-mode median' },
    @{ Name = 'Evaluate LAB'; Cmd = '.\.venv\Scripts\python.exe .\pipeline\evaluate_semiquant.py --features .\pipeline\dataset\features_lab.csv' }
)

for ($i = 0; $i -lt $steps.Count; $i++) {
    $step = $steps[$i]
    $pct = [int](($i / $steps.Count) * 100)

    Write-Progress -Activity 'LAB Pipeline' -Status $step.Name -PercentComplete $pct
    Write-Host "`n[$($i + 1)/$($steps.Count)] $($step.Name)" -ForegroundColor Cyan

    Invoke-Expression $step.Cmd
    if ($LASTEXITCODE -ne 0) {
        throw "Step failed: $($step.Name)"
    }
}

Write-Progress -Activity 'LAB Pipeline' -Completed
Write-Host 'LAB pipeline completed.' -ForegroundColor Green
