# Read-only peer fixtures: execute selected pure AST guards only, never helper body.
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$workspace='C:\Users\piotr\OneDrive\Dokumenty\ChatGPT\devbrain'
$helper=Join-Path $workspace 'evidence/post-ui-admission-finalize-v2-080-20261109.ps1'
$consumer=Join-Path $workspace 'evidence/stage-final-eight-hour-sidebar-resize-604-20261108.ps1'
function Assert([bool]$Value,[string]$Message){if(-not$Value){throw $Message}}
function Parse([string]$Path){$t=$null;$e=$null;$a=[Management.Automation.Language.Parser]::ParseFile($Path,[ref]$t,[ref]$e);Assert ($e.Count-eq0) 'Parse error';return $a}
Assert ((Get-FileHash -LiteralPath $helper).Hash.ToLowerInvariant()-ceq'f99e80c1c5094edd9cd3d9378cb399f9945293330a64ca7980dadf03cb5442b1') 'Wrong V2 helper'
Assert ((Get-FileHash -LiteralPath $consumer).Hash.ToLowerInvariant()-ceq'3527b2c82c372c4d8764d0ff3a8a4be3e84d6c1e78c503044fe94cc8af9cc5ee') 'Wrong consumer'
$a=Parse $helper;$ca=Parse $consumer
$require=@($ca.FindAll({param($n)$n-is[Management.Automation.Language.FunctionDefinitionAst]-and$n.Name-ceq'Require'},$false));Assert ($require.Count-eq1) 'Require definition count';. ([scriptblock]::Create($require[0].Extent.Text))
function Guard([string]$Marker,[switch]$FromConsumer){$source=if($FromConsumer){$ca}else{$a};$nodes=@($source.FindAll({param($n)$n-is[Management.Automation.Language.CommandAst]-and$n.GetCommandName()-ceq'Require'-and$n.Extent.Text.Contains($Marker)},$true));Assert ($nodes.Count-eq1) ('Guard count: '+$Marker);return [scriptblock]::Create($nodes[0].Extent.Text)}
function Header([int]$Line){$nodes=@($a.FindAll({param($n)$n-is[Management.Automation.Language.IfStatementAst]-and$n.Extent.StartLineNumber-eq$Line},$false));Assert ($nodes.Count-eq1) 'Header count';return [scriptblock]::Create($nodes[0].Extent.Text)}
$rows=[Collections.Generic.List[object]]::new()
function Case([string]$Name,[scriptblock]$Guard,[scriptblock]$Setup,[bool]$Reject){
 & {param($N,$G,$S,$R) . $S;$rejected=$false;try{. $G}catch{$rejected=$true};$passed=($rejected-eq$R);$rows.Add([ordered]@{name=$N;expected_rejection=$R;rejected=$rejected;passed=$passed});Assert $passed ('Unexpected guard outcome: '+$N)} $Name $Guard $Setup $Reject
}
$h=Header 7
Case 'missing_UI_context' $h {$Finalize=$true;$UiContext='';$UiContextSha256='a'*64;$UiReceiptSha256='b'*64;$UiFinalReportSha256='c'*64;$UiRootActualExecSession=1} $true
Case 'missing_UI_digest' $h {$Finalize=$true;$UiContext='fixture';$UiContextSha256='';$UiReceiptSha256='b'*64;$UiFinalReportSha256='c'*64;$UiRootActualExecSession=1} $true
Case 'malformed_UI_digest' $h {$Finalize=$true;$UiContext='fixture';$UiContextSha256='G'*64;$UiReceiptSha256='b'*64;$UiFinalReportSha256='c'*64;$UiRootActualExecSession=1} $true
Case 'missing_actual_session' $h {$Finalize=$true;$UiContext='fixture';$UiContextSha256='a'*64;$UiReceiptSha256='b'*64;$UiFinalReportSha256='c'*64;$UiRootActualExecSession=0} $true
Case 'syntactically_complete_UI_inputs' $h {$Finalize=$true;$UiContext='fixture';$UiContextSha256='a'*64;$UiReceiptSha256='b'*64;$UiFinalReportSha256='c'*64;$UiRootActualExecSession=1} $false
Case 'readonly_cannot_finalize' (Header 6) {$ValidatePreparedInputs=$true;$Finalize=$true;$FinalizeStandalone=$false} $true
Case 'readonly_cannot_finalize_standalone' (Header 6) {$ValidatePreparedInputs=$true;$Finalize=$false;$FinalizeStandalone=$true} $true
Case 'two_publication_modes_rejected' (Header 5) {$Finalize=$true;$FinalizeStandalone=$true} $true
$actual=Guard 'Root has not confirmed actual current UI exit'
foreach($kind in @('good','exit1','failed_status','wrong_session')){
 $setup=[scriptblock]::Create('$UiRootActualExecSession=42;$uiContext=@{actual_windows_exec_session=42;actual_windows_exit_code=0;status=''passed''};'+$(switch($kind){'exit1'{'$uiContext.actual_windows_exit_code=1'}'failed_status'{'$uiContext.status=''failed'''}'wrong_session'{'$uiContext.actual_windows_exec_session=41'}default{''}}))
 Case ('actual_UI_'+$kind) $actual $setup ($kind-cne'good')
}
$visual=Guard 'Literal formal visual acceptance missing'
foreach($kind in @('missing','null','false','string_true','number_one','two_photos','good')){
 $assign=switch($kind){'missing'{''}'null'{'$gates.interactive.final.visual_acceptance_passed=$null'}'false'{'$gates.interactive.final.visual_acceptance_passed=$false'}'string_true'{'$gates.interactive.final.visual_acceptance_passed=''true'''}'number_one'{'$gates.interactive.final.visual_acceptance_passed=1'}'two_photos'{'$gates.interactive.final.visual_acceptance_passed=$true;$gates.interactive.final.photos=@(1,2)'}'good'{'$gates.interactive.final.visual_acceptance_passed=$true'}}
 Case ('typed_visual_'+$kind) $visual ([scriptblock]::Create('$gates=@{interactive=@{final=@{photos=@(1,2,3)}}};'+$assign)) ($kind-cne'good')
}
$source=Guard 'Wrong source freeze:' -FromConsumer
Case 'same_source_freeze' $source {$Name='fixture';$sourceSHA='a'*64;$master=@{source_freeze_sha256='a'*64}} $false
Case 'different_source_freeze' $source {$Name='fixture';$sourceSHA='b'*64;$master=@{source_freeze_sha256='a'*64}} $true
$qualified=Guard 'Wrong original qualified source/launcher:' -FromConsumer
Case 'different_source_root' $qualified {$Name='fixture';$c=@{source_root='other';python_launcher='p'};$backend=@{source_root='expected';python_launcher='p'}} $true
Case 'different_interpreter' $qualified {$Name='fixture';$c=@{source_root='expected';python_launcher='other'};$backend=@{source_root='expected';python_launcher='p'}} $true
Case 'same_qualified_source_and_interpreter' $qualified {$Name='fixture';$c=@{source_root='expected';python_launcher='p'};$backend=@{source_root='expected';python_launcher='p'}} $false
$input=Get-Content -Raw -LiteralPath (Join-Path $workspace 'evidence/post-ui-admission-inputs-v2-20261109.json')|ConvertFrom-Json -AsHashtable
$refRows=@($input.refs.GetEnumerator()|ForEach-Object{$e=$_.Value;Assert ((Get-FileHash -LiteralPath $e.context).Hash.ToLowerInvariant()-ceq$e.context_sha256) 'Context digest changed';Assert ((Get-FileHash -LiteralPath $e.final_report).Hash.ToLowerInvariant()-ceq$e.final_report_sha256) 'Report digest changed';[ordered]@{name=$_.Key;context_hash_verified=$true;final_report_hash_verified=$true}})
$diagRows=@(foreach($n in @('frontend','recall','copilot','upgrade_smoke','native')){$e=$input.refs[$n];$c=Get-Content -Raw -LiteralPath $e.context|ConvertFrom-Json -AsHashtable;$r=Get-Content -Raw -LiteralPath $e.final_report|ConvertFrom-Json -AsHashtable;Assert ($c.status-ceq'diagnostic_passed_not_release_qualified'-and$c.error_inventory_only-eq$true-and$c.current_ui_passed-eq$false-and$c.source_final-eq$false-and$c.release_qualified-eq$false-and$r.status-ceq'diagnostic_passed_not_release_qualified') 'Original diagnostic flags altered';[ordered]@{name=$n;original_diagnostic_only_flags_verified=$true}})
$prep=Get-Content -Raw -LiteralPath (Join-Path $workspace 'evidence/post-ui-admission-v2-preparation-20261109.json')|ConvertFrom-Json -AsHashtable
$expected=Get-Content -Raw -LiteralPath (Join-Path $workspace 'evidence/post-ui-admission-finalize-080-20261109.ps1')
foreach($change in $prep.metadata_and_scope_changes.GetEnumerator()){$expected=$expected.Replace($change.Key,$change.Value.replacement)}
$actualText=Get-Content -Raw -LiteralPath $helper
Assert ($actualText-ceq$expected) 'Undeclared V1 to V2 text delta'
$report=[ordered]@{schema_version=1;scope='independent_readonly_post_UI_admission_V2_peer';status='passed';helper_sha256='f99e80c1c5094edd9cd3d9378cb399f9945293330a64ca7980dadf03cb5442b1';inputs_sha256='d015ca0b063c5858545df2293243ce3ed293163fa2f03d28c816141dd27fc888';PS_parse_errors=0;pure_AST_fixture_count=$rows.Count;pure_AST_fixtures=$rows.ToArray();pinned_ref_pairs=$refRows;original_diagnostic_flags=$diagRows;declared_15_changes_exact=$true;V1_suite_before_CleanReceipt_blocker_fixed=$true;selected_pure_guards_only=$true;helper_body_executed=$false;Finalize_invoked=$false;FinalizeStandalone_invoked=$false;Linux_models_accounts_UI_processes_started=$false;application_or_frozen_helpers_modified=$false;admission_records_published=$false;eight_hour_started=$false;scope_note='Readonly ValidatePreparedInputs verifies common source/backend/canonical/runtime/candidate only. Five actual functional raw checks remain after later formal UI gate; this peer is not a test rerun or release qualification.';created_utc=[DateTime]::UtcNow.ToString('o')}
$out=Join-Path $workspace 'evidence/post-ui-admission-v2-independent-peer-20261109.json'
Assert (-not(Test-Path -LiteralPath $out)) 'Peer output already exists'
[IO.File]::WriteAllText($out,($report|ConvertTo-Json -Depth 15),[Text.UTF8Encoding]::new($false))
[ordered]@{status='passed';fixtures=$rows.Count;reference_pairs=$refRows.Count;original_diagnostic_flag_sets=$diagRows.Count;peer=$out;sha256=(Get-FileHash -LiteralPath $out).Hash.ToLowerInvariant()}|ConvertTo-Json
