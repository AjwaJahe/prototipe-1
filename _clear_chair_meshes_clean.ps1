$p='C:\Users\LENOVO\Documents\prototipe-1\Kelas_10_A_Furniture.tscn'
$src=$p+'.before_chair_mesh_cleanup'
Copy-Item -LiteralPath $src -Destination $p -Force

$lines=[System.IO.File]::ReadAllLines($p)
$out=[System.Collections.Generic.List[string]]::new()
$skip=$false
$removed=0

foreach($line in $lines){
    if($line -match '^\[node name=".*" type="MeshInstance3D" parent="FurnitureRoot/Node3D/Chair_0[1-9]"'){
        $skip=$true
        $removed++
        continue
    }

    if($skip){
        if($line -match '^\[node '){
            $skip=$false
            $out.Add('')
            $out.Add($line)
        }
        continue
    }

    $out.Add($line)
}

[System.IO.File]::WriteAllLines($p,$out,(New-Object System.Text.UTF8Encoding($false)))
Write-Output "CHAIR_MESH_NODES_REMOVED=$removed"
