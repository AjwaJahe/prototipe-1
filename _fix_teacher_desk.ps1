$ErrorActionPreference = 'Stop'
$path = 'C:\Users\LENOVO\Documents\prototipe-1\Kelas_10_A_Furniture_Experiment.tscn'
$raw = [System.IO.File]::ReadAllText($path)
$raw = $raw.Replace('[sub_resource type="BoxMesh" id="TeacherSide"]' + [Environment]::NewLine + 'size = Vector3(0.10, 0.70, 1.72)', '[sub_resource type="BoxMesh" id="TeacherSide"]' + [Environment]::NewLine + 'size = Vector3(1.08, 0.70, 0.10)')
$raw = $raw.Replace('[node name="LeftSidePanel" type="MeshInstance3D" parent="FurnitureRoot/TeacherDesk_Prototype"]' + [Environment]::NewLine + 'position = Vector3(-0.54, 0.45, 0)', '[node name="LeftSidePanel" type="MeshInstance3D" parent="FurnitureRoot/TeacherDesk_Prototype"]' + [Environment]::NewLine + 'position = Vector3(0, 0.45, -0.82)')
$raw = $raw.Replace('[node name="RightSidePanel" type="MeshInstance3D" parent="FurnitureRoot/TeacherDesk_Prototype"]' + [Environment]::NewLine + 'position = Vector3(0.54, 0.45, 0)', '[node name="RightSidePanel" type="MeshInstance3D" parent="FurnitureRoot/TeacherDesk_Prototype"]' + [Environment]::NewLine + 'position = Vector3(0, 0.45, 0.82)')
[System.IO.File]::WriteAllText($path, $raw, [System.Text.UTF8Encoding]::new($false))
Write-Output 'Teacher desk side panels adjusted to form a proper cabinet frame.'
