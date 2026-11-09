#Requires -Version 7.5
param([Parameter(Mandatory=$true)][string]$taskContextPath)
# Saved orchestration template; read and verify the current immutable context before use.
$ErrorActionPreference='Stop'
$c=Get-Content -Raw -LiteralPath $taskContextPath|ConvertFrom-Json -AsHashtable
if($c.status-cne'prepared_not_run_pending_root_serial_handoff'){throw 'Fresh prepared context required'}
if($c.ContainsKey('app_freeze') -and -not $c.ContainsKey('app_freeze_sha256')){if(-not $c.ContainsKey('source_freeze_sha256')){throw 'Missing application freeze digest'};$c.app_freeze_sha256=$c.source_freeze_sha256}
foreach($pair in @(@('specification','specification_sha256'),@('guard_receipt','guard_receipt_sha256'),@('app_prepare_receipt','app_prepare_receipt_sha256'),@('app_freeze','app_freeze_sha256'),@('toolbundle_freeze','toolbundle_freeze_sha256'))){
 if($c.ContainsKey($pair[0]) -and (Get-FileHash -LiteralPath $c[$pair[0]]).Hash.ToLowerInvariant()-cne$c[$pair[1]]){throw ('Input binding changed: '+$pair[0])}
}
$a=Get-Content -Raw evidence/080-app-ux-snapshot-active-context.json|ConvertFrom-Json
$g=Get-Content -Raw evidence/080-guards-locale-active-context-20261108.json|ConvertFrom-Json
if(Test-Path -LiteralPath 'evidence/080-guards-gpu-active-context-20261108.json'){
 $newGuard=Get-Content -Raw evidence/080-guards-gpu-active-context-20261108.json|ConvertFrom-Json
 if($newGuard.status-ceq'passed'){$g=$newGuard}
}
if(Test-Path -LiteralPath 'evidence/080-guards-production-final-active-context-20261108.json'){
 $latestGuard=Get-Content -Raw evidence/080-guards-production-final-active-context-20261108.json|ConvertFrom-Json
 if($latestGuard.status-ceq'passed'){$g=$latestGuard}
}
if(Test-Path -LiteralPath 'evidence/080-guards-backup-final-active-context-20261108.json'){
 $latestBackupGuard=Get-Content -Raw evidence/080-guards-backup-final-active-context-20261108.json|ConvertFrom-Json
 if($latestBackupGuard.status-ceq'passed'){$g=$latestBackupGuard}
}
if(Test-Path -LiteralPath 'evidence/080-guards-deploy-final-active-context-20261108.json'){
 $latestDeployGuard=Get-Content -Raw evidence/080-guards-deploy-final-active-context-20261108.json|ConvertFrom-Json
 if($latestDeployGuard.status-ceq'passed'){$g=$latestDeployGuard}
}
if(Test-Path -LiteralPath 'evidence/080-guards-queue-budget-active-context-20261108.json'){
 $latestBudgetGuard=Get-Content -Raw evidence/080-guards-queue-budget-active-context-20261108.json|ConvertFrom-Json
 if($latestBudgetGuard.status-ceq'passed'){$g=$latestBudgetGuard}
}
foreach($hashMapName in @('helper_sha256','reviewed_helper_sha256')){
 if($c.ContainsKey($hashMapName)-and$c.ContainsKey('windows_tools')){
  foreach($helperName in $c[$hashMapName].Keys){
   $helperPath=Join-Path $c.windows_tools $helperName
   if((Get-FileHash -LiteralPath $helperPath).Hash.ToLowerInvariant()-cne$c[$hashMapName][$helperName]){throw ('Frozen helper drift: '+$helperName)}
  }
 }
}
if($c.ContainsKey('guard_receipt')){
 $boundGuard=Get-Content -Raw -LiteralPath $c.guard_receipt|ConvertFrom-Json
 if(-not($boundGuard.passed-and$boundGuard.cleanup_complete-and-not$boundGuard.native_failure)){throw 'Bound guard receipt did not pass'}
}
if($a.status-cne'prepared_passed'-or$g.status-cne'passed'){throw 'Source/guard admission missing'}
$guard=Get-Content -Raw -LiteralPath (Join-Path $g.artifact_root 'receipt.json')|ConvertFrom-Json
if(-not($guard.passed-and$guard.cleanup_complete-and-not$guard.native_failure)){throw 'Guard final receipt not passed'}
if($c.ContainsKey('historical_roots_modified')){$null=$c.Remove('historical_roots_modified');$c.historical_evidence_files_modified=$false}
$c.status='running';$c.started_utc=[DateTime]::UtcNow.ToString('o');$c.linux_workload_started=$true
[IO.File]::WriteAllText($taskContextPath,($c|ConvertTo-Json -Depth 10),[Text.UTF8Encoding]::new($false))
$pw=(Get-Process -Id $PID).Path
& $pw -NoProfile -NonInteractive -File (Join-Path $c.windows_tools 'run-supervised-080.ps1') -ArtifactRoot $c.artifact_root -LinuxArtifactRoot $c.linux_artifact_root -PythonExecutable $c.base_python -Controller $c.controller -ControllerArgumentsFile $c.specification -RunId $c.run_id -TimeoutSeconds $c.timeout_seconds -CleanupGraceSeconds 30 -WslCrashDirectory 'C:\Users\piotr\AppData\Local\Temp\wsl-crashes' -Execute | Out-Null
$code=$LASTEXITCODE
$c.actual_windows_exit_code=$code;$c.finished_utc=[DateTime]::UtcNow.ToString('o')
$c.status=if($code-eq0){'finished_pending_evidence_review'}else{'failed_pending_cleanup_review'}
[IO.File]::WriteAllText($taskContextPath,($c|ConvertTo-Json -Depth 10),[Text.UTF8Encoding]::new($false))
[pscustomobject]@{run_id=$c.run_id;actual_windows_exit_code=$code;status=$c.status}|ConvertTo-Json
exit $code
