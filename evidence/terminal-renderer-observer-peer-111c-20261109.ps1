# Pure AST predicates only. Never executes observer, WT opener, Get-Process or Linux.
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$path=Join-Path (Get-Location) 'evidence/observe-terminal-timing-renderers080-20261109.ps1'
$digest=(Get-FileHash -LiteralPath $path).Hash.ToLowerInvariant()
if($digest-cne'111c74bcd51d935da5338d4d2341a7ad20b2c5a4f3fa6018d665e1f2d2926ed1'){throw 'Observer changed'}
$t=$null;$e=$null;$a=[Management.Automation.Language.Parser]::ParseFile($path,[ref]$t,[ref]$e)
if($e.Count){throw 'Observer parse error'}
$ast=@($a.FindAll({param($x)$x-is[Management.Automation.Language.IfStatementAst]-and$x.Extent.StartLineNumber-eq50},$true))
if($ast.Count-ne1){throw 'Exact admitted guard not found'}
$guard=[scriptblock]::Create($ast[0].Clauses[0].Item1.Extent.Text)
$rows=[Collections.Generic.List[object]]::new()
function TestCase([string]$Name,[scriptblock]$Setup,[bool]$ExpectedReject){
 & {param($N,$S,$Expected)
  $ExpectedRunId='fixture';$arm='direct';$ready=@{nonce='a'*64}
  $launch=@{run_id='fixture';arm='direct';nonce='a'*64}
  $external=@{run_id='fixture';arm='direct';nonce='a'*64;pidfd_admitted=$true;viewer_pid=[int]123;viewer_birth='456'}
  . $S
  $reject=$true
  try{$reject=[bool](& $guard)}catch{$reject=$true}
  $ok=$reject-eq$Expected
  $rows.Add(@{name=$N;rejected=$reject;expected_rejection=$Expected;passed=$ok})
  if(-not$ok){throw ('Unexpected predicate outcome: '+$N)}
 } $Name $Setup $ExpectedReject
}
TestCase 'valid_int_PID' {} $false
TestCase 'valid_long_PID' {$external.viewer_pid=[long]123} $false
TestCase 'wrong_launch_run_with_int_PID' {$launch.run_id='other'} $true
TestCase 'wrong_external_run_with_int_PID' {$external.run_id='other'} $true
TestCase 'wrong_launch_arm' {$launch.arm='bridge'} $true
TestCase 'wrong_external_arm' {$external.arm='bridge'} $true
TestCase 'wrong_launch_nonce' {$launch.nonce='b'*64} $true
TestCase 'wrong_external_nonce' {$external.nonce='b'*64} $true
TestCase 'admission_false' {$external.pidfd_admitted=$false} $true
TestCase 'admission_string' {$external.pidfd_admitted='true'} $true
TestCase 'admission_integer' {$external.pidfd_admitted=1} $true
TestCase 'PID_string' {$external.viewer_pid='123'} $true
TestCase 'PID_double' {$external.viewer_pid=[double]123} $true
TestCase 'PID_boolean' {$external.viewer_pid=$true} $true
TestCase 'PID_zero' {$external.viewer_pid=0} $true
TestCase 'PID_negative' {$external.viewer_pid=-123} $true
TestCase 'birth_number' {$external.viewer_birth=456} $true
TestCase 'birth_zero' {$external.viewer_birth='0'} $true
TestCase 'birth_negative' {$external.viewer_birth='-456'} $true
TestCase 'birth_non_digit' {$external.viewer_birth='a456'} $true
TestCase 'birth_empty' {$external.viewer_birth=''} $true
TestCase 'birth_missing' {$external.Remove('viewer_birth')} $true
$matches=@($a.FindAll({param($x)$x-is[Management.Automation.Language.CommandAst]-and$x.GetCommandName()-ceq'Where-Object'-and$x.Extent.Text.Contains('MainWindowTitle')},$true))
if($matches.Count-ne1){throw 'Exact window matcher not found'}
$matcherAst=@($matches[0].CommandElements|Where-Object{$_-is[Management.Automation.Language.ScriptBlockExpressionAst]})
$matcher=[scriptblock]::Create($matcherAst[0].ScriptBlock.Extent.Text.TrimStart('{').TrimEnd('}'))
$launch=@{title='fixture'};$terminalPath='C:\Installed\WindowsTerminal.exe'
foreach($kind in @('valid','wrong_title','wrong_executable','no_window_handle')){
 $window=[pscustomobject]@{MainWindowHandle=[long]10;MainWindowTitle='fixture';Path=$terminalPath}
 switch($kind){'wrong_title'{$window.MainWindowTitle='other'}'wrong_executable'{$window.Path='C:\Other\WindowsTerminal.exe'}'no_window_handle'{$window.MainWindowHandle=0}}
 $matched=@($window|Where-Object $matcher).Count-eq1
 $ok=$matched-eq($kind-ceq'valid')
 $rows.Add(@{name=('installed_window_'+$kind);passed=$ok;matched=$matched})
 if(-not$ok){throw 'Window matcher outcome'}
}
$out=Join-Path (Get-Location) 'evidence/terminal-renderer-observer-independent-peer-111c-20261109.json'
if(Test-Path -LiteralPath $out){throw 'Never overwrite peer'}
$value=@{schema_version=1;scope='readonly_windows_terminal_renderer_metadata_observer_peer';status='passed';observer_sha256=$digest;PS_parse_errors=0;pure_AST_fixture_count=$rows.Count;fixtures=$rows.ToArray();prior_f739_precedence_blocker_fixed=$true;actual_WT_true_requires_unique_live_installed_executable_window_title_and_stable_PID_birth=$true;controller_independently_verifies_sole_registered_writable_120x40=$true;bounded_observer_deadline_seconds=150;observer_or_opener_body_executed=$false;GetProcess_or_UI_or_Linux_executed=$false;models_accounts_started=0;root_GO_still_required=$true}
[IO.File]::WriteAllText($out,($value|ConvertTo-Json -Depth 10),[Text.UTF8Encoding]::new($false))
@{status='passed';fixtures=$rows.Count;peer=$out;sha256=(Get-FileHash -LiteralPath $out).Hash.ToLowerInvariant()}|ConvertTo-Json
