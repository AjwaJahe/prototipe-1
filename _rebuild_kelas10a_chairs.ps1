$p='C:\Users\LENOVO\Documents\prototipe-1\Kelas_10_A_Furniture.tscn'
$backup=$p+'.before_rebuild_chairs'
Copy-Item -LiteralPath $p -Destination $backup -Force

$lines=[System.IO.File]::ReadAllLines($p)
$out=[System.Collections.Generic.List[string]]::new()
$chair=''
$added=0

foreach($line in $lines){
    $out.Add($line)

    if($line -match '^\[node name="Chair_(0[1-9])" type="Node3D" parent="FurnitureRoot/Node3D"'){
        $chair=$Matches[1]
        continue
    }

    if($chair -ne '' -and $line -match '^transform = Transform3D\(1, 0, 0, 0, 1, 0, 0, 0, 1, [^\)]*\)$'){
        $parent="FurnitureRoot/Node3D/Chair_"+$chair
        $out.Add('')
        $out.Add('[node name="Seat" type="MeshInstance3D" parent="'+$parent+'"]')
        $out.Add('position = Vector3(0, 0.46, 0)')
        $out.Add('material_override = SubResource("Mat_Wood")')
        $out.Add('mesh = SubResource("Mesh_ChairSeat")')
        $out.Add('')
        $out.Add('[node name="Back" type="MeshInstance3D" parent="'+$parent+'"]')
        $out.Add('position = Vector3(-0.27, 0.82, 0)')
        $out.Add('material_override = SubResource("Mat_WoodDark")')
        $out.Add('mesh = SubResource("Mesh_ChairBack")')
        $out.Add('')
        $out.Add('[node name="Leg_Back_Left" type="MeshInstance3D" parent="'+$parent+'"]')
        $out.Add('position = Vector3(-0.24, 0.23, -0.26)')
        $out.Add('material_override = SubResource("Mat_Metal")')
        $out.Add('mesh = SubResource("Mesh_ChairLeg")')
        $out.Add('')
        $out.Add('[node name="Leg_Back_Right" type="MeshInstance3D" parent="'+$parent+'"]')
        $out.Add('position = Vector3(-0.24, 0.23, 0.26)')
        $out.Add('material_override = SubResource("Mat_Metal")')
        $out.Add('mesh = SubResource("Mesh_ChairLeg")')
        $out.Add('')
        $out.Add('[node name="Leg_Front_Left" type="MeshInstance3D" parent="'+$parent+'"]')
        $out.Add('position = Vector3(0.24, 0.23, -0.26)')
        $out.Add('material_override = SubResource("Mat_Metal")')
        $out.Add('mesh = SubResource("Mesh_ChairLeg")')
        $out.Add('')
        $out.Add('[node name="Leg_Front_Right" type="MeshInstance3D" parent="'+$parent+'"]')
        $out.Add('position = Vector3(0.24, 0.23, 0.26)')
        $out.Add('material_override = SubResource("Mat_Metal")')
        $out.Add('mesh = SubResource("Mesh_ChairLeg")')
        $added++
        $chair=''
    }
}

[System.IO.File]::WriteAllLines($p,$out,(New-Object System.Text.UTF8Encoding($false)))
Write-Output "CHAIRS_REBUILT=$added TOTAL_LEGS=$($added*4)"
