$p = 'C:\Users\LENOVO\Documents\prototipe-1\Kelas_10_A_Furniture.tscn'
$backup = $p + '.before_chair_complete'
Copy-Item -LiteralPath $p -Destination $backup -Force

$lines = [System.IO.File]::ReadAllLines($p)
$out = [System.Collections.Generic.List[string]]::new()
$currentChair = ''
$inserted = 0

foreach ($line in $lines) {
    $out.Add($line)

    if ($line -match '^\[node name="Chair_(0[1-9])" type="Node3D" parent="FurnitureRoot/Node3D"') {
        $currentChair = $Matches[1]
        continue
    }

    if ($currentChair -ne '' -and $line -match '^\[node name="Leg_Right" type="MeshInstance3D" parent="FurnitureRoot/Node3D/Chair_'+$currentChair+'"') {
        # Existing Leg_Left + Leg_Right are the rear pair.
        # Add the missing front pair without changing the chair's manually corrected position.
        $out.Add('')
        $out.Add('[node name="Leg_Front_Left" type="MeshInstance3D" parent="FurnitureRoot/Node3D/Chair_'+$currentChair+'"]')
        $out.Add('position = Vector3(0.22, 0.23, -0.22)')
        $out.Add('material_override = SubResource("Mat_Metal")')
        $out.Add('mesh = SubResource("Mesh_ChairLeg")')
        $out.Add('')
        $out.Add('[node name="Leg_Front_Right" type="MeshInstance3D" parent="FurnitureRoot/Node3D/Chair_'+$currentChair+'"]')
        $out.Add('position = Vector3(0.22, 0.23, 0.22)')
        $out.Add('material_override = SubResource("Mat_Metal")')
        $out.Add('mesh = SubResource("Mesh_ChairLeg")')
        $inserted += 2
        $currentChair = ''
    }
}

[System.IO.File]::WriteAllLines($p, $out, (New-Object System.Text.UTF8Encoding($false)))
Write-Output "CHAIR_FRONT_LEGS_ADDED=$inserted"
