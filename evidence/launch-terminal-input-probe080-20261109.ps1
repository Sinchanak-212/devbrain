#Requires -Version 7.5
[CmdletBinding()]
param([switch]$Execute,[string]$Context,[string]$ContextSha256)
if(-not $Execute){'NOT_RUN: requires root review GO for this exact no-model probe context.';return}
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
function Hash([string]$p){(Get-FileHash -LiteralPath $p).Hash.ToLowerInvariant()}
if($ContextSha256-cnotmatch'^[0-9a-f]{64}$'-or(Hash $Context)-cne$ContextSha256){throw 'Probe context changed'}
$c=Get-Content -Raw -LiteralPath $Context|ConvertFrom-Json -AsHashtable
if($c.scope-cne'devbrain_no_model_terminal_probe'-or$c.status-cne'prepared_not_run'-or$c.no_model-ne$true-or$c.model_requests-ne0-or$c.account_operations-ne0-or$c.release_qualified-ne$false-or$c.eight_hour_test_included-ne$false-or$c.controller_duration_seconds-ne120-or$c.timeout_seconds-ne240){throw 'Not a fresh bounded no-model diagnostic'}
foreach($pair in @(@('specification','specification_sha256'),@('input_freeze','input_freeze_sha256'),@('source_freeze','source_freeze_sha256'),@('guard_context','guard_context_sha256'),@('guard_receipt','guard_receipt_sha256'))){if((Hash $c[$pair[0]])-cne$c[$pair[1]]){throw 'Frozen input changed'}}
$f=Get-Content -Raw -LiteralPath $c.input_freeze|ConvertFrom-Json -AsHashtable
foreach($rel in $f.files.Keys){if((Hash (Join-Path $c.windows_root $rel))-cne$f.files[$rel]){throw 'Private input changed'}}
$source=Get-Content -Raw -LiteralPath $c.source_freeze|ConvertFrom-Json -AsHashtable
foreach($rel in $source.files.Keys){if((Hash (Join-Path $c.app_bundle_root $rel))-cne$source.files[$rel]){throw 'Application snapshot changed'}}
$c.status='running';$c.linux_workload_started=$true;$c.started_utc=[DateTimeOffset]::UtcNow.ToString('o')
[IO.File]::WriteAllText($Context,($c|ConvertTo-Json -Depth 40),[Text.UTF8Encoding]::new($false))
$pwsh=(Get-Process -Id $PID).Path
& $pwsh -NoProfile -NonInteractive -File $c.wrapper -ArtifactRoot $c.artifact_root -LinuxArtifactRoot $c.linux_artifact_root -PythonExecutable $c.base_python -Controller $c.controller -ControllerArgumentsFile $c.specification -RunId $c.run_id -TimeoutSeconds $c.timeout_seconds -CleanupGraceSeconds 30 -WslCrashDirectory $c.wsl_crash_directory -Execute |Out-Null
$code=$LASTEXITCODE
$c.actual_windows_exit_code=$code;$c.finished_utc=[DateTimeOffset]::UtcNow.ToString('o');$c.status=if($code-eq0){'diagnostic_finished_pending_evidence_review'}else{'diagnostic_failed_pending_cleanup_review'}
[IO.File]::WriteAllText($Context,($c|ConvertTo-Json -Depth 40),[Text.UTF8Encoding]::new($false))
@{run_id=$c.run_id;actual_windows_exit_code=$code;status=$c.status;model_requests=0;release_qualified=$false}|ConvertTo-Json
exit $code
