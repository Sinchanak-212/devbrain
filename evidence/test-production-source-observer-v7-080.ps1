# Windows-only synthetic validation of the exact output verifier. No observer main, WSL, Python, source read or process launch.
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$scriptPath=Join-Path (Split-Path $PSScriptRoot -Parent) 'release-tools/run-source-preflight080-v7.ps1'
if((Get-FileHash -LiteralPath $scriptPath -Algorithm SHA256).Hash.ToLowerInvariant()-cne'f03ddf073f85636c3fc5ac53d892f695ec761f5674117c3b8d98afbdd3a819be'){throw 'Observer changed'}
$t=$null;$e=$null;$a=[Management.Automation.Language.Parser]::ParseFile($scriptPath,[ref]$t,[ref]$e)
if($e.Count){throw 'Observer syntax invalid'}
$n=@($a.FindAll({param($x)$x-is[Management.Automation.Language.FunctionDefinitionAst]-and$x.Name-ceq'Verify-Outputs'},$true));if($n.Count-ne1){throw 'Expected one real verifier'}
. ([scriptblock]::Create($n[0].Extent.Text))
function Assert-PlainPath([string]$Path){return $Path}
function Read-Json([string]$Path){return $script:syntheticResult}
function Get-Sha([string]$Path){return ('a'*64)}
function Reset-Synthetic([string]$Mode='baseline072'){
 $count=182;$package=64;$zip='6b65e7315895b8c44b84bafc9146dfcdae732c3890f959d0e5e58cbf4fd9aa2c'
 if($Mode-ceq'target080'){$count=198;$package=69;$zip='4fb8b1203dfce52eb5bfd094b2649899316e09ada64cbd2dc14e1bb8de071508'}
 $script:plan=@{mode=$Mode;canonical_output='synthetic/source-comparison.json';expected_file_count=$count;expected_package_file_count=$package;release_zip_sha256=$zip}
 $script:report=@{comparison_validated=$false;output_sha256=@{}}
 $script:syntheticResult=@{schema_version=1;scope='devbrain_readonly_release_source_comparison';status='matched_pending_external_observation';mode=$Mode;production_modified=$false;app_imported=$false;services_or_models_started=$false;source_contents_or_actual_digests_published=$false;deployment_authorized=$false;external_actual_exit_observation_required=$true;point_in_time_only=$true;expected_file_count=$count;expected_package_file_count=$package;expected_release_zip_sha256=$zip;comparison=@{missing=0;modified=0;unexpected=0;ignored_subtrees=2;ignored_bytecode=0;entries=($count+20);matched=$count};two_pass_identity_stable=$true;comparison_passed=$true;elapsed_seconds=1.25}
}
$done=[Collections.Generic.List[string]]::new()
foreach($mode in @('baseline072','target080')){Reset-Synthetic $mode;Verify-Outputs;if(-not$report.comparison_validated){throw 'Complete synthetic comparison refused'};$done.Add("match-$mode")}
$rejects=[ordered]@{
 'wrong-total'={$syntheticResult.expected_file_count=181};'wrong-package'={$syntheticResult.expected_package_file_count=63};'wrong-mode'={$syntheticResult.mode='target080'}
 'wrong-zip'={$syntheticResult.expected_release_zip_sha256='b'*64};'missing'={$syntheticResult.comparison.missing=1};'modified'={$syntheticResult.comparison.modified=1};'extra'={$syntheticResult.comparison.unexpected=1}
 'short-match'={$syntheticResult.comparison.matched=181};'string-count'={$syntheticResult.comparison.matched='182'};'negative'={$syntheticResult.comparison.ignored_bytecode=-1}
 'extra-private-field'={$syntheticResult['actual_source_hashes']=@{}};'extra-private-count-field'={$syntheticResult.comparison['private_filename']='should-never-pass'}
 'source-write'={$syntheticResult.production_modified=$true};'app-import'={$syntheticResult.app_imported=$true};'service-start'={$syntheticResult.services_or_models_started=$true}
 'private-digests'={$syntheticResult.source_contents_or_actual_digests_published=$true};'claims-deploy'={$syntheticResult.deployment_authorized=$true};'claims-no-observer'={$syntheticResult.external_actual_exit_observation_required=$false}
 'claims-not-point-in-time'={$syntheticResult.point_in_time_only=$false};'unstable-passes'={$syntheticResult.two_pass_identity_stable=$false};'not-matched'={$syntheticResult.comparison_passed=$false}
 'nan-elapsed'={$syntheticResult.elapsed_seconds=[double]::NaN};'infinite-elapsed'={$syntheticResult.elapsed_seconds=[double]::PositiveInfinity};'too-long'={$syntheticResult.elapsed_seconds=61}
 'string-false'={$syntheticResult.production_modified='false'};'string-true'={$syntheticResult.comparison_passed='true'}
 'failed-status'={$syntheticResult.status='failed'}
}
foreach($name in $rejects.Keys){Reset-Synthetic;. $rejects[$name];$refused=$false;try{Verify-Outputs}catch{$refused=$true};if(-not$refused-or$report.comparison_validated){throw "Unexpected synthetic admission: $name"};$done.Add($name)}
@{scope='windows_synthetic_source_output_verifier';passed=$true;cases=$done.Count;case_names=@($done);observer_sha256='f03ddf073f85636c3fc5ac53d892f695ec761f5674117c3b8d98afbdd3a819be';linux_started=$false;production_read=$false;observer_main_executed=$false;stage_executed=$false}|ConvertTo-Json -Depth 4
