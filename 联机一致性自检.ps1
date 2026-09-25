# ============================================================================
#  MAKABAKA 联机一致性自检（P2P / 房主即服务端）
#  每个玩家跑一遍 → 生成自己的指纹文件 → 房主用 -Compare 比对，找出差异
#
#  用法（在 r2modman 档目录外的任意位置都行）：
#    1) 生成自己的指纹：
#       powershell -NoProfile -ExecutionPolicy Bypass -File .\联机一致性自检.ps1
#       （默认自动找 %APPDATA%\r2modmanPlus-local\Valheim\profiles\MAKABAKA）
#       指定档目录： -Profile "D:\...\profiles\MAKABAKA"
#
#    2) 房主比对几个人交上来的文件（可多个）：
#       powershell -NoProfile -ExecutionPolicy Bypass -File .\联机一致性自检.ps1 -Compare 一致性_甲.txt,一致性_乙.txt,一致性_丙.txt
#
#  输出：一致性_<电脑名>_<日期>.txt（发给房主即可）
# ============================================================================
param(
    [string]$Profile = "",
    [string]$OutDir = "",
    [string[]]$Compare = @()
)
$ErrorActionPreference = "Stop"
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { }   # 控制台按 UTF-8 输出，中文不乱码
$Culture = [System.Globalization.CultureInfo]::InvariantCulture
function W($msg, $color = "Gray") { Write-Host $msg -ForegroundColor $color }
# ---- 需要"严格一致"的关键配置（这些差异会导致物品/数值不同步）----
$CriticalCfg = @(
    "Azumatt.AzuExtendedPlayerInventory.cfg",
    "randyknapp.mods.epiclooot.cfg", "randyknapp.mods.epicloot.cfg",
    "shudnal.ItemStacksItemWeights.cfg",
    "Azumatt.Recycle_N_Reclaim.cfg",
    "Azumatt.PetPantry.cfg",
    "TastyChickenLegs.HoneyPlease.cfg",
    "kompjoefriek.FermenterUtilities.cfg",
    "advize.PlantEasily.cfg",
    "Skarif.AutoRepairBuilding.cfg",
    "Azumatt.Hooked.cfg"
)
function Get-Md5([string]$path) {
    try { return (Get-FileHash -LiteralPath $path -Algorithm MD5).Hash.ToLower() } catch { return "" }
}
function Find-Profile([string]$given) {
    if ($given -and (Test-Path $given)) { return (Resolve-Path $given).Path }
    $base = Join-Path $env:APPDATA "r2modmanPlus-local\Valheim\profiles"
    if (Test-Path $base) {
        $hit = Get-ChildItem -LiteralPath $base -Directory | Where-Object { $_.Name -like "MAKABAKA*" } |
               Sort-Object Name | Select-Object -First 1
        if ($hit) { return $hit.FullName }
        $any = Get-ChildItem -LiteralPath $base -Directory | Select-Object -First 1
        if ($any) { return $any.FullName }
    }
    return ""
}
# ---- 解析 mods.yml（不依赖 YAML 库）----
function Read-Mods([string]$profile) {
    $p = Join-Path $profile "mods.yml"
    if (-not (Test-Path $p)) { return @() }
    $lines = Get-Content -LiteralPath $p -Encoding UTF8
    $out = @(); $cur = $null
    foreach ($l in $lines) {
        if ($l -match '^\s*-\s+manifestVersion:') { if ($cur) { $out += $cur }; $cur = [ordered]@{ name = ""; ver = ""; enabled = "true" } ; continue }
        if (-not $cur) { continue }
        if ($l -match '^\s+name:\s*(\S+)')      { $cur.name = $Matches[1] }
        if ($l -match '^\s+enabled:\s*(\S+)')   { $cur.enabled = $Matches[1] }
        if ($l -match '^\s+major:\s*(\d+)')     { $cur.v1 = $Matches[1] }
        if ($l -match '^\s+minor:\s*(\d+)')     { $cur.v2 = $Matches[1] }
        if ($l -match '^\s+patch:\s*(\d+)')     { $cur.v3 = $Matches[1] }
        if ($l -match '^\s+build:\s*(\d+)')     { $cur.v4 = $Matches[1] }
    }
    if ($cur) { $out += $cur }
    foreach ($m in $out) {
        $ver = @()
        foreach ($k in @("v1", "v2", "v3", "v4")) { if ($m.Contains($k)) { $ver += $m[$k] } }
        $m.ver = ($ver -join ".")
    }
    return $out
}
function Snapshot([string]$profile) {
    $dlls = @{}
    $pl = Join-Path $profile "BepInEx\plugins"
    if (Test-Path $pl) {
        foreach ($f in (Get-ChildItem -LiteralPath $pl -Recurse -Filter *.dll -File -ErrorAction SilentlyContinue)) {
            $rel = $f.FullName.Substring($pl.Length).TrimStart("\")
            $dlls[$rel] = (Get-Md5 $f.FullName)
        }
    }
    $core = @{}
    $cd = Join-Path $profile "BepInEx\core"
    if (Test-Path $cd) {
        foreach ($f in (Get-ChildItem -LiteralPath $cd -Filter *.dll -File -ErrorAction SilentlyContinue)) { $core[$f.Name] = (Get-Md5 $f.FullName) }
    }
    $cfgs = @{}
    $cf = Join-Path $profile "BepInEx\config"
    if (Test-Path $cf) {
        foreach ($f in (Get-ChildItem -LiteralPath $cf -Recurse -Include *.cfg -File -ErrorAction SilentlyContinue)) {
            $rel = $f.FullName.Substring($cf.Length).TrimStart("\")
            $cfgs[$rel] = (Get-Md5 $f.FullName)
        }
    }
    return [pscustomobject]@{ Profile = $profile; Mods = (Read-Mods $profile); Dll = $dlls; Core = $core; Cfg = $cfgs }
}
function Fingerprint($snap) {
    $sb = New-Object System.Text.StringBuilder
    foreach ($m in ($snap.Mods | Sort-Object { $_.name })) { [void]$sb.AppendLine("M|$($m.name)|$($m.ver)|$($m.enabled)") }
    foreach ($k in ($snap.Core.Keys | Sort-Object)) { [void]$sb.AppendLine("C|$k|$($snap.Core[$k])") }
    foreach ($k in ($snap.Dll.Keys | Sort-Object))  { [void]$sb.AppendLine("D|$k|$($snap.Dll[$k])") }
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($sb.ToString())
    $sha = [System.Security.Cryptography.SHA256]::Create().ComputeHash($bytes)
    return (($sha | ForEach-Object { $_.ToString("x2") }) -join "")
}
function Write-Report($snap, [string]$outFile) {
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.AppendLine("# MAKABAKA 联机一致性指纹")
    [void]$sb.AppendLine("生成时间 = $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')")
    [void]$sb.AppendLine("电脑名   = $env:COMPUTERNAME")
    [void]$sb.AppendLine("档目录   = $($snap.Profile)")
    [void]$sb.AppendLine("BepInEx  = $(if (Test-Path "$($snap.Profile)\BepInEx\core\BepInEx.dll") { (Get-Item "$($snap.Profile)\BepInEx\core\BepInEx.dll").VersionInfo.FileVersion } else { '?' })")
    [void]$sb.AppendLine("指纹     = $(Fingerprint $snap)")
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("[MODS] 启用状态 | 名称 | 版本")
    foreach ($m in ($snap.Mods | Sort-Object { $_.name })) {
        [void]$sb.AppendLine("MOD|$($m.name)|$($m.ver)|$($m.enabled)")
    }
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("[插件 DLL] 相对路径 | MD5（$(($snap.Dll.Keys).Count) 个）")
    foreach ($k in ($snap.Dll.Keys | Sort-Object)) { [void]$sb.AppendLine("DLL|$k|$($snap.Dll[$k])") }
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("[BepInEx core] 名称 | MD5")
    foreach ($k in ($snap.Core.Keys | Sort-Object)) { [void]$sb.AppendLine("CORE|$k|$($snap.Core[$k])") }
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("[配置文件] 相对路径 | MD5（★ = 必须一致的关键配置）")
    foreach ($k in ($snap.Cfg.Keys | Sort-Object)) {
        $star = if ($CriticalCfg -contains (Split-Path $k -Leaf)) { "★" } else { " " }
        [void]$sb.AppendLine("CFG|$star$k|$($snap.Cfg[$k])")
    }
    Set-Content -LiteralPath $outFile -Value $sb.ToString() -Encoding UTF8
}
# ---------------- 比对模式 ----------------
# 把报告解析成扁平表： "MOD|名字" -> "版本|启用" 等（用 LastIndexOf 切分，键里有 ★/空格也不怕）
function Read-Flat([string]$file) {
    $h = @{}
    foreach ($l in (Get-Content -LiteralPath $file -Encoding UTF8)) {
        if ($l -match '^([A-Z]+)\|(.*)$') {
            $type = $Matches[1]
            $rest = $Matches[2]
            if ($type -eq "MOD") { $i = $rest.IndexOf("|") } else { $i = $rest.LastIndexOf("|") }
            if ($i -lt 0) { $h["$type|" + $rest] = "" }
            else { $h["$type|" + $rest.Substring(0, $i)] = $rest.Substring($i + 1) }
        }
        elseif ($l -match '^\s*(\S+)\s*=\s*(.+)$') { $h["META|" + $Matches[1]] = $Matches[2].Trim() }
    }
    return $h
}

function Short-Label($flat) {
    $pc = ""; if ($flat.ContainsKey("META|电脑名")) { $pc = $flat["META|电脑名"] }
    $pf = ""; if ($flat.ContainsKey("META|档目录")) { $pf = Split-Path ($flat["META|档目录"]) -Leaf }
    return ("{0}({1})" -f $pc, $pf)
}

function Compare-Reports([string[]]$files) {
    $snaps = @()
    foreach ($f in $files) {
        if (-not (Test-Path $f)) { W "  [跳过] 找不到 $f" "Yellow"; continue }
        $flat = Read-Flat $f
        $snaps += [pscustomobject]@{ File = $f; Flat = $flat; Label = (Short-Label $flat) }
    }
    if ($snaps.Count -lt 2) { W "  至少给两个指纹文件才能比对。" "Yellow"; return }

    W ""
    W "================ 比对结果 ================" "Cyan"
    foreach ($s in $snaps) {
        W ("{0,-30} 指纹 {1}" -f $s.Label, $s.Flat["META|指纹"])
    }

    function Diff-Type([string]$type, [string]$title, [string]$color) {
        $keys = @{}
        foreach ($s in $snaps) {
            foreach ($k in $s.Flat.Keys) {
                if ($k.StartsWith($type + "|")) { $keys[$k] = 1 }
            }
        }
        $diff = @()
        foreach ($k in ($keys.Keys | Sort-Object)) {
            $vals = @()
            foreach ($s in $snaps) { $v = "（缺）"; if ($s.Flat.ContainsKey($k)) { $v = $s.Flat[$k] }; $vals += $v }
            if (($vals | Select-Object -Unique).Count -gt 1) { $diff += [pscustomobject]@{ Key = $k.Substring($type.Length + 1); Vals = $vals } }
        }
        if ($diff.Count -eq 0) { W ("`n[{0}] 全部一致 ✓" -f $title) "Green" }
        else {
            W ("`n[{0}] 有差异 {1} 项：" -f $title, $diff.Count) $color
            foreach ($d in $diff) {
                W ("  · {0}" -f $d.Key) $color
                for ($i = 0; $i -lt $snaps.Count; $i++) {
                    $v = $d.Vals[$i]
                    if ($type -eq "MOD" -and $v -ne "（缺）") {
                        $v = $v -replace '\|true$', ' · 启用' -replace '\|false$', ' · 禁用'
                    }
                    W ("      {0,-30} {1}" -f $snaps[$i].Label, $v)
                }
            }
        }
    }

    Diff-Type "MOD" "MOD 名称/版本/启用状态" "Yellow"
    Diff-Type "CORE" "BepInEx core" "Yellow"
    Diff-Type "DLL" "插件 DLL（版本号相同但 DLL 不同 = 手动替换过，最容易出问题）" "Red"

    # 关键配置只报 ★ 的
    W "`n[关键配置 ★]（这些不一致 = 物品/数值可能不同步）："
    $critKeys = @{}
    foreach ($s in $snaps) { foreach ($k in $s.Flat.Keys) { if ($k.StartsWith("CFG|★")) { $critKeys[$k] = 1 } } }
    $hit = 0
    foreach ($k in ($critKeys.Keys | Sort-Object)) {
        $vals = @()
        foreach ($s in $snaps) { $v = "（缺）"; if ($s.Flat.ContainsKey($k)) { $v = $s.Flat[$k] }; $vals += $v }
        if (($vals | Select-Object -Unique).Count -gt 1) {
            $hit++
            W ("  · {0}" -f $k.Substring(5)) "Red"
            for ($i = 0; $i -lt $snaps.Count; $i++) { W ("      {0,-30} {1}" -f $snaps[$i].Label, $vals[$i]) }
        }
    }
    if ($hit -eq 0) { W "  全部一致 ✓" "Green" }
    W ""
    W "结论：MOD 与插件 DLL 都一致 → 物品/世界数据同步基本安全；关键配置不一致的人，用完整安装包覆盖一次再进。" "Cyan"
}

# ---------------- 入口 ----------------
if ($Compare.Count -gt 0) {
    # 支持 -Compare a.txt,b.txt 或 -Compare a.txt b.txt 或 -Compare "a.txt, b.txt"
    $list = @()
    foreach ($x in $Compare) {
        foreach ($y in ($x -split "[,，;；]")) {
            $v = $y.Trim().Trim('"').Trim("'")
            if ($v) { $list += $v }
        }
    }
    Compare-Reports $list
    exit 0
}
$prof = Find-Profile $Profile
if (-not $prof) {
    W "[×] 找不到 r2modman 的档目录。请用 -Profile 指定，例如：" "Red"
    W '    -Profile "C:\Users\你\AppData\Roaming\r2modmanPlus-local\Valheim\profiles\MAKABAKA"' "Gray"
    exit 1
}
W "档目录：$prof" "Cyan"
$snap = Snapshot $prof
if (-not $OutDir) { $OutDir = (Get-Location).Path }
if (-not (Test-Path $OutDir)) { $OutDir = (Get-Location).Path }
$outFile = Join-Path $OutDir ("一致性_{0}_{1}_{2}.txt" -f $env:COMPUTERNAME, (Split-Path $prof -Leaf), (Get-Date -Format "yyyyMMdd"))
Write-Report $snap $outFile
W ""
W "================ 本机自检 ================" "Cyan"
W ("  mod 数      : {0}（启用 {1} / 禁用 {2}）" -f $snap.Mods.Count, (@($snap.Mods | Where-Object { $_.enabled -eq "true" }).Count), (@($snap.Mods | Where-Object { $_.enabled -ne "true" }).Count))
W ("  插件 DLL    : {0} 个" -f $snap.Dll.Count)
W ("  配置文件    : {0} 个" -f $snap.Cfg.Count)
W ""
W ("  指纹（发给房主对档）: {0}" -f (Fingerprint $snap)) "Yellow"
W ("  详细清单           : {0}" -f $outFile) "Yellow"
W ""
W "把这两个东西发给房主，让他跑： -Compare 一致性_*.txt" "Gray"
