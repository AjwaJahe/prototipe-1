$p='C:\Users\LENOVO\Documents\prototipe-1\Kelas_10_A_Furniture.tscn'
$src=$p+'.before_chair_mesh_cleanup'
Copy-Item -LiteralPath $src -Destination $p -Force

$lines=[System.IO.File]::ReadAllLines($p)
$out=[System.Collections.Generic.List[string]]::new()
$removeBlock=$false
$removed=0

foreach($line in $lines){
    if(-not $removeBlock -and $line -match '^\[node name="(?:Leg_Left|Leg_Right|Leg_Front_Left|Leg_Front_Right)" type="MeshInstance3D" parent="FurnitureRoot/Node3D/Chair_0[1-9]"'){
        $removeBlock=$true
        $removed++
        continue
    }

    if($removeBlock){
        if($line -match '^mesh = SubResource\("Mesh_ChairLeg"\)'){
            $removeBlock=$false
        }
        continue
    }

    $out.Add($line)
}

[System.IO.File]::WriteAllLines($p,$out,(New-Object System.Text.UTF8Encoding($false)))
Write-Output "CHAIR_LEG_MESH_BLOCKS_REMOVED=$removed"
