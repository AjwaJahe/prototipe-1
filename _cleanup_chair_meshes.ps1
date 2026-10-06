$p='C:\Users\LENOVO\Documents\prototipe-1\Kelas_10_A_Furniture.tscn'
$backup=$p+'.before_chair_mesh_cleanup'
Copy-Item -LiteralPath $p -Destination $backup -Force

$lines=[System.IO.File]::ReadAllLines($p)
$out=[System.Collections.Generic.List[string]]::new()
$remove=0

foreach($line in $lines){
    if($line -match '^\[node name="(?:Leg_Left|Leg_Right|Leg_Front_Left|Leg_Front_Right)" type="MeshInstance3D" parent="FurnitureRoot/Node3D/Chair_0[1-9]"\]'){
        $remove++
        $skip=3
        continue
    }
    if($skip -gt 0){
        $skip--
        continue
    }
    $out.Add($line)
}

[System.IO.File]::WriteAllLines($p,$out,(New-Object System.Text.UTF8Encoding($false)))
Write-Output "CHAIR_MESH_NODES_REMOVED=$remove"
