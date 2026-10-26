$ErrorActionPreference = 'Stop'
$path = 'C:\Users\LENOVO\Documents\prototipe-1\Kelas_10_A_Furniture_Experiment.tscn'
$backup = "$path.before_arrange_fix_20261010.bak"
Copy-Item -LiteralPath $path -Destination $backup -Force
$raw = [System.IO.File]::ReadAllText($path)
$header = ($raw -split '(?=\[node )')[0]
$blocks = [regex]::Split($raw, '(?=\[node )') | Where-Object { $_.Trim().Length -gt 0 }
$rootBlocks = @{}
$deskChild = @()
$benchChild = @()
foreach ($block in $blocks) {
  if ($block -match '^\[node name="Kelas_10_A_Furniture_Experiment" type="Node3D"\]') { $rootBlocks.Scene = $block; continue }
  if ($block -match '^\[node name="FurnitureRoot" type="Node3D" parent="\."\]') { $rootBlocks.Furniture = $block; continue }
  if ($block -match '^\[node name="StudentDesk_Prototype" type="Node3D" parent="FurnitureRoot"\]') { $rootBlocks.Desk = $block; continue }
  if ($block -match '^\[node name="StudentBench_Prototype" type="Node3D" parent="FurnitureRoot"\]') { $rootBlocks.Bench = $block; continue }
  if ($block -match '^\[node name="([^"]+)"[^\r\n]*parent="FurnitureRoot/StudentDesk_Prototype(?:/[^"]*)?"') { $deskChild += $block; continue }
  if ($block -match '^\[node name="([^"]+)"[^\r\n]*parent="FurnitureRoot/StudentBench_Prototype(?:/[^"]*)?"') { $benchChild += $block; continue }
}
if (-not $rootBlocks.Scene -or -not $rootBlocks.Furniture -or -not $rootBlocks.Desk -or -not $rootBlocks.Bench -or $deskChild.Count -lt 5 -or $benchChild.Count -lt 8) { throw "Could not identify scene/prototype nodes safely: desk child count=$($deskChild.Count), bench child count=$($benchChild.Count)" }
$benchChild = @($benchChild | Where-Object { $_ -notmatch 'parent="FurnitureRoot/StudentBench_Prototype/FurnitureCollision' -and $_ -notmatch 'name="FurnitureCollision" type="StaticBody3D" parent="FurnitureRoot/StudentBench_Prototype"' })
$header = $header -replace '(?s)\[sub_resource type="BoxShape3D" id="BenchCollision"\]\r?\nsize = Vector3\(0\.46, 0\.86, 1\.22\)\r?\n?', ''
$out = [System.Text.StringBuilder]::new()
[void]$out.Append($header)
$nl = [Environment]::NewLine
[void]$out.Append($rootBlocks.Scene.TrimEnd() + $nl + $nl)
[void]$out.Append($rootBlocks.Furniture.TrimEnd() + $nl + $nl)
$columns = @(-4.0, 0.0, 4.0)
$rows = @(-3.6, 0.0, 3.6)
$index = 0
foreach ($z in $rows) {
  foreach ($x in $columns) {
    $index++
    $deskName = if ($index -eq 1) { 'StudentDesk_Prototype' } else { "StudentDesk_$('{0:D2}' -f $index)" }
    $benchName = if ($index -eq 1) { 'StudentBench_Prototype' } else { "StudentBench_$('{0:D2}' -f $index)" }
    $deskRoot = $rootBlocks.Desk -replace 'StudentDesk_Prototype', $deskName
    $deskRoot = $deskRoot.TrimEnd() + $nl + "position = Vector3($x, 0, $z)" + $nl + $nl
    [void]$out.Append($deskRoot)
    foreach ($b in $deskChild) {
      $copy = $b -replace 'FurnitureRoot/StudentDesk_Prototype', "FurnitureRoot/$deskName"
      [void]$out.Append($copy.TrimEnd() + $nl + $nl)
    }
    $benchRoot = $rootBlocks.Bench -replace 'StudentBench_Prototype', $benchName
    $benchX = $x - 0.66
    $benchRoot = [regex]::Replace($benchRoot, 'position = Vector3\([^)]+\)', "position = Vector3($benchX, 0, $z)")
    [void]$out.Append($benchRoot.TrimEnd() + $nl + $nl)
    foreach ($b in $benchChild) {
      $copy = $b -replace 'FurnitureRoot/StudentBench_Prototype', "FurnitureRoot/$benchName"
      [void]$out.Append($copy.TrimEnd() + $nl + $nl)
    }
  }
}
[System.IO.File]::WriteAllText($path, $out.ToString(), [System.Text.UTF8Encoding]::new($false))
Write-Output "Arranged 9 desk/bench pairs; scene root preserved; bench collisions omitted; backup: $backup"
