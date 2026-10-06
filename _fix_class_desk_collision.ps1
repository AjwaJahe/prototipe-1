$p='C:\Users\LENOVO\Documents\prototipe-1\Kelas_10_A_Furniture.tscn'
Copy-Item -LiteralPath $p -Destination ($p+'.before_desk_collision_fix') -Force
$s=[IO.File]::ReadAllText($p)

$s=$s.Replace('[sub_resource type="BoxShape3D" id="BoxShape3D_ruifp"]' + [Environment]::NewLine + 'size = Vector3(1.8, 0.78, 1.05)',
'[sub_resource type="BoxShape3D" id="BoxShape3D_ruifp"]' + [Environment]::NewLine + 'size = Vector3(1.05, 1.08, 1.80)')

$s=$s.Replace('[node name="CollisionShape3D" type="CollisionShape3D" parent="FurnitureRoot/TeacherDesk/FurnitureCollision" unique_id=48684245]' + [Environment]::NewLine + 'shape = SubResource("BoxShape3D_ruifp")',
'[node name="CollisionShape3D" type="CollisionShape3D" parent="FurnitureRoot/TeacherDesk/FurnitureCollision" unique_id=48684245]' + [Environment]::NewLine + 'position = Vector3(0, 0.54, 0)' + [Environment]::NewLine + 'shape = SubResource("BoxShape3D_ruifp")')

$marker='[sub_resource type="BoxShape3D" id="BoxShape3D_q0jp6"]'
$deskShape='[sub_resource type="BoxShape3D" id="ClassDeskSolidCollision"]' + [Environment]::NewLine + 'size = Vector3(1.08, 1.08, 1.78)' + [Environment]::NewLine + [Environment]::NewLine
$s=$s.Replace($marker,$deskShape+$marker)

$matches=[regex]::Matches($s,'\[sub_resource type="BoxShape3D" id="(BoxShape3D_[^"]+)"\]' + [Environment]::NewLine + 'size = Vector3\(1\.65, 0\.12, 1\)')
$ids=@()
foreach($m in $matches){
  $ids += $m.Groups[1].Value
  if($ids.Count -eq 9){break}
}
foreach($id in $ids){
  $s=$s.Replace('shape = SubResource("'+$id+'")','shape = SubResource("ClassDeskSolidCollision")')
}

$s=[regex]::Replace($s,'(?m)(\[node name="CollisionShape3D" type="CollisionShape3D" parent="FurnitureRoot/StudentDesks/Desk_0[1-9]/FurnitureCollision"[^\r\n]*\]' + [Environment]::NewLine + ')(shape = SubResource\("ClassDeskSolidCollision"\))',
'$1position = Vector3(0, 0.54, 0)' + [Environment]::NewLine + '$2')

[IO.File]::WriteAllText($p,$s,(New-Object Text.UTF8Encoding($false)))
Write-Output ("UPDATED_DESK_COLLISIONS=" + $ids.Count)
