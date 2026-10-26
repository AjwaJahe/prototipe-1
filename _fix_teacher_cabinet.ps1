$ErrorActionPreference = 'Stop'
$path = 'C:\Users\LENOVO\Documents\prototipe-1\Kelas_10_A_Furniture_Experiment.tscn'
$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
Copy-Item -LiteralPath $path -Destination "$path.before_teacher_cabinet_fix_$stamp.bak"
$raw = Get-Content -LiteralPath $path -Raw

$raw = [regex]::Replace($raw, '(?s)(\[sub_resource type="BoxMesh" id="TeacherSide"\]\s*size = )Vector3\([^\r\n]+\)', '$1Vector3(1.08, 0.70, 0.10)')
$raw = [regex]::Replace($raw, '(?s)(\[node name="LeftSidePanel" type="MeshInstance3D" parent="FurnitureRoot/TeacherDesk_Prototype"\]\s*position = )Vector3\([^\r\n]+\)', '$1Vector3(0, 0.45, -0.82)')
$raw = [regex]::Replace($raw, '(?s)(\[node name="RightSidePanel" type="MeshInstance3D" parent="FurnitureRoot/TeacherDesk_Prototype"\]\s*position = )Vector3\([^\r\n]+\)', '$1Vector3(0, 0.45, 0.82)')

Set-Content -LiteralPath $path -Value $raw -Encoding utf8
Write-Output "Fixed side panel geometry. Backup: $path.before_teacher_cabinet_fix_$stamp.bak"
