@echo off
chcp 65001 >nul 2>&1
title Valheim MAKABAKA - VRM model switcher (only VRM)
setlocal
set "HERE=%~dp0"
set "PS1=%HERE%install.ps1"
if not exist "%PS1%" (
  echo.
  echo [x] install.ps1 was not found next to this file.
  echo     Please keep this .bat and install.ps1 in the same folder.
  echo.
  pause
  exit /b 1
)
findstr /c:"VRMOnly" "%PS1%" >nul 2>&1
if errorlevel 1 (
  echo.
  echo [x] 这个 install.ps1 是旧版（不支持只换模型）。
  echo     请把新版 install.ps1 放到本目录（仓库里那份），或直接从仓库运行：
  echo       git clone https://github.com/kanziguai/valheim-makabaka-pack
  echo.
  pause
  exit /b 1
)
powershell -NoProfile -ExecutionPolicy Bypass -File "%PS1%" -VRMOnly %*
if errorlevel 1 (
  echo.
  echo [x] Did not finish. See the message above / the log on your Desktop.
  echo.
  pause
)
endlocal
