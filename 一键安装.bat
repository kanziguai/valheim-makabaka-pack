@echo off
chcp 65001 >nul 2>&1
title 英灵神殿 MAKABAKA 一键安装
setlocal
set "HERE=%~dp0"
set "PS1=%HERE%install.ps1"
if not exist "%PS1%" (
  echo.
  echo [x] 未找到同目录下的 install.ps1。
  echo     请将本 bat 文件和 install.ps1 放在同一个文件夹中。
  echo.
  pause
  exit /b 1
)
powershell -NoProfile -ExecutionPolicy Bypass -File "%PS1%" %*
if errorlevel 1 (
  echo.
  echo [x] 安装未完成，请查看上方提示或桌面上的安装日志。
  echo.
  pause
)
endlocal
