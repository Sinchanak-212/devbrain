#Requires -Version 7.5
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$workspace='C:\Users\piotr\OneDrive\Dokumenty\ChatGPT\devbrain'
$physicalBase='C:\Users\piotr\AppData\Local\Packages\OpenAI.Codex_2p2nqsd0c76g0\LocalCache\Local\DevBrain\qualification'
$path=Join-Path $workspace 'evidence/stage-standalone-native-failure-1605-20261109.ps1'
$base=Join-Path $workspace 'evidence/stage-standalone-sidebar-resize-1561-20261109.ps1'
if((Get-FileHash -LiteralPath $path).Hash.ToLowerInvariant()-cne'19943bb8fea50075e3dc7f3a7cfb887115142c5cf584139f53ca5543b77e4dad'){throw 'Stager changed'}
if((Get-FileHash -LiteralPath $base).Hash.ToLowerInvariant()-cne'd8edf4496ae5827297fc3466a450a80a2b618a5bbb82649b123c6aa506169304'){throw 'Baseline changed'}
$t=$null;$e=$null;$a=[Management.Automation.Language.Parser]::ParseFile($path,[ref]$t,[ref]$e);if($e.Count){throw 'New parse failed'}
$t=$null;$e=$null;$ba=[Management.Automation.Language.Parser]::ParseFile($base,[ref]$t,[ref]$e);if($e.Count){throw 'Baseline parse failed'}
$nf=@($a.FindAll({param($n)$n-is[Management.Automation.Language.FunctionDefinitionAst]},$false));$of=@($ba.FindAll({param($n)$n-is[Management.Automation.Language.FunctionDefinitionAst]},$false))
if($nf.Count-ne$of.Count){throw 'Function inventory differs'}
foreach($n in $nf){$o=@($of|Where-Object{$_.Name-ceq$n.Name});if($o.Count-ne1-or$o[0].Extent.Text.Replace("`r`n","`n")-cne$n.Extent.Text.Replace("`r`n","`n")){throw 'Pure function code changed'}}
$text=[IO.File]::ReadAllText($path);$first=$text.IndexOf('$sourceHelper=');$last=$text.IndexOf('$contextPath=')
if($first-lt0-or$last-le$first){throw 'Prewrite validator boundary missing'}
. ([scriptblock]::Create($text.Substring($first,$last-$first)))
$root=Join-Path $physicalBase 'PEER_SIMULATION_ONLY_NO_DIRECTORY_CREATED'
$first=$text.IndexOf('$launcher=[IO.File]');$last=$text.IndexOf('$launcherPath=', $first)
if($first-lt0-or$last-le$first){throw 'Mechanical code generation boundary absent'}
. ([scriptblock]::Create($text.Substring($first,$last-$first)))
$expectedLauncher=[IO.File]::ReadAllText($old.launcher).Replace($old.windows_root,$root).Replace((ReadMap $old.plan).tools,$g.windows_tools).Replace('1561','1605').Replace("`$context.status -cne 'passed'","`$context.status -cne 'diagnostic_passed_not_release_qualified'")
$expectedMaterializer=[IO.File]::ReadAllText($old.materializer).Replace($old.windows_root,$root).Replace((ReadMap $old.plan).tools,$g.windows_tools).Replace("`$context.status -ceq 'passed'","`$context.status -ceq 'diagnostic_passed_not_release_qualified'")
Require ($launcher-ceq$expectedLauncher-and$materializer-ceq$expectedMaterializer) 'Generated observer/materializer have an undeclared semantic change'
$generated=@{};foreach($pair in @(@('observer',$old.launcher,$launcher),@('materializer',$old.materializer,$materializer))){
 $t=$null;$e=$null;$newAST=[Management.Automation.Language.Parser]::ParseInput($pair[2],[ref]$t,[ref]$e);Require ($e.Count-eq0) 'Generated parse failed'
 $t=$null;$e=$null;$oldAST=[Management.Automation.Language.Parser]::ParseFile($pair[1],[ref]$t,[ref]$e)
 $newF=@($newAST.FindAll({param($n)$n-is[Management.Automation.Language.FunctionDefinitionAst]},$false));$oldF=@($oldAST.FindAll({param($n)$n-is[Management.Automation.Language.FunctionDefinitionAst]},$false));Require ($newF.Count-eq$oldF.Count) 'Generated function inventory differs'
 $changedFunctions=@()
 foreach($n in $newF){
  $o=@($oldF|Where-Object{$_.Name-ceq$n.Name});Require ($o.Count-eq1) 'Generated function absent'
  if($o[0].Extent.Text-cne$n.Extent.Text){
   Require ($pair[0]-ceq'observer'-and$n.Name-cin@('Verify-Inputs','Verify-Outputs')) ('Unexpected generated function change: '+$pair[0]+'/'+$n.Name)
   $expected=$o[0].Extent.Text.Replace($old.windows_root,$root).Replace((ReadMap $old.plan).tools,$g.windows_tools).Replace('1561','1605').Replace("`$context.status -cne 'passed'","`$context.status -cne 'diagnostic_passed_not_release_qualified'")
   Require ($n.Extent.Text-ceq$expected) 'Admission function differs beyond exact declared count/status/root retarget'
   $changedFunctions+=$n.Name
  }
 }
 $oldL=@([regex]::Matches([IO.File]::ReadAllText($pair[1]),'\b[0-9a-f]{64}\b')|ForEach-Object{$_.Value}|Sort-Object -Unique);$newL=@([regex]::Matches($pair[2],'\b[0-9a-f]{64}\b')|ForEach-Object{$_.Value}|Sort-Object -Unique)
 Require (($oldL-join',')-ceq($newL-join',')) 'A fixed64hex guard changed via count substitution'
 $generated[$pair[0]]=@{parse_errors=0;function_count=$newF.Count;byteidentical_pure_functions=($newF.Count-$changedFunctions.Count);admission_function_changed_only_as_declared=$changedFunctions;fixed64hex_literal_set_unchanged=$true;allowed_delta_only='fresh root/tools,1561->1605 observer count, diagnostic completed backend status literal'}
}
$out=Join-Path $workspace 'evidence/standalone1605-stager-independent-peer-20261109.json';Require (-not(Test-Path -LiteralPath $out)) 'Peer exists'
$record=@{schema_version=1;scope='readonly_standalone1605_stager_peer';status='passed_pending_one_metadata_label_correction';stager_sha256='19943bb8fea50075e3dc7f3a7cfb887115142c5cf584139f53ca5543b77e4dad';PS_parse_errors=0;original_pure_stager_function_code_unchanged_EOL_only=$nf.Count;actual_prewrite_validation_passed=$true;backend_actual_session=74540;backend_actual_count=1605;source_freeze_sha256=$b.app_freeze_sha256;generated=$generated;findings=@('Stager copied mixed LF/CRLF function bodies to CRLF only; after EOL normalization all pure function code is identical. Generated helpers are compared byte-for-byte to exact allowed transforms.','Set reverse_transform_only_root_tools_session_count=false and add reverse_transform_only_root_tools_count_and_diagnostic_status=true, to disclose the honest status literal retarget. No code guard change required.');Stage_or_Prepare_or_Linux_invoked=$false;models_accounts_or_App_changed=$false;eight_hour_started=$false}
[IO.File]::WriteAllText($out,($record|ConvertTo-Json -Depth 8),[Text.UTF8Encoding]::new($false))
@{path=$out;sha256=(Get-FileHash -LiteralPath $out).Hash.ToLowerInvariant();generated=$generated;prewrite_validation_passed=$true;metadata_label_fix_required=$true}|ConvertTo-Json -Depth 6
