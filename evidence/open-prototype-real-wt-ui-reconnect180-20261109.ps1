#Requires -Version 7.5
[CmdletBinding()]
param([switch]$Execute)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$handoffPath=Join-Path $PSScriptRoot '080-prototype-real-wt-ui-prepared-handoff-20261109.json'
if((Get-FileHash -LiteralPath $handoffPath).Hash.ToLowerInvariant()-cne'49e9371d902b684f7a86a009efe0525570acfaf2de022d02811c30868ba8a1a6'){throw 'Prepared UI handoff changed'}
function ReadMap([string]$p){$s=[IO.FileStream]::new($p,[IO.FileMode]::Open,[IO.FileAccess]::Read,([IO.FileShare]::ReadWrite-bor[IO.FileShare]::Delete));try{if($s.Length-gt1MB){throw 'Oversize JSON'};$r=[IO.StreamReader]::new($s,[Text.UTF8Encoding]::new($false,$true),$true,4096,$true);try{return($r.ReadToEnd()|ConvertFrom-Json -AsHashtable)}finally{$r.Dispose()}}finally{$s.Dispose()}}
$h=ReadMap $handoffPath
$c=ReadMap $h.physical_active_context
if($c.run_id-cne$h.run_id-or$c.source_freeze_sha256-cne$h.source_freeze_sha256-or$c.helper_sha256.Count-ne38-or$c.application_qualified-ne$false-or$c.release_qualified-ne$false){throw 'Prototype UI context differs'}
if((Get-FileHash -LiteralPath $h.frozen_viewer_windows).Hash.ToLowerInvariant()-cne$h.frozen_viewer_sha256){throw 'Actual registered viewer source changed'}
if(-not(Test-Path -LiteralPath $h.ready_file)){throw 'Live UI is not ready'}
$ready=ReadMap $h.ready_file
if($ready.run_id-cne$h.run_id-or$ready.operator-cne'agent'-or$ready.controller-cne$c.controller-or$ready.python_launcher-cne$c.python_launcher-or$ready.sizes-cnotcontains'180x55'-or$ready.expires_unix_time-le[DateTimeOffset]::UtcNow.ToUnixTimeSeconds()){throw 'Live UI readiness mismatch'}
if($ready.manifest-isnot[string]-or-not$ready.manifest.StartsWith('/home/piotr/.cache/devbrain-regressions-080/',[StringComparison]::Ordinal)-or$ready.manifest-match'[;\r\n\x00]'){throw 'Canonical private manifest required'}
$package=Get-AppxPackage -Name Microsoft.WindowsTerminal
if(@($package).Count-ne1){throw 'Unique installed Windows Terminal required'}
$wt=Join-Path $package.InstallLocation 'wt.exe'
$terminal=Join-Path $package.InstallLocation 'WindowsTerminal.exe'
$argsList=@($h.WindowsTerminal_launch.arguments)
$placeholders=@(0..($argsList.Count-1)|Where-Object{$argsList[$_]-ceq'READ_LIVE_INTERACTIVE_READY.manifest'})
if($placeholders.Count-ne1){throw 'Exactly one live manifest placeholder required'}
$argsList[$placeholders[0]]=$ready.manifest
for($k=0;$k-lt$argsList.Count;$k++){
 if($argsList[$k]-ceq'120,36'){$argsList[$k]='180,55'}
 elseif($argsList[$k]-ceq'DevBrain UX 120x36'){$argsList[$k]='DevBrain UX 180x55'}
 elseif($argsList[$k]-ceq'120x36'){$argsList[$k]='180x55'}
}
if(-not$Execute){@{status='prepared_not_run';run_id=$c.run_id;ready=$true;viewer_sha256=$h.frozen_viewer_sha256;keyboard_input_sent=$false}|ConvertTo-Json;return}
if($c.status-cnotin@('running','running_diagnostic')){throw 'UI controller must already be running'}
$recordPath=Join-Path $c.artifact_root 'root-real-wt-reconnect-180x55-launch.json'
if(Test-Path -LiteralPath $recordPath){throw 'Root already launched this UI viewer'}
$info=[Diagnostics.ProcessStartInfo]::new()
$info.FileName=$wt;$info.UseShellExecute=$false;$info.WindowStyle=[Diagnostics.ProcessWindowStyle]::Normal
foreach($arg in $argsList){$info.ArgumentList.Add([string]$arg)}
$process=[Diagnostics.Process]::Start($info)
try{
 $record=@{schema_version=1;scope='prototype_real_WT_root_launch';run_id=$c.run_id;viewer_sha256=$h.frozen_viewer_sha256;launch_pid=$process.Id;launch_birth_utc=$process.StartTime.ToUniversalTime().ToString('o');actual_windows_terminal_confirmed=$false;keyboard_input_sent=$false;screenshot_claim=$false;created_utc=[DateTimeOffset]::UtcNow.ToString('o');title='DevBrain UX 180x55'}
 [IO.File]::WriteAllText($recordPath,($record|ConvertTo-Json -Depth 6),[Text.UTF8Encoding]::new($false))
}finally{$process.Dispose()}
$watch=[Diagnostics.Stopwatch]::StartNew()
while($watch.Elapsed.TotalSeconds-lt10){
 $windows=@(Get-Process -Name WindowsTerminal -ErrorAction SilentlyContinue|Where-Object{$_.MainWindowHandle-ne0-and$_.MainWindowTitle-ceq'DevBrain UX 180x55'-and$_.Path-ceq$terminal})
 if($windows.Count-eq1){
  $w=$windows[0];$birth=$w.StartTime.ToUniversalTime().ToFileTimeUtc();$w.Refresh()
  if(-not$w.HasExited-and$w.StartTime.ToUniversalTime().ToFileTimeUtc()-eq$birth-and$w.MainWindowTitle-ceq'DevBrain UX 180x55'){
   $record.actual_windows_terminal_confirmed=$true;$record.windows_pid=$w.Id;$record.windows_birth_filetime_utc=$birth;$record.window_handle=$w.MainWindowHandle.ToInt64();$record.windows_executable=$w.Path;$record.observation_kind='actual_installed_WT_process_window_metadata_only';[IO.File]::WriteAllText($recordPath,($record|ConvertTo-Json -Depth 6),[Text.UTF8Encoding]::new($false))
   @{run_id=$c.run_id;actual_Windows_Terminal=$true;windows_pid=$w.Id;title=$w.MainWindowTitle;keyboard_input_sent=$false;actual_sole_Linux_writer_not_yet_verified=$true}|ConvertTo-Json;return
  }
 }
 Start-Sleep -Milliseconds 50
}
throw 'Actual installed WT window metadata not confirmed; do not Start'
