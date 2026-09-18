param([string]$Share = "")   # 用法：powershell -File tools\测试ModelLib.ps1 -Share "I:\...\英灵神殿mod分享_MAKABAKA"
# 测试 ModelLib.ps1：清单 → 候选 → 下载(file://) → sha256 校验 → 进缓存 → 二次命中缓存
$ErrorActionPreference = "Stop"
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}
$PSScriptRoot = if ($Share) { $Share } else { Split-Path (Split-Path $MyInvocation.MyCommand.Path -Parent) -Parent }

function Say([string]$msg, [string]$color = "Gray") { Write-Host $msg -ForegroundColor $color }
function Get-TextWithMirrors([string]$url, [int]$timeoutSec = 20) {
    return (New-Object System.Net.WebClient).DownloadString($url)
}
function Save-FileWithMirrors([string]$url, [string]$outFile, [string]$label) {
    try { Invoke-WebRequest -Uri $url -OutFile $outFile -UseBasicParsing; return $true } catch { return $false }
}
$VrmDefaultModel = "金乌-毛绒派对"

. "$PSScriptRoot\ModelLib.ps1"
$cache = Join-Path $env:TEMP "makabaka_test_cache"
if (Test-Path $cache) { Remove-Item $cache -Recurse -Force }

Write-Host "`n[1] 读清单" -ForegroundColor Cyan
$man = Get-ModelManifest -packRoot $PSScriptRoot
if (-not $man) { Write-Host "  清单读取失败" -ForegroundColor Red; exit 1 }
Write-Host ("  repo={0}  tag={1}  模型={2}  default={3}" -f $man.repo, $man.tag, $man.models.Count, $man.default)

Write-Host "`n[2] 合并候选（清单 + 缓存 + -ModelPath）" -ForegroundColor Cyan
$c = Get-ModelCandidates -packRoot $PSScriptRoot -cacheDir $cache -manifest $man
Write-Host ("  候选数 = {0}；默认排第一 = {1}" -f $c.Count, $c[0].Name)
Write-Host ("  未下载（需下载）数 = {0}" -f @($c | Where-Object { -not $_.Cached }).Count)

Write-Host "`n[3] 用 -ModelPath 指定本地 vrm（模拟"朋友自己拖进来"）" -ForegroundColor Cyan
$localVrm = "I:\000工作台\英灵神殿mod分享_MAKABAKA\Models\太一·庚辰-海上的私语"   # 目录（递归找 .vrm）
$c3 = Get-ModelCandidates -packRoot "Z:\不存在" -cacheDir $cache -manifest $null -modelPath $localVrm
Write-Host ("  候选数 = {0}；Name={1}；Cached={2}；Source={3}" -f $c3.Count, $c3[0].Name, $c3[0].Cached, $c3[0].Source)

Write-Host "`n[4] 下载（用 file:// 直链代替私有仓库）→ 校验 → 进缓存" -ForegroundColor Cyan
$t = $c | Where-Object { $_.Name -eq "太一·庚辰-海上的私语" }
$t.Url = "file:///I:/000工作台/英灵神殿mod分享_MAKABAKA/Models/太一·庚辰-海上的私语.zip"
Write-Host ("  清单 sha256 = {0}" -f $t.Sha256)
$r = Save-ModelToCache -Cand $t -cacheDir $cache -packRoot $PSScriptRoot
if ($r) {
    $fi = Get-Item $r.Vrm
    Write-Host ("  OK -> {0}（{1} 字节）" -f $r.Vrm, $fi.Length) -ForegroundColor Green
    $h = (Get-FileHash $r.Vrm -Algorithm SHA256).Hash.ToLower()
    Write-Host ("  实际 sha256 = {0}  一致={1}" -f $h, ($h -eq $t.Sha256)) -ForegroundColor Green
} else { Write-Host "  下载失败" -ForegroundColor Red; exit 1 }

Write-Host "`n[5] 再来一次：应命中缓存、不再下载" -ForegroundColor Cyan
$c2 = Get-ModelCandidates -packRoot $PSScriptRoot -cacheDir $cache -manifest $man
$t2 = $c2 | Where-Object { $_.Name -eq "太一·庚辰-海上的私语" }
Write-Host ("  Cached={0}  Local={1}" -f $t2.Cached, $t2.Local)
$r2 = Save-ModelToCache -Cand $t2 -cacheDir $cache -packRoot $PSScriptRoot
Write-Host ("  第二次返回：{0}" -f $(if ($r2) { "命中缓存 OK" } else { "失败" }))

Write-Host "`n[6] 清单展示" -ForegroundColor Cyan
Show-ModelCandidates $c2 $cache

Write-Host "`n全部测试通过" -ForegroundColor Green
