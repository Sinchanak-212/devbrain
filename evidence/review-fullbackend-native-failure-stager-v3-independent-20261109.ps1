#Requires -Version 7.5
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$workspace='C:\Users\piotr\OneDrive\Dokumenty\ChatGPT\devbrain'
$path=Join-Path $workspace 'evidence/stage-fullbackend-native-failure-diagnostic-v3-20261109.ps1'
$sha='4d1eab44dbaa63ed33a773d0911243a55aa190184bad25c63cb23a3901ba8d07'
if((Get-FileHash -LiteralPath $path).Hash.ToLowerInvariant()-cne$sha){throw 'Stager changed'}
$base=Join-Path $workspace 'evidence/stage-fullbackend-sidebar-resize-604-20261108.ps1'
if((Get-FileHash -LiteralPath $base).Hash.ToLowerInvariant()-cne'de36c4daac4b3589cad3dd9bfa95db7df0a1df34b3756cace6cecd0978e00635'){throw 'Baseline changed'}
$t=$null;$e=$null;$ast=[Management.Automation.Language.Parser]::ParseFile($path,[ref]$t,[ref]$e);if($e.Count){throw 'New parse error'}
$t=$null;$e=$null;$baseAST=[Management.Automation.Language.Parser]::ParseFile($base,[ref]$t,[ref]$e);if($e.Count){throw 'Baseline parse error'}
$functions=@($ast.FindAll({param($n)$n-is[Management.Automation.Language.FunctionDefinitionAst]},$false));$oldFunctions=@($baseAST.FindAll({param($n)$n-is[Management.Automation.Language.FunctionDefinitionAst]},$false))
if($functions.Count-ne$oldFunctions.Count){throw 'Function inventory differs'}
foreach($node in $functions){$old=@($oldFunctions|Where-Object{$_.Name-ceq$node.Name});if($old.Count-ne1-or$old[0].Extent.Text-cne$node.Extent.Text){throw 'Old proof/path function changed'}}
$canonical=Join-Path $workspace 'release-tools/stage-postbios-bundle-080.ps1'
$t=$null;$e=$null;$canonAST=[Management.Automation.Language.Parser]::ParseFile($canonical,[ref]$t,[ref]$e)
$add=@($canonAST.FindAll({param($n)$n-is[Management.Automation.Language.CommandAst]-and$n.GetCommandName()-ceq'Add-Type'},$false));if($add.Count-ne1){throw 'Canonical type inventory differs'};. ([scriptblock]::Create($add[0].Extent.Text))
foreach($name in @('NoReparse','HashFile','SourceProof')){$node=@($canonAST.FindAll({param($n)$n-is[Management.Automation.Language.FunctionDefinitionAst]-and$n.Name-ceq$name},$false));if($node.Count-ne1){throw 'Canonical support inventory differs'};. ([scriptblock]::Create($node[0].Extent.Text))}
foreach($name in @('Physical','ReadMap','Require','Verify','RelativeFile','SameMap','ArtifactHashes')){$node=@($functions|Where-Object{$_.Name-ceq$name});. ([scriptblock]::Create($node[0].Extent.Text))}
$g=ReadMap (Join-Path $workspace 'evidence/080-guards-queue-budget-active-context-20261108.json')
$receipt=ReadMap (Join-Path $g.artifact_root 'receipt.json')
$sourceSHA='ad77e00450537294fd26200d0713915689d82ff5a90e65f6c8fb1285fcbb4703'
$AppContextSha256='387f9f0075a89195e52164c1e83a15261afc7847508ec3462f5f094d9404fd92'
$AppPrepareReceiptSha256='fc63c2782c515d63e8c6e45b1c130d8a16b43904a8b6a050163b4034552db0bd'
$AppFinalReportSha256='b3882183d0921fa8f305de86f27ce3af3fc42b9d9a7211d9ee68b5208e543bed'
$AppRootActualExecSession=43687
$text=[IO.File]::ReadAllText($path)
$start=$text.IndexOf('# New App preparation is independent')
$end=$text.IndexOf('# These unchanged process-supervision fixtures', $start)
if($start-lt0-or$end-le$start){throw 'Read-only added proof block missing'}
$block=$text.Substring($start,$end-$start)
if($block-match'CopyExact|CopyInput|NewJson|CreateDirectory|Start-Process|wsl.exe| -Execute'){throw 'Readonly review block unexpectedly mutates or executes'}
. ([scriptblock]::Create($block))
$output=Join-Path $workspace 'evidence/fullbackend-native-failure-stager-v3-independent-peer-20261109.json'
if(Test-Path -LiteralPath $output){throw 'Peer record exists'}
$record=@{schema_version=1;scope='readonly_fresh_prototype_fullbackend_stager_peer';status='passed';stager_sha256=$sha;baseline_sha256='de36c4daac4b3589cad3dd9bfa95db7df0a1df34b3756cace6cecd0978e00635';original_pure_functions_unchanged=$functions.Count;PS_parse_errors=0;actual_readonly_new_prepare_block_passed=$true;actual_App_context_sha256=$AppContextSha256;actual_prepare_receipt_sha256=$AppPrepareReceiptSha256;actual_prepare_final_sha256=$AppFinalReportSha256;actual_prepare_root_session=43687;new_source_freeze_sha256=$sourceSHA;old604_is_old_source_instrumentation_only=$true;new_collection_count_not_assumed=$true;canonical38_unchanged=$true;Stage_body_not_invoked=$true;Linux_or_tests_or_models_or_auth_started=$false;App_files_changed=$false;eight_hour_started=$false;findings=@()}
[IO.File]::WriteAllText($output,($record|ConvertTo-Json -Depth 8),[Text.UTF8Encoding]::new($false))
@{path=$output;sha256=(Get-FileHash -LiteralPath $output).Hash.ToLowerInvariant();pure_functions=$functions.Count;actual_readonly_prepare_block_passed=$true}|ConvertTo-Json
