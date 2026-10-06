@echo off
powershell -NoProfile -Command "(Get-Content 'C:\Users\LENOVO\Documents\prototipe-1\_test.txt' -Raw).Replace('A','B') | Set-Content 'C:\Users\LENOVO\Documents\prototipe-1\_test.txt' -NoNewline"
