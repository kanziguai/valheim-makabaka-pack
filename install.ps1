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
    -VRMOnly               只换模型：不重装档，只做 VRM 的模型与设置（配合 换模型.bat 用）
    -VrmModel <名字|路径>  指定用哪个模型（名字=Models 下的目录名，如 金乌/辰星；也可以给 .vrm 路径）
    -CharName <角色名>     指定角色名（模型会被复制成 <角色名>.vrm + settings_<角色名>.txt）
    -DownloadDir <路径>    安装包下载/解压放哪（默认 %TEMP%\makabaka_pack；不喜欢放 C 盘就换盘，
                           例如 -DownloadDir D:\MAKABAKA_install）。选过一次会记住
    -NonInteractive        不提问：自动关 r2modman、已装过则默认走"升级"
    -Fresh                 已装过时强制"全新重装"（旧档改名备份）
    -DetectOnly            只显示"探测到的 profiles 目录"然后退出（不动任何文件）
    -NoRemember            不使用/不写入 install-path.txt（不记住上次的路径）
    -GameDir <路径>        指定 Valheim 游戏目录（一般不填，脚本自己找 Steam 库）
    -SkipVRM               跳过"附加：ValheimVRM"这一步（只想装档、不碰游戏目录时用）
    -ModsOnly              只更新 mod 本体（= 不装/不换模型）：日常升级用这个最省流量
    -ListModels            只列出可选的 VRM 模型（本机已缓存 / 需下载 + 大小）后退出，不动任何文件
    -Models <名字1,名字2>  要下载并缓存哪些模型（逗号分隔；名字从 -ListModels 抄）
    -ModelPath <文件|目录> 直接用本地的 .vrm（自己下的、别人发的模型拖进来即可）
    -ModelSource <url|文件> 模型清单来源覆盖（默认：包内 Models\models.json → 公开仓库在线清单）
    -ModelToken <令牌>     私有模型仓库的下载凭据（也可设环境变量 MAKABAKA_MODEL_TOKEN，或存 模型凭据.txt）

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
    [string]$ReleaseBase = "",
    [switch]$VRMOnly,
    [string]$VrmModel = "",
    [string]$CharName = "",
    [string]$DownloadDir = "",
    [switch]$ModsOnly,
    [switch]$ListModels,
    [string]$Models = "",
    [string]$ModelPath = "",
    [string]$ModelSource = "",
    [string]$ModelToken = "",
    [string]$SkinTarget = "",    # 武器/物品外观替换：要替换的原版 prefab 名（如 BowDraugrFang）
    [string]$SkinModel = "",     # 武器/物品外观替换：模型库里的模型目录名（如 灵跃心弦）
    [switch]$SkipSkin            # 跳过外观替换模块
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
    "BepInEx\plugins\PortalBroadcastFix\PortalBroadcastFix.dll" = "2c4a8ec2e1f69781fd97761423e72b64"
}

# ---------- 在线安装：本地没有包时，从 GitHub Release 取最新版 ----------
$ReleasesRepo   = "kanziguai/valheim-makabaka-pack"   # ← GitHub 仓库（owner/repo）
$ScriptBuild    = "2026-09-17"                        # ← 本脚本的日期（发新版时由 tools/发布新版.py 自动更新）
$ReleaseLatest  = "https://github.com/$ReleasesRepo/releases/latest/download"
$SumAssetName   = "SHA256SUMS.txt"                   # Release 里固定名字的校验清单附件
$VrmDefaultModel = ""                                   # 已取消默认模型（清单里 default 为空 → 不重排；菜单顺序=清单顺序=参考图编号）

# 必须人人一致的配置项（安装/升级后强制校正；升级模式会保留玩家自己的 config，所以必须在这里兜住）
$script:EnforcedConfig = @(
    @{ File = "jg224.chestflow.cfg"; Section = "Multiplayer"; Key = "AllowConcurrentChestUse"; Value = "false" }
)
$MirrorPrefixes = @("https://ghfast.top/", "https://ghproxy.net/", "")   # "" = 直连，放最后
# 联网拿不到校验清单时的兜底（每次发新版由仓库同步更新，随脚本一起走）
$FallbackAsset   = "MAKABAKA_profile_v1.10_20260917.zip"
$FallbackMd5     = "2c7191d8c656a622d4f9ff3da70d622f"
$script:WorkDir        = ""    # 安装包下载/解压放哪（-DownloadDir / 上次记住的 / 交互选择 / %TEMP%\makabaka_pack）
$script:CacheDir       = ""    # = <WorkDir>\pack（下载缓存）
$script:ModelCacheDir  = ""    # 模型缓存（换模型时用）
$script:DlRememberFile = Join-Path $PSScriptRoot "download-path.txt"   # 记住你选过的下载位置

# ---------- 模型库（清单 / 私有仓库附件 / 缓存）：逻辑都在 ModelLib.ps1 ----------
if ($ModsOnly) { $SkipVRM = $true }        # 只更新 mod：完全不碰模型
$script:ModelRepo = ""
$script:ModelTag  = ""
$script:ModelLibLoaded = $false   # 真正的载入在下面（助手函数都就位之后）；缺文件时会自愈下载一份

# 某个位置所在盘还剩多少 GB（路径不存在就往上找最近的已存在目录）
function Get-FreeGB([string]$path) {
    try {
        $q = $path
        while ($q -and -not (Test-Path $q)) {
            $up = Split-Path $q -Parent
            if (-not $up -or $up -eq $q) { break }
            $q = $up
        }
        if (-not $q) { return $null }
        $root = [System.IO.Path]::GetPathRoot($q)
        if ([string]::IsNullOrWhiteSpace($root)) { return $null }
        $di = New-Object System.IO.DriveInfo($root)
        return [math]::Round($di.AvailableFreeSpace / 1GB, 1)
    } catch { return $null }
}

# 模型缓存放哪：自己指定的下载目录（不在临时目录里）就放那儿，否则放 %LOCALAPPDATA%（临时目录会被系统清理）
function Get-ModelCacheDir([string]$workDir) {
    if ($workDir -and ($workDir -notlike "$env:TEMP*") -and ($workDir -notlike "$env:LOCALAPPDATA\Temp*")) {
        return (Join-Path $workDir "VRM_Models")
    }
    return (Join-Path $env:LOCALAPPDATA "MAKABAKA\VRM\Models")
}

# r2modman 数据文件夹候选（有人每块盘都装过一份；同一个目录的不同写法只算一个）
$script:ProfCands = New-Object System.Collections.Generic.List[string]
function Add-ProfCand([string]$p) {
    if ([string]::IsNullOrWhiteSpace($p)) { return }
    foreach ($x in $script:ProfCands) { if ($x -ieq $p) { return } }
    $script:ProfCands.Add($p)
}
function Get-ProfCandNote([string]$root) {
    $yml = Join-Path (Join-Path $root $ProfileName) "mods.yml"
    if (Test-Path $yml) {
        $tm = ""
        try { $tm = (Get-Item $yml).LastWriteTime.ToString("yyyy-MM-dd HH:mm") } catch {}
        return "已有 $ProfileName 档（$tm）"
    }
    $n = 0
    if (Test-Path $root) { try { $n = @(Get-ChildItem -Path $root -Directory -ErrorAction SilentlyContinue).Count } catch {} }
    return "没有 $ProfileName 档，会新建（该数据文件夹里现有 $n 个档）"
}

# 选"安装包放哪"：不喜欢下到 C 盘的人可以换盘；选过一次就记住（下次不再问）
function Resolve-WorkDir([string]$Given, [switch]$NoPrompt) {
    $defaultDir = Join-Path $env:TEMP "makabaka_pack"
    if (-not [string]::IsNullOrWhiteSpace($Given)) { return $Given.Trim().Trim('"').TrimEnd('\') }
    $prevDl = $null
    if (Test-Path $script:DlRememberFile) { try { $prevDl = (Get-Content $script:DlRememberFile -Raw).Trim() } catch {} }
    if (-not [string]::IsNullOrWhiteSpace($prevDl)) { return $prevDl }
    if ($NonInteractive -or $NoPrompt) { return $defaultDir }

    $freeD = Get-FreeGB $defaultDir
    $cands = New-Object System.Collections.Generic.List[object]
    $cands.Add([pscustomobject]@{ Path = $defaultDir; Note = "默认（当前用户临时目录）；该盘剩余 " + $(if ($freeD -ne $null) { "$freeD GB" } else { "未知" }) })
    foreach ($dv in @([System.IO.DriveInfo]::GetDrives() | Where-Object { $_.DriveType -eq 'Fixed' -and $_.IsReady })) {
        $dvRoot = $dv.RootDirectory.FullName
        if ($dvRoot -like "$env:SystemDrive*") { continue }
        $cands.Add([pscustomobject]@{ Path = (Join-Path $dvRoot "MAKABAKA_install"); Note = "另一个盘；剩余 $([math]::Round($dv.AvailableFreeSpace / 1GB, 1)) GB" })
    }
    Say ""
    Say "  安装包放哪？（要下 138 MB、解压再占约 140 MB；装完脚本会自动清理。不喜欢放 C 盘就选别的）" "Cyan"
    for ($i = 0; $i -lt $cands.Count; $i++) { Say ("    {0}) {1}   （{2}）" -f ($i + 1), $cands[$i].Path, $cands[$i].Note) }
    Say "    0) 我自己输入一个路径（例如 D:\MAKABAKA_install；只写 D: 也行）"
    $ansW = "" + (Read-Host "  选哪个？(直接回车 = 1)")
    $pick = $cands[0].Path
    if ($ansW -match '^\s*$') { $pick = $cands[0].Path }
    elseif ($ansW -match '^\s*0\s*$') {
        $typedW = ("" + (Read-Host "  把路径粘进来（只写盘符如 D: 也行）")).Trim().Trim('"')
        if ($typedW -match '^[A-Za-z]:$') { $typedW = Join-Path ($typedW + "\") "MAKABAKA_install" }
        if (-not [string]::IsNullOrWhiteSpace($typedW)) { $pick = $typedW }
    }
    elseif ($ansW -match '^\d+$' -and [int]$ansW -ge 1 -and [int]$ansW -le $cands.Count) { $pick = $cands[[int]$ansW - 1].Path }
    else { Say "  输入看不懂，按默认来。" "Yellow" }
    $freeW = Get-FreeGB $pick
    if ($freeW -ne $null -and $freeW -lt 1.2) { Say "  [注意] 这个位置所在盘只剩 $freeW GB，可能不够（约需 1 GB）；不够会在下载/解压时报错。" "Yellow" }
    try { [System.IO.File]::WriteAllText($script:DlRememberFile, $pick, (New-Object System.Text.UTF8Encoding($false))) } catch {}
    Say "  ✓ 记住这个位置了（下次不再问；想改就删掉脚本旁的 download-path.txt，或用 -DownloadDir 指定）" "DarkGray"
    return $pick
}

# 真正要用到"下载/解压"时才解析（-VRMOnly 不弹问、本地文件夹也不需要）
function Ensure-WorkDir {
    if ([string]::IsNullOrWhiteSpace($script:WorkDir)) {
        $script:WorkDir = Resolve-WorkDir $DownloadDir
        $script:CacheDir = Join-Path $script:WorkDir "pack"
        $script:ModelCacheDir = Get-ModelCacheDir $script:WorkDir
    }
}

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

# 取一段文本（小文件），多线路依次试；每条线路先按系统代理、失败再绕开代理直连
function Get-TextWithMirrors([string]$url, [int]$timeoutSec = 20) {
    foreach ($u in (Get-MirroredUrls $url)) {
        foreach ($useDirect in @($false, $true)) {
            try {
                $req = [System.Net.HttpWebRequest]::Create($u)
                $req.Timeout = $timeoutSec * 1000
                $req.UserAgent = "makabaka-install"
                if ($useDirect) { $req.Proxy = $null }
                $resp = $req.GetResponse()
                $sr = New-Object System.IO.StreamReader($resp.GetResponseStream(), [System.Text.Encoding]::UTF8)
                $txt = $sr.ReadToEnd()
                $sr.Close(); $resp.Close()
                if (-not [string]::IsNullOrWhiteSpace($txt)) { return $txt }
            } catch {}
        }
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
        # 每条线路先按系统代理下；失败再绕开代理直连（用 Clash / 加速器时经常需要这一步）
        foreach ($useDirect in @($false, $true)) {
            $tag = $line
            if ($useDirect) { $tag = $tag + "（不走代理）" }
            Say "        下载中（$label，$tag）…" "DarkGray"
            $wc = $null
            try {
            $wc = New-Object System.Net.WebClient
            $wc.Headers.Add("User-Agent", "makabaka-install")
            if ($useDirect) { $wc.Proxy = $null }
            # 说明：WebClient 的同步 DownloadFile 不触发进度事件（旧写法等于没显示），
            #       所以这里自己读流写文件 —— 进度/速度必然可显示，还能发现"下到一半断了"
            $req = [System.Net.HttpWebRequest]::Create($u)
            $req.UserAgent = "makabaka-install"
            $req.Timeout = 30000
            $req.ReadWriteTimeout = 60000
            if ($useDirect) { $req.Proxy = $null }
            $resp = $req.GetResponse()
            $total = $resp.ContentLength
            $rs = $resp.GetResponseStream()
            $fs = [System.IO.File]::Create($outFile)
            $sw = [System.Diagnostics.Stopwatch]::StartNew()
            $buf = New-Object byte[] 1048576
            $read = 0L
            $lastAt = 0.0
            try {
                while ($true) {
                    $n = $rs.Read($buf, 0, $buf.Length)
                    if ($n -le 0) { break }
                    $fs.Write($buf, 0, $n)
                    $read += $n
                    $secNow = $sw.Elapsed.TotalSeconds
                    if (($secNow - $lastAt) -ge 0.5) {
                        $lastAt = $secNow
                        if ($secNow -le 0) { continue }
                        $mb   = [math]::Round($read / 1MB, 1)
                        $spd  = [math]::Round(($read / 1MB) / $secNow, 1)
                        $pct  = 0
                        if ($total -gt 0) { $pct = [int](100 * $read / $total) }
                        $totTxt = "?"
                        if ($total -gt 0) { $totTxt = "$([math]::Round($total / 1MB, 1)) MB" }
                        $etaTxt = ""
                        if (($spd -gt 0.05) -and ($total -gt $read)) {
                            $left = ($total - $read) / 1MB / $spd
                            if ($left -lt 60) { $etaTxt = "，剩约 " + [math]::Round($left) + " 秒" }
                            else { $etaTxt = "，剩约 " + [math]::Round($left / 60, 1) + " 分钟" }
                        }
                        Write-Host ("`r          $pct%   $mb MB / $totTxt   $spd MB/s$etaTxt                    ") -NoNewline -ForegroundColor DarkGray
                    }
                }
            } finally {
                try { $fs.Close() } catch {}
                try { $rs.Close() } catch {}
                try { $resp.Close() } catch {}
            }
            $secAll = $sw.Elapsed.TotalSeconds
            $szMB = [math]::Round($read / 1MB, 1)
            $avgAll = 0
            if ($secAll -gt 0) { $avgAll = [math]::Round($szMB / $secAll, 1) }
            Write-Host ""
            if (($total -gt 0) -and ($read -ne $total)) {
                throw "下载不完整（收到 $read / 应有 $total 字节）"
            }
            Say ("        下载完成：$szMB MB，用时 " + [math]::Round($secAll, 1) + " 秒（平均 $avgAll MB/s）") "Green"
            return $true
            } catch {
                if ($wc) { try { $wc.Dispose() } catch {} }
                $how = "代理"
                if ($useDirect) { $how = "直连" }
                Say "        这一条失败（$how）：$($_.Exception.Message)" "DarkGray"
                if (Test-Path $outFile) { Remove-Item $outFile -Force -ErrorAction SilentlyContinue }
            }
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
    Ensure-WorkDir
    $tmp = Join-Path $script:WorkDir ("unpack_" + (Get-Date -Format "HHmmss"))
    Say "        安装包目录：$script:WorkDir" "DarkGray"
    try {
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        [System.IO.Compression.ZipFile]::ExtractToDirectory($zipPath, $tmp)
    } catch { Fail "解压 $zipLeaf 失败：$($_.Exception.Message)" }
    $script:packTmpExtract = $tmp
    if (Test-Path (Join-Path $tmp "$ProfileName\mods.yml")) { return (Join-Path $tmp $ProfileName) }
    elseif (Test-Path (Join-Path $tmp "mods.yml")) { return $tmp }
    else { Fail "zip 里找不到 $ProfileName\mods.yml，包可能不完整。" }
}

# 兜底：用 GitHub API 查最新 Release 里附件的真实地址
# （刚发布时 releases/latest/download/... 可能短暂 404，但 assets 里的直链已经能用）
function Resolve-AssetUrlByApi([string]$repo, [string]$preferLeaf) {
    if ([string]::IsNullOrWhiteSpace($repo) -or ($repo -notmatch '^[\w.-]+/[\w.-]+$')) { return $null }
    try {
        $req = [System.Net.HttpWebRequest]::Create("https://api.github.com/repos/$repo/releases/latest")
        $req.Timeout = 20000
        $req.UserAgent = "makabaka-install"
        $req.Accept = "application/vnd.github+json"
        $resp = $req.GetResponse()
        $sr = New-Object System.IO.StreamReader($resp.GetResponseStream(), [System.Text.Encoding]::UTF8)
        $json = $sr.ReadToEnd()
        $sr.Close(); $resp.Close()
        $assets = @(($json | ConvertFrom-Json).assets)
        foreach ($a in $assets) { if ($preferLeaf -and $a.name -eq $preferLeaf) { return $a.browser_download_url } }
        foreach ($a in $assets) { if ($a.name -like "${ProfileName}_profile*.zip") { return $a.browser_download_url } }
    } catch {}
    return $null
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

# ---------- 模型库载入：ModelLib.ps1（方法一只下 install.ps1 时会缺 → 自愈下载一份）----------
$script:ModelLibPath = Join-Path $PSScriptRoot "ModelLib.ps1"
if (-not (Test-Path $script:ModelLibPath)) {
    $rawBase = "https://raw.githubusercontent.com/$ReleasesRepo/main"
    Say "  没找到 ModelLib.ps1（模型库）→ 从仓库取一份…" "DarkGray"
    $tmpLib = Join-Path $env:TEMP "MAKABAKA-ModelLib.ps1"
    if (Save-FileWithMirrors "$rawBase/ModelLib.ps1" $tmpLib "模型库 ModelLib.ps1") {
        try { Copy-Item $tmpLib $script:ModelLibPath -Force -ErrorAction Stop } catch {}
    }
}
foreach ($libTry in @($script:ModelLibPath, (Join-Path $env:TEMP "MAKABAKA-ModelLib.ps1"))) {
    if ($script:ModelLibLoaded) { break }
    if (Test-Path $libTry) {
        try { . $libTry; $script:ModelLibLoaded = $true } catch { Say "  [注意] ModelLib.ps1 载入失败：$($_.Exception.Message)" "Yellow" }
    }
}
if (-not $script:ModelLibLoaded) {
    Say "  [注意] 模型功能不可用（缺 ModelLib.ps1，且没下下来）；只更新 mod 完全不受影响。" "Yellow"
    Say "         想装/换模型：以后双击 换模型.bat，或在有网时重跑本脚本即可。" "DarkGray"
}

# ---------- 外观替换模块载入：SkinLib.ps1（模块化：选物品 → 选模型 → 或 不替换）----------
$script:SkinLibPath = Join-Path $PSScriptRoot "SkinLib.ps1"
if (-not (Test-Path $script:SkinLibPath)) {
    $rawBaseS = "https://raw.githubusercontent.com/$ReleasesRepo/main"
    Say "  没找到 SkinLib.ps1（外观替换模块）→ 从仓库取一份…" "DarkGray"
    $tmpLibS = Join-Path $env:TEMP "MAKABAKA-SkinLib.ps1"
    if (Save-FileWithMirrors "$rawBaseS/SkinLib.ps1" $tmpLibS "外观替换模块 SkinLib.ps1") {
        try { Copy-Item $tmpLibS $script:SkinLibPath -Force -ErrorAction Stop } catch {}
    }
}
foreach ($skinTry in @($script:SkinLibPath, (Join-Path $env:TEMP "MAKABAKA-SkinLib.ps1"))) {
    if ($script:SkinLibLoaded) { break }
    if (Test-Path $skinTry) {
        try { . $skinTry; $script:SkinLibLoaded = $true } catch { Say "  [注意] SkinLib.ps1 载入失败：$($_.Exception.Message)" "Yellow" }
    }
}

# ---------- -ListModels：只列模型清单就退出（不下载、不动任何文件）----------
if ($ListModels) {
    if (-not $script:ModelLibLoaded) { Fail '模型库（ModelLib.ps1）不可用，没法列清单 —— 请重跑一次安装脚本（会自动补下），或直接用 -Models "名字1,名字2" 指定模型。' }
    $cacheLM = Get-ModelCacheDir ""
    Section "模型清单（只查看，不动任何文件）"
    $cands = Get-ModelCandidates -packRoot $PSScriptRoot -cacheDir $cacheLM -modelPath $ModelPath -manifestSource $ModelSource
    if ($cands.Count -eq 0) {
        Say "  没读到任何模型：包内没有 Models\models.json，也没联网取到清单。" "Yellow"
        Say "  （想直接用本地文件：把 .vrm 拖进来，或用 -ModelPath <文件>）" "DarkGray"
    } else { Show-ModelCandidates $cands $cacheLM }
    Say '  （参考图：打开本包目录里的 Models\预览\ 文件夹，文件名编号与上面序号一致）' "DarkGray"
    Say ""
    Say '  装/换模型：双击 换模型.bat，或用 -Models "名字1,名字2" 指定。' "DarkGray"
    exit 0
}

Section "英灵神殿 MAKABAKA 整合档 一键安装 / 升级"
Say "  本脚本会：把本包里的 MAKABAKA 档装进 r2modman 的 profiles 目录。"
Say "  · 以前没装过 → 全新安装"
Say "  · 装过旧版   → 原地升级：更新 mod 文件，保留你自己的设置与收藏（旧文件先备份）"
Say "  你的世界存档、角色存档不会被碰。" "DarkGray"
Say "  脚本日期：$ScriptBuild   内置仓库：$ReleasesRepo" "DarkGray"
Say "  （如果你是从镜像下载的本脚本，镜像可能有几分钟缓存 —— 拿到旧副本时上面这两行会对不上最新版）" "DarkGray"

# ---------- 1) 找源档（本地文件夹 → 本地 zip → 在线下载）----------
$src = $null
$script:packVer = ""
$script:packTmpExtract = ""

if ($VRMOnly) {
    # -VRMOnly（只换模型）：不动 r2modman 的档、不下载安装包，只处理 VRM 的模型与设置
    Say "  [只换模型模式] 不改动 r2modman 的档，只处理 VRM 的模型与设置（并做三处自检）" "Cyan"
    $packRoot = $PSScriptRoot
    if (-not (Test-Path (Join-Path $PSScriptRoot "Models\models.json")) -and -not (Test-Path (Join-Path $PSScriptRoot "Models")) -and -not (Test-Path (Join-Path $PSScriptRoot "ValheimVRM_手动安装"))) {
        $up = Split-Path $PSScriptRoot -Parent
        if ($up -and ((Test-Path (Join-Path $up "Models")) -or (Test-Path (Join-Path $up "ValheimVRM_手动安装")))) { $packRoot = $up }
    }
    $src = $packRoot   # 占位：只换模型不需要档源
    if ($ModelPath -and -not $ModelSource -and -not (Test-Path (Join-Path $packRoot "Models"))) {
        # 只有本地 .vrm 也能换模型（清单取在线）
        Say "  [只换模型] 用 -ModelPath 指定的本地文件" "DarkGray"
    }
    if (-not (Test-Path (Join-Path $packRoot "ValheimVRM_手动安装")) -and -not (Test-Path (Join-Path $packRoot "Models")) -and -not $ModelPath) {
        Fail "没找到 VRM 的模型源（ValheimVRM_手动安装\ 或 Models\）。把 换模型.bat 和它们放在同一个目录，或用 -ProfilesRoot/-PackRoot 相关参数指定。"
    }
}
elseif (Test-Path (Join-Path $PSScriptRoot "$ProfileName\mods.yml")) {
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
    Ensure-WorkDir
    Say "  [1/7] 本目录没有安装包 → 从 GitHub 获取最新版" "Green"
    if ($ReleasesRepo -notmatch '^[\w.-]+/[\w.-]+$' -or $ReleasesRepo -like 'OWNER/*' -or $ReleasesRepo -like '*/REPO') {
        Fail "本脚本里的仓库地址还没填对（现在是 `"$ReleasesRepo`"）。用 -ReleaseRepo owner/仓库名 指定，或找分享者要一份填好的 install.ps1。"
    }
    Say "        仓库：$ReleasesRepo" "DarkGray"
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
        $ok = Save-FileWithMirrors $dlUrl $zip ($sizeTxt + "多条线路自动重试")
        if (-not $ok) {
            Say "        直接下载失败 → 改用 GitHub API 查附件的真实地址（刚发布的包，latest 链接可能还没生效）…" "Yellow"
            $realUrl = Resolve-AssetUrlByApi $ReleasesRepo $zipLeaf
            if ($realUrl) {
                Say "        真实地址：$realUrl" "DarkGray"
                $ok = Save-FileWithMirrors $realUrl $zip ($sizeTxt + "API 给出的附件地址")
            }
        }
        if (-not $ok) {
            Fail "下载失败：所有线路都连不上（也可能被防火墙/杀软拦了）。刚发布或刚更新时可能需要等 1~2 分钟再试；也可以手动从 Release 页面下载 zip，放到本脚本旁边再运行本脚本。"
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
if (-not $VRMOnly) { $packRoot = Split-Path $src -Parent }

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

function Scan-ProfCands {
    # 扫描所有固定硬盘，找 r2modman 数据文件夹（只加候选，不动任何东西）
    $before = $script:ProfCands.Count
    foreach ($d in (Find-DataFolderOnDrives)) {
        $c = Try-ProfilesRoot $d
        if (-not $c) { $c = Try-AnyProfilesRoot $d }
        if ($c) { Add-ProfCand $c }
    }
    return ($script:ProfCands.Count - $before)
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

if ($VRMOnly) {
    # 只换模型：只做"轻量探测"（不扫盘、不写 install-path.txt），探测不到也不阻断
    $script:WorkDir = Resolve-WorkDir $DownloadDir -NoPrompt
    $script:ModelCacheDir = Get-ModelCacheDir $script:WorkDir
    $resolved = $null
    if (-not [string]::IsNullOrWhiteSpace($ProfilesRoot)) {
        $resolved = Try-ProfilesRoot $ProfilesRoot
        if (-not $resolved) { $resolved = Try-AnyProfilesRoot $ProfilesRoot }
    }
    if (-not $resolved -and (Test-Path $rememberFile)) {
        try { $resolved = Try-ProfilesRoot ((Get-Content $rememberFile -Raw).Trim()) } catch {}
    }
    if (-not $resolved) {
        foreach ($d in @((Join-Path $env:APPDATA "r2modmanPlus-local"), (Join-Path $env:LOCALAPPDATA "r2modmanPlus-local"))) {
            $resolved = Try-ProfilesRoot $d
            if (-not $resolved) { $resolved = Try-AnyProfilesRoot $d }
            if ($resolved) { break }
        }
    }
    if ($resolved) { $ProfilesRoot = $resolved }
    if ($resolved) { Say "  [只换模型] 档目录：$ProfilesRoot" "DarkGray" }
    else { Say "  [只换模型] 没探测到 r2modman 的档目录 → 跳过 ① 插件自检（只装模型，不影响档）" "DarkGray" }
}
else {
$resolved = $null
$remembered = $null
$scanned = $false

# ① 命令行指定（宽松：数据文件夹 / profiles 目录都行；不存在就按给定的用，稍后新建）
#    —— 明确指定了就不再问
if (-not [string]::IsNullOrWhiteSpace($ProfilesRoot)) {
    $given = $ProfilesRoot.Trim().Trim('"').TrimEnd('\')
    $asData = Try-ProfilesRoot $given
    if ($asData) { $resolved = $asData } else { $resolved = $given }
    $script:PathSource = "命令行指定"
}

if (-not $resolved) {
    # ② 上次记住的位置 —— 只当"默认选项"，不当最终答案（有人每块盘都有一份 r2modman）
    if (-not $NoRemember -and (Test-Path $rememberFile)) {
        try {
            $prevTxt = (Get-Content $rememberFile -Raw).Trim()
            $rPrev = Try-ProfilesRoot $prevTxt
            if (-not $rPrev) { $rPrev = Try-AnyProfilesRoot $prevTxt }
            if ($rPrev) { $remembered = $rPrev }
        } catch {}
    }
    # ③ r2modman 自己记录过的路径（换过数据文件夹的人可能留下好几个）
    foreach ($hit in (Get-PathsFromAppFiles)) {
        $variants = @($hit)
        if ($hit -match '\\\\') { $variants += ($hit -replace '\\\\', '\') }
        foreach ($v in $variants) {
            if ($v -match '(?i)^(.*?r2modmanPlus-local)') { $c1 = Try-AnyProfilesRoot $Matches[1]; if ($c1) { Add-ProfCand $c1 } }
            if ($v -match '(?i)^(.*?)\Valheim(\profiles)?') { $c2 = Try-AnyProfilesRoot $Matches[1]; if ($c2) { Add-ProfCand $c2 } }
        }
    }
    # ④ 默认位置（APPDATA / LOCALAPPDATA / USERPROFILE）
    foreach ($d in @((Join-Path $env:APPDATA "r2modmanPlus-local"), (Join-Path $env:LOCALAPPDATA "r2modmanPlus-local"), (Join-Path $env:USERPROFILE "AppData\Roaming\r2modmanPlus-local"))) {
        $c = Try-ProfilesRoot $d
        if (-not $c) { $c = Try-AnyProfilesRoot $d }
        if ($c) { Add-ProfCand $c }
    }
    # 一个都没找到 → 扫盘
    if ($script:ProfCands.Count -eq 0) {
        Say "  [2/7] 默认位置没有 r2modman 的档，正在扫描各硬盘（最多十几秒）…" "Yellow"
        $null = Scan-ProfCands
        $scanned = $true
    }
    # 上次装的那个排最前（多半就是要升级的那份）
    if ($remembered) {
        $idxR = -1
        for ($i = 0; $i -lt $script:ProfCands.Count; $i++) { if ($script:ProfCands[$i] -ieq $remembered) { $idxR = $i; break } }
        if ($idxR -gt 0) { $script:ProfCands.RemoveAt($idxR); $script:ProfCands.Insert(0, $remembered) }
        elseif ($idxR -lt 0) { $script:ProfCands.Insert(0, $remembered) }
    }

    if ($script:ProfCands.Count -eq 1) {
        $resolved = $script:ProfCands[0]
        $script:PathSource = "自动找到"
    }
    elseif (($script:ProfCands.Count -gt 1) -and $NonInteractive) {
        $resolved = $script:ProfCands[0]
        $script:PathSource = "自动选了第 1 个（-NonInteractive）"
        Say "  [非交互] 检测到 $($script:ProfCands.Count) 个 r2modman 数据文件夹，用了第 1 个：" "Yellow"
        for ($i = 0; $i -lt $script:ProfCands.Count; $i++) { Say ("          {0}) {1}   （{2}）" -f ($i + 1), $script:ProfCands[$i], (Get-ProfCandNote $script:ProfCands[$i])) "DarkGray" }
        Say "        想指定别的：-ProfilesRoot <路径>" "DarkGray"
    }
    elseif ($script:ProfCands.Count -gt 1) {
        # ---- 交互：把所有找到的数据文件夹列出来让你选（装在哪个盘、哪一份，由你定）----
        function Show-ProfCands {
            Say "  现在有 $($script:ProfCands.Count) 个候选（数据文件夹）：" "Cyan"
            for ($i = 0; $i -lt $script:ProfCands.Count; $i++) {
                $tagP = ""
                if ($remembered -and ($script:ProfCands[$i] -ieq $remembered)) { $tagP = "   ← 上次装在这" }
                Say ("    {0}) {1}{2}" -f ($i + 1), $script:ProfCands[$i], $tagP)
                Say ("        {0}" -f (Get-ProfCandNote $script:ProfCands[$i])) "DarkGray"
            }
            if (-not $scanned) { Say "    9) 再扫描所有硬盘，找找别的数据文件夹" }
            Say "    0) 我自己输入路径（r2modman → 左下 Settings → Locations → Browse data folder 能看到）"
        }
        Say ""
        Say "  检测到 $($script:ProfCands.Count) 个 r2modman 数据文件夹（有人每块盘都装过一份，所以要你确认一次）" "Cyan"
        Show-ProfCands
        while (-not $resolved) {
            $ansP = "" + (Read-Host "  装到哪个？(直接回车 = 1)")
            if ($ansP -match '^\s*$') { $resolved = $script:ProfCands[0]; $script:PathSource = "你选的（第 1 项）" }
            elseif (($ansP -match '^\s*9\s*$') -and (-not $scanned)) {
                Say "        扫描中（最多十几秒）…" "Yellow"
                $added = Scan-ProfCands
                $scanned = $true
                if ($remembered) {
                    $idxR = -1
                    for ($i = 0; $i -lt $script:ProfCands.Count; $i++) { if ($script:ProfCands[$i] -ieq $remembered) { $idxR = $i; break } }
                    if ($idxR -gt 0) { $script:ProfCands.RemoveAt($idxR); $script:ProfCands.Insert(0, $remembered) }
                }
                Say "        扫描完成：新增 $added 个候选" "Gray"
                Show-ProfCands
                continue
            }
            elseif ($ansP -match '^\s*0\s*$') {
                $typedP = ("" + (Read-Host "  把数据文件夹路径粘进来（回车=放弃）")).Trim().Trim('"').TrimEnd('\')
                if ([string]::IsNullOrWhiteSpace($typedP)) { continue }
                $rT = Try-ProfilesRoot $typedP
                if (-not $rT) { $rT = Try-AnyProfilesRoot $typedP }
                if (-not $rT -and (Test-Path $typedP)) { $rT = $typedP }
                if ($rT) { $resolved = $rT; $script:PathSource = "你手动指定" }
                else { Say "        这个路径用不了（不存在，或不是 r2modman 数据文件夹），再试一次。" "Yellow" }
                continue
            }
            elseif (($ansP -match '^\d+$') -and ([int]$ansP -ge 1) -and ([int]$ansP -le $script:ProfCands.Count)) {
                $resolved = $script:ProfCands[[int]$ansP - 1]
                $script:PathSource = "你选的（第 $ansP 项）"
            }
            else { Say "        输入看不懂：回车 = 第 1 项，0 = 自己输入路径，9 = 再扫一遍。" "Yellow" }
        }
    }
}
# ⑥ 问用户
if (-not $resolved -and -not $NonInteractive) {
    Say ""
    Say "  没能自动找到 r2modman 的档目录。手动找法：" "Yellow"
    Say "    打开 r2modman → 左下 Settings（设置）→ Locations 标签页 → 点 Browse data folder" "Yellow"
    Say "    弹出的文件夹就是数据文件夹（里面有 Valheim、config、image-cache 等）" "Yellow"
    Say "    如果 r2modman 还没装/没运行过：先装好、启动一次、选好 Valheim 位置，再回来运行本脚本。" "Yellow"
    $ans = "" + (Read-Host "  把该文件夹路径粘贴到这里（也可以把文件夹直接拖进本窗口），回车=放弃")
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
}   # ← 结束"完整安装"的档目录探测（-VRMOnly 走上面的轻量分支）

# ---------- 3~7) 只在"完整安装"时执行；-VRMOnly 直接跳到下面的 VRM 段 ----------
if (-not $VRMOnly) {

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
        if ($script:packTmpExtract -or ($env:TEMP -and ($bakParent -like "$env:TEMP*"))) {
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
            if (Test-Path (Join-Path $dst "mods.yml")) {
                Copy-Item (Join-Path $dst "mods.yml") (Join-Path $bakRoot "mods.yml") -Force
                Say "        备份完成（plugins 目录 + mods.yml）。" "Green"
            } else {
                Say "        备份完成（plugins 目录）。[注意] 档里没有 mods.yml，档可能不完整。" "Yellow"
            }
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


# ---------- 5b) 强制统一的配置项 ----------
# 升级模式会跳过 BepInEx\config（保留你的设置），所以这类"不带 [Synced with Server]"的开关
# 必须安装后强制校正，否则每人各自为政（例：多人同时开同一个箱子 → 并发搬运容易物品不同步）
$cfgDir = Join-Path $dst "BepInEx\config"
$ensured = 0; $ensuredList = @()
foreach ($e in $script:EnforcedConfig) {
    $cf = Join-Path $cfgDir $e.File
    if (-not (Test-Path $cf)) { continue }
    if (Set-IniValue -path $cf -section $e.Section -key $e.Key -value $e.Value) { $ensured++; $ensuredList += $e.File }
}
if ($ensured -gt 0) {
    Say ("        已校正必须一致的配置项 $ensured 处：" + ($ensuredList -join "、")) "Green"
} else {
    Say "        必须一致的配置项已符合（无需校正）。" "DarkGray"
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

}   # ← 结束 3~7 步（-VRMOnly 不走这里）

# ---------- 附加：ValheimVRM（角色自定义模型；两处不同落点）----------
# 源目录里两个子目录名（「…に入れるファイル」/「…に入れる文件」两种写法都认）：
#   BepInEx_pluginsに入れるファイル      → 装进 r2modman 的档：<档>\BepInEx\plugins\ValheimVRM_1.2.2\
#   valheim_Data_Managedに入れるファイル → 装进游戏本体：<游戏>\valheim_Data\Managed\
# 模型与设置（ValheimVRM.zip 里的 .vrm + settings_*.txt）→ <游戏>\ValheimVRM\
function Resolve-VrmSub([string]$parent, [string]$baseName) {
    foreach ($suffix in @("ファイル", "文件")) {
        $p = Join-Path $parent ($baseName + $suffix)
        if (Test-Path $p) { return $p }
    }
    return $null
}
$vrmPack = $null
foreach ($cand in @((Join-Path $packRoot "ValheimVRM_手动安装"), (Join-Path $packRoot "vrm"), $packRoot)) {
    if ([string]::IsNullOrWhiteSpace($cand) -or -not (Test-Path $cand)) { continue }
    if ((Resolve-VrmSub $cand "BepInEx_pluginsに入れる") -or (Resolve-VrmSub $cand "valheim_Data_Managedに入れる")) { $vrmPack = $cand; break }
}
$srcVrmPlugins = $null
$srcVrmManaged = $null
if ($vrmPack) {
    $srcVrmPlugins = Resolve-VrmSub $vrmPack "BepInEx_pluginsに入れる"
    $srcVrmManaged = Resolve-VrmSub $vrmPack "valheim_Data_Managedに入れる"
}

if ($vrmPack -and -not $SkipVRM) {
    Section "附加：ValheimVRM（角色换模型）"
    Say "  这个 mod 和别的不一样：它要放【两个不同的地方】，r2modman 只负责其中一个。"
    Say "    ① 插件   → r2modman 的档里 : <档>\BepInEx\plugins\ValheimVRM_1.2.2\"
    Say "    ② 运行时 dll → 游戏本体里   : <游戏>\valheim_Data\Managed\"
    Say "    ③ 模型与设置 → 游戏本体里   : <游戏>\ValheimVRM\<角色名>.vrm + settings_<角色名>.txt"
    $doVrm = $true
    if (-not $NonInteractive) {
        $ansV = "" + (Read-Host "  一并配置 ValheimVRM 吗？(Y/n)")
        if ($ansV -match "^[Nn]") { $doVrm = $false }
    }
    if (-not $doVrm) {
        Say "  已跳过。之后想装：重跑本脚本，或按 $((Split-Path $vrmPack -Leaf))\说明_ValheimVRM.txt 手动做。" "DarkGray"
    } else {
        $vrmOk = @{ "插件" = $false; "Managed" = $false; "模型" = $false }
        $script:vrmActiveName = ""

        # ---- ① 插件：装进 r2modman 的档（这一步不依赖游戏目录，先做）----
        # 目标位置：先找档里已存在的 ValheimVRM.dll 所在目录（避免新建平行目录导致插件重复加载），
        #          找不到就用本包约定的 <档>\BepInEx\plugins\ValheimVRM_1.2.2\
        $profRootThis = Join-Path $ProfilesRoot $ProfileName
        $pluginsDir = Join-Path $profRootThis "BepInEx\plugins"
        $plugDst = $null
        if (Test-Path $pluginsDir) {
            $found = Get-ChildItem -Path $pluginsDir -Recurse -File -Filter "ValheimVRM.dll" -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($found) { $plugDst = $found.DirectoryName }
        }
        if (-not $plugDst) { $plugDst = Join-Path $pluginsDir "ValheimVRM_1.2.2" }
        if ($srcVrmPlugins -and $VRMOnly) {
            # 只换模型模式：① 只做检查（不写档里的任何文件）
            $pMissing = @()
            foreach ($f in (Get-ChildItem -Path $srcVrmPlugins -File)) {
                $t = Join-Path $plugDst $f.Name
                if (-not (Test-Path $t)) { $pMissing += $f.Name; continue }
                if ((Get-FileHash $f.FullName -Algorithm MD5).Hash -ne (Get-FileHash $t -Algorithm MD5).Hash) { $pMissing += $f.Name }
            }
            if ($pMissing.Count -eq 0) { Say "        ① 插件（档里）：已是最新 ✓（只换模型模式不写档）" "Green"; $vrmOk["插件"] = $true }
            else { Say "        ① 插件（档里）：缺/不一致 → $($pMissing -join '、')（跑一次完整安装即可补齐）" "Yellow" }
        }
        elseif ($srcVrmPlugins) {
            $pCopy = 0; $pSame = 0; $pBak = 0
            $pBakDir = Join-Path (Join-Path $profRootThis "BepInEx") ("_vrm_backup_" + (Get-Date -Format "yyyyMMdd-HHmmss"))
            try { New-Item -ItemType Directory -Path $plugDst -Force | Out-Null } catch {}
            foreach ($f in (Get-ChildItem -Path $srcVrmPlugins -File)) {
                $t = Join-Path $plugDst $f.Name
                if (Test-Path $t) {
                    if ((Get-FileHash $f.FullName -Algorithm MD5).Hash -eq (Get-FileHash $t -Algorithm MD5).Hash) { $pSame++; continue }
                    New-Item -ItemType Directory -Path $pBakDir -Force | Out-Null
                    Copy-Item $t (Join-Path $pBakDir $f.Name) -Force; $pBak++
                }
                Copy-Item $f.FullName $t -Force; $pCopy++
            }
            Say "        ① 插件 → $plugDst" "Green"
            Say "           新放/更新 $pCopy 个（本来就一致 $pSame 个；替换前备份 $pBak 个）"
            if ($pBak -gt 0) { Say "           备份目录：$pBakDir" "DarkGray" }
            $vrmOk["插件"] = (Test-Path (Join-Path $plugDst "ValheimVRM.dll"))
        } else {
            $hasPlug = Test-Path (Join-Path $plugDst "ValheimVRM.dll")
            if ($hasPlug) { Say "        ① 插件：包内没有插件源目录，但档里已经有 ValheimVRM 插件了 ✓" "Green"; $vrmOk["插件"] = $true }
            else { Say "        ① 插件：[注意] 包内没有 BepInEx_pluginsに入れるファイル，档里也没有 ValheimVRM 插件。" "Yellow" }
        }

        # ---- ②③ 游戏侧：Managed dll 与模型（需要游戏目录）----
        $game = ""
        if (-not [string]::IsNullOrWhiteSpace($GameDir)) { $game = $GameDir.Trim().Trim('"').TrimEnd('\') }
        if (-not $game) { $game = Find-ValheimGameDir }
        if (-not $game -or -not (Test-Path (Join-Path $game "valheim_Data\Managed"))) {
            if (-not $NonInteractive) {
                Say "  没能自动找到 Valheim 游戏目录（要含 valheim.exe 与 valheim_Data\Managed 的那一层）。" "Yellow"
                $g = "" + (Read-Host "  把游戏目录粘进来（例如 I:\steam\steamapps\common\Valheim），回车=跳过")
                if (-not [string]::IsNullOrWhiteSpace($g)) {
                    $g = $g.Trim().Trim('"').TrimEnd('\')
                    if (Test-Path (Join-Path $g "valheim_Data\Managed")) { $game = $g }
                }
            }
            if (-not $game -or -not (Test-Path (Join-Path $game "valheim_Data\Managed"))) {
                Say "        [跳过] 没找到游戏目录，② Managed dll 与 ③ 模型没放（之后重跑本脚本即可）。" "Yellow"
                $game = ""
            }
        }

        if ($game) {
            Say "  游戏目录：$game" "Green"
            $managed   = Join-Path $game "valheim_Data\Managed"
            $bakDir    = Join-Path $game ("_vrm_backup_" + (Get-Date -Format "yyyyMMdd-HHmmss"))
            $copied = 0; $replaced = 0; $same = 0
            if ($srcVrmManaged) {
                foreach ($f in (Get-ChildItem -Path $srcVrmManaged -File)) {
                    $t = Join-Path $managed $f.Name
                    if (Test-Path $t) {
                        if ((Get-FileHash $f.FullName -Algorithm MD5).Hash -eq (Get-FileHash $t -Algorithm MD5).Hash) { $same++; continue }
                        New-Item -ItemType Directory -Path $bakDir -Force | Out-Null
                        Copy-Item $t (Join-Path $bakDir $f.Name) -Force; $replaced++
                    }
                    Copy-Item $f.FullName $t -Force; $copied++
                }
                Say "        ② Managed dll → $managed" "Green"
                Say "           新放/更新 $copied 个 dll（本来就一致 $same 个；替换前备份 $replaced 个 → $((Split-Path $bakDir -Leaf))）"
            } else {
                Say "        ② [注意] 包里缺少 valheim_Data_Managedに入れるファイル 目录，未能放 dll。" "Yellow"
            }

            $vrmTarget = Join-Path $game "ValheimVRM"
            try { New-Item -ItemType Directory -Path $vrmTarget -Force | Out-Null } catch {}

            # ---- 3a) 候选模型：清单(包内/在线) + 包内 Models\ + -ModelPath + 本机缓存 ----
            #      模型不再进安装包：清单指向【私有仓库 Release 附件】，按需下载 → 进本机缓存 → 换模型不再重下
            $cacheDir = $script:ModelCacheDir
            if ([string]::IsNullOrWhiteSpace($cacheDir)) { $cacheDir = Get-ModelCacheDir $script:WorkDir }
            $script:ModelCacheDir = $cacheDir
            $modelsDir = Join-Path $vrmPack "Models"
            if (-not (Test-Path $modelsDir)) { $modelsDir = Join-Path $packRoot "Models" }
            $man = $null
            $modelList = @()
            if ($script:ModelLibLoaded) {
                $man = Get-ModelManifest -packRoot $packRoot -source $ModelSource
                if ($man) {
                    if ($man.repo) { $script:ModelRepo = "" + $man.repo }
                    if ($man.tag)  { $script:ModelTag  = "" + $man.tag }
                }
                $modelList = Get-ModelCandidates -packRoot $packRoot -cacheDir $cacheDir -modelPath $ModelPath -manifestSource $ModelSource -manifest $man
            } else {
                Say "        ③ [跳过] 缺模型库 ModelLib.ps1 → 这一步跳过（只更新 mod 不受影响；以后用 换模型.bat 可单独装模型）" "Yellow"
            }
            if ($modelList.Count -gt 0) {
                $nC = @($modelList | Where-Object { $_.Cached }).Count
                Say ("  模型：可选 {0} 个（本机已有 {1} 个，需下载 {2} 个）" -f $modelList.Count, $nC, ($modelList.Count - $nC)) "DarkGray"
                if ($modelList.Count -gt $nC) { Say "         模型在私有仓库里按需下载；不选就不会下，装过的以后换模型不用重下" "DarkGray" }
            }
            # 兼容老包 / 手工放法：ValheimVRM.zip（旧版布局）或包根直接丢的 .vrm
            if ($modelList.Count -eq 0) {
                $zipModel = Join-Path $vrmPack "ValheimVRM.zip"
                if (Test-Path $zipModel) {
                    $vrmLegacyTmp = Join-Path $env:TEMP ("vrmm_" + (Get-Date -Format "HHmmss"))
                    try {
                        Add-Type -AssemblyName System.IO.Compression.FileSystem
                        [System.IO.Compression.ZipFile]::ExtractToDirectory($zipModel, $vrmLegacyTmp)
                        $v = Get-ChildItem -Path $vrmLegacyTmp -Recurse -File -Filter "*.vrm" -ErrorAction SilentlyContinue | Select-Object -First 1
                        if ($v) {
                            $s = Get-ChildItem -Path $vrmLegacyTmp -Recurse -File -Filter "settings_*.txt" -ErrorAction SilentlyContinue | Select-Object -First 1
                            $modelList += [pscustomobject]@{
                                Name="默认模型（旧版包内）"; Vrm=$v.FullName; Local=$v.FullName; Cached=$true; Remote=$false
                                Asset=""; Url=""; SizeMB=[math]::Round($v.Length/1MB,1); Sha256=""; VrmFile=$v.Name
                                Desc="（旧版包里自带的模型）"; Settings=$(if ($s) { $s.FullName } else { $null }); Source="legacy"
                            }
                            Say "        [说明] 这是旧版布局的包（只带 1 个模型，就用它）" "DarkGray"
                        }
                    } catch { Say "        [注意] ValheimVRM.zip 解压失败：$($_.Exception.Message)" "Yellow" }
                }
            }
            foreach ($f in (Get-ChildItem -Path $vrmPack -File -Filter "*.vrm" -ErrorAction SilentlyContinue)) {
                $modelList += [pscustomobject]@{
                    Name=$f.BaseName; Vrm=$f.FullName; Local=$f.FullName; Cached=$true; Remote=$false
                    Asset=""; Url=""; SizeMB=[math]::Round($f.Length/1MB,1); Sha256=""; VrmFile=$f.Name
                    Desc="（包根目录里的 .vrm）"; Settings=$null; Source="packroot"
                }
            }
            # 显示顺序 = 清单顺序（已取消默认模型；不再把某个模型排到第一位）
            $script:vrmActiveName = ""
            if ($modelList.Count -eq 0) {
                Say "        ③ [注意] 没找到任何模型文件（包里应有 Models\<模型名>\<模型名>.vrm）" "Yellow"
                $vrmOk["模型"] = (@(Get-ChildItem -Path $vrmTarget -File -Filter "*.vrm" -ErrorAction SilentlyContinue).Count -gt 0)
            } else {
                # ---- 3b) 选哪个/哪几个（多选：选中的下载进缓存；第一个作为当前使用的）----
                $picks = @()
                if (-not [string]::IsNullOrWhiteSpace($VrmModel)) {
                    $VrmModel = $VrmModel.Trim().Trim('"')
                    if (Test-Path $VrmModel) {
                        $picks = @([pscustomobject]@{ Name = (Split-Path $VrmModel -Leaf); Vrm = (Resolve-Path $VrmModel).Path; Settings = $null; Cached = $true })
                        Say "        用 -VrmModel 指定的文件：$($picks[0].Vrm)" "DarkGray"
                    } else {
                        $hit = $modelList | Where-Object { $_.Name -eq $VrmModel } | Select-Object -First 1
                        if (-not $hit) { $hit = $modelList | Where-Object { $_.Name -like "*$VrmModel*" } | Select-Object -First 1 }
                        if ($hit) { $picks = @($hit) }
                        else { Say "        [注意] -VrmModel 指定的「$VrmModel」不在清单里 → 跳过模型这步（用 -ListModels 看清单）" "Yellow" }
                    }
                }
                if ($picks.Count -eq 0 -and $Models) {
                    foreach ($n in ($Models -split "[,，;；\s]+" | Where-Object { $_ })) {
                        $hit = $modelList | Where-Object { $_.Name -eq $n } | Select-Object -First 1
                        if (-not $hit) { $hit = $modelList | Where-Object { $_.Name -like "*$n*" } | Select-Object -First 1 }
                        if ($hit) { $picks += $hit } else { Say "        [注意] -Models 里的「$n」不在清单里，跳过。" "Yellow" }
                    }
                }
                if ($picks.Count -eq 0 -and -not $NonInteractive) {
                    $previewDir = Join-Path $packRoot "Models\预览"
                    while ($picks.Count -eq 0) {
                        Show-ModelCandidates $modelList $cacheDir
                        Say "          0) 不换模型（保持现状）"
                        Say "          p = 打开参考图总览（一张图看全部，图上的编号就是上面的序号）" "DarkGray"
                        Say "          p3 = 只看第 3 个模型的大图；f = 打开参考图文件夹" "DarkGray"
                        Say "          输入：回车 或 0 = 不换（保持现状）；可多选（如 1,3 或 2-4）；选中的都会下到本机，第一个作为当前用的"
                        Say "          （本版已取消默认模型 —— 请按上面的编号挑，想看效果可以先按 p 看图）" "DarkGray"
                        $sel = "" + (Read-Host "        选哪个/哪些？(回车 = 不换)")
                        # 看参考图：p / p<编号> / f
                        if ($sel -match '^\s*[pP]\s*(\d+)?\s*$') {
                            $wantN = 0
                            if ($Matches[1]) { $wantN = [int]$Matches[1] }
                            $opened = $false
                            if (Get-Command Show-ModelPreview -ErrorAction SilentlyContinue) {
                                if (Test-Path $previewDir) {
                                    try { $opened = [bool](Show-ModelPreview -PackRoot $packRoot -Index $wantN) } catch { $opened = $false }
                                }
                            }
                            if (-not $opened) {
                                if (Test-Path $previewDir) {
                                    try { Start-Process -FilePath "explorer.exe" -ArgumentList ('"' + $previewDir + '"') | Out-Null } catch {}
                                } else { Say "        （这个包里没有参考图目录 Models\预览\）" "Yellow" }
                            }
                            Say ""
                            continue
                        }
                        if ($sel -match '^\s*[fF]\s*$') {
                            if (Test-Path $previewDir) {
                                try { Start-Process -FilePath "explorer.exe" -ArgumentList ('"' + $previewDir + '"') | Out-Null } catch {}
                            } else { Say "        （这个包里没有参考图目录 Models\预览\）" "Yellow" }
                            Say ""
                            continue
                        }
                        if ($sel -match '^\s*0\s*$' -or $sel -match '^\s*$') { $picks = @(); break }
                        $idx = @()
                        foreach ($tok in ($sel -split "[,，\s]+" | Where-Object { $_ })) {
                            if ($tok -match '^(\d+)\s*-\s*(\d+)$') { for ($k = [int]$Matches[1]; $k -le [int]$Matches[2]; $k++) { $idx += $k } }
                            elseif ($tok -match '^\d+$') { $idx += [int]$tok }
                        }
                        $idx = @($idx | Sort-Object -Unique | Where-Object { $_ -ge 1 -and $_ -le $modelList.Count })
                        if ($idx.Count -eq 0) { Say "        没看懂 —— 可以输 1 / 1,3 / 2-4 / p 看参考图 / 0 不换。" "Yellow"; Say ""; continue }
                        foreach ($k in $idx) { $picks += $modelList[$k - 1] }
                    }
                }
                if ($picks.Count -eq 0 -and $NonInteractive) {
                    $cachedOnly = @($modelList | Where-Object { $_.Cached })
                    if ($cachedOnly.Count -gt 0) {
                        $picks = @($cachedOnly[0])
                        Say "        （非交互模式：用本机已有的「$($picks[0].Name)」；不会自动下载几百 MB）" "DarkGray"
                    } else {
                        Say "        （非交互模式：本机没有缓存模型 → 跳过模型这步；要装模型请交互运行或用 -Models）" "DarkGray"
                    }
                }

                # ---- 3b-2) 需要的先下载（多选逐个下；失败的跳过，不影响其它）----
                if ($picks.Count -gt 0) {
                    $need = @($picks | Where-Object { -not $_.Cached })
                    $mToken = ""
                    if ($need.Count -gt 0) {
                        $mToken = Get-ModelToken -given $ModelToken -packRoot $packRoot
                        if ([string]::IsNullOrWhiteSpace($mToken) -and -not $NonInteractive) {
                            Say ""
                            Say "        模型放在【私有】仓库里，下载要一次凭据（GitHub 令牌，只读权限就够；输一次会记住）" "Yellow"
                            $mToken = Get-ModelToken -packRoot $packRoot -Prompt -Save
                        }
                    }
                    $okPicks = @()
                    foreach ($pc in $picks) {
                        if ($pc.Cached -and $pc.Vrm) { $okPicks += $pc; continue }
                        Say ""
                        if ([string]::IsNullOrWhiteSpace($mToken) -and -not $pc.Url) {
                            Say "        [×] 没有下载凭据 → 跳过「$($pc.Name)」（也可以用 -ModelPath 直接把 .vrm 给它）" "Yellow"
                            continue
                        }
                        $res = Save-ModelToCache -Cand $pc -cacheDir $cacheDir -packRoot $packRoot -repo $script:ModelRepo -tag $script:ModelTag -token $mToken
                        if ($res) { $pc.Vrm = $res.Vrm; $pc.Settings = $res.Settings; $pc.Cached = $true; $okPicks += $pc }
                        else { Say "        [×] 「$($pc.Name)」没装上（其它模型不受影响）" "Yellow" }
                    }
                    $picks = @($okPicks)
                    if ($picks.Count -gt 1) { Say "        （另外 $($picks.Count - 1) 个也已存到本机，之后用 换模型.bat 秒切、不用再下）" "DarkGray" }
                }
                $pick = $null
                if ($picks.Count -gt 0) { $pick = $picks[0] }
                if (-not $pick) { $pick = "skip" }

                if ($pick -eq "skip") {
                    Say "        ③ 已跳过（保持现有模型不动）" "DarkGray"
                    $vrmOk["模型"] = (@(Get-ChildItem -Path $vrmTarget -File -Filter "*.vrm" -ErrorAction SilentlyContinue).Count -gt 0)
                } else {
                    # ---- 3c) 问角色名（每个人的名字不同，由玩家自己输）----
                    $charName = $CharName.Trim().Trim('"')
                    $existing = @(Get-ChildItem -Path $vrmTarget -File -Filter "*.vrm" -ErrorAction SilentlyContinue | ForEach-Object { $_.BaseName })
                    if (-not [string]::IsNullOrWhiteSpace($charName) -and ($charName -match '[\\/:*?"<>|]')) {
                        Say "        [注意] -CharName 里有不能用于文件名的字符，改用交互输入。" "Yellow"
                        $charName = ""
                    }
                    if ([string]::IsNullOrWhiteSpace($charName) -and -not $NonInteractive) {
                        Say ""
                        Say "        接下来在脚本里输入【你游戏里的角色名】就行，不用自己去文件夹里找文件改名："
                        Say "          · 脚本会把模型复制成  <角色名>.vrm"
                        Say "          · 并把设置复制成     settings_<角色名>.txt"
                        Say "          （名字要和游戏里一模一样；字母别错，大小写无所谓）"
                        if ($existing.Count -gt 0) {
                            Say ""
                            Say "        这个目录里已经有这些模型文件（= 以前用过的角色名）："
                            for ($i = 0; $i -lt $existing.Count; $i++) { Say ("          {0}) {1}" -f ($i + 1), $existing[$i]) }
                            Say "        输编号 = 直接用上面那个名字（最省事、也不会拼错）；输别的 = 当成新名字"
                        }
                        Say "        输入 0 = 不换模型（跳过这步）"
                        for ($try = 0; $try -lt 4; $try++) {
                            $ansRaw = Read-Host "        角色名"
                            if ($null -eq $ansRaw) { $ansRaw = "" }
                            $ans = $ansRaw.Trim().Trim('"')
                            if ([string]::IsNullOrWhiteSpace($ans)) { Say "        （这次没读到输入）请再输一次；输入 0 = 不换模型。" "Yellow"; continue }
                            if ($ans -match '^\s*0\s*$') { $charName = "skip"; break }
                            if (($existing.Count -gt 0) -and ($ans -match '^\d+$')) {
                                $idx = [int]$ans - 1
                                if (($idx -ge 0) -and ($idx -lt $existing.Count)) {
                                    $charName = $existing[$idx]
                                    Say "        用目录里已有的名字：$charName" "Green"
                                    break
                                }
                                Say "        编号超出范围（1-$($existing.Count)）；想用新名字就直接输名字。" "Yellow"
                                continue
                            }
                            if ($ans -match '[\\/:*?"<>|]') { Say "        含不能用于文件名的字符，换一个。" "Yellow"; continue }
                            $charName = $ans
                            Say "        角色名：$charName → 会生成 $charName.vrm 与 settings_$charName.txt" "Green"
                            break
                        }
                    }
                    if ([string]::IsNullOrWhiteSpace($charName) -and $NonInteractive -and $existing.Count -ge 1) {
                        $charName = $existing[0]
                        Say "        （非交互模式：沿用现有角色名「$charName」）" "DarkGray"
                    }

                    if ([string]::IsNullOrWhiteSpace($charName) -or $charName -eq "skip") {
                        Say "        ③ 没有拿到角色名 → 模型这步跳过（想装：重跑本脚本，或双击 换模型.bat）" "Yellow"
                        $vrmOk["模型"] = (@(Get-ChildItem -Path $vrmTarget -File -Filter "*.vrm" -ErrorAction SilentlyContinue).Count -gt 0)
                    } else {
                        Copy-Item $pick.Vrm (Join-Path $vrmTarget "$charName.vrm") -Force
                        $setDst = Join-Path $vrmTarget "settings_$charName.txt"
                        if ($pick.Settings -and (Test-Path $pick.Settings)) { Copy-Item $pick.Settings $setDst -Force }
                        Say "        ③ 模型 → $vrmTarget" "Green"
                        Say "           模型： $charName.vrm（用的「$($pick.Name)」，只是复制一份改名；源文件没动）"
                        if (Test-Path $setDst) { Say "           设置： settings_$charName.txt ✓" "Green" }
                        else { Say "           设置： 缺失（插件会退回默认值：模型大小 1.1、亮度 0.8…）" "Yellow" }
                        $others = @($existing | Where-Object { $_ -ne $charName } | ForEach-Object { "$_.vrm" })
                        if ($others.Count -gt 0) {
                            Say "           目录里还有其它角色的模型：$($others -join '、')（不影响使用：插件只按你当前角色名找文件）" "DarkGray"
                            if (-not $NonInteractive) {
                                $ansMove = "" + (Read-Host "           要把这些旧模型收进备份文件夹吗？(y/N，默认留着)")
                                if ($ansMove -match '^(?i)\s*y') {
                                    $oldDir = Join-Path $vrmTarget ("_旧模型_" + (Get-Date -Format "yyyyMMdd-HHmmss"))
                                    try {
                                        New-Item -ItemType Directory -Path $oldDir -Force | Out-Null
                                        $mv = 0
                                        foreach ($o in $others) {
                                            $srcF = Join-Path $vrmTarget $o
                                            $setS = Join-Path $vrmTarget ("settings_" + [System.IO.Path]::GetFileNameWithoutExtension($o) + ".txt")
                                            if (Test-Path $srcF) { Move-Item $srcF (Join-Path $oldDir $o) -Force; $mv++ }
                                            if (Test-Path $setS) { Move-Item $setS $oldDir -Force }
                                        }
                                        Say "           已收进 $oldDir （里面 $mv 个，随时能搬回来）" "Green"
                                    } catch { Say "           [注意] 收拾旧模型失败：$($_.Exception.Message)（不影响使用）" "Yellow" }
                                }
                            }
                        }
                        $script:vrmActiveName = $charName
                        $vrmOk["模型"] = ((Test-Path (Join-Path $vrmTarget "$charName.vrm")) -and (Test-Path $setDst))
                    }
                }
            }
            if ($vrmLegacyTmp -and (Test-Path $vrmLegacyTmp)) { try { Remove-Item $vrmLegacyTmp -Recurse -Force -ErrorAction SilentlyContinue } catch {} }

            # ---- 3d) 包是从 zip 解出来的（在线安装 / -PackFile）时，把模型缓存到本机 ----
            #      （源在 %TEMP% 里，装完就没了；缓存后 换模型.bat 就不用再下 100MB）
            $cacheModels = $script:ModelCacheDir
            if ([string]::IsNullOrWhiteSpace($cacheModels)) { $cacheModels = Join-Path $env:LOCALAPPDATA "MAKABAKA\VRM\Models" }
            if ((Test-Path $modelsDir) -and $script:packTmpExtract -and ($modelsDir -notlike "$cacheModels*")) {
                try {
                    New-Item -ItemType Directory -Path $cacheModels -Force | Out-Null
                    $n = 0
                    foreach ($d in (Get-ChildItem -Path $modelsDir -Directory -ErrorAction SilentlyContinue)) {
                        $dstD = Join-Path $cacheModels $d.Name
                        New-Item -ItemType Directory -Path $dstD -Force | Out-Null
                        foreach ($f in (Get-ChildItem -Path $d.FullName -File)) {
                            $t = Join-Path $dstD $f.Name
                            if ((Test-Path $t) -and ((Get-FileHash $t -Algorithm MD5).Hash -eq (Get-FileHash $f.FullName -Algorithm MD5).Hash)) { continue }
                            Copy-Item $f.FullName $t -Force; $n++
                        }
                    }
                    $sDef = Join-Path $modelsDir "默认settings.txt"
                    if (Test-Path $sDef) { Copy-Item $sDef (Join-Path $cacheModels "默认settings.txt") -Force }
                    if ($n -gt 0) { Say "        （模型已缓存到本机：$cacheModels —— 以后换模型不用重新下载）" "DarkGray" }
                } catch { Say "        [注意] 模型缓存失败（不影响本次安装）：$($_.Exception.Message)" "DarkGray" }
            }

            Say "        ★ 模型按【角色名】生效：<角色名>.vrm 与 settings_<角色名>.txt" "Yellow"
            Say "          换角色名或换模型：重跑本脚本、或双击 换模型.bat 里输入新名字即可（脚本自动改名，不用自己动文件）" "Yellow"
            Say "        ★ Steam「验证游戏文件完整性」会清掉 Managed 里这些 dll；之后重跑本脚本即可恢复" "Yellow"
        }

        # ---- ④ 三处自检（照说明文档里那三条排查项自动核一遍）----
        Say ""
        Say "        —— VRM 三处自检 ——"
        $plugFile = Join-Path $plugDst "ValheimVRM.dll"
        if (Test-Path $plugFile) { Say "        [✓] ① 插件（档里）：$plugDst" "Green" }
        else { Say "        [×] ① 插件缺失：$plugDst（BepInEx\plugins\ 下应有 ValheimVRM.dll + ValheimVRM.shaders）" "Red" }
        if ($game) {
            $mOk = $true
            if ($srcVrmManaged) {
                foreach ($f in (Get-ChildItem -Path $srcVrmManaged -File)) {
                    if (-not (Test-Path (Join-Path (Join-Path $game "valheim_Data\Managed") $f.Name))) { $mOk = $false; break }
                }
            }
            if ($mOk) { Say "        [✓] ② Managed dll（游戏里）：$((@(Get-ChildItem -Path $srcVrmManaged -File)).Count) 个都在" "Green" }
            else { Say "        [×] ② Managed 里缺 dll（Steam 验证文件完整性会清掉，重跑本脚本即可）" "Red" }
            $vrmCount = @(Get-ChildItem -Path (Join-Path $game "ValheimVRM") -File -Filter "*.vrm" -ErrorAction SilentlyContinue).Count
            if ($script:vrmActiveName) {
                $vf = Join-Path (Join-Path $game "ValheimVRM") "$($script:vrmActiveName).vrm"
                $sf = Join-Path (Join-Path $game "ValheimVRM") "settings_$($script:vrmActiveName).txt"
                if ((Test-Path $vf) -and (Test-Path $sf)) { Say "        [✓] ③ 模型（游戏里）：$($script:vrmActiveName).vrm + settings_$($script:vrmActiveName).txt 都在" "Green" }
                elseif (Test-Path $vf) { Say "        [✓] ③ 模型（游戏里）：$($script:vrmActiveName).vrm 在；settings_$($script:vrmActiveName).txt 没有（插件会用默认值）" "Yellow" }
                else { Say "        [×] ③ 模型缺失：$(Join-Path $game 'ValheimVRM')\$($script:vrmActiveName).vrm" "Red" }
            }
            elseif ($vrmCount -gt 0) { Say "        [✓] ③ 模型（游戏里）：$vrmCount 个 .vrm 在 $(Join-Path $game 'ValheimVRM')" "Green" }
            else {
                Say "        [×] ③ 没找到 .vrm 模型：$(Join-Path $game 'ValheimVRM')" "Red"
                Say "            （想装模型：重跑本脚本、或双击 换模型.bat 选一个模型并输入你的角色名；脚本会自动命名）" "Yellow"
            }
        } else {
            Say "        [—] ②③ 未检查：没找到游戏目录（插件那半已经装好；游戏侧之后重跑本脚本即可）" "Yellow"
        }
    }
}

# ---------- ④ 武器/物品外观替换（独立模块）----------
if (-not $SkipSkin) {
    if (-not $script:SkinLibLoaded) {
        Say "  [—] 外观替换模块不可用（缺 SkinLib.ps1）→ 跳过（不影响 mod 更新）" "Yellow"
    } else {
        Say ""
        Say "  [外观] 武器/物品外观替换（纯客户端外观：不改数值、不发网络包、不写存档）" "Cyan"
        $skinLibDir = Get-SkinLibDir -PackRoot $packRoot
        if (-not $skinLibDir) {
            Say "        包内没有 Models\武器替换\ → 跳过这一步" "DarkGray"
        } else {
            $skinModels = @(Get-SkinModels -LibDir $skinLibDir)
            $skinTargets = @(Get-SkinTargets -LibDir $skinLibDir)
            Say "        模型库：$skinLibDir（$($skinModels.Count) 个模型 / $($skinTargets.Count) 个可选目标）" "DarkGray"
            $skinCfg = Join-Path $dst "BepInEx\config\local.itemskin.cfg"
            if (Test-Path -LiteralPath $skinCfg) {
                $curE = "?"; $curT = "?"; $curM = "?"
                foreach ($cl in (Get-Content -LiteralPath $skinCfg -Encoding UTF8)) {
                    if ($cl -match "^\s*Enabled\s*=\s*(\S+)")      { $curE = $Matches[1] }
                    elseif ($cl -match "^\s*TargetPrefab\s*=\s*(\S+)") { $curT = $Matches[1] }
                    elseif ($cl -match "^\s*Model\s*=\s*(\S+)")        { $curM = $Matches[1] }
                }
                if ($curE -eq "true") { Say "        当前：$curT  ←  $curM" "DarkGray" } else { Say "        当前：不替换（原版外观）" "DarkGray" }
            }
            # 外观模型的凭据（模型实体在私有仓库，按需下载）——与角色模型同一套解析：-ModelToken → 环境变量 → 模型凭据.txt

            $skinToken = ""

            if (Get-Command Get-ModelToken -ErrorAction SilentlyContinue) { $skinToken = Get-ModelToken -given $ModelToken -packRoot $packRoot }

            if (-not $skinToken) { Say "        [注意] 没找到模型凭据：只有本地已有的模型可用，需下载的模型会跳过" "DarkGray" }

            $skinLog = { param($m) Say $m }
            if ($NonInteractive) {
                if ($SkinTarget -and $SkinModel) {
                    $r = Install-Skin -ProfileDir $dst -LibDir $skinLibDir -Prefab $SkinTarget -ModelName $SkinModel -PackProfileDir $src -PackRoot $packRoot -Token $skinToken -Log $skinLog
                    if (-not $r.Ok) { Say "        [×] 外观替换失败（模型名或 prefab 名不对？）" "Yellow" }
                    else { Say "        配置文件：$($r.Cfg)" "DarkGray" }
                } elseif ($SkinTarget -or $SkinModel) {
                    Say "        [注意] -SkinTarget 与 -SkinModel 要一起给；本次不改动外观设置" "Yellow"
                } else {
                    Say "        （非交互：未指定 -SkinTarget/-SkinModel → 保持现有外观设置不动）" "DarkGray"
                }
            } else {
                $pick = Select-SkinInteractive -LibDir $skinLibDir
                if ([string]::IsNullOrEmpty($pick.Prefab) -or [string]::IsNullOrEmpty($pick.Model)) {
                    $skinR = Install-Skin -ProfileDir $dst -LibDir $skinLibDir -Prefab "" -ModelName "" -PackProfileDir $src -PackRoot $packRoot -Token $skinToken -Log $skinLog
                    Say "        已按「不替换」处理（想换：重跑本脚本、或游戏里按 F1 改 local.itemskin）" "DarkGray"
                } else {
                    $skinR = Install-Skin -ProfileDir $dst -LibDir $skinLibDir -Prefab $pick.Prefab -ModelName $pick.Model -PackProfileDir $src -PackRoot $packRoot -Token $skinToken -Log $skinLog
                    if ($skinR.Ok) {
                        Say "        ✓ 已应用：$($pick.Prefab)  ←  $($pick.Display)（$($pick.Model)）" "Green"
                        Say "        游戏里可在 F1 → Item Skin Replacer 里微调（缩放/旋转/光泽/发光颜色）" "DarkGray"
                    } else { Say "        [×] 应用失败（模型库里的目录没了？）" "Yellow" }
                }
            }
            Say "        适用：静态网格物品（弓/剑/斧/盾/镐/工具…）；带骨骼的盔甲不适用" "DarkGray"
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
