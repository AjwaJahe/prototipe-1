$ErrorActionPreference='Stop'
Set-Location 'C:\Users\LENOVO\Documents\prototipe-1'
$utf8=New-Object System.Text.UTF8Encoding($false)
foreach($f in @('Warehouse_Furniture.tscn','Map58CrateHiding.gd','Player.gd')) {
  $content=[System.IO.File]::ReadAllText((Join-Path (Get-Location) $f))
  $tmp=$f+'.nobom.tmp'
  [System.IO.File]::WriteAllText((Join-Path (Get-Location) $tmp),$content,$utf8)
  Move-Item -LiteralPath $tmp -Destination $f -Force
  $bytes=[System.IO.File]::ReadAllBytes((Join-Path (Get-Location) $f))
  Write-Output ($f+' firstbytes='+[BitConverter]::ToString($bytes[0..2]))
}
