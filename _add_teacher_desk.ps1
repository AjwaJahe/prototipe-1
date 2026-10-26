$ErrorActionPreference = 'Stop'
$path = 'C:\Users\LENOVO\Documents\prototipe-1\Kelas_10_A_Furniture_Experiment.tscn'
$backup = "$path.before_teacher_desk_20261010.bak"
Copy-Item -LiteralPath $path -Destination $backup -Force
$raw = [System.IO.File]::ReadAllText($path)
if ($raw -match 'name="TeacherDesk_Prototype"') { throw 'Teacher desk already exists; refusing to duplicate.' }
$sub = @'
[sub_resource type="StandardMaterial3D" id="TeacherWood"]
albedo_color = Color(0.30, 0.16, 0.075, 1)
roughness = 0.82

[sub_resource type="BoxMesh" id="TeacherTop"]
size = Vector3(1.55, 0.14, 1.95)

[sub_resource type="BoxMesh" id="TeacherSide"]
size = Vector3(0.10, 0.70, 1.72)

[sub_resource type="BoxMesh" id="TeacherFrontPanel"]
size = Vector3(0.10, 0.64, 1.72)

[sub_resource type="BoxMesh" id="TeacherDrawerFront"]
size = Vector3(0.055, 0.16, 0.48)

[sub_resource type="BoxMesh" id="TeacherDrawerPull"]
size = Vector3(0.035, 0.035, 0.18)

[sub_resource type="BoxShape3D" id="TeacherDeskCollision"]
size = Vector3(1.62, 0.96, 2.02)

'@
$nodes = @'
[node name="TeacherDesk_Prototype" type="Node3D" parent="FurnitureRoot"]
position = Vector3(0, 0, -7.0)

[node name="Top" type="MeshInstance3D" parent="FurnitureRoot/TeacherDesk_Prototype"]
position = Vector3(0, 0.91, 0)
material_override = SubResource("TeacherWood")
mesh = SubResource("TeacherTop")

[node name="LeftSidePanel" type="MeshInstance3D" parent="FurnitureRoot/TeacherDesk_Prototype"]
position = Vector3(-0.54, 0.45, 0)
material_override = SubResource("TeacherWood")
mesh = SubResource("TeacherSide")

[node name="RightSidePanel" type="MeshInstance3D" parent="FurnitureRoot/TeacherDesk_Prototype"]
position = Vector3(0.54, 0.45, 0)
material_override = SubResource("TeacherWood")
mesh = SubResource("TeacherSide")

[node name="FrontPanel" type="MeshInstance3D" parent="FurnitureRoot/TeacherDesk_Prototype"]
position = Vector3(-0.54, 0.45, 0)
material_override = SubResource("TeacherWood")
mesh = SubResource("TeacherFrontPanel")

[node name="DrawerFront" type="MeshInstance3D" parent="FurnitureRoot/TeacherDesk_Prototype"]
position = Vector3(-0.598, 0.72, 0)
material_override = SubResource("TeacherWood")
mesh = SubResource("TeacherDrawerFront")

[node name="DrawerPull" type="MeshInstance3D" parent="FurnitureRoot/TeacherDesk_Prototype"]
position = Vector3(-0.633, 0.72, 0)
material_override = SubResource("Metal")
mesh = SubResource("TeacherDrawerPull")

[node name="FurnitureCollision" type="StaticBody3D" parent="FurnitureRoot/TeacherDesk_Prototype"]

[node name="CollisionShape3D" type="CollisionShape3D" parent="FurnitureRoot/TeacherDesk_Prototype/FurnitureCollision"]
position = Vector3(0, 0.47, 0)
shape = SubResource("TeacherDeskCollision")
'@
$marker = '[node name="Kelas_10_A_Furniture_Experiment" type="Node3D"]'
if (-not $raw.Contains($marker)) { throw 'Scene root marker missing; file not changed.' }
$raw = $raw.Replace($marker, $sub + $marker)
$nl = [Environment]::NewLine
[System.IO.File]::WriteAllText($path, $raw.TrimEnd() + $nl + $nl + $nodes, [System.Text.UTF8Encoding]::new($false))
Write-Output "Teacher desk added. Backup: $backup"
