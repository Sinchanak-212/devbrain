[CmdletBinding()]
param()
# One Windows-only snapshot. Progress is informational, never a qualification.
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
function Read-SharedSnapshot([string]$Path,[int]$Limit=16777216){
 $stream=$null
 try{
  $stream=[IO.FileStream]::new($Path,[IO.FileMode]::Open,[IO.FileAccess]::Read,([IO.FileShare]::ReadWrite -bor [IO.FileShare]::Delete))
  $length=$stream.Length
  if($length -gt $Limit){throw "Snapshot exceeds bounded reader limit: $([IO.Path]::GetFileName($Path))"}
  $buffer=[byte[]]::new([int]$length);$offset=0
  while($offset -lt $length){$read=$stream.Read($buffer,$offset,[int]$length-$offset);if($read -eq 0){break};$offset+=$read}
  return @{text=[Text.Encoding]::UTF8.GetString($buffer,0,$offset);bytes=$offset;truncated_during_read=($offset -lt $length)}
 }catch [IO.FileNotFoundException]{return $null
 }catch [IO.DirectoryNotFoundException]{return $null
 }finally{if($null -ne $stream){$stream.Dispose()}}
}
function Read-SharedJson([string]$Path){
 $snap=Read-SharedSnapshot $Path
 if($null -eq $snap){return $null}
 if($snap.truncated_during_read){throw "JSON changed while reading: $([IO.Path]::GetFileName($Path))"}
 return ($snap.text|ConvertFrom-Json -AsHashtable -DateKind String)
}
$contextPath=Join-Path $PSScriptRoot '080-fullbackend-length-repair-active-context-20261108.json'
$context=Read-SharedJson $contextPath
if($null -eq $context -or $context.run_id -cne 'fullbackend-length-repair080-20261108T204439Z-b2a1ac34' -or $context.source_freeze_sha256 -cne '1f35dae9f2b3f894bb67535a215e29cba3c1235120ff30daa387bd5450f03e14'){throw 'Unexpected backend context'}
if($context.specification_sha256 -cne '7a8c3c16e7ec3238e19e95edc637819f3e2597017cf5d03e422f6cde58138e45'){throw 'Unexpected whole-suite specification'}
$root=$context.artifact_root
$collection=Read-SharedJson (Join-Path $root 'collection.json')
$nodeids=@()
if($null -ne $collection){
 if($collection.run_id -cne $context.run_id -or $collection.full_test_directory -cne 'tests' -or @($collection.collection_errors).Count -ne 0 -or @($collection.deselected).Count -ne 0){throw 'Collection is incomplete or filtered'}
 $nodeids=@($collection.nodeids)
 if($nodeids.Count -ne 1557 -or @($nodeids|Sort-Object -Unique).Count -ne 1557){throw 'Expected complete unique1557 collection'}
}
$log=Read-SharedSnapshot (Join-Path $root 'test.log')
$symbols=''
if($null -ne $log){
 foreach($line in ($log.text -split "`r?`n")){
  # Only pytest progress lines. Never emit raw test output or assertion locals.
  if($line -cmatch '^\s*([.FEfsxX]{2,})(?:\s+\[\s*[0-9]+%\])?\s*$'){$symbols+=$Matches[1]}
 }
}
$failures=@()
for($i=0;$i -lt $symbols.Length;$i++){
 if($symbols[$i] -ceq 'F' -or $symbols[$i] -ceq 'E'){
  $node=if($i -lt $nodeids.Count){$nodeids[$i]}else{$null}
  $failures+=@{index_one_based=$i+1;symbol=[string]$symbols[$i];nodeid_hint=$node}
 }
}
$junit=$null
$xmlSnapshot=Read-SharedSnapshot (Join-Path $root 'pytest.xml')
if($null -ne $xmlSnapshot){
 try{
  $xml=[Xml.XmlDocument]::new();$xml.XmlResolver=$null;$xml.LoadXml($xmlSnapshot.text)
  $suites=@($xml.SelectNodes('//testsuite'));$tests=0;$failed=0;$errors=0;$skipped=0
  foreach($suite in $suites){$tests+=[int]$suite.GetAttribute('tests');$failed+=[int]$suite.GetAttribute('failures');$errors+=[int]$suite.GetAttribute('errors');$skipped+=[int]$suite.GetAttribute('skipped')}
  $junit=@{present=$true;parse_complete=$true;tests=$tests;failures=$failed;errors=$errors;skipped=$skipped;testcase_count=@($xml.SelectNodes('//testcase')).Count}
 }catch [Xml.XmlException]{$junit=@{present=$true;parse_complete=$false}}
}
$controller=Read-SharedJson (Join-Path $root 'controller-report.json')
$receipt=Read-SharedJson (Join-Path $root 'receipt.json')
$nextHint=if($symbols.Length -lt $nodeids.Count){$nodeids[$symbols.Length]}else{$null}
@{
 schema_version=1;scope='informational_backend_progress_only';run_id=$context.run_id;context_status=$context.status
 expected_collection=1557;observed_collection=$nodeids.Count;whole_collection_observed=($nodeids.Count -eq 1557)
 observed_progress_symbols=$symbols.Length;progress_failure_hints=$failures;next_nodeid_hint=$nextHint
 progress_buffering_may_lag=$true;progress_hints_are_not_test_verdicts=$true;junit=$junit
 controller_status=$(if($null -ne $controller){$controller.status}else{$null})
 receipt_present=($null -ne $receipt);receipt_passed=$(if($null -ne $receipt){$receipt.passed}else{$null})
 actual_windows_exit_code=$context.actual_windows_exit_code;qualification_inferred=$false;linux_started=$false;files_written=$false
}|ConvertTo-Json -Depth 8
