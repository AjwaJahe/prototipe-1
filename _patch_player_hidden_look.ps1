$ErrorActionPreference='Stop'
Set-Location 'C:\Users\LENOVO\Documents\prototipe-1'
$p=Get-Content 'Player.gd' -Raw
$pattern='(?m)^(func _unhandled_input\(event: InputEvent\) -> void:\r?\n)(\s*# Input tetap dikunci saat cutscene/drag; pemain KO boleh melihat arah merangkak\.)'
if (-not [regex]::IsMatch($p,$pattern)) {
  if ($p.Contains('Kamera dikunci ke celah peti selama bersembunyi.')) { Write-Output 'Already patched'; exit 0 }
  throw 'Player input marker missing; no change made.'
}
$nl=[Environment]::NewLine
$insert='$1    # Kamera dikunci ke celah peti selama bersembunyi.'+$nl+'    if bool(get_meta("is_hidden", false)):'+$nl+'        return'+$nl+'    # Input tetap dikunci saat cutscene/drag; pemain KO boleh melihat arah merangkak.'
$p=[regex]::Replace($p,$pattern,$insert,1)
$tmp='Player.gd.crate_patch.tmp'
Set-Content $tmp -Value $p -NoNewline -Encoding utf8
Move-Item -LiteralPath $tmp -Destination 'Player.gd' -Force
Write-Output ('hidden input guard='+(Select-String -Path Player.gd -Pattern 'Kamera dikunci ke celah peti').Count)
