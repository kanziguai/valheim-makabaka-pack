<#
  只换 VRM 模型（不重装 mod 档）—— 转发给同目录的 install.ps1 -VRMOnly

  用法：
    · 双击 换模型.bat（推荐，等价于本文件）
    · 或命令行： powershell -NoProfile -ExecutionPolicy Bypass -File .\换模型.ps1
  可选参数会原样传给 install.ps1：
    -VrmModel 金乌-毛绒派对|辰星|<.vrm 路径>  指定模型（不给就弹菜单选）
    -ListModels                       只列出可选模型（★已缓存/↓需下载）后退出，不动任何文件
    -Models "金乌-毛绒派对,辰星"       预选要下载并缓存的模型（可多选）
    -ModelPath <.vrm 文件|目录>        用本地的模型文件（自己下的/别人发的）
    -CharName 你的角色名              指定角色名（不给就问）
    -GameDir <游戏目录>               指定 Valheim 目录（找不到时会问）
    -ProfilesRoot <档目录>            指定 r2modman 档目录（只用于①插件自检）
  ─ 它只做 VRM 的第③步（模型与设置）+ ①②自检；不会改动 r2modman 的档。
#>
$ErrorActionPreference = "Stop"
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$target = Join-Path $here "install.ps1"
if (-not (Test-Path $target)) {
    Write-Host "[x] 没找到 install.ps1 —— 它必须和 换模型.ps1 放在同一个目录里。" -ForegroundColor Red
    exit 1
}
& $target -VRMOnly @args
exit $LASTEXITCODE
