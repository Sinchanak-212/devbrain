#Requires -Version 7.5
param([Parameter(Mandatory)][string]$ContextPath,[Parameter(Mandatory)][ValidateSet('80x24','120x36','180x55')][string]$Size,[switch]$Execute)
if(-not $Execute){'NOT_RUN: root-only read-only Windows Terminal observer and user-authorized PrintWindow capture';return}
$ErrorActionPreference='Stop'
$c=Get-Content -LiteralPath $ContextPath -Raw|ConvertFrom-Json
$r=Get-Content -LiteralPath $c.ready_file -Raw|ConvertFrom-Json
$recordPath=Join-Path $c.artifact_root ('windows-observer-'+$Size+'.json')
if(Test-Path -LiteralPath $recordPath){throw 'Fresh observer record required'}
$py=@'
import json,sys,time,subprocess,os,termios,select
from pathlib import Path
mode,manifest,record=sys.argv[1:4]
s=json.loads(Path(manifest).read_text()); path=Path(record)
base=[s['runtime']['tmux_executable'],'-u','-S',s['socket']]
def clients():
 p=subprocess.run(base+['list-clients','-F','#{client_pid}|#{client_tty}|#{client_flags}|#{client_width}x#{client_height}'],capture_output=True,text=True,check=True,timeout=3)
 return [x.split('|') for x in p.stdout.splitlines()]
if mode=='before':
 assert s['status']=='running' and time.time()<s['expires_unix_time']
 print(json.dumps({'run_id':s['run_id'],'binary':base[0],'socket':s['socket'],'clients_before':clients()}))
elif mode=='admit':
 old=json.loads(path.read_text()); before={int(x[0]) for x in old['clients_before']}
 fresh=[x for x in clients() if int(x[0]) not in before and 'read-only' in x[2].split(',') and 'ignore-size' in x[2].split(',')]
 assert len(fresh)==1,'readonly_observer_not_yet_unique'
 x=fresh[0];pid=int(x[0]);birth=Path(f'/proc/{pid}/stat').read_text().rpartition(')')[2].split()[19]
 assert Path(f'/proc/{pid}').stat().st_uid==os.getuid() and os.readlink(f'/proc/{pid}/exe')==base[0]
 assert x[3]==old['size_requested']
 fd=os.open(x[1],os.O_RDONLY|os.O_NOCTTY|os.O_NONBLOCK)
 try: rows,cols=termios.tcgetwinsize(fd)
 finally:os.close(fd)
 assert f'{cols}x{rows}'==old['size_requested']
 status=subprocess.run(base+['show-options','-A','-v','-t','devbrain-ui','status'],capture_output=True,text=True,check=True,timeout=3).stdout.strip()
 n={'on':1,'off':0}.get(status);n=int(status) if n is None else n
 window=subprocess.run(base+['display-message','-p','-t','devbrain-ui:workspace','#{window_width}x#{window_height}'],capture_output=True,text=True,check=True,timeout=3).stdout.strip()
 assert window==f'{cols}x{rows-n}','primary_window_geometry_differs'
 print(json.dumps({'pid':pid,'birth':birth,'tty':x[1],'flags':x[2],'client_geometry':x[3],'window_geometry':window,'status_rows':n}))
elif mode=='detach':
 old=json.loads(path.read_text());x=old['actual_observer'];pid=x['pid'];fd=os.pidfd_open(pid)
 try:
  assert not select.select([fd],[],[],0)[0]
  assert Path(f'/proc/{pid}/stat').read_text().rpartition(')')[2].split()[19]==x['birth']
  assert os.readlink(f'/proc/{pid}/exe')==base[0] and Path(f'/proc/{pid}').stat().st_uid==os.getuid()
  match=[z for z in clients() if z[0]==str(pid) and z[1]==x['tty']]
  assert len(match)==1 and 'read-only' in match[0][2].split(',') and 'ignore-size' in match[0][2].split(',')
  subprocess.run(base+['detach-client','-t',x['tty']],capture_output=True,text=True,check=True,timeout=3)
  assert select.select([fd],[],[],5)[0]
  print(json.dumps({'run_id':s['run_id'],'pid':pid,'birth':x['birth'],'tty':x['tty'],'actual_exit_verified':True,'readonly_observer_only':True,'observed_unix_time':time.time()}))
 finally:os.close(fd)
'@
$linuxRecord='/mnt/c/'+$recordPath.Substring(3).Replace('\','/')
$raw=& wsl.exe -d Ubuntu -u piotr --exec $r.python_launcher -I -B -c $py before $r.manifest $linuxRecord
if($LASTEXITCODE-ne0){throw 'Live observer metadata failed'}
$old=$raw|ConvertFrom-Json -AsHashtable
$old.size_requested=$Size;$old.title='DevBrain Capture '+$Size;$old.readonly=$true;$old.ignore_size=$true
[IO.File]::WriteAllText($recordPath,($old|ConvertTo-Json -Depth 8),[Text.UTF8Encoding]::new($false))
$package=Get-AppxPackage -Name Microsoft.WindowsTerminal
$psi=[Diagnostics.ProcessStartInfo]::new();$psi.FileName=Join-Path $package.InstallLocation 'wt.exe';$psi.UseShellExecute=$false
foreach($arg in @('-w','new','--size',$Size.Replace('x',','),'new-tab','--title',$old.title,(Join-Path $env:WINDIR 'System32/wsl.exe'),'--distribution','Ubuntu','--user','piotr','--exec',$old.binary,'-u','-S',$old.socket,'attach-session','-r','-f','ignore-size','-t','devbrain-ui')){$psi.ArgumentList.Add($arg)}
$p=[Diagnostics.Process]::Start($psi);try{$old.launcher_pid=$p.Id}finally{$p.Dispose()}
try{
 $deadline=[DateTime]::UtcNow.AddSeconds(20);$actual=$null
 do{
  $raw=& wsl.exe -d Ubuntu -u piotr --exec $r.python_launcher -I -B -c $py admit $r.manifest $linuxRecord 2>$null
  if($LASTEXITCODE-eq0){$actual=$raw|ConvertFrom-Json -AsHashtable;break}
  Start-Sleep -Milliseconds 250
 }while([DateTime]::UtcNow-lt$deadline)
 if(-not$actual){throw 'Readonly observer admission failed; preserve before record for owned recovery'}
 $old.actual_observer=$actual
 [IO.File]::WriteAllText($recordPath,($old|ConvertTo-Json -Depth 8),[Text.UTF8Encoding]::new($false))
 # User-authorized screenshot identity lookup ONLY; no input or activation API.
 Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
using System.Text.RegularExpressions;
public static class DevBrainCaptureLocator080 {
 [DllImport("user32.dll",CharSet=CharSet.Unicode)] static extern IntPtr FindWindowW(string className,string windowName);
 [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr window,out uint process);
 public static long[] Locate(string title) {
  if(!Regex.IsMatch(title,@"^DevBrain Capture (80x24|120x36|180x55)$")) throw new ArgumentException("capture title refused");
  IntPtr h=FindWindowW("CASCADIA_HOSTING_WINDOW_CLASS",title);
  if(h==IntPtr.Zero)return new long[0];
  uint p; if(GetWindowThreadProcessId(h,out p)==0||p==0) return new long[0];
  return new long[]{h.ToInt64(),p};
 }
}
'@
 $deadline=[DateTime]::UtcNow.AddSeconds(15)
 do{$target=[DevBrainCaptureLocator080]::Locate($old.title);if($target.Length-eq2){break};Start-Sleep -Milliseconds 250}while([DateTime]::UtcNow-lt$deadline)
 if($target.Length-ne2){throw 'Exact Capture window not available'}
 $hwnd=$target[0];$pidWin=[int]$target[1];$window=Get-Process -Id $pidWin
 $birthWin=$window.StartTime.ToUniversalTime().ToFileTimeUtc()
 $capture=Join-Path (Split-Path (Split-Path $ContextPath)) 'release-tools/capture-devbrain-window080.ps1'
 if((Get-FileHash -LiteralPath $capture).Hash.ToLowerInvariant()-cne'71afe70ebe3bcfc137417f8a6c5a46c5ed1b2e3421654b7ce754b9ddf67fbbf4'){throw 'Authorized PrintWindow helper changed'}
 $png=Join-Path $c.artifact_root ('windows-terminal-080-'+$Size+'.png')
 & (Get-Process -Id $PID).Path -NoProfile -NonInteractive -File $capture -WindowHandle $hwnd -Title $old.title -ExpectedProcessId $pidWin -ExpectedProcessStartFileTime $birthWin -OutputPath $png -Execute
 if($LASTEXITCODE-ne0){throw 'PrintWindow capture failed'}
}finally{
 if($old.actual_observer){
  $raw=& wsl.exe -d Ubuntu -u piotr --exec $r.python_launcher -I -B -c $py detach $r.manifest $linuxRecord
  if($LASTEXITCODE-ne0){throw 'Exact readonly observer exit not confirmed'}
  $exit=$raw|ConvertFrom-Json
  [IO.File]::WriteAllText((Join-Path $c.artifact_root ('windows-observer-'+$Size+'-exit.json')),($exit|ConvertTo-Json -Depth 5),[Text.UTF8Encoding]::new($false))
 }
}
[pscustomobject]@{run_id=$c.run_id;size=$Size;png=$png;png_sha256=(Get-FileHash -LiteralPath $png).Hash.ToLowerInvariant();readonly_observer_actual_exit=$exit.actual_exit_verified;automatic_visual_pass=$false}|ConvertTo-Json

