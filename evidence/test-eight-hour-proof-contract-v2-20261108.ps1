#Requires -Version 7.5
# Synthetic Windows-only evaluation of the reviewed stager's exact predicates.
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$path=Join-Path $PSScriptRoot 'stage-final-eight-hour-length-repair-604-v2-20261108.ps1'
if((Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()-cne'5a94acfd267fcdfaf92a91f174fcd5589e46366db242e9e39a539aebe635a7a0'){throw 'Wrong stager'}
$tokens=$null;$errors=$null;$ast=[Management.Automation.Language.Parser]::ParseFile($path,[ref]$tokens,[ref]$errors)
if($errors.Count){throw 'Invalid syntax'}
function Extract-One([scriptblock]$Predicate){$nodes=@($ast.FindAll($Predicate,$true));if($nodes.Count-ne1){throw 'Ambiguous source predicate'};return [scriptblock]::Create($nodes[0].Extent.Text)}
function Require([bool]$Good,[string]$Message){if(-not$Good){throw $Message}}
$statusBlock=Extract-One {param($n)$n-is[Management.Automation.Language.AssignmentStatementAst]-and$n.Left.Extent.Text-ceq'$finalStatus'}
$gateBlock=Extract-One {param($n)$n-is[Management.Automation.Language.CommandAst]-and$n.GetCommandName()-ceq'Require'-and$n.Extent.Text.Contains('Final process handoff missing:')}
$processBlock=Extract-One {param($n)$n-is[Management.Automation.Language.CommandAst]-and$n.GetCommandName()-ceq'Require'-and$n.Extent.Text.Contains('Standalone final process report incomplete')}
$identityBlock=Extract-One {param($n)$n-is[Management.Automation.Language.CommandAst]-and$n.GetCommandName()-ceq'Require'-and$n.Extent.Text.Contains('Standalone final report identity differs')}
$script:cases=0
function Expect([string]$Label,[bool]$Pass,[scriptblock]$Body){$ok=$true;try{&$Body}catch{$ok=$false};if($ok-ne$Pass){throw "Unexpected verdict: $Label"};$script:cases++}
function Check-Gate([string]$Name,[string]$Status,[hashtable]$Change=@{}){
 $final=@{status=$Status;run_id='run-1';actual_windows_exit_code=0;actual_windows_exec_session=123;cleanup_complete=$true;receipt_sha256='receipt-1'}
 foreach($key in $Change.Keys){$final[$key]=$Change[$key]}
 $c=@{run_id='run-1'};$Entry=@{receipt_sha256='receipt-1'}
 . $statusBlock
 & $gateBlock
}
Expect 'queue truthful focused verdict' $true {Check-Gate 'queue_copy' 'passed_focused_queue_copy_only'}
Expect 'queue relabelled generic verdict refused' $false {Check-Gate 'queue_copy' 'passed'}
Expect 'queue failure refused' $false {Check-Gate 'queue_copy' 'failed'}
Expect 'ordinary gate generic pass retained' $true {Check-Gate 'ux' 'passed'}
Expect 'focused status cannot qualify UX' $false {Check-Gate 'ux' 'passed_focused_queue_copy_only'}
Expect 'nonzero actual exit refused' $false {Check-Gate 'queue_copy' 'passed_focused_queue_copy_only' @{actual_windows_exit_code=1}}
Expect 'incomplete cleanup refused' $false {Check-Gate 'queue_copy' 'passed_focused_queue_copy_only' @{cleanup_complete=$false}}
Expect 'wrong receipt refused' $false {Check-Gate 'queue_copy' 'passed_focused_queue_copy_only' @{receipt_sha256='other'}}
Expect 'wrong run refused' $false {Check-Gate 'queue_copy' 'passed_focused_queue_copy_only' @{run_id='other'}}
function Check-Standalone([hashtable]$Change=@{}){
 $standaloneFinal=@{schema_version=1;status='passed';passed=$true;full_suite_attestation_passed=$true;actual_root_session=4727;actual_exit_code=0;cleanup_complete=$true;context_sha256='envelope-1';backend_context_sha256='backend-1';backend_receipt_sha256='receipt-1';source_freeze_sha256='source-1';canonical='C:\synthetic\backend\final-full-suite.json';canonical_sha256='attestation-1';observation_sha256='observation-1'}
 foreach($key in $Change.Keys){$standaloneFinal[$key]=$Change[$key]}
 $envelope=@{actual_windows_exec_session=4727};$AttestationContextSha256='envelope-1';$backendEntry=@{context_sha256='backend-1'};$receiptSHA='receipt-1';$master=@{source_freeze_sha256='source-1'};$attestationPath='C:\synthetic\backend\final-full-suite.json';$AttestationSha256='attestation-1';$ObservationSha256='observation-1'
 & $processBlock
 & $identityBlock
}
Expect 'separate exact standalone report accepted' $true {Check-Standalone}
foreach($change in @(@{schema_version=2},@{status='failed'},@{passed=$false},@{full_suite_attestation_passed=$false},@{actual_root_session=999},@{actual_exit_code=1},@{cleanup_complete=$false},@{context_sha256='other'},@{backend_context_sha256='other'},@{backend_receipt_sha256='other'},@{source_freeze_sha256='other'},@{canonical='C:\synthetic\other\final-full-suite.json'},@{canonical_sha256='other'},@{observation_sha256='other'})){
 Expect ('standalone tamper '+@($change.Keys)[0]) $false {Check-Standalone $change}
}
[ordered]@{scope='windows_synthetic_metadata_contract_only';passed=$true;cases=$script:cases;stage_executed=$false;linux_executed=$false;filesystem_mutated_by_test=$false}|ConvertTo-Json
