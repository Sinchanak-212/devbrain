#Requires -Version 7.5
param([Parameter(Mandatory)][string]$ContextPath,[Parameter(Mandatory)][ValidateSet('80x24','120x36','180x55')][string]$Size,[Parameter(Mandatory)][string]$Observation,[switch]$RootPersonallyViewed,[switch]$LayoutPassed)
if(-not $RootPersonallyViewed){throw 'Actual root visual inspection is required'}
$ErrorActionPreference='Stop'
$c=Get-Content -LiteralPath $ContextPath -Raw|ConvertFrom-Json -AsHashtable
$a=$c.artifact_root;$png=Join-Path $a ('windows-terminal-080-'+$Size+'.png')
$capPath=$png+'.capture.json';$exitPath=Join-Path $a ('windows-observer-'+$Size+'-exit.json');$obsPath=Join-Path $a ('windows-observer-'+$Size+'.json')
$cap=Get-Content -LiteralPath $capPath -Raw|ConvertFrom-Json -AsHashtable;$exit=Get-Content -LiteralPath $exitPath -Raw|ConvertFrom-Json -AsHashtable;$obs=Get-Content -LiteralPath $obsPath -Raw|ConvertFrom-Json -AsHashtable
$sha=(Get-FileHash -LiteralPath $png).Hash.ToLowerInvariant()
if($cap.api-cne'PrintWindow'-or$cap.png_sha256-cne$sha-or-not$cap.identity_verified_before_and_after-or-not$cap.nonblank_client_check-or$cap.desktop_capture-or$cap.input_or_activation-or-not$exit.actual_exit_verified-or-not$exit.readonly_observer_only-or$exit.run_id-cne$c.run_id-or$exit.pid-ne$obs.actual_observer.pid-or$exit.birth-cne$obs.actual_observer.birth){throw 'Actual image/observer identity proof mismatch'}
$p=Join-Path $a 'root-visual-review.json'
$v=if(Test-Path -LiteralPath $p){Get-Content -LiteralPath $p -Raw|ConvertFrom-Json -AsHashtable}else{@{schema_version=1;run_id=$c.run_id;source_snapshot=$c.source_snapshot;source_freeze_sha256=$c.source_freeze_sha256;photos=@();root_personally_visually_reviewed=$false;automatic_ux_pass=$false;human_acceptance_passed=$false;operator='agent';visual_acceptance_passed=$false;overall_ui_acceptance_passed=$false}}
if($v.run_id-cne$c.run_id-or@($v.photos|Where-Object{$_.size-ceq$Size}).Count){throw 'Wrong or duplicate root visual row'}
$v.photos+=@{size=$Size;png=$png;png_sha256=$sha;capture_report=$capPath;capture_report_sha256=(Get-FileHash -LiteralPath $capPath).Hash.ToLowerInvariant();readonly_observer_exit=$exitPath;readonly_observer_exit_sha256=(Get-FileHash -LiteralPath $exitPath).Hash.ToLowerInvariant();window_only=$true;actual_windows_terminal=$true;root_personally_visually_reviewed=$true;readonly_observer_exit_verified=$true;visual_layout_passed=[bool]$LayoutPassed;visual_findings=$Observation;observer_control='read_only';five_persistent_statuses_visible=$true}
$v.root_personally_visually_reviewed=($v.photos.Count-eq3)
$v.visual_acceptance_passed=($v.photos.Count-eq3-and@($v.photos|Where-Object{-not$_.visual_layout_passed}).Count-eq0)
[IO.File]::WriteAllText($p,($v|ConvertTo-Json -Depth 12),[Text.UTF8Encoding]::new($false))
[pscustomobject]@{path=$p;sha256=(Get-FileHash -LiteralPath $p).Hash.ToLowerInvariant();photo_count=$v.photos.Count;visual_acceptance_passed=$v.visual_acceptance_passed;overall_ui_acceptance_passed=$false}|ConvertTo-Json

