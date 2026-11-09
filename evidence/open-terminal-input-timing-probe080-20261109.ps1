#Requires -Version 7.5
[CmdletBinding()]
param([Parameter(Mandatory)][string]$Context,[Parameter(Mandatory)][string]$ContextSha256,[Parameter(Mandatory)][string]$WindowsTerminal,[switch]$Execute)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
function Plain([string]$p){$full=[IO.Path]::GetFullPath($p);if($full-cnotmatch'^[Cc]:\\'-or$p.Contains([char]0)){throw 'Absolute C path required'};$v=$full;while($v){if((Test-Path -LiteralPath $v)-and((Get-Item -LiteralPath $v -Force).Attributes-band[IO.FileAttributes]::ReparsePoint)){throw 'Reparse path refused'};$v=[IO.Path]::GetDirectoryName($v)};return $full}
function Hash([string]$p){(Get-FileHash -LiteralPath (Plain $p)).Hash.ToLowerInvariant()}
function ReadMap([string]$p){$s=[IO.FileStream]::new((Plain $p),[IO.FileMode]::Open,[IO.FileAccess]::Read,([IO.FileShare]::ReadWrite-bor[IO.FileShare]::Delete));try{if($s.Length-gt1MB){throw 'Oversize JSON'};$r=[IO.StreamReader]::new($s,[Text.UTF8Encoding]::new($false,$true),$true,4096,$true);try{return($r.ReadToEnd()|ConvertFrom-Json -AsHashtable)}finally{$r.Dispose()}}finally{$s.Dispose()}}
if($ContextSha256-cnotmatch'^[0-9a-f]{64}$'-or(Hash $Context)-cne$ContextSha256){throw 'Bound context changed'}
$c=ReadMap $Context
if($c.scope-cne'devbrain_no_model_terminal_timing_probe'-or$c.status-cne'running'-or$c.no_model-ne$true-or$c.model_requests-ne0-or$c.account_operations-ne0){throw 'Not a live no-model probe'}
$readyPath=Join-Path $c.artifact_root 'ready.json';$ready=ReadMap $readyPath
if($ready.run_id-cne$c.run_id-or$ready.status-cne'awaiting_windows_renderer'-or$ready.arm-cnotin@('attached','delayed')-or$ready.nonce-cnotmatch'^[0-9a-f]{64}$'-or$ready.columns-ne120-or$ready.rows-ne40-or$ready.expires_unix_time-le[DateTimeOffset]::UtcNow.ToUnixTimeSeconds()){throw 'Invalid current arm ready proof'}
$controller=$c.controller;$manifest=$ready.manifest
foreach($p in @($controller,$manifest,$c.python_launcher)){if($p-isnot[string]-or-not$p.StartsWith('/')-or$p-match'[;\r\n\x00]'){throw 'Invalid literal Linux path'}}
if([IO.Path]::GetFileName($controller)-cne'probe-native-terminal-timing080.py'-or-not$manifest.StartsWith('/home/piotr/.cache/devbrain-regressions-080/',[StringComparison]::Ordinal)){throw 'Probe path scope mismatch'}
if((Hash (Join-Path $c.windows_tools 'probe-native-terminal-timing080.py'))-cne$c.controller_sha256){throw 'Probe helper changed'}
$wt=Plain $WindowsTerminal
if([IO.Path]::GetFileName($wt)-ine'wt.exe'-or-not(Test-Path -LiteralPath $wt -PathType Leaf)){throw 'Installed Windows Terminal executable required'}
$receipt=Join-Path $c.artifact_root ('windows-renderer-launch-'+$ready.arm+'.json')
if(Test-Path -LiteralPath $receipt){throw 'This arm already has a Windows launch record'}
$title='DevBrain terminal timing '+$ready.arm+' '+$c.run_id.Substring($c.run_id.Length-8)
$argv=@('-w','new','--size','120,40','new-tab','--title',$title,(Join-Path $env:WINDIR 'System32\wsl.exe'),'--distribution','Ubuntu','--exec',$c.python_launcher,'-I','-B',$controller,'--attach','--manifest',$manifest)
if(-not$Execute){@{execute=$false;argv=$argv;automatic_renderer_confirmation=$false}|ConvertTo-Json -Depth 5;return}
$info=[Diagnostics.ProcessStartInfo]::new();$info.FileName=$wt;$info.UseShellExecute=$false;$info.WindowStyle=[Diagnostics.ProcessWindowStyle]::Normal
foreach($arg in $argv){$info.ArgumentList.Add($arg)}
$process=[Diagnostics.Process]::Start($info)
try{
 $record=@{schema_version=1;scope='devbrain_terminal_timing_probe_windows_renderer_launch';run_id=$c.run_id;arm=$ready.arm;nonce=$ready.nonce;title=$title;actual_windows_terminal_confirmed=$false;launch_pid=$process.Id;launch_birth_utc=$process.StartTime.ToUniversalTime().ToString('o');launcher_exit_is_not_viewer_cleanup=$true;columns=120;rows=40;created_utc=[DateTimeOffset]::UtcNow.ToString('o');model_requests=0;account_operations=0}
 [IO.File]::WriteAllText($receipt,($record|ConvertTo-Json -Depth 5),[Text.UTF8Encoding]::new($false))
 $record|ConvertTo-Json -Depth 5
}finally{$process.Dispose()}
