#Requires -Version 7.5
[CmdletBinding()]
param([switch]$Stage,[ValidatePattern('^[0-9a-f]{64}$')][string]$ProbeSha256)
if(-not $Stage){'NOT_RUN: Windows-only staging for a no-model terminal diagnostic.';return}
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$workspace='C:\Users\piotr\OneDrive\Dokumenty\ChatGPT\devbrain'
$physicalBase='C:\Users\piotr\AppData\Local\Packages\OpenAI.Codex_2p2nqsd0c76g0\LocalCache\Local\DevBrain\qualification'
$canonical=Join-Path $workspace 'release-tools/stage-postbios-bundle-080.ps1'
if((Get-FileHash -LiteralPath $canonical).Hash.ToLowerInvariant()-cne'6a97d4d99d66467d07916ff2f2c3cdf142cbd4f49780615ed5da6bc6602dc619'){throw 'Canonical path helper changed'}
$tok=$null;$err=$null;$ast=[Management.Automation.Language.Parser]::ParseFile($canonical,[ref]$tok,[ref]$err)
if($err.Count){throw 'Canonical path helper parse failed'}
$add=@($ast.FindAll({param($n)$n-is[Management.Automation.Language.CommandAst]-and$n.GetCommandName()-ceq'Add-Type'},$false))
if($add.Count-ne1){throw 'Canonical Add-Type changed'};. ([scriptblock]::Create($add[0].Extent.Text))
foreach($name in @('NoReparse','HashFile','SourceProof')){
 $node=@($ast.FindAll({param($n)$n-is[Management.Automation.Language.FunctionDefinitionAst]-and$n.Name-ceq$name},$false))
 if($node.Count-ne1){throw 'Canonical function changed'};. ([scriptblock]::Create($node[0].Extent.Text))
}
$formal=Join-Path $workspace 'evidence/stage-five-sidebar-final-gates-after-ui-20261108.ps1'
if((Get-FileHash -LiteralPath $formal).Hash.ToLowerInvariant()-cne'37293adac1ea634fc9da250c80fd88bebaf0491bc1369c4c997d157818bd0c84'){throw 'Formal materializer changed'}
$tok=$null;$err=$null;$ast=[Management.Automation.Language.Parser]::ParseFile($formal,[ref]$tok,[ref]$err)
if($err.Count){throw 'Formal materializer parse failed'}
foreach($name in @('Require','PathProof','ReadMap','Verify','NewJson','CopyExact','RelativeFile','SameMap','Artifacts')){
 $node=@($ast.FindAll({param($n)$n-is[Management.Automation.Language.FunctionDefinitionAst]-and$n.Name-ceq$name},$false))
 if($node.Count-ne1){throw 'Reviewed pure function changed'};. ([scriptblock]::Create($node[0].Extent.Text))
}
$guardPath=Join-Path $workspace 'evidence/080-guards-queue-budget-active-context-20261108.json'
$guardSHA='9e9d865acea676f9fab11225c54e49095610e44feb37d9a0b0cd6e882633e6d6'
Verify $guardPath $guardSHA;$g=ReadMap $guardPath
Require ($g.status-ceq'passed'-and$g.actual_test_count-eq604-and$g.actual_windows_exit_code-eq0-and$g.cleanup_complete-eq$true-and$g.helper_sha256.Count-eq38) 'Current guard generation missing'
$guardReceipt=Join-Path $g.artifact_root 'receipt.json';$guardReceiptSHA='9dca1fd31a494fd015d3ba198af5a7ea453211f93c484bdf5b0d931f33865f84'
Verify $guardReceipt $guardReceiptSHA;$receipt=ReadMap $guardReceipt
Require ($receipt.passed-eq$true-and$receipt.cleanup_complete-eq$true-and$receipt.native_failure-eq$false-and$receipt.forced_cleanup-eq$false-and$receipt.scope_empty_verified-eq$true-and$receipt.scope_cleanup_grace_seconds-ge30-and$receipt.cleanup_grace_seconds-ge30-and$receipt.sleep_inhibition.restored-eq$true) 'Guard independent cleanup incomplete'
foreach($n in $g.helper_sha256.Keys){Verify (Join-Path $g.windows_tools $n) $g.helper_sha256[$n]}
$masterPath=Join-Path $workspace 'evidence/080-sidebar-resize-remaining-gate-templates-604-20261108.json'
$masterSHA='f4e039f5040cd70f2f3b0aa18699bfacc92e1f445ad2bb81dd685d96b2643dba'
Verify $masterPath $masterSHA;$master=ReadMap $masterPath
Require ($master.source_freeze_sha256-ceq'ad77e00450537294fd26200d0713915689d82ff5a90e65f6c8fb1285fcbb4703'-and$master.helper_count-eq38) 'Current source generation differs'
SameMap $g.helper_sha256 $master.helper_sha256
Verify $master.source_freeze $master.source_freeze_sha256
$appPath=Join-Path $workspace 'evidence/080-app-ux-snapshot-active-context.json'
Verify $appPath 'd0a5b7e2682cd3f540fcce87446517fb8a11b6712f689aeb6df6dfbf562c771c'
$app=ReadMap $appPath
Artifacts (ReadMap $master.source_freeze).files $app.bundle_root
$controllerName='probe-native-terminal-timing080.py'
$probe=Join-Path $workspace 'evidence/terminal-input-timing-probe-v2-20261109.py'
Require ($ProbeSha256-cmatch'^[0-9a-f]{64}$') 'Explicit reviewed probe hash is required'
Verify $probe $ProbeSha256
$open=Join-Path $workspace 'evidence/open-terminal-input-timing-probe080-20261109.ps1'
$launch=Join-Path $workspace 'evidence/launch-terminal-input-timing-probe080-20261109.ps1'
foreach($p in @($open,$launch)){$t=$null;$e=$null;$null=[Management.Automation.Language.Parser]::ParseFile($p,[ref]$t,[ref]$e);Require ($e.Count-eq0) 'Observer helper parse failed';PathProof $p}
$stamp=[DateTime]::UtcNow.ToString('yyyyMMddTHHmmssZ')
$run='terminal-timing-probe080-'+$stamp+'-'+[Guid]::NewGuid().ToString('N').Substring(0,8)
$root=Join-Path $physicalBase $run;Require (-not(Test-Path -LiteralPath $root)) 'Probe root already exists';NoReparse $root
$null=[IO.Directory]::CreateDirectory($root);PathProof $root
$tools=Join-Path $root 'tools';$inputs=Join-Path $root 'inputs';$art=Join-Path $root 'artifacts'
foreach($p in @($tools,$inputs,$art)){$null=[IO.Directory]::CreateDirectory($p);PathProof $p}
$linuxRoot='/mnt/c/'+$root.Substring(3).Replace('\','/');$linuxTools=$linuxRoot+'/tools';$linuxArt=$linuxRoot+'/artifacts'
foreach($n in $g.helper_sha256.Keys){CopyExact (Join-Path $g.windows_tools $n) (Join-Path $tools $n) $g.helper_sha256[$n]}
CopyExact $probe (Join-Path $tools $controllerName) $ProbeSha256
CopyExact $open (Join-Path $tools 'open-terminal-input-timing-probe080.ps1') (HashFile $open)
$replacementProof=[ordered]@{}
function Replace-One([string]$Text,[string]$From,[string]$To){
 Require (($Text.Split(@($From),[StringSplitOptions]::None)).Count-eq2) 'Registry anchor not unique'
 return $Text.Replace($From,$To)
}
foreach($name in @('supervise-080.py','run-supervised-080.ps1')){
 $path=Join-Path $tools $name;$before=[IO.File]::ReadAllText($path)
 $changes=[Collections.Generic.List[object]]::new()
 if($name-ceq'supervise-080.py'){
  $changes.Add(@('CONTROLLERS = {',('CONTROLLERS = {"'+$controllerName+'": "terminal_timing_probe_completed_pending_external_watch",'+[char]10)))
  $changes.Add(@('CONTROLLER_DEPENDENCIES = {',('CONTROLLER_DEPENDENCIES = {'+[char]10+'    "'+$controllerName+'": ("validate-native-account080.py",),')))
  $changes.Add(@('CONTROLLER_ARTIFACTS = {',('CONTROLLER_ARTIFACTS = {'+[char]10+'    "'+$controllerName+'": {"ready.json", "terminal-timing-results.json"},')))
 }else{
  $changes.Add(@('$controllerDependencies = @{',('$controllerDependencies = @{'+[char]10+"    '$controllerName'=@('validate-native-account080.py')")))
  $changes.Add(@('$controllerArtifacts = @{',('$controllerArtifacts = @{'+[char]10+"    '$controllerName'=@('ready.json','terminal-timing-results.json')")))
  $changes.Add(@("if (`$controllerName -cnotin @('run-full-suite-080.py'",("if (`$controllerName -cnotin @('$controllerName','run-full-suite-080.py'")))
 }
 $after=$before
 foreach($change in $changes){$after=Replace-One $after $change[0] $change[1]}
 [IO.File]::WriteAllText($path,$after,[Text.UTF8Encoding]::new($false))
 $undo=$after;for($i=$changes.Count-1;$i-ge0;$i--){$undo=Replace-One $undo $changes[$i][1] $changes[$i][0]}
 Require ($undo-ceq$before) 'Registry delta is not exactly reversible'
 $replacementProof[$name]=@{original_sha256=$g.helper_sha256[$name];private_sha256=(HashFile $path);replacement_count=$changes.Count;replacements=@($changes);all_other_bytes_unchanged=$true}
}
$helperHashes=[ordered]@{};foreach($n in @($g.helper_sha256.Keys)+@($controllerName,'open-terminal-input-timing-probe080.ps1')){$helperHashes[$n]=HashFile (Join-Path $tools $n)}
Require ($helperHashes.Count-eq40) 'Probe private helper inventory differs'
$gate=Join-Path $art 'gate.json';CopyExact (Join-Path $g.artifact_root 'gate.json') $gate $master.runtime_gate_sha256
$required=@('gate.json','controller-report.json','supervisor-report.json','ready.json','terminal-timing-results.json')
$specPath=Join-Path $art 'spec.json'
$spec=@{run_id=$run;python_launcher=$master.python_launcher;argv=@('--execute','--run-id',$run,'--artifact-root',$linuxArt,'--source-root',$master.source_root,'--private-root','/home/piotr/.cache/devbrain-regressions-080','--duration','120');env=@{LANG='C.UTF-8';LC_ALL='C.UTF-8';TMPDIR='/tmp'};required_artifacts=$required}
NewJson $specPath $spec
$files=[ordered]@{'artifacts/spec.json'=(HashFile $specPath);'artifacts/gate.json'=(HashFile $gate)}
foreach($n in $helperHashes.Keys){$files['tools/'+$n]=$helperHashes[$n]}
$pins=[ordered]@{
 'guard-context.json'=@($guardPath,$guardSHA)
 'guard-receipt.json'=@($guardReceipt,$guardReceiptSHA)
 'source-freeze.json'=@($master.source_freeze,$master.source_freeze_sha256)
 'proposal-master.json'=@($masterPath,$masterSHA)
 'probe-stager.ps1'=@($PSCommandPath,(HashFile $PSCommandPath))
 'probe-launcher.ps1'=@($launch,(HashFile $launch))
}
foreach($n in $pins.Keys){CopyExact $pins[$n][0] (Join-Path $inputs $n) $pins[$n][1];$files['inputs/'+$n]=$pins[$n][1]}
$freeze=Join-Path $root 'prepared-input-freeze.json'
NewJson $freeze @{schema_version=1;scope='devbrain_no_model_terminal_timing_probe_inputs';run_id=$run;files=$files;helper_sha256=$helperHashes;original_38_helper_sha256=$g.helper_sha256;registry_changes=$replacementProof;source_freeze_sha256=$master.source_freeze_sha256;application_qualified=$false;model_requests=0;account_operations=0;eight_hour_test_included=$false}
$context=Join-Path $workspace ('evidence/080-terminal-input-timing-probe-prepared-context-'+$stamp+'.json')
$c=[ordered]@{schema_version=1;scope='devbrain_no_model_terminal_timing_probe';status='prepared_not_run';run_id=$run;windows_root=$root;linux_root=$linuxRoot;artifact_root=$art;linux_artifact_root=$linuxArt;windows_tools=$tools;linux_tools=$linuxTools;wrapper=(Join-Path $tools 'run-supervised-080.ps1');controller=($linuxTools+'/'+$controllerName);controller_sha256=$ProbeSha256;base_python=$master.runtime.python_executable;python_launcher=$master.python_launcher;source_root=$master.source_root;source_freeze=$master.source_freeze;source_freeze_sha256=$master.source_freeze_sha256;app_bundle_root=$app.bundle_root;runtime=$master.runtime;specification=$specPath;specification_sha256=(HashFile $specPath);input_freeze=$freeze;input_freeze_sha256=(HashFile $freeze);helper_sha256=$helperHashes;original_38_helper_sha256=$g.helper_sha256;registry_changes=$replacementProof;runtime_gate_sha256=$master.runtime_gate_sha256;guard_context=$guardPath;guard_context_sha256=$guardSHA;guard_receipt=$guardReceipt;guard_receipt_sha256=$guardReceiptSHA;required_artifacts=$required;timeout_seconds=240;controller_duration_seconds=120;per_query_capture_seconds=3;cleanup_grace_seconds=30;wsl_crash_directory='C:\Users\piotr\AppData\Local\Temp\wsl-crashes';no_model=$true;model_requests=0;account_operations=0;application_qualified=$false;release_qualified=$false;production_modified=$false;production_remains_stopped=$true;eight_hour_test_included=$false;linux_workload_started=$false;launch_permitted=$false;requires_root_review_go=$true;actual_windows_exit_code=$null;actual_windows_exec_session=$null;cleanup_complete=$false;created_utc=[DateTimeOffset]::UtcNow.ToString('o')}
Artifacts $files $root
foreach($n in $g.helper_sha256.Keys){Verify (Join-Path $g.windows_tools $n) $g.helper_sha256[$n]}
NewJson $context $c
@{context=$context;sha256=(HashFile $context);run_id=$run;private_helper_count=$helperHashes.Count;registry_changes=$replacementProof;linux_workload_started=$false}|ConvertTo-Json -Depth 10
