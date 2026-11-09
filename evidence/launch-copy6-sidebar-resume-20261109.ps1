#Requires -Version 7.5
[CmdletBinding()]
param([switch]$Execute)
if(-not $Execute){'NOT_RUN: requires explicit root HOST_GO before invocation.';return}
$ErrorActionPreference='Stop'
$taskContextPath='C:\Users\piotr\OneDrive\Dokumenty\ChatGPT\devbrain\evidence\080-queue-copy-sidebar-resize-active-context-20261108.json'
if((Get-FileHash -LiteralPath $taskContextPath).Hash.ToLowerInvariant()-cne'8b7af74e202354b6a1564bd5ef9356de6c1de17fd9321e79b1f8478821cb3ce0'){throw 'Prepared copy6 context drift'}
$c=Get-Content -LiteralPath $taskContextPath -Raw|ConvertFrom-Json -AsHashtable
if($c.status-cne'prepared_not_run'-or$c.run_id-cne'queue-copy-sidebar-resize080-20261109T100447Z-c1dacc95'-or$c.source_freeze_sha256-cne'ad77e00450537294fd26200d0713915689d82ff5a90e65f6c8fb1285fcbb4703'){throw 'Copy6 binding mismatch'}
foreach($pair in @(@('specification','specification_sha256'),@('input_freeze','input_freeze_sha256'),@('guard_context','guard_context_sha256'),@('guard_receipt','guard_receipt_sha256'),@('guard_final_report','guard_final_report_sha256'),@('app_prepare_receipt','app_prepare_receipt_sha256'),@('app_freeze','app_freeze_sha256'),@('toolbundle_freeze','toolbundle_freeze_sha256'))){
 if((Get-FileHash -LiteralPath $c[$pair[0]]).Hash.ToLowerInvariant()-cne$c[$pair[1]]){throw ('Frozen binding changed: '+$pair[0])}
}
$f=Get-Content -LiteralPath $c.input_freeze -Raw|ConvertFrom-Json -AsHashtable
if($f.files.Count-ne15){throw 'Wrong copy6 frozen input inventory'}
foreach($name in $f.files.Keys){if((Get-FileHash -LiteralPath (Join-Path $c.windows_root $name)).Hash.ToLowerInvariant()-cne$f.files[$name]){throw ('Frozen input changed: '+$name)}}
if($c.helper_sha256.Count-ne38){throw 'Wrong copy6 helper inventory'}
foreach($name in $c.helper_sha256.Keys){if((Get-FileHash -LiteralPath (Join-Path $c.windows_tools $name)).Hash.ToLowerInvariant()-cne$c.helper_sha256[$name]){throw ('Frozen helper changed: '+$name)}}
$a=Get-Content -LiteralPath 'C:\Users\piotr\OneDrive\Dokumenty\ChatGPT\devbrain\evidence\080-app-ux-snapshot-active-context.json' -Raw|ConvertFrom-Json -AsHashtable
$g=Get-Content -LiteralPath $c.guard_context -Raw|ConvertFrom-Json -AsHashtable
$r=Get-Content -LiteralPath $c.guard_receipt -Raw|ConvertFrom-Json -AsHashtable
if($a.status-cne'prepared_passed'-or$a.freeze_sha256-cne$c.source_freeze_sha256-or$g.status-cne'passed'-or$r.passed-ne$true-or$r.cleanup_complete-ne$true-or$r.native_failure-ne$false){throw 'Copy6 admission missing'}
$af=Get-Content -LiteralPath $c.app_freeze -Raw|ConvertFrom-Json -AsHashtable
if($af.files.Count-ne209){throw 'App209 inventory differs'}
foreach($name in $af.files.Keys){if((Get-FileHash -LiteralPath (Join-Path $a.bundle_root $name)).Hash.ToLowerInvariant()-cne$af.files[$name]){throw ('Frozen App source changed: '+$name)}}
$c.status='running';$c.started_utc=[DateTime]::UtcNow.ToString('o');$c.linux_workload_started=$true
[IO.File]::WriteAllText($taskContextPath,($c|ConvertTo-Json -Depth 15),[Text.UTF8Encoding]::new($false))
$pw=(Get-Process -Id $PID).Path
& $pw -NoProfile -NonInteractive -File $c.wrapper -ArtifactRoot $c.artifact_root -LinuxArtifactRoot $c.linux_artifact_root -PythonExecutable $c.base_python -Controller $c.controller -ControllerArgumentsFile $c.specification -RunId $c.run_id -TimeoutSeconds 1800 -CleanupGraceSeconds 30 -WslCrashDirectory $c.wsl_crash_directory -Execute
$code=$LASTEXITCODE
$c.actual_windows_exit_code=$code;$c.finished_utc=[DateTime]::UtcNow.ToString('o')
$c.status=if($code-eq0){'finished_pending_evidence_review'}else{'failed_pending_cleanup_review'}
[IO.File]::WriteAllText($taskContextPath,($c|ConvertTo-Json -Depth 15),[Text.UTF8Encoding]::new($false))
[pscustomobject]@{run_id=$c.run_id;actual_windows_exit_code=$code;status=$c.status}|ConvertTo-Json
exit $code

