$p='C:\Users\LENOVO\Documents\prototipe-1\Kelas_10_A_Furniture.tscn'
Copy-Item -LiteralPath $p -Destination ($p+'.before_desk_collision_fix2') -Force
$s=[IO.File]::ReadAllText($p)

if($s.IndexOf('[sub_resource type="BoxShape3D" id="ClassDeskSolidCollision"]') -lt 0){
  $marker='[sub_resource type="BoxMesh" id="Mesh_CupboardBody"]'
  $res='[sub_resource type="BoxShape3D" id="ClassDeskSolidCollision"]' + [Environment]::NewLine + 'size = Vector3(1.08, 1.08, 1.78)' + [Environment]::NewLine + [Environment]::NewLine
  $s=$s.Replace($marker,$res+$marker)
}

$pattern='(?s)(\[node name="CollisionShape3D" type="CollisionShape3D" parent="FurnitureRoot/StudentDesks/Desk_0[1-9]/FurnitureCollision"[^\]]*\]\r?\n)(.*?)(?=\r?\n\[node )'
$count=0
$s=[regex]::Replace($s,$pattern,{
  param($m)
  $b=$m.Groups[2].Value
  $b=[regex]::Replace($b,'(?m)^position = Vector3\([^\r\n]*\)\r?\n','')
  $b=[regex]::Replace($b,'(?m)^shape = SubResource\("[^"]+"\)\r?\n?','')
  $count++
  return $m.Groups[1].Value + 'position = Vector3(0, 0.54, 0)' + [Environment]::NewLine + 'shape = SubResource("ClassDeskSolidCollision")'
})

$tp='(?s)(\[node name="CollisionShape3D" type="CollisionShape3D" parent="FurnitureRoot/TeacherDesk/FurnitureCollision"[^\]]*\]\r?\n)(.*?)(?=\r?\n\[node )'
$s=[regex]::Replace($s,$tp,{
  param($m)
  return $m.Groups[1].Value + 'position = Vector3(0, 0.54, 0)' + [Environment]::NewLine + 'shape = SubResource("BoxShape3D_ruifp")'
},1)

$s=[regex]::Replace($s,'(?s)(\[node name="Desk_0[1-9]" type="Node3D" parent="FurnitureRoot/StudentDesks"[^\]]*\]\r?\ntransform = [^\r\n]+\r?\n.*?)(?=\r?\n\[node name="Desk_0[1-9]" type="Node3D" parent="FurnitureRoot/StudentDesks")',
  {param($m) $m.Value}, [System.Text.RegularExpressions.RegexOptions]::None)

[IO.File]::WriteAllText($p,$s,(New-Object Text.UTF8Encoding($false)))
Write-Output "DESK_COLLISION_NODES_UPDATED=$count"
