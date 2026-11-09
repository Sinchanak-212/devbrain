#Requires -Version 7.5
[CmdletBinding()]
param([switch]$Execute,[string]$RootGoEvidence)
if(-not$Execute){'NOT_RUN: requires explicit root GO; fresh-source diagnostics only, no release qualification';return}
$ErrorActionPreference='Stop'
function Need([bool]$ok,[string]$why){if(-not$ok){throw $why}}
function Sha([string]$p){(Get-FileHash -LiteralPath $p -Algorithm SHA256).Hash.ToLowerInvariant()}
$path=Join-Path (Get-Location) 'evidence/080-ux-native-failure-diagnostic-context-20261109.json'
Need ((Sha $path)-ceq'1133f98d4c2a8fd97daa3fa8164e90148b5542f140d5006fb0b8a0d83c4286ad') 'Reviewed fresh context drift'
$c=Get-Content -LiteralPath $path -Raw|ConvertFrom-Json -AsHashtable -DateKind String
Need ($c.status-ceq'prepared_diagnostic_not_run_pending_root_GO'-and$c.pytest_maxfail-eq0-and$c.diagnostic_only-eq$true-and$c.release_qualified-eq$false-and$c.app_freeze_sha256-ceq'9e5168bece45cf3c06bd0abded7e1573b51cf55778570fdc49c8e0a8872e81b9') 'Fresh diagnostic admission differs'
Need (-not[string]::IsNullOrWhiteSpace($RootGoEvidence)-and(Sha $RootGoEvidence)-ceq$c.app_prepare_final_report_sha256) 'Explicit root admission must reference the fresh App preparation proof'
foreach($pair in @(@('input_freeze','input_freeze_sha256'),@('specification','specification_sha256'),@('app_context','app_context_sha256'),@('app_freeze','app_freeze_sha256'),@('app_prepare_receipt','app_prepare_receipt_sha256'),@('app_prepare_final_report','app_prepare_final_report_sha256'),@('toolbundle_freeze','toolbundle_freeze_sha256'),@('guard_context','guard_context_sha256'))){Need ((Sha $c[$pair[0]])-ceq$c[$pair[1]]) ('Input drift: '+$pair[0])}
$f=Get-Content -LiteralPath $c.input_freeze -Raw|ConvertFrom-Json -AsHashtable
Need ($f.files.Count-eq50-and$c.helper_sha256.Count-eq38-and$c.expected_module_count-eq28-and$null-eq$c.expected_nodeid_count) 'Full diagnostic inventory differs'
foreach($rel in $f.files.Keys){Need ((Sha (Join-Path $c.windows_root $rel))-ceq$f.files[$rel]) 'Frozen diagnostic file changed'}
$g=Get-Content -LiteralPath $c.guard_context -Raw|ConvertFrom-Json -AsHashtable
$unchanged=0
foreach($name in $c.helper_sha256.Keys){
 Need ((Sha (Join-Path $c.windows_tools $name))-ceq$c.helper_sha256[$name]) 'Actual private helper changed'
 Need ((Sha (Join-Path $g.windows_tools $name))-ceq$g.helper_sha256[$name]) 'Canonical helper changed'
 if($c.helper_sha256[$name]-ceq$g.helper_sha256[$name]){$unchanged++}
}
Need ($unchanged-eq37-and$c.controller_sha256-ceq'f8bbfbfee3a465f1b521a005a04c6441154186acda20a7102adc747a10737218') 'Unexpected helper generation'
$before=[IO.File]::ReadAllBytes((Join-Path $g.windows_tools run-regressions-080.py));$after=[IO.File]::ReadAllBytes((Join-Path $c.windows_tools run-regressions-080.py))
Need ($before.Length-eq$after.Length) 'Controller byte length differs'
$delta=@(for($i=0;$i-lt$before.Length;$i++){if($before[$i]-ne$after[$i]){$i}})
Need ($delta.Count-eq1-and$before[$delta[0]]-eq49-and$after[$delta[0]]-eq48) 'Controller is not exact maxfail1 to0 byte delta'
$reviewed=Join-Path (Get-Location) 'evidence/080-ux-native-failure-diagnostic-rootreviewed-context-20261109.json'
[IO.File]::Copy($path,$reviewed,$false)
$c.status='running';$c.started_utc=[DateTime]::UtcNow.ToString('o');$c.linux_workload_started=$true;$c.root_GO_evidence=$RootGoEvidence
[IO.File]::WriteAllText($path,($c|ConvertTo-Json -Depth 35),[Text.UTF8Encoding]::new($false))
$launch=$c.launch_parameters_without_Execute
& (Get-Process -Id $PID).Path -NoProfile -NonInteractive -File (Join-Path $c.windows_tools run-supervised-080.ps1) @launch -Execute | Out-Null
$code=$LASTEXITCODE
$c.actual_windows_exit_code=$code;$c.finished_utc=[DateTime]::UtcNow.ToString('o');$c.status=if($code-eq0){'finished_pending_diagnostic_evidence_review'}else{'failed_pending_diagnostic_cleanup_review'}
$c.release_qualified=$false;$c.application_qualified=$false
[IO.File]::WriteAllText($path,($c|ConvertTo-Json -Depth 35),[Text.UTF8Encoding]::new($false))
[pscustomobject]@{run_id=$c.run_id;actual_windows_exit_code=$code;status=$c.status;diagnostic_only=$true;release_qualified=$false}|ConvertTo-Json
exit $code

