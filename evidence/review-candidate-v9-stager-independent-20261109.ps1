#Requires -Version 7.5
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$workspace='C:\Users\piotr\OneDrive\Dokumenty\ChatGPT\devbrain'
$physicalBase='C:\Users\piotr\AppData\Local\Packages\OpenAI.Codex_2p2nqsd0c76g0\LocalCache\Local\DevBrain\qualification'
$path=Join-Path $workspace 'evidence/stage-candidate-build-v9-20261109.ps1'
$base=Join-Path $workspace 'evidence/stage-candidate-build-v8-20261108.ps1'
if((Get-FileHash -LiteralPath $path).Hash.ToLowerInvariant()-cne'4788e90d9999c19b07ea17ac5a0dc6c84102aa25ef372bbc293d04659db81c74'){throw 'New V9 source changed'}
if((Get-FileHash -LiteralPath $base).Hash.ToLowerInvariant()-cne'21eb822af641c9ab2b95407f908e51e25da19907d8da49b29789dee3d90a5f2a'){throw 'V8 source changed'}
$t=$null;$e=$null;$a=[Management.Automation.Language.Parser]::ParseFile($path,[ref]$t,[ref]$e);if($e.Count){throw 'V9 parse failed'}
$t=$null;$e=$null;$b=[Management.Automation.Language.Parser]::ParseFile($base,[ref]$t,[ref]$e);if($e.Count){throw 'V8 parse failed'}
$newFunctions=@($a.FindAll({param($n)$n-is[Management.Automation.Language.FunctionDefinitionAst]},$false));$oldFunctions=@($b.FindAll({param($n)$n-is[Management.Automation.Language.FunctionDefinitionAst]},$false))
if($newFunctions.Count-ne$oldFunctions.Count){throw 'Function inventory differs'}
foreach($node in $newFunctions){$old=@($oldFunctions|Where-Object{$_.Name-ceq$node.Name});if($old.Count-ne1-or$old[0].Extent.Text-cne$node.Extent.Text){throw 'Original pure function changed'}}
$AppContextSha256='387f9f0075a89195e52164c1e83a15261afc7847508ec3462f5f094d9404fd92'
$PrepareReceiptSha256='fc63c2782c515d63e8c6e45b1c130d8a16b43904a8b6a050163b4034552db0bd'
$s=[IO.File]::ReadAllText($path);$start=$s.IndexOf('$sourceHelper=');$end=$s.IndexOf('PathProof $physicalBase')
if($start-lt0-or$end-le$start){throw 'Readonly validation boundary absent'}
# Only imports, function declarations, reads and predicates before first directory creation.
. ([scriptblock]::Create($s.Substring($start,$end-$start)))
$first=$s.IndexOf('$oldTools=$old.windows_tools');$last=$s.IndexOf('$launcherText=', $first)
if($first-lt0-or$last-le$first){throw 'Observer equality block absent'}
. ([scriptblock]::Create($s.Substring($first,$last-$first)))
$record=@{schema_version=1;scope='readonly_candidate_v9_stager_independent_peer';status='passed_for_Windows_staging_only';stager_sha256='4788e90d9999c19b07ea17ac5a0dc6c84102aa25ef372bbc293d04659db81c74';baseline_stager_sha256='21eb822af641c9ab2b95407f908e51e25da19907d8da49b29789dee3d90a5f2a';PS_parse_errors=0;original_functions_exact=$newFunctions.Count;actual_prewrite_readonly_validation_passed=$true;actual_fresh_App_context_sha256=$AppContextSha256;actual_App_prepare_receipt_sha256=$PrepareReceiptSha256;source_freeze_sha256=$app.freeze_sha256;actual_changed_App_files=$changed;canonical_builder_sha256=$old.helper_sha256['build-devbrain-update-080.py'];canonical_template_sha256=$old.helper_sha256['devbrain-update080-template.py'];baseline072_sha256=$old.baseline_sha256;old403_to_current604_observer_function_equality_count=8;old403_wrapper_sha256='4cab90d8ee3b0febb6aaf10bc424b76b9b0b7f14a39a5a2df97b978492ba3a74';current604_wrapper_sha256=$g.helper_sha256['run-supervised-080.ps1'];canonical38_unchanged=$true;old604_not_new_App_qualification=$true;actual_Stage_or_build_invoked=$false;Linux_or_models_or_accounts_started=$false;App_or_previous_V8_modified=$false;eight_hour_started=$false;findings=@()}
$output=Join-Path $workspace 'evidence/candidate-v9-stager-independent-peer-20261109.json';if(Test-Path -LiteralPath $output){throw 'Peer record exists'}
[IO.File]::WriteAllText($output,($record|ConvertTo-Json -Depth 8),[Text.UTF8Encoding]::new($false))
@{path=$output;sha256=(Get-FileHash -LiteralPath $output).Hash.ToLowerInvariant();readonly_prewrite_validation_passed=$true;original_functions=$newFunctions.Count;observer_functions=8}|ConvertTo-Json
