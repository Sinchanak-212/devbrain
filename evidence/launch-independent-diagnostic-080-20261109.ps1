#Requires -Version 7.5
[CmdletBinding()]
param([switch]$Execute,[string]$Context,[string]$ContextSha256)
if(-not$Execute){'NOT_RUN: independent diagnostics require root HOST_GO and an owned workload slot.';return}
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
if($ContextSha256-cnotmatch'^[0-9a-f]{64}$'-or(Get-FileHash -LiteralPath $Context).Hash.ToLowerInvariant()-cne$ContextSha256){throw 'Diagnostic context changed'}
$c=Get-Content -Raw -LiteralPath $Context|ConvertFrom-Json -AsHashtable
if($c.scope-cne'devbrain_independent_diagnostic_context'-or$c.status-cne'prepared_not_run'-or$c.error_inventory_only-ne$true-or$c.current_ui_passed-ne$false-or$c.current_backend_actual_pass-ne$false-or$c.release_qualified-ne$false-or$c.application_qualified-ne$false){throw 'Not a fresh independent diagnostic context'}
if($c.source_freeze_sha256-cne'ad77e00450537294fd26200d0713915689d82ff5a90e65f6c8fb1285fcbb4703'-or$c.helper_file_count-ne38){throw 'Diagnostic source/helper generation differs'}
foreach($pair in @(@('specification','specification_sha256'),@('input_freeze','input_freeze_sha256'),@('guard_context','guard_context_sha256'),@('guard_receipt','guard_receipt_sha256'),@('guard_final_report','guard_final_report_sha256'),@('app_prepare_receipt','app_prepare_receipt_sha256'),@('app_freeze','app_freeze_sha256'),@('toolbundle_freeze','toolbundle_freeze_sha256'),@('candidate_build_context','candidate_build_context_sha256'))){
 if((Get-FileHash -LiteralPath $c[$pair[0]]).Hash.ToLowerInvariant()-cne$c[$pair[1]]){throw ('Bound diagnostic input changed: '+$pair[0])}
}
$f=Get-Content -Raw -LiteralPath $c.input_freeze|ConvertFrom-Json -AsHashtable
foreach($rel in $f.files.Keys){if((Get-FileHash -LiteralPath (Join-Path $c.windows_root $rel)).Hash.ToLowerInvariant()-cne$f.files[$rel]){throw ('Frozen diagnostic input changed: '+$rel)}}
foreach($n in $c.helper_sha256.Keys){if((Get-FileHash -LiteralPath (Join-Path $c.windows_tools $n)).Hash.ToLowerInvariant()-cne$c.helper_sha256[$n]){throw ('Frozen controller changed: '+$n)}}
$g=Get-Content -Raw -LiteralPath $c.guard_context|ConvertFrom-Json -AsHashtable
$r=Get-Content -Raw -LiteralPath $c.guard_receipt|ConvertFrom-Json -AsHashtable
if($g.status-cne'passed'-or$g.actual_test_count-ne604-or$r.passed-ne$true-or$r.cleanup_complete-ne$true-or$r.native_failure-ne$false){throw 'Diagnostic guard admission incomplete'}
$b=Get-Content -Raw -LiteralPath $c.candidate_build_context|ConvertFrom-Json -AsHashtable
foreach($rel in $b.output_sha256.Keys){if((Get-FileHash -LiteralPath (Join-Path $b.windows_root $rel)).Hash.ToLowerInvariant()-cne$b.output_sha256[$rel]){throw 'Mechanical candidate changed'}}
$c.status='running';$c.linux_workload_started=$true;$c.started_utc=[DateTime]::UtcNow.ToString('o')
[IO.File]::WriteAllText($Context,($c|ConvertTo-Json -Depth 30),[Text.UTF8Encoding]::new($false))
$pwsh=(Get-Process -Id $PID).Path
& $pwsh -NoProfile -NonInteractive -File $c.wrapper -ArtifactRoot $c.artifact_root -LinuxArtifactRoot $c.linux_artifact_root -PythonExecutable $c.base_python -Controller $c.controller -ControllerArgumentsFile $c.specification -RunId $c.run_id -TimeoutSeconds $c.timeout_seconds -CleanupGraceSeconds 30 -WslCrashDirectory $c.wsl_crash_directory -Execute |Out-Null
$code=$LASTEXITCODE
$c.actual_windows_exit_code=$code;$c.finished_utc=[DateTime]::UtcNow.ToString('o')
$c.status=if($code-eq0){'diagnostic_finished_pending_evidence_review'}else{'diagnostic_failed_pending_cleanup_review'}
[IO.File]::WriteAllText($Context,($c|ConvertTo-Json -Depth 30),[Text.UTF8Encoding]::new($false))
[pscustomobject]@{run_id=$c.run_id;actual_windows_exit_code=$code;status=$c.status;error_inventory_only=$true;release_qualified=$false}|ConvertTo-Json
exit $code

