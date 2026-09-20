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
    -DryRun                只演练：打印"将要做什么"（档内哪些文件会被新增/覆盖、VRM 三处、要下哪些模型）后退出，
                           不写任何文件 —— 用来验证安装脚本的流程
    -Verify                只读自检：核对本机"装好没有"（加载器/面板/程序集/旧 loader/模型库/settings/F9 占用），
                           逐项 ✅/⚠️/❌ 后退出；退出码 1 = 有未通过项
    -NoRemember            不使用/不写入 install-path.txt（不记住上次的路径）
    -GameDir <路径>        指定 Valheim 游戏目录（一般不填，脚本自己找 Steam 库）
    -SkipVRM               跳过"附加：ValheimVRM"这一步（只想装档、不碰游戏目录时用）
    -ModsOnly              只更新 mod 本体（= 不装/不换模型）：日常升级用这个最省流量
    -ListModels            只列出可选的 VRM 模型（本机已缓存 / 需下载 + 大小）后退出，不动任何文件
    -Models <名字1,名字2>  要下载并缓存哪些模型（逗号分隔；名字从 -ListModels 抄；写 all = 全部）
    -AllModels             下载【全部】模型并放进模型库（配合 -VRMOnly：一次补齐，之后进游戏按 F9 随便切）
    -LibraryOnly           只把模型放进模型库，不改"当前正在用的那只"
    -ModelPath <文件|目录> 直接用本地的 .vrm（自己下的、别人发的模型拖进来即可）
    -ModelSource <url|文件> 模型清单来源覆盖（默认：包内 Models\models.json → 公开仓库在线清单）
    -ModelToken <令牌>     私有模型仓库的下载凭据（也可设环境变量 MAKABAKA_MODEL_TOKEN，或存 模型凭据.txt）

  关于 r2modman 装在别的盘：r2modman 的"数据文件夹"可以用 设置→Locations→Change data folder
  挪到别的盘，所以本脚本按以下顺序找（找到就用）：
    ① 命令行 -ProfilesRoot 指定 ② 上次记住的 install-path.txt ③ r2modman 自己记录过的路径
    ④ 默认位置（%APPDATA%\r2modmanPlus-local 等，含通过符号链接/联结点搬家的情况）
       —— 只有"里面确实还有档"才算候选；只剩空壳（数据文件夹被挪走了）就只提示、不当目标，
          免得 r2modman 明明在别的盘、脚本却静默装到 C 盘去
    ⑤ 逐个扫描所有固定硬盘（找 r2modmanPlus-local 或含 <游戏>\profiles 的目录）
    ⑥ 实在找不到就问你要路径（r2modman→设置→Locations→Browse data folder）
  找到 2 个以上候选（或加了 -Pick）会列出来让你选；只找到 1 个就直接用 —— [2/7] 会写出来源
    -Pick                  只找到一个数据文件夹时也列出来让你选一次（想装到别处时用）
#>
param(
    [string]$ProfilesRoot = "",
    [string]$ProfileName = "MAKABAKA",
    [switch]$NonInteractive,
    [switch]$Fresh,
    [switch]$Rollback,              # 从已选 profiles 根下的备份恢复档
    [switch]$ListBackups,           # 只列出可回滚备份，不改任何文件
    [string]$BackupPath = "",      # 指定回滚备份目录
    [switch]$Pick,               # 就算只找到一个数据文件夹也列出来让你选（想装到别处时用）
    [switch]$DetectOnly,
    [switch]$DryRun,             # 只演练：把将要做的每一步（改哪些档内文件、VRM 三处、要下哪些模型）打印出来，不写任何文件
    [switch]$Verify,             # 只读自检：核对"装好没有"，逐项 ✅/⚠️/❌ 后退出（退出码 1 = 有 ❌）
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
    [switch]$AllModels,          # 下载【全部】模型并放进模型库（配 -VRMOnly 用：只补库，不动当前使用的那只）
    [switch]$LibraryOnly,        # 只把模型放进模型库，不改"当前使用"的 <角色名>.vrm
    [switch]$ListModels,
    [string]$Models = "",
    [string]$ModelPath = "",
    [string]$ModelSource = "",
    [string]$ModelToken = "",
    [string]$SkinTarget = "",    # 武器/物品外观替换：要替换的原版 prefab 名（如 BowDraugrFang）
    [string]$SkinModel = "",     # 武器/物品外观替换：模型库里的模型目录名（如 灵跃心弦）
    [switch]$SkipSkin,           # 跳过外观替换模块
    [switch]$NoMirrorProbe       # 不测速：直接按脚本内置顺序用（默认先给每条线路测速，选最快的先下）
)

$script:MenuSelected = $false
if (-not $NonInteractive -and $PSBoundParameters.Count -eq 0) {
    while ($true) {
        Clear-Host
        Write-Host "============================================================" -ForegroundColor Cyan
        Write-Host "  英灵神殿 MAKABAKA 一键安装器" -ForegroundColor Cyan
        Write-Host "============================================================" -ForegroundColor Cyan
        Write-Host "  1) 安装 / 升级（推荐）"
        Write-Host "  2) 选择 r2modman 数据文件夹后安装 / 升级"
        Write-Host "  3) 列出备份"
        Write-Host "  4) 从备份回滚"
        Write-Host "  5) 安装结果自检（只读）"
        Write-Host "  6) 升级前演练（只读）"
        Write-Host "  7) 查看可选 VRM 模型"
        Write-Host "  8) 只安装 / 更换 VRM"
        Write-Host "  9) 只更新 mod，不处理 VRM"
        Write-Host "  0) 退出"
        Write-Host ""
        $menu = Read-Host "请输入编号"
        switch ($menu.Trim()) {
            '1' { $script:MenuSelected = $true; break }
            '2' {
                $ProfilesRoot = Read-Host "请输入 r2modman 数据文件夹、Valheim 文件夹或 profiles 文件夹路径"
                if ([string]::IsNullOrWhiteSpace($ProfilesRoot)) { continue }
                $Pick = $true; $script:MenuSelected = $true; break
            }
            '3' { $ListBackups = $true; $script:MenuSelected = $true; break }
            '4' { $Rollback = $true; $script:MenuSelected = $true; break }
            '5' { $Verify = $true; $script:MenuSelected = $true; break }
            '6' { $DryRun = $true; $script:MenuSelected = $true; break }
            '7' { $ListModels = $true; $script:MenuSelected = $true; break }
            '8' { $VRMOnly = $true; $script:MenuSelected = $true; break }
            '9' { $ModsOnly = $true; $SkipVRM = $true; $script:MenuSelected = $true; break }
            '0' { exit 0 }
            default { Write-Host "输入无效，请输入 0 到 9。" -ForegroundColor Yellow; Start-Sleep -Seconds 1 }
        }
        if ($script:MenuSelected) { break }
    }
}

$ErrorActionPreference = "Stop"
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}
$OutputEncoding = [System.Text.Encoding]::UTF8

# ---------- 出厂校验值（不一致只提示，不阻断）----------
$Expect = @{
    "BepInEx\plugins\RandyKnapp-EpicLoot\EpicLoot.dll" = "4ca65ee6417ace9bc35187f35be2e5d0"
    "BepInEx\plugins\blacks7ar-Endurance\Endurance.dll"   = "5e632a79528a5fe12c792afbb95e7d65"
    "BepInEx\plugins\Skarif-AutoRepairBuilding\AutoRepairBuilding.dll" = "3519ae6136d816dbc49425f002ed3447"
    "BepInEx\plugins\SafeBox\SafeBox.dll" = "0ee83cd3688447e723365119649d2a8c"
    "BepInEx\plugins\KeepBuffsOnDeath\KeepBuffsOnDeath.dll" = "6fc8037642f4bc4508d585312525e191"
    "BepInEx\plugins\Azumatt-AzuExtendedPlayerInventory\AzuExtendedPlayerInventory.dll" = "8d9f4ac43884e64fb0fafa08b04f609c"
    "BepInEx\plugins\PortalBroadcastFix\PortalBroadcastFix.dll" = "2c4a8ec2e1f69781fd97761423e72b64"
    "BepInEx\plugins\ItemSkin\ItemSkin.dll" = "c6a3b2aa698b120726febe59fb055bee"
    "BepInEx\plugins\Azumatt-Minimal_UI\MinimalUI.dll" = "d81470836d83a1e802fd09446b5fcea0"
    "BepInEx\plugins\InventorySortOnly\InventorySortOnly.dll" = "957c0c96dafe4d7a738a59a9837144ce"
}

# ---------- 在线安装：本地没有包时，从 GitHub Release 取最新版 ----------
$ReleasesRepo   = "kanziguai/valheim-makabaka-pack"   # ← GitHub 仓库（owner/repo）
$ScriptBuild    = "2026-09-20"                        # ← 本脚本的日期（发新版时由 tools/发布新版.py 自动更新）
$ReleaseLatest  = "https://github.com/$ReleasesRepo/releases/latest/download"
$SumAssetName   = "SHA256SUMS.txt"                   # Release 里固定名字的校验清单附件
$VrmDefaultModel = ""                                   # 已取消默认模型（清单里 default 为空 → 不重排；菜单顺序=清单顺序=参考图编号）

# 必须人人一致的配置项（安装/升级后强制校正；升级模式会保留玩家自己的 config，所以必须在这里兜住）
$script:EnforcedConfig = @(
    @{ File = "jg224.chestflow.cfg"; Section = "Multiplayer"; Key = "AllowConcurrentChestUse"; Value = "false" }
)
# 下载线路：全部是实测能用的 GitHub 加速（国内可直连）；顺序 = 测速不可用时的兜底顺序
#   ""       = 直连 github.com（放最后）
#   发布后跑 tools/预热镜像.py 会把这几个镜像的边缘缓存“烫热”，别人下起来会明显更快
$MirrorPrefixes = @(
    "https://gh-proxy.com/",
    "https://gh.jasonzeng.dev/",
    "https://ghfast.top/",
    "https://gh.xxooo.cf/",
    "https://gh.llkk.cc/",
    "https://ghproxy.net/",
    "https://gh.xmly.dev/",
    ""
)
$MirrorProbeBytes   = 262144   # 测速每条线路取样 256 KB（只读这么多就断开，不会白下整包）
$MirrorProbeSeconds = 6        # 测速单条线路超时
$MirrorGoodEnough   = 1.5      # MB/s：某条线路已经这么快就用它，不再测后面的（省时间）
$script:ProbeCache  = @{}      # 同一个 URL 只测一次
# 联网拿不到校验清单时的兜底（每次发新版由仓库同步更新，随脚本一起走）
$FallbackAsset   = "MAKABAKA_profile_v1.14_20260920.zip"
$FallbackMd5     = "598b5a2a813f55f7c7ba9fbf574c345d"
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
$script:ProfSrc   = @{}       # 候选 → 来源（命令行 / 记住的 / r2modman 记录过 / 默认位置 / 扫盘找到）
$script:DefaultShell = $null  # 默认位置那个"一个档都没有"的空壳（数据文件夹被挪走后留下的）
function Add-ProfCand([string]$p, [string]$Src = "") {
    if ([string]::IsNullOrWhiteSpace($p)) { return }
    foreach ($x in $script:ProfCands) {
        if ($x -ieq $p) { if ($Src -and -not $script:ProfSrc.ContainsKey($x)) { $script:ProfSrc[$x] = $Src }; return }
    }
    $script:ProfCands.Add($p)
    if ($Src) { $script:ProfSrc[$p] = $Src }
}
function Get-ProfSrc([string]$p) {
    if ($p -and $script:ProfSrc.ContainsKey($p)) { return $script:ProfSrc[$p] }
    return ""
}
# 这个数据文件夹里是否"真的还有档"（至少一个档里有 mods.yml）—— 空壳不算
function Test-ProfRootHasProfiles([string]$root) {
    if ([string]::IsNullOrWhiteSpace($root) -or -not (Test-Path $root)) { return $false }
    try {
        foreach ($d in (Get-ChildItem -Path $root -Directory -ErrorAction SilentlyContinue)) {
            if (Test-Path (Join-Path $d.FullName "mods.yml")) { return $true }
        }
    } catch {}
    return $false
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
    $downloadPick = $cands[0].Path
    if ($ansW -match '^\s*$') { $downloadPick = $cands[0].Path }
    elseif ($ansW -match '^\s*0\s*$') {
        $typedW = ("" + (Read-Host "  把路径粘进来（只写盘符如 D: 也行）")).Trim().Trim('"')
        if ($typedW -match '^[A-Za-z]:$') { $typedW = Join-Path ($typedW + "\") "MAKABAKA_install" }
        if (-not [string]::IsNullOrWhiteSpace($typedW)) { $downloadPick = $typedW }
    }
    elseif ($ansW -match '^\d+$' -and [int]$ansW -ge 1 -and [int]$ansW -le $cands.Count) { $downloadPick = $cands[[int]$ansW - 1].Path }
    else { Say "  输入看不懂，按默认来。" "Yellow" }
    $freeW = Get-FreeGB $downloadPick
    if ($freeW -ne $null -and $freeW -lt 1.2) { Say "  [注意] 这个位置所在盘只剩 $freeW GB，可能不够（约需 1 GB）；不够会在下载/解压时报错。" "Yellow" }
    try { [System.IO.File]::WriteAllText($script:DlRememberFile, $downloadPick, (New-Object System.Text.UTF8Encoding($false))) } catch {}
    Say "  ✓ 记住这个位置了（下次不再问；想改就删掉脚本旁的 download-path.txt，或用 -DownloadDir 指定）" "DarkGray"
    return $downloadPick
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
    # raw 文件再加一条 jsDelivr（CDN，不在上面那批代理里，代理全挂时仍可能通）
    if ($url -match '^https://raw\.githubusercontent\.com/([^/]+)/([^/]+)/([^/]+)/(.+)$') {
        $out += ("https://cdn.jsdelivr.net/gh/{0}/{1}@{2}/{3}" -f $Matches[1], $Matches[2], $Matches[3], $Matches[4])
    }
    return @($out | Select-Object -Unique)
}

# 给某条线路测速：只读 512 KB 就断开（服务器不支持 Range 也不会白下整包，因为我们自己停读）
function Test-LineSpeed([string]$u, [int]$bytes = 0, [int]$timeoutSec = 0) {
    if ($bytes -le 0) { $bytes = $MirrorProbeBytes }
    if ($timeoutSec -le 0) { $timeoutSec = $MirrorProbeSeconds }
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    try {
        $req = [System.Net.HttpWebRequest]::Create($u)
        $req.UserAgent = "makabaka-install"
        $req.Timeout = $timeoutSec * 1000
        $req.ReadWriteTimeout = $timeoutSec * 1000
        try { $req.AddRange(0, $bytes - 1) } catch {}
        $resp = $req.GetResponse()
        $rs = $resp.GetResponseStream()
        $buf = New-Object byte[] 65536
        $n = 0L
        try {
            while ($n -lt $bytes) {
                $k = $rs.Read($buf, 0, $buf.Length)
                if ($k -le 0) { break }
                $n += $k
            }
        } finally { try { $rs.Close() } catch {}; try { $resp.Close() } catch {} }
        $sec = $sw.Elapsed.TotalSeconds
        if (($n -le 0) -or ($sec -le 0.05)) { return 0.0 }
        return [math]::Round(($n / 1MB) / $sec, 2)
    } catch { return 0.0 }
}

# 先测速再排序：最快的排第一条。测速全部失败时回落到脚本内置顺序（不影响可用性）
function Get-RankedUrls([string]$url) {
    $urls = @(Get-MirroredUrls $url)
    # 只有大文件（Release 附件 / zip 包）才值得先测速；小脚本（几十 KB）直接按顺序试更快
    $big = ($url -match '\.zip($|\?)') -or ($url -match '/releases/')
    if ($NoMirrorProbe -or (-not $big) -or ($urls.Count -le 1)) { return $urls }
    if ($script:ProbeCache.ContainsKey($url)) { return $script:ProbeCache[$url] }
    Say ("        给 {0} 条线路测速（每条取样 256 KB，选最快的先下）…" -f $urls.Count) "DarkGray"
    $scored = @()
    $idx = 0
    $best = 0.0
    foreach ($u in $urls) {
        if (($idx -gt 0) -and ($best -ge $MirrorGoodEnough)) { break }   # 已经够快，剩下的不测了
        $h = ""
        try { $h = ([Uri]$u).Host } catch {}
        if ([string]::IsNullOrWhiteSpace($h)) { $h = "本地文件" }
        $spd = Test-LineSpeed $u
        $scored += [pscustomobject]@{ Url = $u; Host = $h; Speed = $spd; Idx = $idx }
        $idx++
        if ($spd -gt $best) { $best = $spd }
        if ($spd -gt 0) { Say ("        {0,-24} {1} MB/s" -f $h, $spd) "DarkGray" }
        else { Say ("        {0,-24} 超时/连不上" -f $h) "DarkGray" }
    }
    # 速度降序；速度相同的保持原顺序（Idx 升序）——两键排序在 PS 5.1 里也是确定的
    $sorted = @($scored | Sort-Object -Property @{Expression = { $_.Speed }; Descending = $true },
                                              @{Expression = { $_.Idx };   Descending = $false })
    # 提前停止测速时，没测过的线路按原顺序接在后面（仍然保留"全线路重试"的能力）
    $extra = @($urls | Where-Object { $scored.Url -notcontains $_ })
    $ranked = @($sorted | ForEach-Object { $_.Url }) + $extra
    $fast = $sorted[0]
    if ($fast.Speed -gt 0) { Say ("        首选线路：{0}（{1} MB/s）" -f $fast.Host, $fast.Speed) "Green" }
    else { Say "        所有线路测速都没通过，按脚本内置顺序继续试（会逐条重试，不会卡住）。" "Yellow" }
    $script:ProbeCache[$url] = $ranked
    return $ranked
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
    $urls = @(Get-RankedUrls $url)
    $i = 0
    # 目标位置若有残留（上一次没下完的、或别处留下的旧副本），先清掉：
    # 拿一个"已经完整/来路不明"的文件做断点续传会拿到坏文件，甚至从 EOF 开始要数据被服务器回 416
    if (Test-Path $outFile) { Remove-Item $outFile -Force -ErrorAction SilentlyContinue }
    $have = 0L          # 已经落盘的字节数：换线路时从这里接着下（断点续传），不从头再来
    foreach ($u in $urls) {
        $i++
        $line = "第 $i/$($urls.Count) 条线路"
        try {
            $h = ([Uri]$u).Host
            if ([string]::IsNullOrWhiteSpace($h)) { $line = $line + "：本地文件" } else { $line = $line + "：" + $h }
        } catch {}
        # 每条线路先按系统代理下；失败再绕开代理直连（用 Clash / 加速器时经常需要这一步）
        foreach ($useDirect in @($false, $true)) {
            if (Test-Path $outFile) { try { $have = (Get-Item $outFile).Length } catch { $have = 0 } } else { $have = 0 }
            $resume = ($have -gt 0)
            $tag = $line
            if ($useDirect) { $tag = $tag + "（不走代理）" }
            if ($resume) { $tag = $tag + ("（接着下：已有 " + [math]::Round($have / 1MB, 1) + " MB）") }
            Say "        下载中（$label，$tag）…" "DarkGray"
            try {
            $req = [System.Net.HttpWebRequest]::Create($u)
            $req.UserAgent = "makabaka-install"
            $req.Timeout = 30000
            # 25 秒收不到任何数据就判这条线路死了 → 抛异常 → 换下一条（从断点续）
            $req.ReadWriteTimeout = 25000
            if ($useDirect) { $req.Proxy = $null }
            if ($resume) { try { $req.AddRange([int64]$have) } catch { $resume = $false } }
            $resp = $req.GetResponse()
            $code = 0
            try { $code = [int]($resp.StatusCode) } catch {}
            $total = $resp.ContentLength
            $mode = [System.IO.FileMode]::Create      # 默认：从头写
            if ($resume -and ($code -eq 206)) {
                $mode = [System.IO.FileMode]::Append  # 服务器支持续传 → 接着写
                $total = $have + $resp.ContentLength
            } elseif ($resume) {
                # 服务器不理 Range（返回 200 整包）→ 只能从头下
                Say "        这条线路不支持断点续传，从头下这个包。" "DarkGray"
                $resume = $false
                $have = 0
                $total = $resp.ContentLength
            }
            $rs = $resp.GetResponseStream()
            $fs = [System.IO.File]::Open($outFile, $mode, [System.IO.FileAccess]::Write, [System.IO.FileShare]::None)
            $sw = [System.Diagnostics.Stopwatch]::StartNew()
            $buf = New-Object byte[] 1048576
            $read = 0L
            $lastAt = 0.0
            $job = "download"
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
                        $done = $have + $read
                        $mb   = [math]::Round($done / 1MB, 1)
                        $spd  = [math]::Round(($read / 1MB) / $secNow, 1)
                        $pct  = 0
                        if ($total -gt 0) { $pct = [int](100 * $done / $total) }
                        $totTxt = "?"
                        if ($total -gt 0) { $totTxt = "$([math]::Round($total / 1MB, 1)) MB" }
                        $etaTxt = ""
                        if (($spd -gt 0.05) -and ($total -gt $done)) {
                            $left = ($total - $done) / 1MB / $spd
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
            $done = $have + $read
            $szMB = [math]::Round($done / 1MB, 1)
            $avgAll = 0
            if ($secAll -gt 0) { $avgAll = [math]::Round(($read / 1MB) / $secAll, 1) }
            Write-Host ""
            if (($total -gt 0) -and ($done -ne $total)) {
                throw "下载不完整（收到 $done / 应有 $total 字节）"
            }
            Say ("        下载完成：$szMB MB，耗时 " + [math]::Round($secAll, 1) + " 秒（这条线路平均 $avgAll MB/s）") "Green"
            return $true
            } catch {
                $job = $null
                $how = "代理"
                if ($useDirect) { $how = "直连" }
                Say "        这一条失败（$how）：$($_.Exception.Message)" "DarkGray"
                if ($_.Exception.Message -match '416') {
                    # 416 = 要的区间超出文件尾（说明这个残包对不上，或镜像缓存有问题）→ 删掉，下一条从头下
                    Remove-Item $outFile -Force -ErrorAction SilentlyContinue
                    $have = 0
                } elseif (Test-Path $outFile) {
                    # 其余情况保留已下到的部分：下一条线路从断点接着下（网络抖动/限速是常态，重来一次就白下一段）
                    try { $have = (Get-Item $outFile).Length } catch { $have = 0 }
                }
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
function Resolve-ExplicitProfilesRoot([string]$inputPath) {
    if ([string]::IsNullOrWhiteSpace($inputPath)) { return $null }
    $p = $inputPath.Trim().Trim('"').TrimEnd('\')
    if ((Split-Path $p -Leaf) -ieq $ProfileName -and (Test-Path (Join-Path $p 'mods.yml'))) { return $p }
    if ((Split-Path $p -Leaf) -ieq 'profiles') { return $p }
    $direct = Join-Path $p "$GameName\profiles"
    if (Test-Path $direct) { return $direct }
    # Existing Valheim data root may be supplied as ...\Valheim.
    if ((Split-Path $p -Leaf) -ieq $GameName) {
        return (Join-Path $p 'profiles')
    }
    # A new drive/root selection is interpreted as r2modman data root,
    # never as an arbitrary profiles parent.
    if (Test-Path $p) { return (Join-Path $p "$GameName\profiles") }
    return (Join-Path $p "$GameName\profiles")
}
function Get-BackupRoot([string]$profilesRoot) {
    if ([string]::IsNullOrWhiteSpace($profilesRoot)) { return $null }
    $parent = Split-Path $profilesRoot -Parent
    if (-not $parent) { return $null }
    $root = Join-Path $parent "MAKABAKA_backups"
    try { New-Item -ItemType Directory -Path $root -Force | Out-Null } catch { return $null }
    return $root
}
function Get-BackupDirs([string]$profilesRoot) {
    $root = Get-BackupRoot $profilesRoot
    $all = New-Object System.Collections.Generic.List[object]
    if ($root -and (Test-Path $root)) {
        foreach ($d in (Get-ChildItem -Path $root -Directory -Filter "$ProfileName.backup-*" -ErrorAction SilentlyContinue)) { $all.Add($d) }
    }
    # Legacy installers used a sibling directory named MAKABAKA.backup-*.
    $parent = Split-Path $profilesRoot -Parent
    if ($parent -and (Test-Path $parent)) {
        foreach ($d in (Get-ChildItem -Path $parent -Directory -Filter "$ProfileName.backup-*" -ErrorAction SilentlyContinue)) { $all.Add($d) }
        foreach ($d in (Get-ChildItem -Path $parent -Directory -Filter "${ProfileName}_backup-*" -ErrorAction SilentlyContinue)) { $all.Add($d) }
    }
    return @($all | Sort-Object FullName -Unique -Descending LastWriteTime)
}
function Copy-ProfileBackup([string]$profileDir, [string]$profilesRoot, [string]$reason) {
    if (-not (Test-Path $profileDir)) { return $null }
    $root = Get-BackupRoot $profilesRoot
    if (-not $root) { Fail "无法创建备份目录。升级/重装已停止，原档未修改。" }
    $dest = Join-Path $root ("$ProfileName.backup-" + (Get-Date -Format "yyyyMMdd-HHmmss") + "-" + $reason)
    try {
        New-Item -ItemType Directory -Path $dest -Force | Out-Null
        $rb = Join-Path $env:SystemRoot "System32\robocopy.exe"
        if (Test-Path $rb) {
            & $rb $profileDir $dest /E /R:2 /W:1 /NFL /NDL /NJH /NJS /NP | Out-Null
            if ($LASTEXITCODE -ge 8) { throw "robocopy exit $LASTEXITCODE" }
        } else { Copy-Item (Join-Path $profileDir '*') $dest -Recurse -Force }
        Say "        升级前完整备份：$dest" "Green"
        return $dest
    } catch {
        if (Test-Path $dest) { Remove-Item $dest -Recurse -Force -ErrorAction SilentlyContinue }
        Fail "升级前备份失败：$($_.Exception.Message)。原档未修改。"
    }
}
function Restore-ProfileBackup([string]$profilesRoot, [string]$backupPath) {
    $dirs = @(Get-BackupDirs $profilesRoot)
    if ($backupPath) { $chosen = Get-Item -LiteralPath $backupPath -ErrorAction SilentlyContinue }
    elseif ($NonInteractive) { $chosen = $dirs | Select-Object -First 1 }
    else {
        if ($dirs.Count -eq 0) { Fail "没有找到可回滚备份：$(Get-BackupRoot $profilesRoot)" }
        Say "可回滚备份：" "Cyan"
        for ($i=0; $i -lt $dirs.Count; $i++) { Say ("  {0}) {1}  {2}" -f ($i+1), $dirs[$i].Name, $dirs[$i].LastWriteTime) }
        $ans = Read-Host "选择编号（回车=最新，0=取消）"
        if ($ans -match '^\s*0\s*$') { Exit 0 }
        $idx = if ([string]::IsNullOrWhiteSpace($ans)) { 0 } else { [int]$ans - 1 }
        if ($idx -lt 0 -or $idx -ge $dirs.Count) { Fail "备份编号无效。" }
        $chosen = $dirs[$idx]
    }
    if (-not $chosen -or -not (Test-Path $chosen.FullName)) { Fail "指定的备份不存在：$backupPath" }
    $dst = Join-Path $profilesRoot $ProfileName
    if (Test-Path $dst) {
        $safety = Copy-ProfileBackup $dst $profilesRoot "before-rollback"
        Remove-Item $dst -Recurse -Force
    }
    New-Item -ItemType Directory -Path $dst -Force | Out-Null
    Copy-Item (Join-Path $chosen.FullName '*') $dst -Recurse -Force
    Say "已从备份恢复：$($chosen.FullName)" "Green"
}
function Show-Backups([string]$profilesRoot) {
    $dirs = @(Get-BackupDirs $profilesRoot)
    if ($dirs.Count -eq 0) { Say "没有找到备份。" "Yellow"; return }
    foreach ($d in $dirs) { Say ("{0}  {1}" -f $d.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss'), $d.FullName) }
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

# 私有模型附件：分段并发下载的连接数（默认 6；环境变量 MAKABAKA_MODEL_THREADS 可覆盖，1 = 关闭分段）
if ($script:ModelLibLoaded -and (Test-Path Env:MAKABAKA_MODEL_THREADS)) {
    try {
        $nThr = [int]$env:MAKABAKA_MODEL_THREADS
        if ($nThr -ge 1 -and $nThr -le 16) { $script:ModelDownloadThreads = $nThr }
    } catch {}
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

# 本机模型库目录（新版加载器 = <游戏>\EnhancedValheimVRM；旧方案 = <游戏>\ValheimVRM）
function Get-LocalVrmLibraryDir {
    $g = if (-not [string]::IsNullOrWhiteSpace($GameDir)) { $GameDir.Trim().Trim('"').TrimEnd('\') } else { Find-ValheimGameDir }
    if (-not $g) { return $null }
    $ev = Join-Path $g "EnhancedValheimVRM"
    if (Test-Path $ev) { return $ev }        # 新版加载器的模型库优先
    $old = Join-Path $g "ValheimVRM"
    if (Test-Path $old) { return $old }      # 旧方案
    return $null
}
# 打印"本机模型库已覆盖多少个清单里的模型"（按 .vrm 大小匹配；安装时会按同样规则跳过下载）
function Show-LibraryStatus($cands) {
    $d = Get-LocalVrmLibraryDir
    if (-not $d) { return }
    $files = @(Get-ChildItem -Path $d -Filter "*.vrm" -File -ErrorAction SilentlyContinue)
    $n = 0
    foreach ($c in $cands) {
        if (-not $c.SizeMB) { continue }
        $want = [int64]($c.SizeMB * 1MB)
        if (@($files | Where-Object { [math]::Abs($_.Length - $want) -le 102400 }).Count -gt 0) { $n++ }
    }
    Say "  本机模型库：$d" "Green"
    Say "   已有 $($files.Count) 个 .vrm；清单 $($cands.Count) 个里已覆盖 $n 个（覆盖了就不用再下：脚本按大小自动跳过）" "Green"
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
    Show-LibraryStatus $cands
    Say '  （参考图：打开本包目录里的 Models\预览\ 文件夹，文件名编号与上面序号一致）' "DarkGray"
    Say ""
    Say '  装/换模型：双击 换模型.bat，或在主菜单选择 8。' "DarkGray"
    if ($script:MenuSelected) { Read-Host "按回车返回主菜单" | Out-Null }
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
    if (-not (Test-Path (Join-Path $PSScriptRoot "Models\models.json")) -and -not (Test-Path (Join-Path $PSScriptRoot "Models")) -and -not (Test-Path (Join-Path $PSScriptRoot "EnhancedValheimVRM_手动安装"))) {
        $up = Split-Path $PSScriptRoot -Parent
        if ($up -and ((Test-Path (Join-Path $up "Models")) -or (Test-Path (Join-Path $up "EnhancedValheimVRM_手动安装")))) { $packRoot = $up }
    }
    $src = $packRoot   # 占位：只换模型不需要档源
    if ($ModelPath -and -not $ModelSource -and -not (Test-Path (Join-Path $packRoot "Models"))) {
        # 只有本地 .vrm 也能换模型（清单取在线）
        Say "  [只换模型] 用 -ModelPath 指定的本地文件" "DarkGray"
    }
    if (-not (Test-Path (Join-Path $packRoot "EnhancedValheimVRM_手动安装")) -and -not (Test-Path (Join-Path $packRoot "Models")) -and -not $ModelPath) {
        Fail "没找到 VRM 的模型源（EnhancedValheimVRM_手动安装\ 或 Models\）。把 换模型.bat 和它们放在同一个目录，或用 -ProfilesRoot/-PackRoot 相关参数指定。"
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
    # 找"r2modman 自己记录过的数据文件夹路径"。
    # r2modman 是 Electron 应用：路径可能写在日志/配置里（ANSI/UTF-8），也可能写在 LevelDB 里（UTF-16），
    # 所以同一份文件两种编码各读一遍；每个文件最多留 40 条、总量最多 800 条，避免拖慢安装。
    $roots = @()
    if ($env:APPDATA)      { $roots += (Join-Path $env:APPDATA "r2modman"); $roots += (Join-Path $env:APPDATA "r2modmanPlus-local\config") }
    if ($env:LOCALAPPDATA) { $roots += (Join-Path $env:LOCALAPPDATA "r2modman"); $roots += (Join-Path $env:LOCALAPPDATA "r2modmanPlus-local\config") }
    $found = New-Object System.Collections.Generic.List[string]
    $seen  = New-Object System.Collections.Generic.HashSet[string]
    foreach ($r in $roots) {
        try { if (-not (Test-Path $r)) { continue } } catch { continue }
        $files = $null
        try {
            $files = Get-ChildItem -Path $r -Recurse -File -ErrorAction SilentlyContinue |
                     Where-Object { $_.Length -lt (64MB) -and (($_.Extension -eq "") -or ($_.Extension -match '^\.(log|ldb|sst|blob|json|yml|yaml|txt|db|config|dat|ini|cfg|json5)$')) }
        } catch { continue }
        foreach ($f in $files) {
            try {
                $bytes = [System.IO.File]::ReadAllBytes($f.FullName)
                $perFile = 0
                foreach ($encName in @("utf8", "latin", "u16")) {
                    if (($perFile -ge 40) -or ($found.Count -ge 800)) { break }
                    try {
                        if ($encName -eq "utf8")       { $txt = [System.Text.Encoding]::UTF8.GetString($bytes) }
                        elseif ($encName -eq "latin")  { $txt = [System.Text.Encoding]::GetEncoding(28591).GetString($bytes) }
                        else                           { $txt = [System.Text.Encoding]::Unicode.GetString($bytes) }
                    } catch { continue }
                    foreach ($m in [regex]::Matches($txt, '[A-Za-z]:\\[^\x00-\x1F<>|:*?"\r\n]{2,140}')) {
                        if ($m.Value -match 'r2modman') {
                            $val = $m.Value.TrimEnd('\')
                            if ($seen.Add($val)) { $found.Add($val); $perFile++ }
                            if (($perFile -ge 40) -or ($found.Count -ge 800)) { break }
                        }
                    }
                }
            } catch { }
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
        if ($c -and (Test-ProfRootHasProfiles $c)) { Add-ProfCand $c "扫盘找到" }
    }
    return ($script:ProfCands.Count - $before)
}


if ($VRMOnly) {
    # 只换模型：只做"轻量探测"（不扫盘、不写 install-path.txt），探测不到也不阻断
    if ([string]::IsNullOrWhiteSpace($dst) -and -not [string]::IsNullOrWhiteSpace($ProfilesRoot)) { $dst = Join-Path $ProfilesRoot $ProfileName }   # 兜底：后面有些模块会引用它（VRMOnly 里通常拿不到档根，留着空即可）
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
    $resolved = Resolve-ExplicitProfilesRoot $given
    # If the user selected an existing profile itself, do not append Valheim\profiles.
    if ((Split-Path $given -Leaf) -ieq $ProfileName -and (Test-Path (Join-Path $given 'mods.yml'))) {
        $resolved = $given
    }
    $script:PathSource = "命令行指定"
    Say "        目标 profiles：$resolved" "DarkGray"
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
    #    整段包 try/catch：某个文件/正则出问题也不能把整个安装打断（曾经一个非法转义就在这里把脚本崩掉）
    try {
        foreach ($hit in (Get-PathsFromAppFiles)) {
            try {
                $variants = @($hit)
                if ($hit -match '\\\\') { $variants += ($hit -replace '\\\\', '\') }
                foreach ($v in $variants) {
                    if ($v -match '(?i)^(.*?r2modmanPlus-local)') { $c1 = Try-AnyProfilesRoot $Matches[1]; if ($c1) { Add-ProfCand $c1 "r2modman 记录过的路径" } }
                    if ($v -match '(?i)^(.*?)\\Valheim(\\profiles)?') { $c2 = Try-AnyProfilesRoot $Matches[1]; if ($c2) { Add-ProfCand $c2 "r2modman 记录过的路径" } }
                }
            } catch { }
        }
    } catch { Say "        （读 r2modman 自己的记录时出错，已跳过这一步）" "DarkGray" }
    # ④ 默认位置（APPDATA / LOCALAPPDATA / USERPROFILE）
    #    只有"里面真的还有档"才算候选；只有空壳（数据文件夹被挪到别的盘后留下的）就只记下来当提示，
    #    免得 r2modman 明明在别的盘、脚本却因为 C 盘这个残留静默装到 C 盘去。
    foreach ($d in @((Join-Path $env:APPDATA "r2modmanPlus-local"), (Join-Path $env:LOCALAPPDATA "r2modmanPlus-local"), (Join-Path $env:USERPROFILE "AppData\Roaming\r2modmanPlus-local"))) {
        $c = Try-ProfilesRoot $d
        if (-not $c) { $c = Try-AnyProfilesRoot $d }
        if ($c) {
            if (Test-ProfRootHasProfiles $c) { Add-ProfCand $c "默认位置" }
            elseif (-not $script:DefaultShell) { $script:DefaultShell = $c }
        }
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

    if ($script:ProfCands.Count -eq 0 -and $script:DefaultShell) {
        Say "  注意：默认位置有个 r2modman 数据文件夹，但里面【一个档都没有】：" "Yellow"
        Say "        $($script:DefaultShell)" "DarkGray"
        Say "        这多半是数据文件夹被挪到别的盘（r2modman→设置→Locations）后留下的空壳，所以没把它当目标。" "Yellow"
    }
    if (($script:ProfCands.Count -eq 1) -and $NonInteractive -and -not $Pick) {
        $resolved = $script:ProfCands[0]
        $src1 = Get-ProfSrc $resolved
        if ($src1) { $script:PathSource = "自动找到（$src1，-NonInteractive）" } else { $script:PathSource = "自动找到（-NonInteractive）" }
        Say "        非交互模式使用唯一候选：$resolved" "DarkGray"
    }
    elseif (($script:ProfCands.Count -ge 1 -or $Pick) -and $NonInteractive) {
        $resolved = $script:ProfCands[0]
        $script:PathSource = "自动选了第 1 个（-NonInteractive）"
        Say "  [非交互] 检测到 $($script:ProfCands.Count) 个 r2modman 数据文件夹，用了第 1 个：" "Yellow"
        for ($i = 0; $i -lt $script:ProfCands.Count; $i++) { Say ("          {0}) {1}   （{2}）" -f ($i + 1), $script:ProfCands[$i], (Get-ProfCandNote $script:ProfCands[$i])) "DarkGray" }
        Say "        想指定别的：-ProfilesRoot <路径>" "DarkGray"
    }
    elseif ($script:ProfCands.Count -gt 1 -or $Pick) {
        # ---- 交互：把所有找到的数据文件夹列出来让你选（装在哪个盘、哪一份，由你定）----
        if ($Pick -and ($script:ProfCands.Count -eq 0) -and -not $scanned) {
            Say "  [ -Pick ] 先扫描各硬盘找找数据文件夹（最多十几秒）…" "Yellow"
            $null = Scan-ProfCands
            $scanned = $true
        }
        function Show-ProfCands {
            Say "  现在有 $($script:ProfCands.Count) 个候选（数据文件夹）：" "Cyan"
            if ($script:ProfCands.Count -eq 0) { Say "    （还没有候选：输 9 扫盘，或 0 自己输入路径）" "DarkGray" }
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
        $emptyTries = 0
        while (-not $resolved) {
            $ansP = "" + (Read-Host "  装到哪个？(直接回车 = 1)")
            if ($ansP -match '^\s*$') {
                if ($script:ProfCands.Count -eq 0) {
                    $emptyTries++
                    Say "        现在还没有候选：输 9 = 扫描各硬盘找，输 0 = 自己粘贴数据文件夹路径。" "Yellow"
                    if ($emptyTries -ge 3) { Say "        连续 3 次没选 → 放弃自动探测，改走手动指定。" "Yellow"; break }
                    continue
                }
                $resolved = $script:ProfCands[0]; $script:PathSource = "你选的（第 1 项）"
            }
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
                $typedP = ("" + (Read-Host "  把数据文件夹路径粘进来（可输入完整 MAKABAKA 档目录；回车=放弃）")).Trim().Trim('"').TrimEnd('\')
                if ([string]::IsNullOrWhiteSpace($typedP)) { continue }
                $rT = Resolve-ExplicitProfilesRoot $typedP
                if ($rT) { $resolved = $rT; $script:PathSource = "你手动指定" }
                else { Say "        这个路径用不了，再试一次。" "Yellow" }
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
    if ($script:DefaultShell) {
        Say "  注意：默认位置有个 r2modman 数据文件夹，但里面【一个档都没有】：" "Yellow"
        Say "        $($script:DefaultShell)" "DarkGray"
        Say "        这多半是数据文件夹被挪到别的盘后留下的空壳，所以这次没把它当目标。" "Yellow"
        Say ""
    }
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
    $shellHint = ""
    if ($script:DefaultShell) { $shellHint = " 检测到默认位置有个「一个档都没有的空壳」：$($script:DefaultShell) —— 说明数据文件夹很可能被挪到别的盘了。" }
    Fail "找不到 r2modman 的 profiles 目录（可能在别的盘）。$shellHint 请用 一键安装.bat -ProfilesRoot <数据文件夹> 指定，或先运行一次 r2modman 并选好 Valheim。"
}

$ProfilesRoot = $resolved
# 回滚/列备份必须在任何安装写入前处理。
if ($ListBackups) { Show-Backups $ProfilesRoot; SaveLog; Exit 0 }
if ($Rollback) { Restore-ProfileBackup $ProfilesRoot $BackupPath; SaveLog; Exit 0 }
# 配置里读出来的路径可能带双反斜杠（JSON 转义），若正常写法也存在就用正常写法
if ($ProfilesRoot -match '\\\\') {
    $norm = $ProfilesRoot -replace '\\\\', '\'
    if (Test-Path $norm) { $ProfilesRoot = $norm }
}
Say "  [2/7] 目标目录（来源：$($script:PathSource)）" "Green"
Say "        $ProfilesRoot" "Green"
if (-not $NoRemember -and -not $DryRun -and -not $DetectOnly) {
    try { [System.IO.File]::WriteAllText($rememberFile, $ProfilesRoot, (New-Object System.Text.UTF8Encoding($false))) } catch {}
}

# ---------- 只读自检（-Verify）：核对"装好没有"，不写任何文件 ----------
if ($Verify) {
    Say ""
    Say "  ============================================================" "Cyan"
    Say "   安装结果自检（-Verify：只读，不写任何文件）" "Cyan"
    Say "  ============================================================" "Cyan"
    $vProf = Join-Path $ProfilesRoot $ProfileName
    $vGame = if (-not [string]::IsNullOrWhiteSpace($GameDir)) { $GameDir.Trim().Trim('"').TrimEnd('\') } else { Find-ValheimGameDir }
    Say "   档     : $vProf"
    Say "   游戏   : $(if ($vGame) { $vGame } else { '(未找到)' })"
    Say ""
    $script:VOk = 0; $script:VWarn = 0; $script:VFail = 0
    function VOk  { param($m) $script:VOk++;   Say "   ✅ $m" "Green" }
    function VWarn{ param($m) $script:VWarn++; Say "   ⚠️  $m" "Yellow" }
    function VBad { param($m) $script:VFail++; Say "   ❌ $m" "Red" }
    function HashOf($p) { try { (Get-FileHash -LiteralPath $p -Algorithm MD5).Hash } catch { "" } }

    $pluginsDir = Join-Path $vProf "BepInEx\plugins"
    $evDir = $null
    foreach ($cand in @((Join-Path $pluginsDir "Rawrtastic-EnhancedValheimVRM"), (Join-Path $pluginsDir "EnhancedValheimVRM"))) {
        if (Test-Path $cand) { $evDir = $cand; break }
    }
    $swDll   = Join-Path (Join-Path $pluginsDir "VRMModelSwitcher") "VRMModelSwitcher.dll"
    $legacy  = Join-Path $pluginsDir "ValheimVRM_1.2.2"
    $lib     = if ($vGame) { Join-Path $vGame "EnhancedValheimVRM" } else { $null }
    $libOld  = if ($vGame) { Join-Path $vGame "ValheimVRM" } else { $null }
    $managed = if ($vGame) { Join-Path $vGame "valheim_Data\Managed" } else { $null }

    # —— 新布局（EnhancedValheimVRM + F9 面板）——
    $asm = @()
    if ($evDir) {
        VOk "加载器插件目录存在：$evDir"
        $evDll = Join-Path $evDir "EnhancedValheimVRM.dll"
        if (Test-Path $evDll) { VOk ("加载器插件：EnhancedValheimVRM.dll  " + (HashOf $evDll).Substring(0,12)) } else { VBad "加载器插件 DLL 缺失：$evDll" }
        $sh = @(Get-ChildItem -Path $evDir -Filter "*.shaders" -File -ErrorAction SilentlyContinue)
        if ($sh.Count -ge 2) { VOk "shader 包 $($sh.Count) 个（UniVrm / OldUniVrm）" } elseif ($sh.Count -eq 1) { VWarn "shader 包只有 1 个（建议 2 个）" } else { VWarn "shader 包缺失" }
        $asm = @(Get-ChildItem -Path $evDir -Filter "*.dll" -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -ne "EnhancedValheimVRM.dll" })
        if ($asm.Count -ge 18) { VOk "插件目录内 UniVRM 程序集 $($asm.Count) 个（≥18）" }
        elseif ($asm.Count -gt 0) { VBad "插件目录内程序集只有 $($asm.Count) 个（应为 18）" }
        else { VWarn "插件目录里没有程序集（加载器没装全）" }
        if ($managed -and $asm.Count -gt 0) {
            $same = 0; $diff = 0; $miss = 0
            foreach ($f in $asm) {
                $t = Join-Path $managed $f.Name
                if (-not (Test-Path $t)) { $miss++ }
                elseif ((HashOf $f.FullName) -eq (HashOf $t)) { $same++ }
                else { $diff++ }
            }
            if ($miss -eq 0 -and $diff -eq 0) { VOk "游戏 valheim_Data\Managed：$same 个程序集与插件目录逐字节一致" }
            else { VBad "程序集不一致：一致 $same / 不同 $diff / 缺失 $miss（重跑本脚本或同步脚本）" }
        }
    } else {
        VWarn "未发现新加载器插件目录（本机还是旧 ValheimVRM 1.2.2 方案）"
    }
    if (Test-Path $swDll) {
        $swHash = HashOf $swDll
        VOk ("F9 面板存在：VRMModelSwitcher.dll  " + $swHash.Substring(0,12))
    } elseif ($evDir) { VWarn "F9 面板缺失：$swDll（进游戏按 F9 不会有反应）" }

    # —— 旧 loader 状态 ——
    $lgDll = Join-Path $legacy "ValheimVRM.dll"
    $lgOld = Join-Path $legacy "ValheimVRM.dll.old"
    if (Test-Path $lgDll) {
        if ($evDir) { VBad "旧 loader 仍启用（plugins\ValheimVRM_1.2.2\ValheimVRM.dll）：两个 loader 会同时 patch Player.Awake，必须只留一个" }
        else { VWarn "旧 loader 启用中（当前是 v1.12 旧方案，属正常；升级到新版时会自动改名 .dll.old）" }
    } elseif (Test-Path $lgOld) { VOk "旧 loader 已禁用（ValheimVRM.dll.old）" } else { VOk "档内没有旧 loader" }

    # —— 旧布局（v1.12）的运行时 dll ——
    if (-not $evDir -and $managed) {
        if (-not (Test-Path (Join-Path $managed "assembly_valheim.dll"))) {
            VWarn "游戏目录不完整（没有 valheim_Data\Managed\assembly_valheim.dll）→ 跳过旧布局的运行时 dll 核对（沙盒/没装游戏的机器会这样）"
        } else {
        $v12 = @("VRM.dll","VRM10.dll","VrmLib.dll","UniGLTF.dll","UniGLTF.Utils.dll","UniHumanoid.dll","MToon.dll",
                 "FastSpringBone.dll","FastSpringBone10.dll","UnityEngine.VRModule.dll",
                 "VRMShaders.GLTF.IO.Runtime.dll","VRMShaders.GLTF.UniUnlit.Runtime.dll",
                 "VRMShaders.VRM.IO.Runtime.dll","VRMShaders.VRM10.Format.Runtime.dll","VRMShaders.VRM10.MToon10.Runtime.dll")
        $m = @($v12 | Where-Object { -not (Test-Path (Join-Path $managed $_)) })
        if ($m.Count -eq 0) { VOk "旧布局：游戏 Managed 里 15 个运行时 dll 都在" } else { VBad "旧布局：Managed 缺 $($m.Count) 个（$($m -join ', ')）→ Steam 校验文件完整性会清掉，重跑本脚本即可" }
        }
    }

    # —— 模型库与设置 ——
    if ($lib) {
        if (Test-Path $lib) {
            $vrms = @(Get-ChildItem -Path $lib -Filter "*.vrm" -File -ErrorAction SilentlyContinue)
            if ($script:EvMode -and $lib) {
                if ($vrms.Count -gt 0) { VOk "新版模型库：$($vrms.Count) 个 .vrm @ $lib（由 F9 选择，不需要角色名槽）" } else { VWarn "新版模型库存在但没有 .vrm：$lib" }
            } elseif ($vrms.Count -gt 0) { VOk "旧版模型库：$($vrms.Count) 个 .vrm @ $lib" }
            $sh = @(Get-ChildItem -Path $lib -Filter "settings_*.txt" -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -notlike "*Example*" -and $_.Name -notlike "*____Default*" })
            if ($script:EvMode) {
                if ($sh.Count -gt 0) { VWarn "新版模型库仍有 settings_<角色名>.txt（新版不使用角色名槽，请保留或清理旧残留）" }
            } elseif ($sh.Count -gt 0) {
                $s1 = $sh[0]
                $at = (Select-String -LiteralPath $s1.FullName -Pattern '^\s*AttemptTextureFix\s*=\s*(\S+)' -ErrorAction SilentlyContinue | Select-Object -Last 1).Matches.Groups[1].Value
                $mb = (Select-String -LiteralPath $s1.FullName -Pattern '^\s*ModelBrightness\s*=\s*(\S+)' -ErrorAction SilentlyContinue | Select-Object -Last 1).Matches.Groups[1].Value
                VOk "settings：$($s1.Name)  AttemptTextureFix=$at  ModelBrightness=$mb"
                if ("$at" -notmatch "true") { VWarn "AttemptTextureFix 不是 true → 模型会保留无光照着色器（发灰 / 眼睛发黑 / 半透明）" }
            } else { VWarn "旧版模型库下没有 settings_<角色名>.txt（插件会用默认值）" }
        } else { VWarn "没有模型库目录：$lib（还没进过游戏，或没跑过模型那一步）" }
    }
    if ($libOld -and (Test-Path $libOld)) { VWarn "旧 loader 的模型目录还在：$libOld（新版不读它；可以整个挪走备份）" }

    # —— 热键占用（F9）——
    $cfgDir = Join-Path $vProf "BepInEx\config"
    if (Test-Path $cfgDir) {
        $occ = @(Get-ChildItem -Path $cfgDir -Filter *.cfg -File -ErrorAction SilentlyContinue |
                 Where-Object { $_.Name -notlike "*modelswitcher*" } |
                 Where-Object { (Get-Content -LiteralPath $_.FullName -Encoding UTF8 -ErrorAction SilentlyContinue) -match '=\s*F9\s*$' })
        if ($occ.Count -gt 0) { VWarn "F9 被其它 cfg 占用：$((@($occ | ForEach-Object { $_.Name })) -join ', ')" } else { VOk "F9 未被其它 mod 占用" }
    }

    Say ""
    Say "  ------------------------------------------------------------" "Cyan"
    Say "   ✅ $($script:VOk)   ⚠️  $($script:VWarn)   ❌ $($script:VFail)" "Cyan"
    if ($script:VFail -eq 0) { Say "   结论：与文档一致（警告项按需处理）" "Green" } else { Say "   结论：有未通过项，见上面 ❌" "Red" }
    Say "  ============================================================" "Cyan"
    if ($script:packTmpExtract -and (Test-Path $script:packTmpExtract)) {
        try { Remove-Item $script:packTmpExtract -Recurse -Force -ErrorAction SilentlyContinue } catch {}
    }
    SaveLog
    if ($script:VFail -eq 0) { Exit 0 } else { Exit 1 }
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

# ---------- 只演练（-DryRun）：打印"将要做什么"，不写任何文件 ----------
if ($DryRun) {
    Say ""
    Say "  ============================================================" "Cyan"
    Say "   安装流程演练（-DryRun：不写任何文件；去掉该参数即照此执行）" "Cyan"
    Say "  ============================================================" "Cyan"
    $dDst = Join-Path $ProfilesRoot $ProfileName
    $dEvPlug = Join-Path (Join-Path (Join-Path $ProfilesRoot $ProfileName) "BepInEx\plugins") "Rawrtastic-EnhancedValheimVRM"
    $dEvMode = (Test-Path (Join-Path $dEvPlug "EnhancedValheimVRM.dll"))
    $dGame = if (-not [string]::IsNullOrWhiteSpace($GameDir)) { $GameDir.Trim().Trim('"').TrimEnd('\') } else { Find-ValheimGameDir }
    Say "   源档   : $(if ($src) { $src } else { '(未解析到)' })"
    Say "   目标档 : $dDst   $(if (Test-Path $dDst) { '（已存在 → 默认【升级】；-Fresh 则整档改名备份后重装）' } else { '（不存在 → 全新安装）' })"
    Say "   游戏   : $(if ($dGame) { $dGame } else { '(未找到，VRM 那步会问你)' })"
    Say ""

    # —— 1) 档内文件差异（BepInEx\config 会跳过，保留你的设置）——
    if ($src -and (Test-Path $src)) {
        $dNew = 0; $dChg = 0; $dSame = 0
        $show = New-Object System.Collections.Generic.List[string]
        Get-ChildItem -Path $src -File -Recurse -ErrorAction SilentlyContinue | ForEach-Object {
            $rel = $_.FullName.Substring($src.Length).TrimStart('\')
            if ($rel -like "BepInEx\config\*") { return }
            # 与 robocopy 的排除保持一致（否则演练会把自己这几份文件误报成"新增"）
            if ($script:SelfFiles -contains $_.Name) { return }
            if ($_.Name -like "*.bak-*") { return }
            if ($dEvMode -and ($_.Name -eq "ValheimVRM.dll" -or $_.Name -eq "VRMGhostFix.dll")) { return }   # 与 robocopy 的 /XF 对齐
            $t = Join-Path $dDst $rel
            if (-not (Test-Path $t)) { $dNew++; if ($show.Count -lt 12) { $show.Add("       新增   $rel") } }
            else {
                $h1 = (Get-FileHash -LiteralPath $_.FullName -Algorithm MD5).Hash
                $h2 = (Get-FileHash -LiteralPath $t -Algorithm MD5).Hash
                if ($h1 -ne $h2) { $dChg++; if ($show.Count -lt 12) { $show.Add("       覆盖   $rel") } } else { $dSame++ }
            }
        }
        Say "   [档] 复制计划：新增 $dNew / 覆盖 $dChg / 已一致 $dSame（BepInEx\config 不动）"
        foreach ($l in $show) { Say $l "DarkGray" }
        if (($dNew + $dChg) -gt $show.Count) { Say "       …（其余差异省略）" "DarkGray" }
    } else { Say "   [档] 源档没解析到，无法列差异" "Yellow" }

    # —— 2) VRM 那一步（包内找 BepInEx_plugins* / valheim_Data_Managed* 两个子目录）——
    $dPackRoot = $PSScriptRoot
    $dVrmPack = $null
    foreach ($cand in @((Join-Path $dPackRoot "EnhancedValheimVRM_手动安装"), (Join-Path $dPackRoot "vrm"), $dPackRoot)) {
        if ([string]::IsNullOrWhiteSpace($cand) -or -not (Test-Path $cand)) { continue }
        $subs = @(Get-ChildItem -Path $cand -Directory -ErrorAction SilentlyContinue |
                  Where-Object { $_.Name -like "BepInEx_plugins*" -or $_.Name -like "valheim_Data_Managed*" })
        if ($subs.Count -gt 0) { $dVrmPack = $cand; break }
    }
    Say ""
    if ($dVrmPack) {
        $dPlug = @(Get-ChildItem -Path $dVrmPack -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -like "BepInEx_plugins*" } | Select-Object -First 1)
        $dMan  = @(Get-ChildItem -Path $dVrmPack -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -like "valheim_Data_Managed*" } | Select-Object -First 1)
        $nPlug = if ($dPlug) { @(Get-ChildItem $dPlug.FullName -File -ErrorAction SilentlyContinue).Count } else { 0 }
        $nMan  = if ($dMan)  { @(Get-ChildItem $dMan.FullName  -File -ErrorAction SilentlyContinue).Count } else { 0 }
        if ($dEvMode) {
            Say "   [VRM] 本档已装【新版加载器 EnhancedValheimVRM】→ 这一步会按新版维护：" "Yellow"
            Say "         · 不写旧包的 15 个 dll；改为把新版加载器的 UniVRM 程序集同步进 <游戏>\valheim_Data\Managed\" "DarkGray"
            Say "         · 档里残留的 ValheimVRM.dll / VRMGhostFix.dll 会被停用（.dll → .dll.old）" "DarkGray"
            Say "         · 模型库放 <游戏>\EnhancedValheimVRM\，进游戏按 F9 选择（不需要角色名，也不生成 settings_<角色名>.txt）" "DarkGray"
        }
        if (-not $dEvMode) { Say "   [VRM/角色模型] 三处（源：$(Split-Path $dVrmPack -Leaf)）：" }
        if (-not $dEvMode) {
            Say "       ① 插件      → <档>\BepInEx\plugins\...            （$nPlug 个文件）" "DarkGray"
            Say "       ② 运行时 dll → <游戏>\valheim_Data\Managed\         （$nMan 个文件；覆盖前备份到 <游戏>\_vrm_backup_<时间>\）" "DarkGray"
            Say "       ③ 模型与设置 → <游戏>\ValheimVRM\<角色名>.vrm + settings_<角色名>.txt（交互时问你角色名）" "DarkGray"
            Say "       末尾会打印 VRM 三处自检。" "DarkGray"
        }
    } else {
        Say "   [VRM] 新版 EnhancedValheimVRM：选模型后放入游戏模型库，进游戏按 F9 切换，不询问角色名。" "DarkGray"
    }

    # —— 3) 模型下载/缓存计划 ——
    Say ""
    if (-not [string]::IsNullOrWhiteSpace($ModelPath)) { Say "   [模型] 用你给的本地文件：$ModelPath" "DarkGray" }
    elseif (-not [string]::IsNullOrWhiteSpace($Models)) { Say "   [模型] 下载/缓存：$Models" "DarkGray" }
    elseif ($VRMOnly) { Say "   [模型] -VRMOnly：会问你选一只模型（演练不提问）" "DarkGray" }
    else { Say "   [模型] 交互模式：会问「一并配置 VRM 吗」+ 选模型（演练不提问）；不想装用 -ModsOnly / -SkipVRM" "DarkGray" }

    Say ""
    Say "   其余步骤：关 r2modman（若在运行）→ 复制/升级档 → [6/7] 关键文件校验 → 外观替换（若未 -SkipSkin）→ 清理临时目录 → 写日志" "DarkGray"
    Say "   日志路径：$(Join-Path $env:USERPROFILE 'Desktop\MAKABAKA安装日志.txt')" "DarkGray"
    if ($script:packTmpExtract -and (Test-Path $script:packTmpExtract)) {
        try { Remove-Item $script:packTmpExtract -Recurse -Force -ErrorAction SilentlyContinue } catch {}
    }
    SaveLog
    Say ""
    Say "   （演练结束：未改动任何档内文件、游戏目录、模型缓存；临时解压目录已清理）" "Green"
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

# ---- 新版加载器（EnhancedValheimVRM）检测：新旧两套不能共存 ----
# 新版加载器要的是【更新版】UniVRM 程序集；旧 ValheimVRM 1.2.2 自带的那 15 个 dll 是旧版。
# 一旦被本脚本覆盖回游戏 Managed，新版加载器就会加载到旧程序集（表现为模型不生效/报错）。
# 所以只要档里装了新版加载器，这一步就改成"维护新版加载器"，绝不写旧 loader 的任何东西。
$evPlugDir = Join-Path (Join-Path (Join-Path $ProfilesRoot $ProfileName) "BepInEx\plugins") "Rawrtastic-EnhancedValheimVRM"
# 新包源若带 EnhancedValheimVRM，即使目标机器仍是旧 loader，也必须走迁移分支。
# 否则首次升级会把新 DLL 错放进 ValheimVRM_1.2.2，随后 VRM 仍按旧方案运行。
$sourceEnhancedVrm = $false
if (-not [string]::IsNullOrWhiteSpace($packRoot) -and (Test-Path $packRoot)) {
    $sourceEnhancedVrm = [bool](Get-ChildItem -Path $packRoot -Recurse -File -Filter "EnhancedValheimVRM.dll" -ErrorAction SilentlyContinue | Select-Object -First 1)
}
$script:EvMode = (Test-Path (Join-Path $evPlugDir "EnhancedValheimVRM.dll")) -or $sourceEnhancedVrm

# 停用与新版加载器冲突的旧插件（ValheimVRM 1.2.2 的 dll / VRMGhostFix）：先备份，再 .dll → .dll.old
# 注意 Rename-Item 在目标已存在时会报错（.old 上一轮就在）⇒ 一律"先拷 .old 再删原文件"
function Disable-LegacyVrmResidue([string]$profRootThis) {
    $pluginsX = Join-Path $profRootThis "BepInEx\plugins"
    $bakX = Join-Path (Join-Path $profRootThis "BepInEx") ("_vrm_backup_" + (Get-Date -Format "yyyyMMdd-HHmmss"))
    $n = 0
    foreach ($it in @(@{ D = "ValheimVRM_1.2.2"; F = "ValheimVRM.dll" }, @{ D = "VRMGhostFix"; F = "VRMGhostFix.dll" })) {
        $f = Join-Path (Join-Path $pluginsX $it.D) $it.F
        if (-not (Test-Path $f)) { continue }
        New-Item -ItemType Directory -Path $bakX -Force | Out-Null
        Copy-Item $f (Join-Path $bakX $it.F) -Force
        Copy-Item $f "$f.old" -Force
        Remove-Item $f -Force
        Say "        ① $($it.F) → .old（与新版加载器不能共存；备份在 $(Split-Path $bakX -Leaf)）" "Green"
        $n++
    }
    return $n
}

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
        $backup = Copy-ProfileBackup $dst $ProfilesRoot "before-reinstall"
        Remove-Item $dst -Recurse -Force
        Say "        旧档已移除，完整备份保留在：$backup" "Green"
    }
    else {
        $backup = Copy-ProfileBackup $dst $ProfilesRoot "before-upgrade"
    }
} else {
    Say "  [4/7] 没有已安装的档 → 全新安装 ✓" "Green"
}

# ---------- 5) 复制 ----------
$rb = Join-Path $env:SystemRoot "System32\robocopy.exe"
$xf = @()
foreach ($f in $script:SelfFiles) { $xf += "/XF"; $xf += $f }
# 装了新版加载器的档：绝不再把旧 loader / VRMGhostFix 拷回档里（否则每次 -ModsOnly 都会把它们复活）
if ($script:EvMode) { $xf += "/XF"; $xf += "ValheimVRM.dll"; $xf += "VRMGhostFix.dll" }
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
        if ($LASTEXITCODE -ge 8) { Say "        [注意] 补充配置文件时有几项没复制成功（robocopy 退出码 $LASTEXITCODE）；mod 本体已更新，不影响进游戏。" "Yellow" }
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
    if ($script:EvMode -and $rel -like "*VRMGhostFix*") { continue }   # 新版加载器方案下它被停用
    $f = Join-Path $dst $rel
    if (-not (Test-Path $f)) { $bad += "$rel （缺失）"; continue }
    $h = (Get-FileHash -Path $f -Algorithm MD5).Hash.ToLower()
    if ($h -ne $Expect[$rel]) { $bad += "$rel （内容与出厂不一致）" }
}
if ($bad.Count -eq 0) {
    $critTxt = "ChestFlow 汉化版、ChestFlowTweaks 0.3.1、EpicLoot 0.14.10、Endurance 汉化版"
    if (-not $script:EvMode) { $critTxt += "、VRMGhostFix" }
    Say "        关键文件校验通过 ✓（$critTxt）" "Green"
} else {
    Say "        [注意] 以下文件与出厂版本不一致：" "Yellow"
    foreach ($b in $bad) { Say "          - $b" "Yellow" }
    Say "        （若是刚升级后仍不一致，说明升级没生效，请把本日志发我们）" "Yellow"
}
try {
    $ver = (Get-Content (Join-Path $dst "BepInEx\plugins\jg224-ChestFlow\manifest.json") -Raw -Encoding UTF8 | ConvertFrom-Json).version_number
    Say "        ChestFlow 版本：$ver（界面已简体汉化）"
} catch {}
if ($script:EvMode) {
    $nDis2 = Disable-LegacyVrmResidue -profRootThis $dst
    if ($nDis2 -gt 0) { Say "        （已停用 $nDis2 个与新版加载器冲突的旧插件：.dll → .dll.old）" "Green" }
}
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
foreach ($cand in @((Join-Path $packRoot "EnhancedValheimVRM_手动安装"), (Join-Path $packRoot "vrm"), $packRoot)) {
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
    if ($script:EvMode) {
        Say ""
        Say "  ★ 本档已装【新版加载器 EnhancedValheimVRM】→ 本节改为维护新版加载器：" "Cyan"
        Say "    · 不再安装旧的 ValheimVRM 1.2.2（两个 loader 会同时 patch Player.Awake，只能留一个）" "Cyan"
        Say "    · 档里若残留旧 loader / VRMGhostFix → 自动停用（.dll → .dll.old，先备份）" "Cyan"
        Say "    · 游戏 Managed 里改为同步新版加载器的 UniVRM 程序集（不用旧包那 15 个）" "Cyan"
        Say "    · 模型目录改为 <游戏>\EnhancedValheimVRM\<角色名>.vrm（进游戏按 F9 换模型）" "Cyan"
    }
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
        if ($script:EvMode) {
            # 新版加载器在场，或新包正在把旧方案迁移到新版：先把新版插件本体放入档。
            # -VRMOnly 承诺不写档，因此只报告，不复制。
            $srcEvPlugin = $null
            if ($vrmPack) {
                $evFound = Get-ChildItem -Path $vrmPack -Recurse -File -Filter "EnhancedValheimVRM.dll" -ErrorAction SilentlyContinue | Select-Object -First 1
                if ($evFound) { $srcEvPlugin = $evFound.DirectoryName }
            }
            if ($VRMOnly) {
                if (Test-Path (Join-Path $evPlugDir "EnhancedValheimVRM.dll")) { Say "        ① 加载器：新版 EnhancedValheimVRM 已在档里 ✓（只换模型模式不写档）" "Green" }
                elseif ($srcEvPlugin) { Say "        ① [注意] 新包带新版加载器，但档里尚未迁移；跑一次完整安装会复制到 $evPlugDir（只换模型模式不写档）" "Yellow" }
                else { Say "        ① [×] 找不到新版加载器源文件" "Red" }
            } else {
                try {
                    if (-not (Test-Path $evPlugDir)) { New-Item -ItemType Directory -Path $evPlugDir -Force | Out-Null }
                    if ($srcEvPlugin) {
                        foreach ($f in (Get-ChildItem -Path $srcEvPlugin -File)) { Copy-Item $f.FullName (Join-Path $evPlugDir $f.Name) -Force }
                        Say "        已将新版加载器复制到档：$evPlugDir" "Green"
                    } elseif (-not (Test-Path (Join-Path $evPlugDir "EnhancedValheimVRM.dll"))) {
                        Say "        [注意] 找不到新版加载器源文件，无法迁移" "Yellow"
                    }
                } catch { Fail "复制新版 EnhancedValheimVRM 到档失败：$($_.Exception.Message)" }
                $nDis = Disable-LegacyVrmResidue -profRootThis $profRootThis
                if ($nDis -eq 0) { Say "        ① 旧 loader / VRMGhostFix：未发现（本档就是新版加载器方案）✓" "Green" }
                $vrmOk["插件"] = (Test-Path (Join-Path $evPlugDir "EnhancedValheimVRM.dll"))
            }
        }
        elseif ($srcVrmPlugins -and $VRMOnly) {
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
            if ($script:EvMode) {
                # 同步【新版加载器】的 UniVRM 程序集到 Managed（不再写旧包的 15 个）
                $evAsm = @(Get-ChildItem -Path $evPlugDir -Filter "*.dll" -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -ne "EnhancedValheimVRM.dll" })
                $evBak = Join-Path $managed "_evv_prev"
                $cEv = 0; $sEv = 0; $bEv = 0
                foreach ($f in $evAsm) {
                    $t = Join-Path $managed $f.Name
                    if (Test-Path $t) {
                        if ((Get-FileHash $f.FullName -Algorithm MD5).Hash -eq (Get-FileHash $t -Algorithm MD5).Hash) { $sEv++; continue }
                        New-Item -ItemType Directory -Path $evBak -Force | Out-Null
                        Copy-Item $t (Join-Path $evBak $f.Name) -Force; $bEv++
                    }
                    Copy-Item $f.FullName $t -Force; $cEv++
                }
                Say "        ② Managed 程序集 → $managed" "Green"
                Say "           新放/更新 $cEv 个（新版加载器的 $($evAsm.Count) 个；本来就一致 $sEv 个；替换前备份 $bEv 个 → _evv_prev）"
                $vrmOk["Managed"] = $true
            }
            elseif ($srcVrmManaged) {
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

            $vrmDirName = if ($script:EvMode) { "EnhancedValheimVRM" } else { "ValheimVRM" }
            $vrmTarget = Join-Path $game $vrmDirName
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
                $modelList = Get-ModelCandidates -packRoot $packRoot -cacheDir $cacheDir -libraryDir $vrmTarget -modelPath $ModelPath -manifestSource $ModelSource -manifest $man
            } else {
                Say "        ③ [跳过] 缺模型库 ModelLib.ps1 → 这一步跳过（只更新 mod 不受影响；以后用 换模型.bat 可单独装模型）" "Yellow"
            }
            if ($modelList.Count -gt 0) {
                $nC = @($modelList | Where-Object { $_.Cached }).Count
                Say ("  模型：可选 {0} 个（本机缓存 {1} 个）" -f $modelList.Count, $nC) "DarkGray"
                Show-LibraryStatus $modelList
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
                $wantAll = ($AllModels -or (($Models -as [string]) -match '^(?i)\s*(all|全部|所有)\s*$'))
                if ($wantAll) {
                    $picks = @($modelList)
                    Say "        已选【全部 $($modelList.Count) 个】模型（本机已有 $(@($modelList | Where-Object { $_.Cached }).Count) 个，需下载 $(@($modelList | Where-Object { -not $_.Cached }).Count) 个）" "Cyan"
                    $LibraryOnly = $true   # 全量补库：默认不动"当前使用的那只"（要同时设当前用，加 -CharName）
                }
                if ($picks.Count -eq 0 -and -not [string]::IsNullOrWhiteSpace($VrmModel)) {
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
                        # 模型库里已经有"同大小、只是名字不同"的文件（老版本入的库）→ 不必再下一遍
                        if ($pc.SizeMB) {
                            $wantSz = [int64]($pc.SizeMB * 1MB)
                            $dupLib = @(Get-ChildItem -Path $vrmTarget -Filter "*.vrm" -File -ErrorAction SilentlyContinue |
                                        Where-Object { [math]::Abs($_.Length - $wantSz) -le 102400 } | Select-Object -First 1)
                            if ($dupLib) {
                                Say "        「$($pc.Name)」库里已有同大小的 $($dupLib.Name) → 跳过下载（不重复占盘）" "DarkGray"
                                continue
                            }
                        }
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
                # ---- 3b-3) 把选中的模型【都】放进模型库（各自独立文件名）→ 进游戏 F9 可随时切 ----
                # 先记下"入库前"目录里已有哪些文件（角色名候选 / 旧模型提示都只看它们，免得把刚入库的模型名当角色名）
                $existingBefore = @(Get-ChildItem -Path $vrmTarget -File -Filter "*.vrm" -ErrorAction SilentlyContinue | ForEach-Object { $_.BaseName })
                if ($picks.Count -gt 0) {
                    $libNew = 0; $libSame = 0
                    foreach ($pc in $picks) {
                        if (-not $pc.Vrm -or -not (Test-Path $pc.Vrm)) { continue }
                        $libName = (($pc.Name -replace '[\\/:*?"<>|]', '_').Trim()) + ".vrm"
                        $libPath = Join-Path $vrmTarget $libName
                        if (Test-Path $libPath) {
                            if ((Get-FileHash $libPath -Algorithm MD5).Hash -eq (Get-FileHash $pc.Vrm -Algorithm MD5).Hash) { $libSame++; continue }
                        } else {
                            # 库里已经有"同大小、只是名字不同"的文件（老命名）→ 不重复入库
                            $pcSz = [int64](Get-Item -LiteralPath $pc.Vrm).Length
                            $dup2 = @(Get-ChildItem -Path $vrmTarget -Filter "*.vrm" -File -ErrorAction SilentlyContinue | Where-Object { [math]::Abs($_.Length - $pcSz) -le 102400 } | Select-Object -First 1)
                            if ($dup2) { Say "        「$($pc.Name)」库里已有同大小的 $($dup2.Name) → 不重复入库" "DarkGray"; $libSame++; continue }
                        }
                        try { Copy-Item $pc.Vrm $libPath -Force; $libNew++ } catch { Say "        [注意] 没能入库「$($pc.Name)」：$($_.Exception.Message)" "Yellow" }
                    }
                    $libCount = @(Get-ChildItem -Path $vrmTarget -Filter "*.vrm" -File -ErrorAction SilentlyContinue).Count
                    Say "        ③a 模型库 → $vrmTarget" "Green"
                    Say "           本机现有 $libCount 个模型（本次新入库 $libNew 个 / 已一致 $libSame 个）→ 进游戏按 F9 就能切" "Green"
                }
                $selectedModel = $null
                if ($script:EvMode) {
                    # 新版 EnhancedValheimVRM：模型库由 F9 读取，不使用角色名槽位。
                    # 选中的模型只需入库；当前使用哪一个由游戏内 F9 选择。
                    $selectedModel = "skip"
                    if ($picks.Count -gt 0) {
                        Say "        ③ 新版加载器不需要角色名：选中的模型已放入模型库，进游戏按 F9 选择。" "Green"
                    } else {
                        Say "        ③ 未选择模型：保持当前游戏内 F9 选择不变。" "DarkGray"
                    }
                } elseif ($picks.Count -gt 0) { $selectedModel = $picks[0] }
                # -LibraryOnly / -AllModels 未给 -CharName 时：只补模型库，不动"当前使用"的那只
                $libOnlyEffective = (-not $script:EvMode) -and ($LibraryOnly -and [string]::IsNullOrWhiteSpace($CharName))
                if ($libOnlyEffective) { $selectedModel = $null }
                if ($null -eq $selectedModel) { $selectedModel = "skip" }

                if ($selectedModel -eq "skip") {
                    if ($picks.Count -gt 0) { Say "        ③ 当前使用的模型未改动（模型已入进上面的模型库；想换进游戏按 F9，或加 -CharName 指定）" "DarkGray" }
                    else { Say "        ③ 已跳过（保持现有模型不动）" "DarkGray" }
                    $vrmOk["模型"] = (@(Get-ChildItem -Path $vrmTarget -File -Filter "*.vrm" -ErrorAction SilentlyContinue).Count -gt 0)
                } else {
                    # ---- 3c) 问角色名（每个人的名字不同，由玩家自己输）----
                    $charName = $CharName.Trim().Trim('"')
                    $existing = $existingBefore
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
                    if ([string]::IsNullOrWhiteSpace($charName) -and $NonInteractive -and $existing.Count -ge 1 -and -not $libOnlyEffective) {
                        # 只把"真正的角色槽"当候选：它旁边必须有 settings_<名字>.txt；
                        # 模型库里的模型（<清单名>.vrm）没有配对 settings，不能被当成角色名 —— 否则会把库里的模型覆盖掉
                        $slotNames = @($existing | Where-Object { Test-Path (Join-Path $vrmTarget ("settings_$_.txt")) })
                        if ($slotNames.Count -ge 1) {
                            $charName = $slotNames[0]
                            Say "        （非交互模式：沿用现有角色名「$charName」）" "DarkGray"
                        } else {
                            Say "        （非交互模式：目录里没有现成的角色槽（settings_<角色名>.txt）→ 只补模型库，不碰当前使用的模型）" "DarkGray"
                        }
                    }

                    if ([string]::IsNullOrWhiteSpace($charName) -or $charName -eq "skip") {
                        Say "        ③ 没有拿到角色名 → 模型这步跳过（想装：重跑本脚本，或双击 换模型.bat）" "Yellow"
                        $vrmOk["模型"] = (@(Get-ChildItem -Path $vrmTarget -File -Filter "*.vrm" -ErrorAction SilentlyContinue).Count -gt 0)
                    } else {
                        Copy-Item $selectedModel.Vrm (Join-Path $vrmTarget "$charName.vrm") -Force
                        $setDst = Join-Path $vrmTarget "settings_$charName.txt"
                        if ($selectedModel.Settings -and (Test-Path $selectedModel.Settings)) { Copy-Item $selectedModel.Settings $setDst -Force }
                        Say "        ③ 模型 → $vrmTarget" "Green"
                        Say "           模型： $charName.vrm（用的「$($selectedModel.Name)」，只是复制一份改名；源文件没动）"
                        if (Test-Path $setDst) { Say "           设置： settings_$charName.txt ✓" "Green" }
                        else { Say "           设置： 缺失（插件会退回默认值：模型大小 1.1、亮度 0.8…）" "Yellow" }
                        $others = @($existing | Where-Object { $_ -ne $charName } | ForEach-Object { "$_.vrm" })
                        if ($others.Count -gt 0 -and -not $script:EvMode) {
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
        if ($script:EvMode) {
            if (Test-Path (Join-Path $evPlugDir "EnhancedValheimVRM.dll")) {
                if (Test-Path (Join-Path $plugDst "ValheimVRM.dll")) { Say "        [×] ① 旧 loader 又启用了：$plugDst\ValheimVRM.dll（与新版加载器冲突，必须改名 .old）" "Red" }
                else { Say "        [✓] ① 加载器（档里）：新版 EnhancedValheimVRM；旧 loader 未启用" "Green" }
            } else { Say "        [×] ① 新版加载器插件缺失：$evPlugDir" "Red" }
        } else {
            $plugFile = Join-Path $plugDst "ValheimVRM.dll"
            if (Test-Path $plugFile) { Say "        [✓] ① 插件（档里）：$plugDst" "Green" }
            else { Say "        [×] ① 插件缺失：$plugDst（BepInEx\plugins\ 下应有 ValheimVRM.dll + ValheimVRM.shaders）" "Red" }
        }
        if ($game) {
            $mOk = $true
            $mSrc = @()
            if ($script:EvMode) { $mSrc = @(Get-ChildItem -Path $evPlugDir -Filter "*.dll" -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -ne "EnhancedValheimVRM.dll" }) }
            elseif ($srcVrmManaged) { $mSrc = @(Get-ChildItem -Path $srcVrmManaged -File) }
            foreach ($f in $mSrc) {
                $t = Join-Path (Join-Path $game "valheim_Data\Managed") $f.Name
                if (-not (Test-Path $t)) { $mOk = $false; break }
                if ((Get-FileHash $f.FullName -Algorithm MD5).Hash -ne (Get-FileHash $t -Algorithm MD5).Hash) { $mOk = $false; break }
            }
            if ($mOk) { Say "        [✓] ② Managed 程序集（游戏里）：$($mSrc.Count) 个与加载器目录逐字节一致" "Green" }
            else { Say "        [×] ② Managed 里的程序集缺失或不一致（Steam 验证文件完整性会清掉旧 loader 的 dll；新版方案重跑本脚本即可）" "Red" }
            $selfDirName = if ($script:EvMode) { "EnhancedValheimVRM" } else { "ValheimVRM" }
            $selfVrmDir = Join-Path $game $selfDirName
            $vrmCount = @(Get-ChildItem -Path $selfVrmDir -File -Filter "*.vrm" -ErrorAction SilentlyContinue).Count
            if ($script:vrmActiveName) {
                $vf = Join-Path $selfVrmDir "$($script:vrmActiveName).vrm"
                $sf = Join-Path $selfVrmDir "settings_$($script:vrmActiveName).txt"
                if ((Test-Path $vf) -and (Test-Path $sf)) { Say "        [✓] ③ 模型（游戏里）：$($script:vrmActiveName).vrm + settings_$($script:vrmActiveName).txt 都在" "Green" }
                elseif (Test-Path $vf) { Say "        [✓] ③ 模型（游戏里）：$($script:vrmActiveName).vrm 在；settings_$($script:vrmActiveName).txt 没有（插件会用默认值）" "Yellow" }
                else { Say "        [×] ③ 模型缺失：$vf" "Red" }
            }
            elseif ($vrmCount -gt 0) { Say "        [✓] ③ 模型（游戏里）：$vrmCount 个 .vrm 在 $selfVrmDir" "Green" }
            else {
                Say "        [×] ③ 没找到 .vrm 模型：$selfVrmDir" "Red"
                Say "            （想装模型：重跑本脚本、或双击 换模型.bat 选一个模型并输入你的角色名；脚本会自动命名）" "Yellow"
            }
        } else {
            Say "        [—] ②③ 未检查：没找到游戏目录（插件那半已经装好；游戏侧之后重跑本脚本即可）" "Yellow"
        }
    }
}

# ---------- ④ 武器/物品外观替换（独立模块）----------
if (-not $SkipSkin) {
    if ($VRMOnly -and [string]::IsNullOrWhiteSpace($SkinTarget)) {
        Say "  [—] 只换模型模式：跳过武器/物品外观替换（要一起改就加 -SkinTarget/-SkinModel）" "DarkGray"
    }
    elseif (-not $script:SkinLibLoaded) {
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

            if (-not $skinToken -and -not $NonInteractive) {
                # 和角色模型同一套做法：外观模型实体也在私有仓库 → 没凭据就问一次并记住
                $skinRemote = @(Get-SkinModels -LibDir $skinLibDir | Where-Object { $_.Remote })
                if ($skinRemote.Count -gt 0) {
                    Say "        外观模型也在【私有】仓库里，下载要一次凭据（GitHub 令牌，只读权限即可；输一次会记住）" "Yellow"
                    $skinToken = Get-ModelToken -packRoot $packRoot -Prompt -Save
                }
            }
            if (-not $skinToken) { Say "        [注意] 没拿到模型凭据：只有本机已有的模型能用，需要下载的会跳过（把 模型凭据.txt 放到 install.ps1 旁边，或去掉 -NonInteractive 让它问你一次）" "Yellow" }

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
