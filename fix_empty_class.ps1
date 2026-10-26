$ErrorActionPreference='Stop'
$root='C:\Users\LENOVO\Documents\prototipe-1'
$target=Join-Path $root 'Kelas_10_A_Furniture.tscn'
$source=Join-Path $root 'Kelas_10_A_Furniture.tscn.before_replace_with_experiment_20261010.bak'
$stamp=Get-Date -Format 'yyyyMMdd_HHmmss'
$backup="$target.before_fix_empty_class_$stamp.bak"
Copy-Item $target $backup
$text=[System.IO.File]::ReadAllText($source)
$old='(?ms)(\[node name="TeacherDesk" type="Node3D" parent="FurnitureRoot"[^\r\n]*\]\s*\r?\n)transform = Transform3D\([^\r\n]*\)'
$new='$1transform = Transform3D(0.76604444, 0, -0.6427876, 0, 1, 0, 0.6427876, 0, 0.76604444, 6.2364817, 0, -2.5440426)'
$updated=[regex]::Replace($text,$old,$new,1)
if($updated -eq $text){ throw 'TeacherDesk root transform not found in recovery backup; no restore applied.' }
[System.IO.File]::WriteAllText($target,$updated,[System.Text.UTF8Encoding]::new($false))
Write-Output "Previous broken file backed up to: $backup"
Write-Output "Restored full valid classroom scene from: $source"
Write-Output "Applied latest teacher desk transform."
Write-Output "Whiteboard nodes: $([regex]::Matches($updated,'(?m)^\[node name="Whiteboard"').Count)"
Write-Output "Student desk nodes: $([regex]::Matches($updated,'(?m)^\[node name="Desk_\d+"').Count)"
Write-Output "Subresource after node section: $([regex]::Matches($updated,'(?ms)^\[node[^\r\n]*\].*?^\[sub_resource').Count)"