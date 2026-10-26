$ErrorActionPreference='Stop'
Set-Location 'C:\Users\LENOVO\Documents\prototipe-1'
$f='Warehouse_Furniture.tscn'
$s=Get-Content $f -Raw
$blockPattern='(?s)\[sub_resource type="BoxMesh" id="crate_wall_front"\].*?\[sub_resource type="BoxShape3D" id="crate_side_collision"\]\r?\nsize = Vector3\(0\.12, 1\.72, 1\.6\)\r?\n'
$m=[regex]::Match($s,$blockPattern)
if (-not $m.Success) { throw 'Inserted crate resources block not found; refusing to change scene.' }
$block=$m.Value
$s=$s.Remove($m.Index,$m.Length)
$firstNode='[node name="Warehouse_Furniture" type="Node3D" unique_id=1817555379]'
if (-not $s.Contains($firstNode)) { throw 'Scene root marker missing.' }
$s=$s.Replace($firstNode,$block+[Environment]::NewLine+$firstNode)
$tmp='Warehouse_Furniture.tscn.resource_order.tmp'
Set-Content $tmp -Value $s -NoNewline -Encoding utf8
Move-Item -LiteralPath $tmp -Destination $f -Force
Write-Output ('crate resource block moved before nodes=' + ($s.IndexOf('id="crate_wall_front"') -lt $s.IndexOf('[node name="Warehouse_Furniture"')))
Write-Output ('racks=' + (Select-String -Path $f -Pattern '\[node name="Rack_').Count)
Write-Output ('subresources after root node=' + [regex]::Matches(($s.Substring($s.IndexOf('[node name="Warehouse_Furniture"'))),'(?m)^\[sub_resource').Count)
