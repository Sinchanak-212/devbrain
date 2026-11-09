#Requires -Version 7.5
[CmdletBinding()]
param([switch]$Stage)
if(-not $Stage){Write-Output 'NOT_RUN: private diagnostic-only preparation; no process launch';return}
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$workspace='C:\Users\piotr\OneDrive\Dokumenty\ChatGPT\devbrain'
$base='C:\Users\piotr\AppData\Local\Packages\OpenAI.Codex_2p2nqsd0c76g0\LocalCache\Local\DevBrain\qualification'
$canonical=Join-Path $workspace 'release-tools/stage-postbios-bundle-080.ps1'
if((Get-FileHash -LiteralPath $canonical).Hash.ToLowerInvariant()-cne'6a97d4d99d66467d07916ff2f2c3cdf142cbd4f49780615ed5da6bc6602dc619'){throw 'Canonical path guard changed'}
$tokens=$null;$errors=$null;$ast=[Management.Automation.Language.Parser]::ParseFile($canonical,[ref]$tokens,[ref]$errors)
if($errors.Count){throw 'Canonical syntax invalid'}
$nodes=@($ast.FindAll({param($n)$n -is [Management.Automation.Language.CommandAst]-and$n.GetCommandName()-ceq'Add-Type'},$false))
if($nodes.Count-ne1){throw 'Canonical path guard inventory differs'}
. ([scriptblock]::Create($nodes[0].Extent.Text))
foreach($name in @('NoReparse','SourceProof','HashFile')){
 $nodes=@($ast.FindAll({param($n)$n -is [Management.Automation.Language.FunctionDefinitionAst]-and$n.Name-ceq$name},$false))
 if($nodes.Count-ne1){throw 'Canonical path function inventory differs'}
 . ([scriptblock]::Create($nodes[0].Extent.Text))
}
function Verify([string]$path,[string]$sha){
 if($path.StartsWith($workspace+'\',[StringComparison]::OrdinalIgnoreCase)){SourceProof $path}else{NoReparse $path}
 if((HashFile $path)-cne$sha){throw ('Input drift: '+$path)}
 if(-not[QualificationStagePath080]::FinalPath($path).Equals([IO.Path]::GetFullPath($path),[StringComparison]::OrdinalIgnoreCase)){throw 'Final path differs'}
}
function NewJson([string]$path,$value){
 NoReparse $path
 $bytes=[Text.UTF8Encoding]::new($false).GetBytes(($value|ConvertTo-Json -Depth 60)+[Environment]::NewLine)
 $stream=[IO.File]::Open($path,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::Read)
 try{$stream.Write($bytes,0,$bytes.Length);$stream.Flush($true)}finally{$stream.Dispose()}
}
function CopyExact([string]$source,[string]$dest,[string]$sha){
 Verify $source $sha;NoReparse $dest
 [void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($dest))
 [IO.File]::Copy($source,$dest,$false)
 Verify $dest $sha;Verify $source $sha
}
$formalPath=Join-Path $workspace 'evidence/080-ux-sidebar-resize-active-context-20261108.json'
$formalSHA='1335f698735597cd322ece666b5a33935070bd6f892d605983dc85360b5c2cd9'
Verify $formalPath $formalSHA
$c=Get-Content -LiteralPath $formalPath -Raw|ConvertFrom-Json -AsHashtable -DateKind String
if($c.status-cne'prepared_not_run_pending_root_serial_handoff'-or$c.app_freeze_sha256-cne'ad77e00450537294fd26200d0713915689d82ff5a90e65f6c8fb1285fcbb4703'-or$c.helper_sha256.Count-ne38){throw 'Formal prepared context differs'}
Verify $c.input_freeze $c.input_freeze_sha256
$f=Get-Content -LiteralPath $c.input_freeze -Raw|ConvertFrom-Json -AsHashtable
if($f.files.Count-ne16){throw 'Formal frozen input count differs'}
foreach($name in $f.files.Keys){Verify (Join-Path $c.windows_root $name) $f.files[$name]}
foreach($name in $c.helper_sha256.Keys){Verify (Join-Path $c.windows_tools $name) $c.helper_sha256[$name]}
$run='ux381-diagnostic080-'+[DateTime]::UtcNow.ToString('yyyyMMddTHHmmssZ')+'-'+[Guid]::NewGuid().ToString('N').Substring(0,8)
$root=Join-Path $base $run
NoReparse $root
if(Test-Path -LiteralPath $root){throw 'Diagnostic root exists'}
foreach($dir in @('artifacts','inputs','tools')){[void][IO.Directory]::CreateDirectory((Join-Path $root $dir))}
$art=Join-Path $root artifacts;$tools=Join-Path $root tools
$linuxRoot='/mnt/c/'+$root.Substring(3).Replace('\','/')
$linuxArt=$linuxRoot+'/artifacts';$linuxTools=$linuxRoot+'/tools'
$files=@{};$helpers=@{}
foreach($name in $c.helper_sha256.Keys){
 $src=Join-Path $c.windows_tools $name;$dst=Join-Path $tools $name
 if($name-ceq'run-regressions-080.py'){
  $old=[IO.File]::ReadAllText($src)
  if([regex]::Matches($old,'--maxfail=1').Count-ne1-or$old.Contains('--maxfail=0')){throw 'Controller delta is not unique'}
  $new=$old.Replace('--maxfail=1','--maxfail=0')
  if($new.Replace('--maxfail=0','--maxfail=1')-cne$old){throw 'Controller reversible byte delta differs'}
  [IO.File]::WriteAllText($dst,$new,[Text.UTF8Encoding]::new($false))
  if([IO.File]::ReadAllText($dst)-cne$new){throw 'Controller publication differs'}
  $oldBytes=[IO.File]::ReadAllBytes($src);$newBytes=[IO.File]::ReadAllBytes($dst)
  if($oldBytes.Length-ne$newBytes.Length){throw 'Controller byte length changed'}
  $indices=@(for($i=0;$i-lt$oldBytes.Length;$i++){if($oldBytes[$i]-ne$newBytes[$i]){$i}})
  if($indices.Count-ne1-or$oldBytes[$indices[0]]-ne49-or$newBytes[$indices[0]]-ne48){throw 'Controller delta is not exactly one ASCII byte1 to0'}
  Verify $src $c.helper_sha256[$name]
 }else{CopyExact $src $dst $c.helper_sha256[$name]}
 $helpers[$name]=HashFile $dst;$files['tools/'+$name]=$helpers[$name]
}
$unchanged=@($helpers.Keys|Where-Object{$helpers[$_]-ceq$c.helper_sha256[$_]})
if($unchanged.Count-ne37-or$helpers['run-regressions-080.py']-ceq$c.helper_sha256['run-regressions-080.py']){throw 'Unexpected helper delta'}
foreach($name in $f.files.Keys){
 if($name-ceq'artifacts/spec.json'){continue}
 $dest=Join-Path $root $name
 CopyExact (Join-Path $c.windows_root $name) $dest $f.files[$name]
 $files[$name]=$f.files[$name]
}
$spec=Get-Content -LiteralPath $c.specification -Raw|ConvertFrom-Json -AsHashtable
if($spec.argv.Count-ne13-or$spec.argv[2]-cne'ux'-or$spec.argv[4]-cne$c.run_id-or$spec.argv[6]-cne$c.linux_artifact_root){throw 'Formal whole381 argv differs'}
$spec.run_id=$run;$spec.argv[4]=$run;$spec.argv[6]=$linuxArt
$specPath=Join-Path $art 'spec.json';NewJson $specPath $spec;$files['artifacts/spec.json']=HashFile $specPath
$helperPath=Join-Path $root 'diagnostic-helpers.json'
NewJson $helperPath @{schema_version=1;scope='ux381_diagnostic_tools_not_release_qualification';run_id=$run;helper_sha256=$helpers;baseline_helper_sha256=$c.helper_sha256;changed_helper='run-regressions-080.py';exact_delta='--maxfail=1 -> --maxfail=0';unchanged_helper_count=37;release_qualification=$false}
$files['diagnostic-helpers.json']=HashFile $helperPath
$freezePath=Join-Path $root 'diagnostic-input-freeze.json'
NewJson $freezePath @{schema_version=1;scope='ux381_diagnostic_frozen_inputs_not_release_qualification';run_id=$run;files=$files;helper_sha256=$helpers;source_freeze_sha256=$c.app_freeze_sha256;baseline_formal_context_sha256=$formalSHA;release_qualification=$false}
$diag=@{}
foreach($k in $c.Keys){$diag[$k]=$c[$k]}
$diag.scope='devbrain_ux381_diagnostic_preparation_not_release_qualification'
$diag.status='prepared_diagnostic_not_run_pending_host_go'
$diag.run_id=$run;$diag.windows_root=$root;$diag.linux_root=$linuxRoot;$diag.artifact_root=$art;$diag.linux_artifact_root=$linuxArt
$diag.windows_tools=$tools;$diag.linux_tools=$linuxTools;$diag.controller=$linuxTools+'/run-regressions-080.py';$diag.controller_sha256=$helpers['run-regressions-080.py']
$diag.specification=$specPath;$diag.specification_sha256=HashFile $specPath
$diag.input_freeze=$freezePath;$diag.input_freeze_sha256=HashFile $freezePath;$diag.input_file_count=$files.Count;$diag.frozen_input_count=$files.Count
$diag.helper_sha256=$helpers;$diag.reviewed_helper_sha256=$helpers;$diag.toolbundle_freeze=$helperPath;$diag.toolbundle_freeze_sha256=HashFile $helperPath
$diag.baseline_expected_helper_sha256=$c.helper_sha256;$diag.baseline_formal_context=$formalPath;$diag.baseline_formal_context_sha256=$formalSHA
$diag.diagnostic_only=$true;$diag.diagnostic_changes=@{'run-regressions-080.py'='exact one maxfail1 -> maxfail0'};$diag.unchanged_helper_count=37
$diag.release_qualified=$false;$diag.application_qualified=$false;$diag.source_final=$false;$diag.full_suite_pass=$false;$diag.eight_hour_qualification=$false
$diag.release_helper_map_qualified=$false;$diag.guard_qualifies_unchanged_supervision_only=$true;$diag.pytest_maxfail=0
$diag.actual_windows_exit_code=$null;$diag.cleanup_complete=$false;$diag.receipt_sha256=$null;$diag.linux_workload_started=$false
$diag.created_utc=[DateTime]::UtcNow.ToString('o');$diag.preparation_only=$true
$diag.launch_parameters_without_Execute=@{ArtifactRoot=$art;LinuxArtifactRoot=$linuxArt;PythonExecutable=$diag.base_python;Controller=$diag.controller;ControllerArgumentsFile=$specPath;RunId=$run;TimeoutSeconds=$diag.timeout_seconds;CleanupGraceSeconds=30;WslCrashDirectory=$diag.wsl_crash_directory}
$contextPath=Join-Path $workspace 'evidence/080-ux381-diagnostic-active-context-20261109.json'
if(Test-Path -LiteralPath $contextPath){throw 'Diagnostic context already exists'}
NewJson $contextPath $diag
foreach($name in $files.Keys){Verify (Join-Path $root $name) $files[$name]}
Verify $formalPath $formalSHA
@{context=$contextPath;context_sha256=(HashFile $contextPath);root=$root;run_id=$run;specification_sha256=$diag.specification_sha256;input_freeze_sha256=$diag.input_freeze_sha256;controller_sha256=$diag.controller_sha256;files=$files.Count;helpers=38;unchanged_helpers=37;maxfail=0;modules=28;expected_cases=381;diagnostic_only=$true;linux_started=$false}|ConvertTo-Json

