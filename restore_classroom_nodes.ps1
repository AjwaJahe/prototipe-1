$root='C:\Users\LENOVO\Documents\prototipe-1'
$current=Join-Path $root 'Kelas_10_A_Furniture.tscn'
$source=Join-Path $root 'Kelas_10_A_Furniture.tscn.before_replace_with_experiment_20261010.bak'
$cur=[System.IO.File]::ReadAllText($current)
$old=[System.IO.File]::ReadAllText($source)
$stamp=Get-Date -Format 'yyyyMMdd_HHmmss'
$backup="$current.before_restore_board_$stamp.bak"
Copy-Item $current $backup
function Get-Blocks([string]$text,[string]$kind) {
  $pattern='(?ms)^\['+[regex]::Escape($kind)+'[^\r\n]*\].*?(?=^\[|\z)'
  return [regex]::Matches($text,$pattern) | ForEach-Object { $_.Value }
}
$curSubs=@(Get-Blocks $cur 'sub_resource')
$oldSubs=@(Get-Blocks $old 'sub_resource')
$ids=@{}
foreach($b in $curSubs) { if($b -match '^\[sub_resource[^\r\n]*\bid="([^"]+)"') { $ids[$Matches[1]]=$true } }
$addSubs=@()
foreach($b in $oldSubs) { if($b -match '^\[sub_resource[^\r\n]*\bid="([^"]+)"') { $id=$Matches[1]; if(-not $ids.ContainsKey($id)) { $addSubs+=,$b; $ids[$id]=$true } } }
$oldNodes=@(Get-Blocks $old 'node')
$targetNodes=@()
foreach($b in $oldNodes) {
  $h=($b -split '\r?\n')[0]
  if(($h -match '\bname="(Whiteboard|Cupboard)"') -or ($h -match '\bparent="[^"]*/(Whiteboard|Cupboard)(/[^"]*)?"')) { $targetNodes+=,$b }
}
if(-not ($targetNodes | Where-Object { ($_ -split '\r?\n')[0] -match '\bname="Whiteboard"' })) { throw 'STOP: Whiteboard root not found' }
if(-not ($targetNodes | Where-Object { ($_ -split '\r?\n')[0] -match '\bname="Cupboard"' })) { throw 'STOP: Cupboard root not found' }
$existingHeaders=@(Get-Blocks $cur 'node' | ForEach-Object { ($_ -split '\r?\n')[0] })
foreach($b in $targetNodes) {
  $h=($b -split '\r?\n')[0]
  if($h -in $existingHeaders) { throw "STOP: duplicate node header $h" }
  if($h -match '\bunique_id=(\d+)') {
    $uid=$Matches[1]
    foreach($eh in $existingHeaders) { if($eh -match ('\bunique_id='+$uid+'\b')) { throw "STOP: duplicate unique_id $uid" } }
  }
}
$addition=($addSubs -join "`r`n`r`n")+"`r`n`r`n"+($targetNodes -join "`r`n`r`n")
[System.IO.File]::WriteAllText($current, $cur.TrimEnd()+"`r`n`r`n"+$addition+"`r`n", [System.Text.UTF8Encoding]::new($false))
Write-Output "Backup: $backup"
Write-Output "Added subresources: $($addSubs.Count)"
Write-Output "Restored board/cupboard nodes: $($targetNodes.Count)"