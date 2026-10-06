$root='C:\Users\LENOVO\Documents\prototipe-1'
$patterns=@('UKS_Furniture','TeacherRoom_Furniture','UKS_Furniture.tscn','TeacherRoom_Furniture.tscn')
Get-ChildItem -LiteralPath $root -Recurse -File | Where-Object {$_.Extension -in '.tscn','.gd','.godot'} | ForEach-Object {
  try {
    $content=[System.IO.File]::ReadAllText($_.FullName)
    foreach($p in $patterns){
      if($content.IndexOf($p,[System.StringComparison]::OrdinalIgnoreCase) -ge 0){
        Write-Output ("MATCH|"+$_.FullName+"|"+$p)
      }
    }
  } catch {}
}
