#Requires -Version 7.5
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
function Require([bool]$Good,[string]$Message){if(-not$Good){throw $Message}}
function Verify([string]$Path,[string]$Hash){if($Path-cne'C:\synthetic\pixels.png'-or$Hash-cne'fixture-digest'){throw 'Unexpected synthetic image binding'}}
$sources=@{
 'stage-five-length-final-gates-after-ui-v2-20261108.ps1'='f06db0400e3d7c02f68bd48930458156aa417808a456056c046bd96ad49294bd'
 'stage-final-eight-hour-length-repair-604-v3-20261108.ps1'='c5acbb4670305e9dae7a878be6c7571945bb06089774fc3622b3283bd0c289e9'
}
$script:cases=0
foreach($name in $sources.Keys){
 $path=Join-Path $PSScriptRoot $name
 if((Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()-cne$sources[$name]){throw 'Wrong materializer'}
 $tokens=$null;$errors=$null;$ast=[Management.Automation.Language.Parser]::ParseFile($path,[ref]$tokens,[ref]$errors)
 if($errors.Count){throw 'Syntax error'}
 $visual=@($ast.FindAll({param($n)$n-is[Management.Automation.Language.CommandAst]-and$n.GetCommandName()-ceq'Require'-and$n.Extent.Text.Contains('Actual root visual acceptance required')},$true))
 $count=@($ast.FindAll({param($n)$n-is[Management.Automation.Language.CommandAst]-and$n.GetCommandName()-ceq'Require'-and$n.Extent.Text.Contains('Three actual Windows captures required')},$true))
 $photos=@($ast.FindAll({param($n)$n-is[Management.Automation.Language.ForEachStatementAst]-and$n.Extent.Text.StartsWith('foreach($photo in $gates.interactive.final.photos)')},$true))
 if($visual.Count-ne1-or$count.Count-ne1-or$photos.Count-ne1){throw 'Ambiguous actual predicates'}
 $visualBlock=[scriptblock]::Create($visual[0].Extent.Text)
 $countBlock=[scriptblock]::Create($count[0].Extent.Text)
 $photoBlock=[scriptblock]::Create($photos[0].Extent.Text)
 $matrix=@(
  @{label='literal true with three actual reviewed images';value=$true;present=$true;pass=$true},
  @{label='known visual failure despite three reviewed images';value=$false;present=$true;pass=$false},
  @{label='missing visual verdict';value=$null;present=$false;pass=$false},
  @{label='null visual verdict';value=$null;present=$true;pass=$false},
  @{label='string true is not a verdict';value='true';present=$true;pass=$false},
  @{label='string false is not a verdict';value='false';present=$true;pass=$false},
  @{label='numeric one is not a verdict';value=1;present=$true;pass=$false},
  @{label='numeric zero is not a verdict';value=0;present=$true;pass=$false},
  @{label='array is not a verdict';value=@($true);present=$true;pass=$false},
  @{label='object is not a verdict';value=@{passed=$true};present=$true;pass=$false},
  @{label='two photographs remain insufficient';value=$true;present=$true;pass=$false;count=2},
  @{label='unclosed image observer remains insufficient';value=$true;present=$true;pass=$false;unclosed=$true}
 )
 foreach($case in $matrix){
  $photoCount=if($case.Contains('count')){$case.count}else{3}
  $rows=@(for($i=0;$i-lt$photoCount;$i++){@{png='C:\synthetic\pixels.png';png_sha256='fixture-digest';window_only=$true;actual_windows_terminal=$true;root_personally_visually_reviewed=$true;readonly_observer_exit_verified=$true}})
  if($case.Contains('unclosed')){$rows[0].readonly_observer_exit_verified=$false}
  $final=@{photos=$rows}
  if($case.present){$final.visual_acceptance_passed=$case.value}
  $gates=@{interactive=@{final=$final}}
  $passed=$true
  try{&$visualBlock;&$countBlock;&$photoBlock}catch{$passed=$false}
  if($passed-ne$case.pass){throw "Unexpected verdict in $name : $($case.label)"}
  $script:cases++
 }
}
[ordered]@{scope='windows_synthetic_actual_visual_admission_predicates';passed=$true;cases=$script:cases;stage_executed=$false;linux_executed=$false;filesystem_mutated_by_test=$false}|ConvertTo-Json
