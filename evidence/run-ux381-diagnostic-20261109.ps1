#Requires -Version 7.5
[CmdletBinding()]
param([switch]$Execute,[string]$HostGoEvidence)
if(-not $Execute){'NOT_RUN: requires explicit root HOST_GO; diagnostic-only run, no release qualification';return}
$ErrorActionPreference='Stop'
if([string]::IsNullOrWhiteSpace($HostGoEvidence)){throw 'Explicit root host admission reference is required'}
$path='C:\Users\piotr\OneDrive\Dokumenty\ChatGPT\devbrain\evidence\080-ux381-diagnostic-active-context-20261109.json'
if((Get-FileHash -LiteralPath $path).Hash.ToLowerInvariant()-cne'ecd47bbcca805588e51272a55c38488daef4935f54495207f6678a7910c18dbc'){throw 'Prepared diagnostic context drift'}
$c=Get-Content -LiteralPath $path -Raw|ConvertFrom-Json -AsHashtable -DateKind String
if($c.status-cne'prepared_diagnostic_not_run_pending_host_go'-or$c.diagnostic_only-ne$true-or$c.release_qualified-ne$false-or$c.pytest_maxfail-ne0-or$c.app_freeze_sha256-cne'ad77e00450537294fd26200d0713915689d82ff5a90e65f6c8fb1285fcbb4703'){throw 'Diagnostic admission mismatch'}
foreach($pair in @(@('input_freeze','input_freeze_sha256'),@('specification','specification_sha256'),@('app_freeze','app_freeze_sha256'),@('guard_context','guard_context_sha256'),@('guard_receipt','guard_receipt_sha256'),@('app_prepare_receipt','app_prepare_receipt_sha256'),@('toolbundle_freeze','toolbundle_freeze_sha256'))){
 if((Get-FileHash -LiteralPath $c[$pair[0]]).Hash.ToLowerInvariant()-cne$c[$pair[1]]){throw ('Input binding drift: '+$pair[0])}
}
$f=Get-Content -LiteralPath $c.input_freeze -Raw|ConvertFrom-Json -AsHashtable
if($f.files.Count-ne55-or$c.helper_sha256.Count-ne38){throw 'Diagnostic inventory differs'}
foreach($rel in $f.files.Keys){if((Get-FileHash -LiteralPath (Join-Path $c.windows_root $rel)).Hash.ToLowerInvariant()-cne$f.files[$rel]){throw 'Frozen diagnostic input drift'}}
foreach($name in $c.helper_sha256.Keys){if((Get-FileHash -LiteralPath (Join-Path $c.windows_tools $name)).Hash.ToLowerInvariant()-cne$c.helper_sha256[$name]){throw 'Frozen diagnostic helper drift'}}
$formal=Get-Content -LiteralPath $c.baseline_formal_context -Raw|ConvertFrom-Json -AsHashtable
if((Get-FileHash -LiteralPath $c.baseline_formal_context).Hash.ToLowerInvariant()-cne$c.baseline_formal_context_sha256){throw 'Historical formal context drift'}
$unchanged=0
foreach($name in $formal.helper_sha256.Keys){
 if((Get-FileHash -LiteralPath (Join-Path $formal.windows_tools $name)).Hash.ToLowerInvariant()-cne$formal.helper_sha256[$name]){throw 'Canonical helper drift'}
 if($c.helper_sha256[$name]-ceq$formal.helper_sha256[$name]){$unchanged++}
}
if($unchanged-ne37-or$c.controller_sha256-cne'f8bbfbfee3a465f1b521a005a04c6441154186acda20a7102adc747a10737218'){throw 'Unexpected controller delta'}
$c.status='running';$c.started_utc=[DateTime]::UtcNow.ToString('o');$c.linux_workload_started=$true;$c.root_host_go_evidence=$HostGoEvidence
[IO.File]::WriteAllText($path,($c|ConvertTo-Json -Depth 30),[Text.UTF8Encoding]::new($false))
& (Get-Process -Id $PID).Path -NoProfile -NonInteractive -File (Join-Path $c.windows_tools 'run-supervised-080.ps1') -ArtifactRoot $c.artifact_root -LinuxArtifactRoot $c.linux_artifact_root -PythonExecutable $c.base_python -Controller $c.controller -ControllerArgumentsFile $c.specification -RunId $c.run_id -TimeoutSeconds $c.timeout_seconds -CleanupGraceSeconds 30 -WslCrashDirectory $c.wsl_crash_directory -Execute | Out-Null
$code=$LASTEXITCODE
$c.actual_windows_exit_code=$code;$c.finished_utc=[DateTime]::UtcNow.ToString('o')
$c.status=if($code-eq0){'finished_pending_diagnostic_evidence_review'}else{'failed_pending_diagnostic_cleanup_review'}
$c.release_qualified=$false;$c.application_qualified=$false
[IO.File]::WriteAllText($path,($c|ConvertTo-Json -Depth 30),[Text.UTF8Encoding]::new($false))
[pscustomobject]@{run_id=$c.run_id;actual_windows_exit_code=$code;status=$c.status;diagnostic_only=$true;release_qualified=$false}|ConvertTo-Json
exit $code

