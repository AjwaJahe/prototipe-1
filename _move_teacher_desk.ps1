$ErrorActionPreference = 'Stop'
$path = 'C:\Users\LENOVO\Documents\prototipe-1\Kelas_10_A_Furniture_Experiment.tscn'
$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
Copy-Item -LiteralPath $path -Destination "$path.before_teacher_desk_move_$stamp.bak"
$raw = Get-Content -LiteralPath $path -Raw

# Move teacher desk to the front of the student rows, leaving a clear gap.
$raw = $raw.Replace('position = Vector3(0, 0, -7.0)', 'position = Vector3(0, 0, -5.9)')

# Correct the cabinet geometry: side panels span the desk width at the two ends.
$raw = $raw.Replace('[sub_resource type="BoxMesh" id="TeacherSide"]' + "`r`n" + 'size = Vector3(0.10, 0.70, 1.72)', '[sub_resource type="BoxMesh" id="TeacherSide"]' + "`r`n" + 'size = Vector3(1.08, 0.70, 0.10)')
$raw = $raw.Replace('position = Vector3(-0.54, 0.45, 0)' + "`r`n" + 'material_override = SubResource("TeacherWood")' + "`r`n" + 'mesh = SubResource("TeacherSide")', 'position = Vector3(0, 0.45, -0.82)' + "`r`n" + 'material_override = SubResource("TeacherWood")' + "`r`n" + 'mesh = SubResource("TeacherSide")')
$raw = $raw.Replace('position = Vector3(0.54, 0.45, 0)' + "`r`n" + 'material_override = SubResource("TeacherWood")' + "`r`n" + 'mesh = SubResource("TeacherSide")', 'position = Vector3(0, 0.45, 0.82)' + "`r`n" + 'material_override = SubResource("TeacherWood")' + "`r`n" + 'mesh = SubResource("TeacherSide")')

Set-Content -LiteralPath $path -Value $raw -Encoding utf8
Write-Output "Updated teacher desk position and cabinet sides. Backup: $path.before_teacher_desk_move_$stamp.bak"
