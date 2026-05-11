$ErrorActionPreference = 'Stop'

$python = '.\.venv\Scripts\python.exe'

$steps = @(
    @{ Name = 'Validate semiquant labels'; Cmd = "$python .\pipeline\validate_semiquant_labels.py --strict" },
    @{ Name = 'Check semiquant readiness'; Cmd = "$python .\pipeline\check_training_readiness.py --mode semiquant --json" },
    @{ Name = 'Analyze feature space'; Cmd = "$python .\pipeline\analyze_feature_space.py" },
    @{ Name = 'Tune semiquant settings'; Cmd = "$python .\pipeline\tune_semiquant_settings.py --map .\pipeline\output\knn_reference_map_20260323_baseline_restored.json" },
    @{ Name = 'Build checkpoint summary'; Cmd = "$python .\pipeline\generate_phase1_checkpoint_summary.py" }
)

for ($i = 0; $i -lt $steps.Count; $i++) {
    $step = $steps[$i]
    $pct = [int](($i / $steps.Count) * 100)

    Write-Progress -Activity 'Phase 1 checkpoint' -Status $step.Name -PercentComplete $pct
    Write-Host "`n[$($i + 1)/$($steps.Count)] $($step.Name)" -ForegroundColor Cyan

    Invoke-Expression $step.Cmd
    if ($LASTEXITCODE -ne 0) {
        throw "Step failed: $($step.Name)"
    }
}

Write-Progress -Activity 'Phase 1 checkpoint' -Completed
Write-Host 'Phase 1 checkpoint artifacts refreshed.' -ForegroundColor Green