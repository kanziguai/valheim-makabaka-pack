<#
  英灵神殿 MAKABAKA 整合档 —— 一键安装 / 一键升级
  把本包里的 MAKABAKA 档安装进 r2modman（%APPDATA%\r2modmanPlus-local\Valheim\profiles\）

  用法（双击 一键安装.bat 即可，本文件不用手动运行）：
    没装过 → 全新安装；装过旧版 → 原地升级（保留你的设置与收藏，旧文件先备份）
    同目录里没有安装包时 → 自动从 GitHub Release 下载最新版（镜像优先，下完自动校验）
  命令行参数（一般用不到）：
    -ProfilesRoot <路径>   直接指定 profiles 目录（不给就自动探测）
    -PackFile <路径>       直接用指定的本地 zip（跳过自动查找）
    -PackUrl <url>         直接从指定 URL 下载包（http/https/file 都行）
    -Offline               只用本地文件，绝不联网下载
    -ReleaseRepo <o/r>     换成别的 GitHub 仓库（默认见脚本里的 $ReleasesRepo）
    -NonInteractive        不提问：自动关 r2modman、已装过则默认走"升级"
    -Fresh                 已装过时强制"全新重装"（旧档改名备份）
    -DetectOnly            只显示"探测到的 profiles 目录"然后退出（不动任何文件）
    -NoRemember            不使用/不写入 install-path.txt（不记住上次的路径）
    -GameDir <路径>        指定 Valheim 游戏目录（一般不填，脚本自己找 Steam 库）
    -SkipVRM               跳过"附加：ValheimVRM"这一步（只想装档、不碰游戏目录时用）

  关于 r2modman 装在别的盘：r2modman 的"数据文件夹"可以用 设置→Locations→Change data folder
  挪到别的盘，所以本脚本按以下顺序找（找到就用）：
    ① 命令行 -ProfilesRoot 指定 ② 上次记住的 install-path.txt ③ r2modman 自己记录过的路径
    ④ 默认位置（%APPDATA%\r2modmanPlus-local 等，含通过符号链接/联结点搬家的情况）
    ⑤ 逐个扫描所有固定硬盘（找 r2modmanPlus-local 或含 <游戏>\profiles 的目录）
    ⑥ 实在找不到就问你要路径（r2modman→设置→Locations→Browse data folder）
#>
param(
    [string]$ProfilesRoot = "",
    [string]$ProfileName = "MAKABAKA",
    [switch]$NonInteractive,
    [switch]$Fresh,
    [switch]$DetectOnly,
    [switch]$NoRemember,
    [string]$GameDir = "",
    [switch]$SkipVRM,
    [string]$PackFile = "",
    [string]$PackUrl = "",
    [switch]$Offline,
    [string]$ReleaseRepo = "",
    [string]$ReleaseBase = ""
)

$ErrorActionPreference = "Stop"
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}
$OutputEncoding = [System.Text.Encoding]::UTF8

# ---------- 出厂校验值（不一致只提示，不阻断）----------
$Expect = @{
    "BepInEx\plugins\jg224-ChestFlow\ChestFlow.dll"       = "a749310465c4fa9a260f66a4b91f11ff"
    "BepInEx\plugins\ChestFlowTweaks\ChestFlowTweaks.dll" = "4c7460dc819a46bd1905f5ef5bc0fb7b"
    "BepInEx\plugins\RandyKnapp-EpicLoot\EpicLoot.dll"    = "56c35cd9125ef7f9e43c90c77f9dfa6e"
    "BepInEx\plugins\blacks7ar-Endurance\Endurance.dll"   = "5e632a79528a5fe12c792afbb95e7d65"
    "BepInEx\plugins\VRMGhostFix\VRMGhostFix.dll"         = "297936525d808cfdd38b33da54eeb87c"
    "BepInEx\plugins\Skarif-AutoRepairBuilding\AutoRepairBuilding.dll" = "3519ae6136d816dbc49425f002ed3447"
    "BepInEx\plugins\SafeBox\SafeBox.dll" = "5fbea845657a211ca7749026a6ae0fff"
    "BepInEx\plugins\KeepBuffsOnDeath\KeepBuffsOnDeath.dll" = "6fc8037642f4bc4508d585312525e191"
    "BepInEx\plugins\Azumatt-AzuExtendedPlayerInventory\AzuExtendedPlayerInventory.dll" = "8d9f4ac43884e64fb0fafa08b04f609c"
}

# ---------- 在线安装：本地没有包时，从 GitHub Release 取最新版 ----------
$ReleasesRepo   = "OWNER/valheim-makabaka-pack"      # ← GitHub 仓库（owner/repo）
$ReleaseLatest  = "https://github.com/$ReleasesRepo/releases/latest/download"
$SumAssetName   = "SHA256SUMS.txt"                   # Release 里固定名字的校验清单附件
$MirrorPrefixes = @("https://ghfast.top/", "https://ghproxy.net/", "")   # "" = 直连，放最后
# 联网拿不到校验清单时的兜底（每次发新版由仓库同步更新，随脚本一起走）
$FallbackAsset   = "MAKABAKA_profile_v1.0_20260915.zip"
$FallbackMd5     = "b6e36ae8b042344f0da02ddb4d93d844"
$script:CacheDir = Join-Path $env:TEMP "makabaka_pack"

if (-not [string]::IsNullOrWhiteSpace($ReleaseRepo)) {
    $ReleasesRepo  = $ReleaseRepo.Trim()
    $ReleaseLatest = "https://github.com/$ReleasesRepo/releases/latest/download"
}
# 自建镜像/自测时可以直接改这一项（指向"放 zip 与 SHA256SUMS.txt 的目录"）
if (-not [string]::IsNullOrWhiteSpace($ReleaseBase)) { $ReleaseLatest = $ReleaseBase.Trim().TrimEnd('/') }

try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch {}

# 把 GitHub 链接展开成"镜像优先 + 直连兜底"的候选列表
function Get-MirroredUrls([string]$url) {
    if ($url -notmatch '^https://') { return @($url) }
    if ($url -notmatch '^https://(github\.com|raw\.githubusercontent\.com|objects\.githubusercontent\.com)/') { return @($url) }
    $out = @()
    foreach ($m in $MirrorPrefixes) { $out += ($m + $url) }
    return @($out | Select-Object -Unique)
}

# 取一段文本（小文件），多线路依次试
function Get-TextWithMirrors([string]$url, [int]$timeoutSec = 20) {
    foreach ($u in (Get-MirroredUrls $url)) {
        try {
            $req = [System.Net.HttpWebRequest]::Create($u)
            $req.Timeout = $timeoutSec * 1000
            $req.UserAgent = "makabaka-install"
            $resp = $req.GetResponse()
            $sr = New-Object System.IO.StreamReader($resp.GetResponseStream(), [System.Text.Encoding]::UTF8)
            $txt = $sr.ReadToEnd()
            $sr.Close(); $resp.Close()
            if (-not [string]::IsNullOrWhiteSpace($txt)) { return $txt }
        } catch {}
    }
    return $null
}

# 下载一个大文件，带百分比进度，多线路依次试；全部失败返回 $false
function Save-FileWithMirrors([string]$url, [string]$outFile, [string]$label) {
    $urls = @(Get-MirroredUrls $url)
    $i = 0
    foreach ($u in $urls) {
        $i++
        $line = "第 $i/$($urls.Count) 条线路"
        try {
            $h = ([Uri]$u).Host
            if ([string]::IsNullOrWhiteSpace($h)) { $line = $line + "：本地文件" } else { $line = $line + "：" + $h }
        } catch {}
        Say "        下载中（$label，$line）…" "DarkGray"
        $wc = $null
        try {
            $wc = New-Object System.Net.WebClient
            $wc.Headers.Add("User-Agent", "makabaka-install")
            $script:dlLastPct = -5
            $script:dlLastAt  = Get-Date
            $wc.add_DownloadProgressChanged({
                param($s, $e)
                $pct = 0
                if ($e.TotalBytesToReceive -gt 0) { $pct = [int](100 * $e.BytesReceived / $e.TotalBytesToReceive) }
                $now = Get-Date
                if (($pct -ge ($script:dlLastPct + 5)) -or ($pct -ge 100) -or (($now - $script:dlLastAt).TotalSeconds -ge 10)) {
                    $script:dlLastPct = $pct
                    $script:dlLastAt  = $now
                    $mb = [math]::Round($e.BytesReceived / 1MB, 1)
                    $tot = if ($e.TotalBytesToReceive -gt 0) { [math]::Round($e.TotalBytesToReceive / 1MB, 1) } else { "?" }
                    Write-Host ("          $pct%   $mb MB / $tot MB") -ForegroundColor DarkGray
                }
            })
            $wc.DownloadFile($u, $outFile)
            $wc.Dispose()
            return $true
        } catch {
            if ($wc) { try { $wc.Dispose() } catch {} }
            Say "        这条线路失败：$($_.Exception.Message)" "DarkGray"
            if (Test-Path $outFile) { Remove-Item $outFile -Force -ErrorAction SilentlyContinue }
        }
    }
    return $false
}

# 解析校验清单（key=value 行）
function Read-SumManifest([string]$text) {
    $m = @{}
    foreach ($line in ($text -split "`r?`n")) {
        if ($line -match '^\s*([A-Za-z0-9_]+)\s*=\s*(.+?)\s*$') { $m[$Matches[1].ToLower()] = $Matches[2] }
    }
    if ($m.ContainsKey("file") -and $m.ContainsKey("md5")) { return $m }
    return $null
}

# 解压安装包并返回"档源目录"（脚本里所有复制逻辑都用它）
function Expand-PackZip([string]$zipPath, [string]$zipLeaf) {
    if ($zipLeaf -match '_v([0-9][0-9.]*)(?:_([0-9]{8}))?\.zip$') {
        $script:packVer = "v" + $Matches[1]
        if ($Matches[2]) { $script:packVer = $script:packVer + "（" + $Matches[2] + "）" }
    } else { $script:packVer = "无版本号（旧包）" }
    $tmp = Join-Path $env:TEMP ("makabaka_" + (Get-Date -Format "HHmmss"))
    try {
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        [System.IO.Compression.ZipFile]::ExtractToDirectory($zipPath, $tmp)
    } catch { Fail "解压 $zipLeaf 失败：$($_.Exception.Message)" }
    $script:packTmpExtract = $tmp
    if (Test-Path (Join-Path $tmp "$ProfileName\mods.yml")) { return (Join-Path $tmp $ProfileName) }
    elseif (Test-Path (Join-Path $tmp "mods.yml")) { return $tmp }
    else { Fail "zip 里找不到 $ProfileName\mods.yml，包可能不完整。" }
}

$script:LogLines = New-Object System.Collections.Generic.List[string]
$script:LogPath = ""
$script:SelfFiles = @("一键安装.bat", "install.ps1", "安装日志.txt")
function Say([string]$msg, [string]$color = "Gray") {
    Write-Host $msg -ForegroundColor $color
    $script:LogLines.Add($msg)
}
function Section([string]$title) {
    Say ""
    Say ("=" * 62) "DarkCyan"
    Say "  $title" "Cyan"
    Say ("=" * 62) "DarkCyan"
}
function SaveLog() {
    $dir = if (Test-Path (Join-Path $env:USERPROFILE "Desktop")) { Join-Path $env:USERPROFILE "Desktop" } else { $env:TEMP }
    $p = Join-Path $dir "MAKABAKA安装日志.txt"
    $script:LogPath = $p
    try {
        $head = "MAKABAKA 一键安装日志  " + (Get-Date -Format "yyyy-MM-dd HH:mm:ss") + "`r`n"
        [System.IO.File]::WriteAllText($p, $head + ($script:LogLines -join "`r`n"), (New-Object System.Text.UTF8Encoding($true)))
    } catch {}
}
function Fail([string]$msg) {
    Say ""
    Say "[×] $msg" "Red"
    Say "    没装成功。把本窗口内容或桌面上的 MAKABAKA安装日志.txt 发给我们即可。" "Red"
    SaveLog
    Exit 1
}

Section "英灵神殿 MAKABAKA 整合档 一键安装 / 升级"
Say "  本脚本会：把本包里的 MAKABAKA 档装进 r2modman 的 profiles 目录。"
Say "  · 以前没装过 → 全新安装"
Say "  · 装过旧版   → 原地升级：更新 mod 文件，保留你自己的设置与收藏（旧文件先备份）"
Say "  你的世界存档、角色存档不会被碰。" "DarkGray"

# ---------- 1) 找源档（本地文件夹 → 本地 zip → 在线下载）----------
$src = $null
$script:packVer = ""
$script:packTmpExtract = ""

if (Test-Path (Join-Path $PSScriptRoot "$ProfileName\mods.yml")) {
    $src = Join-Path $PSScriptRoot $ProfileName
    Say "  [1/7] 源档：脚本同目录下的 $ProfileName 文件夹" "Green"
}
elseif ((Split-Path $PSScriptRoot -Leaf) -eq $ProfileName -and (Test-Path (Join-Path $PSScriptRoot "mods.yml"))) {
    $src = $PSScriptRoot
    Say "  [1/7] 源档：脚本所在的 $ProfileName 目录本身" "Green"
}
elseif (-not [string]::IsNullOrWhiteSpace($PackFile)) {
    if (-not (Test-Path $PackFile)) { Fail "-PackFile 指定的文件不存在：$PackFile" }
    $leaf = Split-Path $PackFile -Leaf
    Say "  [1/7] 源档：-PackFile 指定的 $leaf 解压中…" "Green"
    $src = Expand-PackZip $PackFile $leaf
    Say "        包版本：$($script:packVer)" "Green"
}
elseif ($zipItem = (Get-ChildItem -Path $PSScriptRoot -Filter "${ProfileName}_profile*.zip" -File |
                   Where-Object { $_.Name -notmatch '\.bak-' } |
                   Sort-Object LastWriteTime -Descending | Select-Object -First 1)) {
    Say "  [1/7] 源档：从 $($zipItem.Name) 解压中…" "Green"
    $src = Expand-PackZip $zipItem.FullName $zipItem.Name
    Say "        包版本：$($script:packVer)" "Green"
}
elseif ($Offline) {
    Fail "找不到源档，而且你用了 -Offline（不联网）。请把 MAKABAKA_profile*.zip 或 MAKABAKA 文件夹放到本脚本旁边，再运行本脚本。"
}
else {
    # ---- 在线安装：从 GitHub Release 取最新版（镜像优先 + 下载后校验）----
    Say "  [1/7] 本目录没有安装包 → 从 GitHub 获取最新版" "Green"
    if (-not (Test-Path $script:CacheDir)) { New-Item -ItemType Directory -Path $script:CacheDir -Force | Out-Null }

    $man = $null
    $zip = $null
    $zipLeaf = ""
    $dlUrl = ""

    if (-not [string]::IsNullOrWhiteSpace($PackUrl)) {
        $zipLeaf = Split-Path $PackUrl -Leaf
        if ([string]::IsNullOrWhiteSpace($zipLeaf)) { $zipLeaf = "MAKABAKA_profile_download.zip" }
        $zip = Join-Path $script:CacheDir $zipLeaf
        $dlUrl = $PackUrl.Trim()
        Say "        来源：-PackUrl 指定" "DarkGray"
        Say "        $dlUrl" "DarkGray"
    }
    else {
        Say "        取校验清单 $SumAssetName …"
        $manTxt = Get-TextWithMirrors "$ReleaseLatest/$SumAssetName"
        if ($manTxt) { $man = Read-SumManifest $manTxt }
        if ($man) {
            $zipLeaf = $man["file"]
            $zip = Join-Path $script:CacheDir $zipLeaf
            $dlUrl = "$ReleaseLatest/$zipLeaf"
            Say "        最新版本：$($man["version"])    包：$zipLeaf" "Green"
        } else {
            Say "        [注意] 没能从网上取到校验清单，改用本脚本内置的已知版本信息。" "Yellow"
            $zipLeaf = $FallbackAsset
            $zip = Join-Path $script:CacheDir $zipLeaf
            $dlUrl = "$ReleaseLatest/$zipLeaf"
            $man = @{ "version" = "未知（以包名为准）"; "file" = $FallbackAsset; "md5" = $FallbackMd5 }
            Say "        $zipLeaf" "Yellow"
        }
    }

    if (Test-Path $zip) {
        $h0 = (Get-FileHash -Path $zip -Algorithm MD5).Hash.ToLower()
        if ($man -and $h0 -eq $man["md5"]) {
            Say "        本地缓存里已有同版本包，校验通过，跳过下载 ✓" "Green"
        } else {
            Say "        本地缓存里的包校验不通过（或没有清单可比对），删掉重下。" "DarkGray"
            Remove-Item $zip -Force -ErrorAction SilentlyContinue
        }
    }

    if (-not (Test-Path $zip)) {
        $sizeTxt = ""
        if ($man -and $man.ContainsKey("size")) { $sizeTxt = "约 " + [math]::Round(([int64]$man["size"]) / 1MB, 1) + " MB，" }
        if (-not (Save-FileWithMirrors $dlUrl $zip ($sizeTxt + "多条线路自动重试"))) {
            Fail "下载失败：所有线路都连不上（也可能被防火墙拦了）。可以手动从 Release 页面下载 zip，放到本脚本旁边再运行本脚本。"
        }
        Say "        下载完成。" "Green"
    }

    Say "        校验下载到的包…"
    $h = (Get-FileHash -Path $zip -Algorithm MD5).Hash.ToLower()
    if ($man) {
        if ($h -ne $man["md5"]) {
            Remove-Item $zip -Force -ErrorAction SilentlyContinue
            Fail "包校验失败：下载到 $h，清单里是 $($man["md5"])。文件已删除，请重试（可能是下载被截断，或链路被动过）。"
        }
        Say "        MD5 一致 ✓  $h" "Green"
        if ($man.ContainsKey("size")) {
            $len = (Get-Item $zip).Length
            if ("$len" -ne "$($man["size"])") { Say "        [注意] 文件大小 $len 字节，与清单 $($man["size"]) 不一致" "Yellow" }
        }
    } else {
        Say "        （-PackUrl 指定，没有清单可比对）MD5：$h" "DarkGray"
    }

    Say "        解压中…"
    $src = Expand-PackZip $zip $zipLeaf
    Say "        包版本：$($script:packVer)" "Green"
}

if (-not $src) { Fail "没能定位到档源目录，请把日志发给我们。" }
$packRoot = Split-Path $src -Parent

# ---------- 2) 目标 profiles 目录（多路探测，支持数据文件夹被挪到别的盘）----------
$GameName = "Valheim"
$script:PathSource = ""
$rememberFile = Join-Path $PSScriptRoot "install-path.txt"

function Try-ProfilesRoot([string]$p) {
    if ([string]::IsNullOrWhiteSpace($p)) { return $null }
    $p = $p.Trim().Trim('"').TrimEnd('\')
    if ($p -eq "") { return $null }
    if ((Split-Path $p -Leaf) -eq "profiles") { if (Test-Path $p) { return $p } ; return $null }
    $cand = Join-Path $p "$GameName\profiles"
    if (Test-Path $cand) { return $cand }
    return $null
}
function Try-AnyProfilesRoot([string]$p) {
    if ([string]::IsNullOrWhiteSpace($p)) { return $null }
    $p = $p.Trim().Trim('"').TrimEnd('\')
    if (-not (Test-Path $p)) { return $null }
    $cand = Join-Path $p "$GameName\profiles"
    if (Test-Path $cand) { return $cand }
    foreach ($g in (Get-ChildItem -Path $p -Directory -ErrorAction SilentlyContinue)) {
        if (Test-Path (Join-Path $g.FullName "profiles")) { return (Join-Path $g.FullName "profiles") }
    }
    return $null
}
function Get-PathsFromAppFiles {
    $roots = @()
    if ($env:APPDATA)      { $roots += (Join-Path $env:APPDATA "r2modman") }
    if ($env:LOCALAPPDATA) { $roots += (Join-Path $env:LOCALAPPDATA "r2modman") }
    $found = New-Object System.Collections.Generic.List[string]
    foreach ($r in $roots) {
        if (-not (Test-Path $r)) { continue }
        $files = Get-ChildItem -Path $r -Recurse -File -ErrorAction SilentlyContinue |
                 Where-Object { $_.Length -lt (64MB) -and $_.Extension -match '^\.(log|ldb|sst|blob|json|yml|yaml|txt|db)$' }
        foreach ($f in $files) {
            try {
                $txt = [System.Text.Encoding]::GetEncoding(28591).GetString([System.IO.File]::ReadAllBytes($f.FullName))
                foreach ($m in [regex]::Matches($txt, '[A-Za-z]:\\[^\x00-\x1F<>|:*?"\r\n]{2,120}')) {
                    if ($m.Value -match 'r2modman') { $found.Add($m.Value) }
                }
            } catch {}
        }
    }
    return $found
}
function Find-DataFolderOnDrives {
    $hits = New-Object System.Collections.Generic.List[string]
    $drives = @()
    try {
        $drives = @([System.IO.DriveInfo]::GetDrives() | Where-Object { $_.DriveType -eq 'Fixed' -and $_.IsReady } | ForEach-Object { $_.RootDirectory.FullName })
    } catch {}
    foreach ($d in $drives) {
        try {
            foreach ($m in (Get-ChildItem -Path $d -Directory -Depth 2 -Filter "r2modmanPlus-local" -ErrorAction SilentlyContinue)) { $hits.Add($m.FullName) }
        } catch {}
        try {
            foreach ($m in (Get-ChildItem -Path $d -Directory -Depth 2 -Filter $GameName -ErrorAction SilentlyContinue)) {
                if (Test-Path (Join-Path $m.FullName "profiles")) { $hits.Add((Split-Path $m.FullName -Parent)) }
            }
        } catch {}
    }
    return ($hits | Select-Object -Unique)
}

function Find-ValheimGameDir {
    # 找 Valheim 游戏目录（含 valheim_Data\Managed 的那一层）：Steam 注册表 + 库文件，再兜底扫盘
    $cands = New-Object System.Collections.Generic.List[string]
    foreach ($k in @("HKCU:\Software\Valve\Steam","HKLM:\SOFTWARE\WOW6432Node\Valve\Steam","HKLM:\SOFTWARE\Valve\Steam")) {
        try {
            $sp = (Get-ItemProperty -Path $k -Name SteamPath -ErrorAction SilentlyContinue).SteamPath
            if ([string]::IsNullOrWhiteSpace($sp)) { continue }
            $sp = ($sp -replace '/', '\').TrimEnd('\')
            $cands.Add((Join-Path $sp "steamapps\common\Valheim"))
            $vdf = Join-Path $sp "steamapps\libraryfolders.vdf"
            if (Test-Path $vdf) {
                $vtxt = Get-Content $vdf -Raw
                foreach ($m in [regex]::Matches($vtxt, '"path"\s+"([^"]+)"')) {
                    $lib = ($m.Groups[1].Value -replace '\\\\', '\').TrimEnd('\')
                    $cands.Add((Join-Path $lib "steamapps\common\Valheim"))
                }
            }
        } catch {}
    }
    foreach ($c in $cands) { if (Test-Path (Join-Path $c "valheim_Data\Managed")) { return $c } }
    try {
        foreach ($d in @([System.IO.DriveInfo]::GetDrives() | Where-Object { $_.DriveType -eq 'Fixed' -and $_.IsReady } | ForEach-Object { $_.RootDirectory.FullName })) {
            foreach ($m in (Get-ChildItem -Path $d -Directory -Depth 4 -Filter "Valheim" -ErrorAction SilentlyContinue)) {
                if ($m.FullName -match '(?i)steamapps\\common\\Valheim$' -and (Test-Path (Join-Path $m.FullName "valheim_Data\Managed"))) { return $m.FullName }
            }
        }
    } catch {}
    return $null
}

$resolved = $null

# ① 命令行指定（宽松：当成数据文件夹 / profiles 目录都行；不存在就按给定的用，稍后新建）
if (-not [string]::IsNullOrWhiteSpace($ProfilesRoot)) {
    $given = $ProfilesRoot.Trim().Trim('"').TrimEnd('\')
    $asData = Try-ProfilesRoot $given
    if ($asData) { $resolved = $asData } else { $resolved = $given }
    $script:PathSource = "命令行指定"
}
# ② 上次记住的
if (-not $resolved -and -not $NoRemember -and (Test-Path $rememberFile)) {
    try {
        $prev = (Get-Content $rememberFile -Raw).Trim()
        $resolved = Try-ProfilesRoot $prev
        if ($resolved) { $script:PathSource = "上次记住的位置" }
    } catch {}
}
# ③ r2modman 自己记录过的路径（改过数据文件夹时会在这里留下痕迹）
#    注意：配置里路径可能被 JSON 转义成双反斜杠（D:\\x\\r2modmanPlus-local），所以两种写法都试
if (-not $resolved) {
    foreach ($hit in (Get-PathsFromAppFiles)) {
        $variants = @($hit)
        if ($hit -match '\\\\') { $variants += ($hit -replace '\\\\', '\') }
        foreach ($v in $variants) {
            $cand = $null
            if ($v -match '(?i)^(.*?r2modmanPlus-local)') { $cand = Try-AnyProfilesRoot $Matches[1] }
            if (-not $cand -and $v -match '(?i)^(.*?)\\Valheim(\\profiles)?') { $cand = Try-AnyProfilesRoot $Matches[1] }
            if ($cand) { $resolved = $cand; $script:PathSource = "从 r2modman 的设置里读到"; break }
        }
        if ($resolved) { break }
    }
}
# ④ 默认位置（符号链接/联结点搬家的情况也在这里覆盖）
if (-not $resolved) {
    $defaults = @()
    if ($env:APPDATA)      { $defaults += (Join-Path $env:APPDATA "r2modmanPlus-local") }
    if ($env:LOCALAPPDATA) { $defaults += (Join-Path $env:LOCALAPPDATA "r2modmanPlus-local") }
    if ($env:USERPROFILE)  { $defaults += (Join-Path $env:USERPROFILE "AppData\Roaming\r2modmanPlus-local") }
    foreach ($d in $defaults) {
        $cand = Try-ProfilesRoot $d
        if (-not $cand) { $cand = Try-AnyProfilesRoot $d }
        if ($cand) { $resolved = $cand; $script:PathSource = "r2modman 默认位置"; break }
    }
}
# ⑤ 扫盘
if (-not $resolved) {
    Say "  [2/7] 默认位置没有 r2modman 的档，正在扫描各硬盘（最多十几秒）…" "Yellow"
    foreach ($d in (Find-DataFolderOnDrives)) {
        $cand = Try-ProfilesRoot $d
        if (-not $cand) { $cand = Try-AnyProfilesRoot $d }
        if ($cand) { $resolved = $cand; $script:PathSource = "扫描硬盘找到（$d）"; break }
    }
}
# ⑥ 问用户
if (-not $resolved -and -not $NonInteractive) {
    Say ""
    Say "  没能自动找到 r2modman 的档目录。手动找法：" "Yellow"
    Say "    打开 r2modman → 左下 Settings（设置）→ Locations 标签页 → 点 Browse data folder" "Yellow"
    Say "    弹出的文件夹就是数据文件夹（里面有 Valheim、config、image-cache 等）" "Yellow"
    Say "    如果 r2modman 还没装/没运行过：先装好、启动一次、选好 Valheim 位置，再回来运行本脚本。" "Yellow"
    $ans = Read-Host "  把该文件夹路径粘贴到这里（也可以把文件夹直接拖进本窗口），回车=放弃"
    if (-not [string]::IsNullOrWhiteSpace($ans)) {
        $resolved = Try-ProfilesRoot $ans
        if (-not $resolved) { $resolved = Try-AnyProfilesRoot $ans }
        if ($resolved) { $script:PathSource = "你手动指定" }
    }
}
if (-not $resolved) {
    Fail "找不到 r2modman 的 profiles 目录（可能在别的盘）。请先运行一次 r2modman 并选好 Valheim，或把数据文件夹路径告诉脚本。"
}

$ProfilesRoot = $resolved
# 配置里读出来的路径可能带双反斜杠（JSON 转义），若正常写法也存在就用正常写法
if ($ProfilesRoot -match '\\\\') {
    $norm = $ProfilesRoot -replace '\\\\', '\'
    if (Test-Path $norm) { $ProfilesRoot = $norm }
}
Say "  [2/7] 目标目录（来源：$($script:PathSource)）" "Green"
Say "        $ProfilesRoot" "Green"
if (-not $NoRemember) {
    try { [System.IO.File]::WriteAllText($rememberFile, $ProfilesRoot, (New-Object System.Text.UTF8Encoding($false))) } catch {}
}

if ($DetectOnly) {
    Say "" ; Say "  （-DetectOnly：只探测，什么都没改）" "DarkGray"
    $gDetect = Find-ValheimGameDir
    if ($gDetect) { Say "  Valheim 游戏目录（来源：Steam 注册表/库文件/扫盘）：$gDetect" "Green" }
    else { Say "  没能自动找到 Valheim 游戏目录（ValheimVRM 那步会问你）" "Yellow" }
    if ($script:packTmpExtract -and (Test-Path $script:packTmpExtract)) {
        try { Remove-Item $script:packTmpExtract -Recurse -Force -ErrorAction SilentlyContinue } catch {}
    }
    SaveLog
    Exit 0
}

if (-not (Test-Path $ProfilesRoot)) {
    try { New-Item -ItemType Directory -Path $ProfilesRoot -Force | Out-Null }
    catch { Fail "无法创建目录 $ProfilesRoot ：$($_.Exception.Message)" }
    Say "        （该目录原本不存在，已新建）" "Yellow"
    Say "        提示：如果 r2modman 你还没装/没运行过，请先装好 r2modman 并启动一次" "Yellow"
    Say "             （它会自己建立目录并让你选 Valheim 安装位置），再运行本脚本。" "Yellow"
}

# ---------- 3) r2modman 必须先关掉 ----------
$proc = Get-Process -Name "r2modman" -ErrorAction SilentlyContinue
if ($proc) {
    Say "  [3/7] r2modman 正在运行（它的退出会重写档信息），需要先关掉。" "Yellow"
    $do = $NonInteractive
    if (-not $NonInteractive) {
        $ans = Read-Host "        现在自动关闭它吗？(Y/N)"
        if ($ans -match "^[Yy]") { $do = $true }
    }
    if ($do) {
        try { $proc | Stop-Process -Force; Start-Sleep -Seconds 2; Say "        已关闭 r2modman。" "Green" }
        catch { Fail "关闭 r2modman 失败，请手动退出后重试：$($_.Exception.Message)" }
    } else {
        Fail "请手动完全退出 r2modman（含右下角托盘图标）后，再运行本脚本。"
    }
} else {
    Say "  [3/7] r2modman 未在运行 ✓" "Green"
}

# ---------- 4) 已装过？升级 or 重装 ----------
$dst = Join-Path $ProfilesRoot $ProfileName
$mode = "fresh"
if (Test-Path $dst) {
    Say "  [4/7] 检测到已安装的档：$dst" "Yellow"
    if ($NonInteractive) {
        $mode = if ($Fresh) { "fresh" } else { "upgrade" }
        Say "        （非交互模式，按 $mode 处理）"
    } else {
        Say "          [1] 升级（推荐）：更新 mod 文件，保留你的设置与收藏格，旧文件先备份"
        Say "          [2] 全新重装：旧档整个改名备份，装一份干净的（你的 F1 设置会回到默认）"
        $ans = Read-Host "          选择 1 或 2（直接回车 = 1 升级）"
        $mode = if ($ans -eq "2") { "fresh" } else { "upgrade" }
    }

    if ($mode -eq "fresh") {
        $bakName = "$ProfileName.backup-" + (Get-Date -Format "yyyyMMdd-HHmmss")
        try { Rename-Item -Path $dst -NewName $bakName }
        catch { Fail "备份旧档失败：$($_.Exception.Message)" }
        Say "        旧档已改名备份为：$bakName" "Green"
    }
    else {
        # 在线安装时 $packRoot 在 %TEMP% 里（结束时会被清理），所以备份要放到能留住的位置
        $bakParent = $packRoot
        if ($env:TEMP -and ($bakParent -like "$env:TEMP*")) {
            $bakParent = if (Test-Path (Join-Path $env:USERPROFILE "Desktop")) { Join-Path $env:USERPROFILE "Desktop" } else { $env:USERPROFILE }
        }
        $bakRoot = Join-Path $bakParent ("MAKABAKA_backup-" + (Get-Date -Format "yyyyMMdd-HHmmss"))
        Say "        升级前备份旧文件到：$bakRoot"
        try {
            New-Item -ItemType Directory -Path $bakRoot -Force | Out-Null
            $rb = Join-Path $env:SystemRoot "System32\robocopy.exe"
            if (Test-Path $rb) {
                & $rb (Join-Path $dst "BepInEx\plugins") (Join-Path $bakRoot "plugins") /E /NFL /NDL /NJH /NJS /R:1 /W:1 /NP | Out-Null
            } else {
                Copy-Item (Join-Path $dst "BepInEx\plugins") (Join-Path $bakRoot "plugins") -Recurse -Force
            }
            Copy-Item (Join-Path $dst "mods.yml") (Join-Path $bakRoot "mods.yml") -Force
            Say "        备份完成（plugins 目录 + mods.yml）。" "Green"
        } catch { Fail "升级前备份失败：$($_.Exception.Message)" }
    }
} else {
    Say "  [4/7] 没有已安装的档 → 全新安装 ✓" "Green"
}

# ---------- 5) 复制 ----------
$rb = Join-Path $env:SystemRoot "System32\robocopy.exe"
$xf = @()
foreach ($f in $script:SelfFiles) { $xf += "/XF"; $xf += $f }
$xf += "/XF"; $xf += "*.bak-*"
if ($mode -eq "upgrade") {
    Say "  [5/7] 升级中：覆盖 mod 文件，跳过 BepInEx\config（保留你的设置）…"
    # 注意：robocopy 的 /XD 要写【源侧】路径（或裸目录名），写目标路径会静默失效！（实测踩过）
    $xd = @("/XD", (Join-Path $src "BepInEx\config"))
    & $rb $src $dst /E /NFL /NDL /NJH /NJS /R:2 /W:1 /NP @xf @xd | Out-Null
    if ($LASTEXITCODE -ge 8) { Fail "复制失败（robocopy 退出码 $LASTEXITCODE）。" }
    # 缺失的配置文件补上（只补不存在的新文件，绝不覆盖已有设置）
    $srcCfg = Join-Path $src "BepInEx\config"
    $dstCfg = Join-Path $dst "BepInEx\config"
    if ((Test-Path $srcCfg) -and (Test-Path $dstCfg)) {
        & $rb $srcCfg $dstCfg /E /XC /XN /XO /NFL /NDL /NJH /NJS /R:1 /W:1 /NP | Out-Null
    }
    Say "        升级完成（mod 文件已更新）。" "Green"
} else {
    Say "  [5/7] 复制文件中（约 100MB，请稍候）…"
    if (Test-Path $rb) {
        & $rb $src $dst /E /NFL /NDL /NJH /NJS /R:2 /W:1 /NP @xf | Out-Null
        if ($LASTEXITCODE -ge 8) { Fail "复制失败（robocopy 退出码 $LASTEXITCODE）。" }
    } else {
        try {
            New-Item -ItemType Directory -Path $dst -Force | Out-Null
            Copy-Item -Path (Join-Path $src "*") -Destination $dst -Recurse -Force
            foreach ($f in $script:SelfFiles) {
                $p = Join-Path $dst $f
                if (Test-Path $p) { Remove-Item $p -Force -Recurse }
            }
            Get-ChildItem -Path $dst -Recurse -File -Filter "*.bak-*" | Remove-Item -Force
        } catch { Fail "复制失败：$($_.Exception.Message)" }
    }
    Say "        复制完成。" "Green"
}

# ---------- 6) 校验 ----------
Say "  [6/7] 校验中…"
$srcFiles = @(Get-ChildItem -Path $src -Recurse -File | Where-Object {
    $n = $_.Name
    ($script:SelfFiles -notcontains $n) -and ($n -notlike "*.bak-*")
})
$dstCount = (Get-ChildItem -Path $dst -Recurse -File).Count
Say "        文件数：包内 $($srcFiles.Count) 个 → 档里 $dstCount 个"
if ($dstCount -lt $srcFiles.Count) {
    if ($mode -eq "upgrade") { Say "        （升级模式会跳过已设置好的配置文件，数量略少属正常）" "DarkGray" }
    else { Fail "复制不完整（少了 $($srcFiles.Count - $dstCount) 个文件），请重试或换用文件夹方式拷贝。" }
}

$bad = @()
foreach ($rel in $Expect.Keys) {
    $f = Join-Path $dst $rel
    if (-not (Test-Path $f)) { $bad += "$rel （缺失）"; continue }
    $h = (Get-FileHash -Path $f -Algorithm MD5).Hash.ToLower()
    if ($h -ne $Expect[$rel]) { $bad += "$rel （内容与出厂不一致）" }
}
if ($bad.Count -eq 0) {
    Say "        关键文件校验通过 ✓（ChestFlow 汉化版、ChestFlowTweaks 0.3.1、EpicLoot 0.14.5、Endurance 汉化版、VRMGhostFix）" "Green"
} else {
    Say "        [注意] 以下文件与出厂版本不一致：" "Yellow"
    foreach ($b in $bad) { Say "          - $b" "Yellow" }
    Say "        （若是刚升级后仍不一致，说明升级没生效，请把本日志发我们）" "Yellow"
}
try {
    $ver = (Get-Content (Join-Path $dst "BepInEx\plugins\jg224-ChestFlow\manifest.json") -Raw -Encoding UTF8 | ConvertFrom-Json).version_number
    Say "        ChestFlow 版本：$ver（界面已简体汉化）"
} catch {}
try {
    $mods = Get-Content (Join-Path $dst "mods.yml") -Raw
    $enabled = ([regex]::Matches($mods, "(?m)^  enabled: true")).Count
    $disabled = ([regex]::Matches($mods, "(?m)^  enabled: false")).Count
    Say "        mod 状态：启用 $enabled 个 / 禁用 $disabled 个"
} catch {}
try {
    $bytes = [System.IO.File]::ReadAllBytes((Join-Path $dst "BepInEx\plugins\ChestFlowTweaks\ChestFlowTweaks.dll"))
    if ([System.Text.Encoding]::ASCII.GetString($bytes).Contains("0.3.1")) { Say "        ChestFlowTweaks：0.3.1（已修复掉帧 bug）" "Green" }
} catch {}

# ---------- 7) 后续步骤 ----------
Say "  [7/7] 完成。" "Green"
if ($mode -eq "upgrade") { Say "  （升级模式：你自己的 F1 设置、收藏格、热键都保留着）" "DarkGray" }
Section "接下来你要做的（只差这几步）"
Say "  1) 打开 r2modman → 左上 Profile 下拉里选中  $ProfileName"
Say "  2) 点 Start modded 启动游戏（不要用 Start vanilla / 不要直接开 Steam）"
Say "  3) 进游戏后按 F1 应能弹出配置管理器 → 说明 mod 全部生效"
Say ""
Say "  如果 r2modman 列表里某些 mod 显示""未知版本""或提示有更新：" "Yellow"
Say "   → 正常，别点 Update / Reinstall 就行（里面有汉化和我们自编译的版本）。" "Yellow"
Say "   → 详见 安装指南.txt 第 8 节""别用 r2modman 点更新的 mod""。" "Yellow"
Say ""
Say "  如果帧率还是 15fps 左右（明显卡）：" "Yellow"
Say "   → 那是旧版自研插件 ChestFlowTweaks 0.3.0 的 bug，本包是 0.3.1。" "Yellow"
Say "   → 上面第 [6/7] 步若显示""校验通过""就说明已经修好；若显示不一致，把日志发我们。" "Yellow"

# ---------- 附加：ValheimVRM（角色自定义模型；需要往游戏目录放文件） ----------
$vrmPack = Join-Path $packRoot "ValheimVRM_手动安装"
if ((Test-Path $vrmPack) -and -not $SkipVRM) {
    Section "附加：ValheimVRM（角色换模型）"
    Say "  这个 mod 和别的不一样：它必须往【游戏目录】放文件（r2modman 不会同步这些），"
    Say "  所以要单独配置一次："
    Say "    · vrm/gltf 相关 dll（15 个） → <游戏>\valheim_Data\Managed\"
    Say "    · 模型 + 设置文件           → <游戏>\ValheimVRM\"
    $doVrm = $true
    if (-not $NonInteractive) {
        $ansV = Read-Host "  一并配置 ValheimVRM 吗？(Y/n)"
        if ($ansV -match "^[Nn]") { $doVrm = $false }
    }
    if (-not $doVrm) {
        Say "  已跳过。之后想装：重跑本脚本，或按 ValheimVRM_手动安装\说明_ValheimVRM.txt 手动做。" "DarkGray"
    } else {

        $game = ""
        if (-not [string]::IsNullOrWhiteSpace($GameDir)) { $game = $GameDir.Trim().Trim('"').TrimEnd('\') }
        if (-not $game) { $game = Find-ValheimGameDir }
        if (-not $game -or -not (Test-Path (Join-Path $game "valheim_Data\Managed"))) {
            if (-not $NonInteractive) {
                Say "  没能自动找到 Valheim 游戏目录（要含 valheim.exe 与 valheim_Data\Managed 的那一层）。" "Yellow"
                $g = Read-Host "  把游戏目录粘进来（例如 I:\steam\steamapps\common\Valheim），回车=跳过"
                if (-not [string]::IsNullOrWhiteSpace($g)) {
                    $g = $g.Trim().Trim('"').TrimEnd('\')
                    if (Test-Path (Join-Path $g "valheim_Data\Managed")) { $game = $g }
                }
            }
            if (-not $game -or -not (Test-Path (Join-Path $game "valheim_Data\Managed"))) {
                Say "  [跳过] 没找到游戏目录，ValheimVRM 的游戏侧文件没放（之后重跑本脚本即可）。" "Yellow"
                $game = ""
            }
        }

        if ($game) {
            Say "  游戏目录：$game" "Green"
            $managed   = Join-Path $game "valheim_Data\Managed"
            $srcManaged = Join-Path $vrmPack "valheim_Data_Managedに入れる文件"
            $bakDir    = Join-Path $game ("_vrm_backup_" + (Get-Date -Format "yyyyMMdd-HHmmss"))
            $copied = 0; $replaced = 0; $same = 0
            if (Test-Path $srcManaged) {
                foreach ($f in (Get-ChildItem -Path $srcManaged -File)) {
                    $t = Join-Path $managed $f.Name
                    if (Test-Path $t) {
                        if ((Get-FileHash $f.FullName -Algorithm MD5).Hash -eq (Get-FileHash $t -Algorithm MD5).Hash) { $same++; continue }
                        New-Item -ItemType Directory -Path $bakDir -Force | Out-Null
                        Copy-Item $t (Join-Path $bakDir $f.Name) -Force; $replaced++
                    }
                    Copy-Item $f.FullName $t -Force; $copied++
                }
                Say "        Managed：新放/更新 $copied 个 dll（原本就一致的 $same 个；替换前备份 $replaced 个 → $((Split-Path $bakDir -Leaf))）"
            } else {
                Say "        [注意] 包里缺少 valheim_Data_Managedに入れる文件 目录，未能放 dll。" "Yellow"
            }

            $vrmTarget = Join-Path $game "ValheimVRM"
            try { New-Item -ItemType Directory -Path $vrmTarget -Force | Out-Null } catch {}
            $zipModel = Join-Path $vrmPack "ValheimVRM.zip"
            $got = @()
            if (Test-Path $zipModel) {
                $tmpX = Join-Path $env:TEMP ("vrmx_" + (Get-Date -Format "HHmmss"))
                try {
                    Add-Type -AssemblyName System.IO.Compression.FileSystem
                    [System.IO.Compression.ZipFile]::ExtractToDirectory($zipModel, $tmpX)
                    foreach ($f in (Get-ChildItem -Path $tmpX -Recurse -File | Where-Object { $_.Extension -eq ".vrm" -or $_.Name -like "settings_*.txt" })) {
                        Copy-Item $f.FullName (Join-Path $vrmTarget $f.Name) -Force
                        $got += $f.Name
                    }
                    Remove-Item $tmpX -Recurse -Force -ErrorAction SilentlyContinue
                } catch { Say "        [注意] 模型解压失败：$($_.Exception.Message)" "Yellow" }
            }
            Say "        模型目录 $vrmTarget ：$($got -join '、')"
            Say "        ★ 模型按【角色名】生效：<角色名>.vrm 与 settings_<角色名>.txt（角色不叫 KaNzI 就把这两个文件改名）" "Yellow"
            Say "        ★ Steam「验证游戏文件完整性」会清掉 Managed 里这些 dll；之后重跑本脚本即可恢复" "Yellow"
        }
    }
}

# ---------- 清理：临时解压目录（档已装好，VRM 那步要用的文件也都复制完了）----------
if ($script:packTmpExtract -and (Test-Path $script:packTmpExtract)) {
    try { Remove-Item $script:packTmpExtract -Recurse -Force -ErrorAction SilentlyContinue } catch {}
}

SaveLog
Say ""
Say "  日志已保存到：$script:LogPath" "DarkGray"
Say ""
if (-not $NonInteractive) { Read-Host "  按回车键关闭本窗口" | Out-Null }
