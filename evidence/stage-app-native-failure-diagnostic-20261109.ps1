#Requires -Version 7.5
[CmdletBinding()]
param([switch]$Stage)
if(-not $Stage){Write-Output 'NOT_RUN: Windows staging only; no Linux preparation or tests are launched.';return}
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$workspace='C:\Users\piotr\OneDrive\Dokumenty\ChatGPT\devbrain'
$physicalBase='C:\Users\piotr\AppData\Local\Packages\OpenAI.Codex_2p2nqsd0c76g0\LocalCache\Local\DevBrain\qualification'
# Reuse the exact already reviewed path/copy/publication functions.
$sourceHelper=Join-Path $workspace 'release-tools/stage-postbios-bundle-080.ps1'
if((Get-FileHash -LiteralPath $sourceHelper -Algorithm SHA256).Hash.ToLowerInvariant()-cne'6a97d4d99d66467d07916ff2f2c3cdf142cbd4f49780615ed5da6bc6602dc619'){throw 'Canonical stage helper changed'}
$tokens=$null;$errors=$null;$ast=[Management.Automation.Language.Parser]::ParseFile($sourceHelper,[ref]$tokens,[ref]$errors)
if($errors.Count){throw 'Stage helper syntax changed'}
$nodes=@($ast.FindAll({param($n)$n-is[Management.Automation.Language.CommandAst]-and$n.GetCommandName()-ceq'Add-Type'},$false))
if($nodes.Count-ne1){throw 'Path helper inventory differs'};. ([scriptblock]::Create($nodes[0].Extent.Text))
foreach($name in @('NoReparse','HashFile','SourceProof')){
 $nodes=@($ast.FindAll({param($n)$n-is[Management.Automation.Language.FunctionDefinitionAst]-and$n.Name-ceq$name},$false))
 if($nodes.Count-ne1){throw 'Canonical function missing'};. ([scriptblock]::Create($nodes[0].Extent.Text))
}
$reviewedStage=Join-Path $workspace 'evidence/stage-ux-sidebar-resize-604-20261108.ps1'
if((HashFile $reviewedStage)-cne'8a4eb75de06a55e5e40c3db58739d8b90079381c23fa6b6962550b29c861ff5c'){throw 'Reviewed stage source changed'}
$tokens=$null;$errors=$null;$ast=[Management.Automation.Language.Parser]::ParseFile($reviewedStage,[ref]$tokens,[ref]$errors)
if($errors.Count){throw 'Reviewed stage syntax changed'}
foreach($name in @('Require','PathProof','ReadMap','Verify','NewJson','CopyExact','RelativeFile','SameMap','Artifacts')){
 $nodes=@($ast.FindAll({param($n)$n-is[Management.Automation.Language.FunctionDefinitionAst]-and$n.Name-ceq$name},$false))
 if($nodes.Count-ne1){throw 'Reviewed function missing'};. ([scriptblock]::Create($nodes[0].Extent.Text))
}
$contextPath=Join-Path $workspace 'evidence/080-app-native-failure-diagnostic-prepared-context-20261109.json'
Require (-not(Test-Path -LiteralPath $contextPath)) 'Do not overwrite a prior diagnostic context'
$appPath=Join-Path $workspace 'evidence/080-app-ux-snapshot-active-context.json'
$appSHA='d0a5b7e2682cd3f540fcce87446517fb8a11b6712f689aeb6df6dfbf562c771c';Verify $appPath $appSHA;$old=ReadMap $appPath
Require ($old.run_id-ceq'app080-20261108T222731Z'-and$old.status-ceq'prepared_passed'-and$old.actual_windows_exit_code-eq0) 'Proven previous prepare absent'
Verify $old.freeze_manifest 'ad77e00450537294fd26200d0713915689d82ff5a90e65f6c8fb1285fcbb4703'
Verify $old.setup_receipt '4cba08753a5d44463687271f5e695ccddac4d2284ca348b66630f480facde918'
$af=ReadMap $old.freeze_manifest;$oldReceipt=ReadMap $old.setup_receipt
Require ($af.files.Count-eq209-and$af.app_files-eq198-and$oldReceipt.passed-eq$true-and$oldReceipt.cleanup_complete-eq$true-and$oldReceipt.forced_cleanup-eq$false) 'Previous source/prepare mismatch'
Artifacts $af.files $old.bundle_root
foreach($rel in $af.files.Keys){if($rel.StartsWith('devbrain/')){Verify (RelativeFile $workspace $rel) $af.files[$rel]}}
$proposalPath=Join-Path $workspace 'evidence/080-native-failure-combined-proposal-20261109.json'
$proposalSHA='a1ae09656010cadbfc50719f2d6da22004e22a9222247f603c4178e0d4610606';Verify $proposalPath $proposalSHA;$p=ReadMap $proposalPath
Require ($p.unique_changed_files-eq8-and$p.logical_patch_components-eq9-and$p.all_other_UX_test_function_AST_unchanged-eq$true-and$p.all_UX_test_function_names_preserved-eq$true-and$p.source_changed-eq$false-and$p.release_qualified-eq$false) 'Combined proposal contract differs'
$expectedChanges=@('devbrain/src/devbrain/terminal_bridge.py','devbrain/src/devbrain/terminal_panels.py','devbrain/src/devbrain/workspace.py','devbrain/src/devbrain/terminal_i18n.py','devbrain/src/devbrain/native_worker.py','devbrain/tests/test_terminal_bridge.py','devbrain/tests/test_terminal_ux080.py','devbrain/tests/test_workspace_ux080.py')
Require ($p.files.Count-eq8-and@(Compare-Object @($p.files.Keys|Sort-Object) @($expectedChanges|Sort-Object)).Count-eq0) 'Unexpected changed files'
foreach($rel in $p.files.Keys){Require ($p.files[$rel].baseline_sha256-ceq$af.files[$rel]) 'Proposal baseline differs';Verify $p.files[$rel].proposal_path $p.files[$rel].proposal_sha256}
$uxPatch=Join-Path $workspace 'evidence/native-failure-ux-proposal-20261109/proposal.patch'
$termPatch=Join-Path $workspace 'evidence/native-worker-term-proposal-20261109/proposal.patch'
Verify $uxPatch 'b2344d7511cec32a38967c705ef01bcc83d71babe8e25e2868ed4c170483bbab'
Verify $termPatch '61927180e1743f44b40dfbc86323d641f68539792c34f18b0be6970f198f8d50'
$uxPeer=Join-Path $workspace 'evidence/native-failure-ux-independent-peer-20261109.json'
$termPeer=Join-Path $workspace 'evidence/080-native-worker-term-consistency-peer-20261109.json'
Verify $uxPeer 'e789ec8a8f17ec05d941d251cdb3915486c1420c60d9a625a1cb7330a11e863b'
Verify $termPeer '486e7dcebe4bfd304883f7bddd0baefe4207128aa54a2990fc98cf5ef97e98d5'
$guardPath=Join-Path $workspace 'evidence/080-guards-queue-budget-active-context-20261108.json'
$guardSHA='9e9d865acea676f9fab11225c54e49095610e44feb37d9a0b0cd6e882633e6d6';Verify $guardPath $guardSHA;$g=ReadMap $guardPath
Require ($g.status-ceq'passed'-and$g.actual_windows_exit_code-eq0-and$g.helper_sha256.Count-eq38) 'Canonical instrumentation not ready'
Verify $g.freeze_manifest $g.freeze_sha256
foreach($n in $g.helper_sha256.Keys){Verify (RelativeFile $g.windows_tools $n) $g.helper_sha256[$n]}
$run='app-uxfailure080-'+[DateTime]::UtcNow.ToString('yyyyMMddTHHmmssZ')+'-'+[Guid]::NewGuid().ToString('N').Substring(0,8)
Require ($run.Length-le64) 'Prepare run identifier too long'
$root=Join-Path $physicalBase $run;Require (-not(Test-Path -LiteralPath $root)) 'Fresh root already exists';NoReparse $root
foreach($sub in @('bundle','setup-evidence','inputs')){[void][IO.Directory]::CreateDirectory((Join-Path $root $sub));PathProof (Join-Path $root $sub)}
$bundle=Join-Path $root bundle;$setup=Join-Path $root setup-evidence;$files=[ordered]@{};$changes=[ordered]@{}
foreach($rel in @($af.files.Keys|Sort-Object)){
 $source=RelativeFile $old.bundle_root $rel;$digest=$af.files[$rel]
 if($p.files.Contains($rel)){$source=$p.files[$rel].proposal_path;$digest=$p.files[$rel].proposal_sha256;$changes[$rel]=$digest}
 $target=RelativeFile $bundle $rel;[void][IO.Directory]::CreateDirectory((Split-Path $target))
 CopyExact $source $target $digest;$files[$rel]=$digest
}
Require ($files.Count-eq209-and$changes.Count-eq8-and@(Get-ChildItem -LiteralPath $bundle -Recurse -File).Count-eq209) 'New bundle inventory differs'
Artifacts $files $bundle
$freezePath=Join-Path $root source-freeze.json
NewJson $freezePath @{
 schema_version=1;scope='diagnostic_app_source_proposal_copy';run_id=$run;status='Windows_staged_not_Linux_prepared';diagnostic_only=$true
 previous_snapshot=$old.run_id;previous_freeze_sha256=$old.freeze_sha256;files=$files;app_files=198;total_files=209
 approved_changes=$changes;logical_patch_components=9;combined_proposal_sha256=$proposalSHA
 no_reparse_destination=$true;source_and_destination_handle_proofs_passed=$true;historical_source_mutated=$false;working_source_mutated=$false
 runtime_changed=$false;requirements_sha256=$files['requirements.txt'];expected_qualified_package_pin_count=59
 source_final=$false;application_qualified=$false;release_qualified=$false
}
$inputs=[ordered]@{}
$bindings=[ordered]@{
 'previous-app-context.json'=@{path=$appPath;sha=$appSHA}
 'previous-source-freeze.json'=@{path=$old.freeze_manifest;sha=$old.freeze_sha256}
 'previous-prepare-receipt.json'=@{path=$old.setup_receipt;sha=$old.setup_receipt_sha256}
 'combined-proposal.json'=@{path=$proposalPath;sha=$proposalSHA}
 'UX-proposal.patch'=@{path=$uxPatch;sha='b2344d7511cec32a38967c705ef01bcc83d71babe8e25e2868ed4c170483bbab'}
 'TERM-proposal.patch'=@{path=$termPatch;sha='61927180e1743f44b40dfbc86323d641f68539792c34f18b0be6970f198f8d50'}
 'UX-independent-peer.json'=@{path=$uxPeer;sha='e789ec8a8f17ec05d941d251cdb3915486c1420c60d9a625a1cb7330a11e863b'}
 'TERM-independent-peer.json'=@{path=$termPeer;sha='486e7dcebe4bfd304883f7bddd0baefe4207128aa54a2990fc98cf5ef97e98d5'}
 'canonical-guard-context.json'=@{path=$guardPath;sha=$guardSHA}
 'canonical-toolbundle-freeze.json'=@{path=$g.freeze_manifest;sha=$g.freeze_sha256}
 'materializer.ps1'=@{path=$PSCommandPath;sha=(HashFile $PSCommandPath)}
}
foreach($name in $bindings.Keys){$v=$bindings[$name];CopyExact $v.path (Join-Path $root ('inputs/'+$name)) $v.sha;$inputs['inputs/'+$name]=$v.sha}
$inputs['source-freeze.json']=HashFile $freezePath
$inputFreeze=Join-Path $root prepared-input-freeze.json
NewJson $inputFreeze @{schema_version=1;scope='diagnostic_app_setup_inputs';run_id=$run;files=$inputs;source_freeze_sha256=(HashFile $freezePath);canonical_regression_helper_sha256=$g.helper_sha256;Linux_started=$false}
$c=@{
 schema_version=1;scope='isolated_diagnostic_app_prepare_only';status='prepared_not_run_pending_root_Linux_GO';run_id=$run;created_utc=[DateTime]::UtcNow.ToString('o')
 windows_root=$root;bundle_root=$bundle;artifact_root=$setup;linux_bundle_root=('/mnt/c/'+$bundle.Substring(3).Replace('\','/'))
 linux_root=('/home/piotr/.cache/devbrain-runtime-080/postbios-'+$run)
 source_root=('/home/piotr/.cache/devbrain-runtime-080/postbios-'+$run+'/project/devbrain')
 python_launcher=('/home/piotr/.cache/devbrain-runtime-080/postbios-'+$run+'/venv/bin/python')
 freeze_manifest=$freezePath;freeze_sha256=(HashFile $freezePath);input_freeze=$inputFreeze;input_freeze_sha256=(HashFile $inputFreeze);frozen_input_count=$inputs.Count
 previous_app_context=$appPath;previous_app_context_sha256=$appSHA;previous_snapshot=$old.run_id;previous_source_freeze_sha256=$old.freeze_sha256
 unique_changed_files=8;logical_patch_components=9;app_files=198;total_files=209;combined_proposal=$proposalPath;combined_proposal_sha256=$proposalSHA
 prepare_launcher=(Join-Path $bundle 'release-tools/run-postbios-diagnostic-080.ps1')
 prepare_launcher_sha256=$files['release-tools/run-postbios-diagnostic-080.ps1'];prepare_controller_sha256=$files['release-tools/postbios-diagnostic-080.py']
 prepare_historical_supervision_helper_sha256=$files['release-tools/supervise-080.py'];prepare_pipeline_unchanged=$true
 requirements_sha256=$files['requirements.txt'];expected_qualified_package_pin_count=59;runtime=$oldReceipt.runtime
 canonical_regression_windows_tools=$g.windows_tools;canonical_regression_linux_tools=$g.linux_tools;canonical_regression_helper_sha256=$g.helper_sha256
 canonical_regression_toolbundle_freeze=$g.freeze_manifest;canonical_regression_toolbundle_freeze_sha256=$g.freeze_sha256;canonical_regression_helper_count=38
 targeted_modules=@('tests/test_terminal_bridge.py','tests/test_terminal_ux080.py','tests/test_workspace_ux080.py')
 actual_collection_required=$true;test_count_assumed=$false;test_mode='diagnostic_collect_all_not_release_qualification'
 launch_requires_explicit_root_GO=$true;Linux_workload_started=$false;runtime_prepared=$false;actual_windows_exec_session=$null;actual_windows_exit_code=$null
 source_final=$false;application_qualified=$false;release_qualified=$false;production_modified=$false;private_database_started=$false;models_or_auth_started=$false
 global_app_context_modified=$false;historical_snapshots_modified=$false;eight_hour_started=$false
}
$c.launch_parameters_without_Execute=@{BundleRoot=$bundle;ArtifactRoot=$setup;RunId=$run;Phase='prepare';TimeoutSeconds=1800}
Artifacts $inputs $root;Verify $appPath $appSHA;Artifacts $af.files $old.bundle_root
foreach($rel in $af.files.Keys){if($rel.StartsWith('devbrain/')){Verify (RelativeFile $workspace $rel) $af.files[$rel]}}
foreach($n in $g.helper_sha256.Keys){Verify (RelativeFile $g.windows_tools $n) $g.helper_sha256[$n]}
NewJson $contextPath $c
@{context=$contextPath;context_sha256=(HashFile $contextPath);run_id=$run;windows_root=$root;bundle_files=209;app_files=198;changed=8;logical_components=9
 input_freeze_sha256=$c.input_freeze_sha256;source_freeze_sha256=$c.freeze_sha256;inputs=$inputs.Count;canonical_helpers=38;Linux_started=$false;launch_permitted=$false}|ConvertTo-Json -Depth 4

