#Requires -Version 7.5
[CmdletBinding()]
param([Parameter(Mandatory)][string]$Context,[Parameter(Mandatory)][string]$ExpectedRunId,[Parameter(Mandatory)][string]$Opener,[Parameter(Mandatory)][string]$OpenerSha256,[switch]$Execute)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
function Plain([string]$p){$v=[IO.Path]::GetFullPath($p);if($v-cnotmatch'^[Cc]:\\'-or$p.Contains([char]0)){throw 'Absolute C path required'};$full=$v;while($v){if((Test-Path -LiteralPath $v)-and((Get-Item -LiteralPath $v -Force).Attributes-band[IO.FileAttributes]::ReparsePoint)){throw 'Reparse path refused'};$v=[IO.Path]::GetDirectoryName($v)};return $full}
function ReadMap([string]$p){$stream=[IO.FileStream]::new((Plain $p),[IO.FileMode]::Open,[IO.FileAccess]::Read,([IO.FileShare]::ReadWrite-bor[IO.FileShare]::Delete));try{if($stream.Length-gt1MB){throw 'Oversize JSON'};$reader=[IO.StreamReader]::new($stream,[Text.UTF8Encoding]::new($false,$true),$true,4096,$true);try{return ($reader.ReadToEnd()|ConvertFrom-Json -AsHashtable)}finally{$reader.Dispose()}}finally{$stream.Dispose()}}
function Hash([string]$p){(Get-FileHash -LiteralPath (Plain $p)).Hash.ToLowerInvariant()}
function WriteNew([string]$p,$value){$p=Plain $p;$tmp=$p+'.'+[Guid]::NewGuid().ToString('N')+'.tmp';$bytes=[Text.UTF8Encoding]::new($false).GetBytes(($value|ConvertTo-Json -Depth 12));$stream=[IO.FileStream]::new($tmp,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None);try{$stream.Write($bytes,0,$bytes.Length);$stream.Flush($true)}finally{$stream.Dispose()};try{[IO.File]::Move($tmp,$p,$false)}finally{if(Test-Path -LiteralPath $tmp){Remove-Item -LiteralPath $tmp}}}
if($ExpectedRunId-cnotmatch'^terminal-probe080-[0-9TZ]+-[0-9a-f]{8}$'-or$OpenerSha256-cnotmatch'^[0-9a-f]{64}$'){throw 'Explicit frozen run and opener required'}
$contextPath=Plain $Context
$openerPath=Plain $Opener
if((Hash $openerPath)-cne$OpenerSha256){throw 'Opener changed'}
$initial=ReadMap $contextPath
if($initial.run_id-cne$ExpectedRunId-or$initial.scope-cne'devbrain_no_model_terminal_probe'-or$initial.no_model-ne$true-or$initial.model_requests-ne0-or$initial.account_operations-ne0-or$initial.release_qualified-ne$false-or$initial.eight_hour_test_included-ne$false-or$initial.status-cnotin@('prepared_not_run','running')){throw 'Only fresh bounded no-model probe supported'}
$root=Plain $initial.artifact_root
if([IO.Path]::GetDirectoryName($root)-cne(Plain $initial.windows_root)){throw 'Artifact scope mismatch'}
$package=Get-AppxPackage -Name Microsoft.WindowsTerminal
if(@($package).Count-ne1){throw 'Unique installed Windows Terminal required'}
$terminalPath=Plain (Join-Path $package.InstallLocation 'WindowsTerminal.exe')
$wt=Plain (Join-Path $package.InstallLocation 'wt.exe')
if(-not(Test-Path -LiteralPath $terminalPath -PathType Leaf)-or-not(Test-Path -LiteralPath $wt -PathType Leaf)){throw 'Installed Windows Terminal files absent'}
if(-not$Execute){@{status='prepared_not_run';scope='windows_terminal_metadata_observer';run_id=$ExpectedRunId;observes_only_windows_metadata=$true;sends_keyboard_input=$false;captures_screenshot=$false;starts_linux_controller=$false;model_requests=0;account_operations=0}|ConvertTo-Json;return}
$deadline=[Diagnostics.Stopwatch]::StartNew()
$confirmed=@{}
while($confirmed.Count-lt2){
 if($deadline.Elapsed.TotalSeconds-gt150){throw 'Windows renderer observer timed out'}
 $c=ReadMap $contextPath
 if($c.run_id-cne$ExpectedRunId-or$c.controller_sha256-cne$initial.controller_sha256-or$c.source_freeze_sha256-cne$initial.source_freeze_sha256-or$c.artifact_root-cne$root){throw 'Probe binding changed'}
 if($c.status-eq'prepared_not_run'){Start-Sleep -Milliseconds 100;continue}
 if($c.status-cne'running'){throw 'Probe stopped before both renderer confirmations'}
 $controllerReport=Join-Path $root 'controller-report.json'
 if((Test-Path -LiteralPath $controllerReport)-and(ReadMap $controllerReport).status-eq'failed'){throw 'Controller already failed; stale ready refused'}
 $readyPath=Join-Path $root 'ready.json'
 if(-not(Test-Path -LiteralPath $readyPath)){Start-Sleep -Milliseconds 50;continue}
 $ready=ReadMap $readyPath
 if($ready.run_id-cne$ExpectedRunId-or$ready.arm-cnotin@('direct','bridge')-or$ready.status-cne'awaiting_windows_renderer'-or$ready.nonce-cnotmatch'^[0-9a-f]{64}$'-or$ready.expires_unix_time-le[DateTimeOffset]::UtcNow.ToUnixTimeSeconds()){throw 'Current ready proof invalid'}
 $arm=$ready.arm
 if($confirmed.ContainsKey($arm)){Start-Sleep -Milliseconds 50;continue}
 $launchPath=Join-Path $root ('windows-renderer-launch-'+$arm+'.json')
 if(-not(Test-Path -LiteralPath $launchPath)){
  if((Hash $openerPath)-cne$OpenerSha256){throw 'Frozen opener changed'}
  $contextHash=Hash $contextPath
  & $openerPath -Context $contextPath -ContextSha256 $contextHash -WindowsTerminal $wt -Execute |Out-Null
 }
 $launch=ReadMap $launchPath
 $externalPath=Join-Path $root ('external-viewer-'+$arm+'.json')
 if(-not(Test-Path -LiteralPath $externalPath)){Start-Sleep -Milliseconds 50;continue}
 $external=ReadMap $externalPath
 if($launch.run_id-cne$ExpectedRunId-or$external.run_id-cne$ExpectedRunId-or$launch.arm-cne$arm-or$external.arm-cne$arm-or$launch.nonce-cne$ready.nonce-or$external.nonce-cne$ready.nonce-or$external.pidfd_admitted-isnot[bool]-or$external.pidfd_admitted-ne$true-or($external.viewer_pid-isnot[long]-and$external.viewer_pid-isnot[int])-or$external.viewer_pid-le0-or$external.viewer_birth-isnot[string]-or$external.viewer_birth-cnotmatch'^[1-9][0-9]*$'){throw 'Admitted renderer binding mismatch'}
 $windows=@(Get-Process -Name WindowsTerminal -ErrorAction SilentlyContinue|Where-Object {$_.MainWindowHandle-ne0-and$_.MainWindowTitle-ceq$launch.title-and$_.Path-ceq$terminalPath})
 if($windows.Count-ne1){Start-Sleep -Milliseconds 50;continue}
 $window=$windows[0]
 $birth=$window.StartTime.ToUniversalTime().ToFileTimeUtc()
 $window.Refresh()
 if($window.HasExited-or$window.MainWindowTitle-cne$launch.title-or$window.Path-cne$terminalPath-or$window.StartTime.ToUniversalTime().ToFileTimeUtc()-ne$birth){throw 'Windows Terminal identity changed'}
 # Actual installed WT window and its admitted Linux renderer are now observed.
 # The controller independently checks the one writable 120x40 client before queries.
 $confirmation=@{schema_version=1;run_id=$ExpectedRunId;arm=$arm;nonce=$ready.nonce;actual_windows_terminal=$true;viewer_pid=$external.viewer_pid;viewer_birth=$external.viewer_birth;observation_kind='installed_WindowsTerminal_process_window_and_pidfd_admission_metadata';screenshot_observed=$false;keyboard_input_sent=$false;windows_pid=$window.Id;windows_birth_filetime_utc=$birth;windows_window_handle=$window.MainWindowHandle.ToInt64();windows_title=$window.MainWindowTitle;windows_executable=$window.Path;created_utc=[DateTimeOffset]::UtcNow.ToString('o');model_requests=0;account_operations=0}
 WriteNew (Join-Path $root ('terminal-renderer-'+$arm+'.json')) $confirmation
 $confirmed[$arm]=$true
 @{run_id=$ExpectedRunId;arm=$arm;actual_windows_terminal=$true;observation_kind=$confirmation.observation_kind;windows_pid=$window.Id;model_requests=0;account_operations=0}|ConvertTo-Json -Compress
}
@{status='two_actual_Windows_renderer_metadata_confirmations_written';run_id=$ExpectedRunId;arms=@('direct','bridge');elapsed_seconds=$deadline.Elapsed.TotalSeconds;no_keyboard_input=$true;no_screenshot_claim=$true;model_requests=0;account_operations=0;controller_cleanup_not_inferred=$true}|ConvertTo-Json
