#Requires -Version 7.5
[CmdletBinding()]
param([switch]$Execute)
if(-not$Execute){'NOT_RUN: exact fresh diagnostic backend requires Root GO.';return}
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$workspace='C:\Users\piotr\OneDrive\Dokumenty\ChatGPT\devbrain'
$context=Join-Path $workspace 'evidence/080-fullbackend-native-failure-diagnostic-active-context-20261109.json'
function Hash([string]$p){(Get-FileHash -LiteralPath $p -Algorithm SHA256).Hash.ToLowerInvariant()}
if((Hash $context)-cne'bb7c2cebf99068951794e916c7850d72138d0130965c46647a1752d642d032ca'){throw 'Fresh backend context changed'}
$c=Get-Content -Raw -LiteralPath $context|ConvertFrom-Json -AsHashtable
if($c.status-cne'prepared_not_run'-or$c.source_freeze_sha256-cne'9e5168bece45cf3c06bd0abded7e1573b51cf55778570fdc49c8e0a8872e81b9'-or$c.source_final-ne$false-or$c.application_qualified-ne$false-or$c.release_qualified-ne$false-or$c.error_inventory_only-ne$true-or$c.helper_file_count-ne38){throw 'Not the reviewed isolated diagnostic backend'}
if((Hash $c.specification)-cne'f8cf12d6926a02a9b10c347b7ad76fc0e3659360ed70280ca794ab8bdab29928'-or(Hash $c.input_freeze)-cne'594b1a44b9ced1dff7916623505bedf0bc18298a2b54c2ea27e72b8237874280'){throw 'Fresh backend inputs changed'}
$freeze=Get-Content -Raw -LiteralPath $c.input_freeze|ConvertFrom-Json -AsHashtable
foreach($name in $freeze.files.Keys){if((Hash (Join-Path $c.windows_root $name))-cne$freeze.files[$name]){throw 'Frozen backend input changed'}}
foreach($name in $c.helper_sha256.Keys){if((Hash (Join-Path $c.windows_tools $name))-cne$c.helper_sha256[$name]){throw 'Canonical helper changed'}}
$wrapper=Join-Path $c.windows_tools 'run-supervised-080.ps1'
if((Hash $wrapper)-cne'721109e2295099fcc4dea6e1a1bc55e773e577e2de673931c33a7e4bb7812c74'){throw 'Canonical observer changed'}
$c.status='running_diagnostic';$c.linux_workload_started=$true;$c.started_utc=[DateTime]::UtcNow.ToString('o')
[IO.File]::WriteAllText($context,($c|ConvertTo-Json -Depth 40),[Text.UTF8Encoding]::new($false))
$pwsh=(Get-Process -Id $PID).Path
& $pwsh -NoProfile -NonInteractive -File $wrapper -ArtifactRoot $c.artifact_root -LinuxArtifactRoot $c.linux_artifact_root -PythonExecutable $c.base_python -Controller $c.controller -ControllerArgumentsFile $c.specification -RunId $c.run_id -TimeoutSeconds $c.timeout_seconds -CleanupGraceSeconds 30 -WslCrashDirectory $c.wsl_crash_directory -Execute |Out-Null
$actualExit=$LASTEXITCODE
$c.actual_windows_exit_code=$actualExit;$c.finished_utc=[DateTime]::UtcNow.ToString('o');$c.status=if($actualExit-eq0){'diagnostic_completed_pending_evidence_review'}else{'diagnostic_failed_pending_cleanup_review'}
[IO.File]::WriteAllText($context,($c|ConvertTo-Json -Depth 40),[Text.UTF8Encoding]::new($false))
@{run_id=$c.run_id;actual_windows_exit_code=$actualExit;status=$c.status;test_count_not_assumed=$true;application_qualified=$false;release_qualified=$false;eight_hour_started=$false}|ConvertTo-Json
exit $actualExit
