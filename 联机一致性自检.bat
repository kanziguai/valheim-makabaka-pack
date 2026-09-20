@echo off
chcp 65001 >nul
title MAKABAKA 联机一致性自检
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0联机一致性自检.ps1" %*
echo.
echo 把生成的 一致性_xxx.txt 和上面的指纹发给房主；房主跑：
echo   powershell -NoProfile -ExecutionPolicy Bypass -File .\联机一致性自检.ps1 -Compare 甲.txt,乙.txt
echo.
pause
