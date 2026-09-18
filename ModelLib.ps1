<#
  ModelLib.ps1 —— MAKABAKA 整合档的「模型清单 / 下载 / 缓存」库（由 install.ps1 dot-source）

  设计目标：
    · 日常更新 mod 时**完全不碰模型**（模型不进安装包，也不再每次重下）
    · 想装/换模型时，脚本里列出可选项 → 按需下载 → 校验 → 进本机缓存 → 以后换模型秒切不重下
    · 模型托管在【私有】GitHub 仓库的 Release 附件（models.json 里写仓库/标签/附件名；也可填直链 url 覆盖）

  由 install.ps1 提供：$ReleasesRepo、$MirrorPrefixes、Say()、Save-FileWithMirrors()
  本文件不自己下载依赖，保持可单独测试。
#>

# ---------- 常量（发新版时按需改）----------
$ModelRepoDefault  = "kanziguai/valheim-makabaka-models"   # 私有模型仓库（owner/repo）
$ModelReleaseTag   = "models-v1"                            # 模型附件的 Release 标签
$ModelTokenFile    = "模型凭据.txt"                          # 令牌文件（脚本同目录或 %LOCALAPPDATA%\MAKABAKA\）
$ModelManifestName = "models.json"                          # 清单文件名（仓库 Models\ 下）

# 私有仓库附件是"按连接限速"的（实测单连接 0.59~0.85 MB/s 且随进度衰减）⇒ 分段并发下载：
#   实测 Windows PS 5.1、32.4MB 附件：单连接 54.5s（0.59 MB/s）→ 6 段 7.9s（4.12 MB/s，6.9×）
# 8 段没有继续变快（4.2×，比 6 段略差）⇒ 6 是甜点。小附件分段不划算（握手开销占比高）。
$script:ModelDownloadThreads  = 6        # 并发连接数（1 = 关闭分段，走单连接）
$script:ModelSegmentMinBytes  = 8MB      # 小于这个大小就单连接下（一次 API 跳转 + 握手就够快）
$script:ModelSegmentTries     = 3        # 单段失败重试次数（每次从该段断点续）

# 安全的 Join-Path：父目录不存在/盘符不存在时返回 $null（避免 DriveNotFoundException）
function Join-Safe([string]$base, [string]$rel) {
    if ([string]::IsNullOrWhiteSpace($base)) { return $null }
    try { if (-not (Test-Path -LiteralPath $base)) { return $null } } catch { return $null }
    try { return (Join-Path $base $rel) } catch { return $null }
}

function Get-ModelTokenPaths([string]$packRoot) {
    $ps = @()
    if ($PSScriptRoot) { $ps += (Join-Path $PSScriptRoot $ModelTokenFile) }
    $ps += (Join-Safe $packRoot $ModelTokenFile)
    $ps += (Join-Path (Join-Path $env:LOCALAPPDATA "MAKABAKA") $ModelTokenFile)
    # 仓库里的 Models\ 也允许放一份（.gitignore 掉，不进公开仓库）
    $ps += (Join-Safe (Join-Safe $packRoot "Models") $ModelTokenFile)
    return $ps
}

# 令牌解析顺序：参数 → 环境变量 → 凭据文件；都没有就返回 ""
function Get-ModelToken([string]$given = "", [string]$packRoot = "", [switch]$Prompt, [switch]$Save) {
    if (-not [string]::IsNullOrWhiteSpace($given)) { return $given.Trim() }
    $env1 = [Environment]::GetEnvironmentVariable("MAKABAKA_MODEL_TOKEN")
    if (-not [string]::IsNullOrWhiteSpace($env1)) { return $env1.Trim() }
    foreach ($p in (Get-ModelTokenPaths $packRoot)) {
        if ($p -and (Test-Path $p)) {
            $t = (Get-Content -LiteralPath $p -Raw -ErrorAction SilentlyContinue)
            if ($t) { $t = $t.Trim(); if ($t) { return $t } }
        }
    }
    if ($Prompt) {
        $t = "" + (Read-Host "  这个模型要从【私有】仓库下载，需要下载凭据（GitHub 令牌，只读权限即可）")
        $t = $t.Trim()
        if ($t -and $Save) {
            $dst = Get-ModelTokenPaths $packRoot | Select-Object -First 1
            try { Set-Content -LiteralPath $dst -Value $t -Encoding UTF8 -NoNewline; Say "        （已记住凭据：$dst）" "DarkGray" } catch {}
        }
        return $t
    }
    return ""
}

# ---------- 清单：models.json ----------
# 找清单的顺序：-ModelSource 指定的 URL/文件 → 包内 Models\models.json → 仓库在线 raw（走镜像）
function Get-ModelManifest([string]$packRoot = "", [string]$source = "", [string]$repo = "") {
    # 1) 显式指定
    if (-not [string]::IsNullOrWhiteSpace($source)) {
        try {
            if (Test-Path $source) { return (Get-Content -LiteralPath $source -Raw -Encoding UTF8 | ConvertFrom-Json) }
            $txt = Get-TextWithMirrors $source 20
            if ($txt) { return ($txt | ConvertFrom-Json) }
        } catch { Say "        [注意] 指定的模型清单读取失败：$($_.Exception.Message)" "Yellow" }
    }
    # 2) 包内 / 脚本同目录
    foreach ($p in @(
        (Join-Safe (Join-Safe $packRoot "Models") $ModelManifestName),
        (Join-Safe $packRoot $ModelManifestName),
        (Join-Safe (Join-Safe $PSScriptRoot "Models") $ModelManifestName),
        (Join-Safe $PSScriptRoot $ModelManifestName)
    )) {
        if ($p -and (Test-Path $p)) {
            try { return (Get-Content -LiteralPath $p -Raw -Encoding UTF8 | ConvertFrom-Json) } catch {}
        }
    }
    # 3) 在线（公开仓库里的清单，不需要令牌）
    $r = if ($repo) { $repo } else { $ReleasesRepo }
    if ($r) {
        foreach ($u in @("https://raw.githubusercontent.com/$r/main/Models/$ModelManifestName",
                         "https://raw.githubusercontent.com/$r/master/Models/$ModelManifestName")) {
            try {
                $txt = Get-TextWithMirrors $u 20
                if ($txt -and $txt -notmatch '^\s*404' -and $txt.Trim().StartsWith("{")) { return ($txt | ConvertFrom-Json) }
            } catch {}
        }
    }
    return $null
}

# ---------- 缓存：本机已下载的模型 ----------
# 缓存布局：<cacheDir>\<模型名>\<xxx.vrm>（+ settings.txt）
function Get-ModelCacheState([string]$cacheDir) {
    $st = @{}
    if (-not $cacheDir -or -not (Test-Path $cacheDir)) { return $st }
    foreach ($d in (Get-ChildItem -Path $cacheDir -Directory -ErrorAction SilentlyContinue)) {
        $v = Get-ChildItem -Path $d.FullName -File -Filter "*.vrm" -ErrorAction SilentlyContinue | Select-Object -First 1
        if (-not $v) { continue }
        $s = Join-Path $d.FullName "settings.txt"
        $st[$d.Name] = @{ Vrm = $v.FullName; Settings = $(if (Test-Path $s) { $s } else { $null }); Dir = $d.FullName }
    }
    return $st
}

function Get-File-Sha256OrEmpty([string]$path) {
    try { if ($path -and (Test-Path $path)) { return (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLower() } } catch {}
    return ""
}

# ---------- 候选合并 ----------
# 返回 @( PSCustomObject: Name / Local / Cached / Remote / Asset / SizeMB / Sha256 / Desc / Settings / Default )
function Get-ModelCandidates {
    param(
        [string]$packRoot = "",
        [string]$cacheDir = "",
        [string]$modelPath = "",      # -ModelPath：单个 .vrm 或目录（朋友自己拖进来的）
        [string]$manifestSource = "",
        [string]$repo = "",
        $manifest = $null
    )
    $list = New-Object System.Collections.ArrayList
    $seen = @{}
    $cache = Get-ModelCacheState $cacheDir
    if ($manifest) { $man = $manifest } else { $man = Get-ModelManifest -packRoot $packRoot -source $manifestSource -repo $repo }

    # 1) 清单里的模型（含未下载的）—— 排在最前，顺序即显示顺序
    if ($man -and $man.models) {
        foreach ($m in $man.models) {
            $name = "" + $m.name
            $seen[$name] = $true
            $cachedVrm = $null; $cachedSet = $null
            if ($cache.ContainsKey($name)) { $cachedVrm = $cache[$name].Vrm; $cachedSet = $cache[$name].Settings }
            $sizeMB = $null
            if ($m.size) { $sizeMB = [math]::Round([double]$m.size / 1MB, 1) }
            [void]$list.Add([pscustomobject]@{
                Name    = $name
                Local   = $cachedVrm
                Cached  = [bool]$cachedVrm
                Remote  = (-not $cachedVrm)
                Asset   = "" + $m.asset
                Url     = $(if ($m.PSObject.Properties.Name -contains "url") { "" + $m.url } else { "" })
                SizeMB  = $sizeMB
                Sha256  = $(if ($m.sha256) { ("" + $m.sha256).ToLower() } else { "" })
                Vrm     = $cachedVrm
                VrmFile = "" + $m.vrm
                Desc    = $(if ($m.desc) { "" + $m.desc } else { "" })
                Settings= $cachedSet
                Source  = "manifest"
            })
        }
    }
    # 2) 包内 Models\<名>\*.vrm（本地包/老包）
    foreach ($base in @((Join-Safe $packRoot "Models"), (Join-Safe $packRoot "ValheimVRM_手动安装\Models"))) {
        if (-not $base -or -not (Test-Path $base)) { continue }
        foreach ($d in (Get-ChildItem -Path $base -Directory -ErrorAction SilentlyContinue | Sort-Object Name)) {
            if ($seen.ContainsKey($d.Name)) { continue }
            $v = Get-ChildItem -Path $d.FullName -File -Filter "*.vrm" -ErrorAction SilentlyContinue | Select-Object -First 1
            if (-not $v) { continue }
            $seen[$d.Name] = $true
            $s = Join-Path $d.FullName "settings.txt"
            [void]$list.Add([pscustomobject]@{
                Name=$d.Name; Local=$v.FullName; Cached=$true; Remote=$false; Asset=""; Url=""
                SizeMB=[math]::Round($v.Length/1MB,1); Sha256=(Get-File-Sha256OrEmpty $v.FullName); Vrm=$v.FullName; VrmFile=$v.Name
                Desc="（包内自带）"; Settings=$(if (Test-Path $s) { $s } else { $null }); Source="pack"
            })
        }
    }
    # 3) -ModelPath 指定的本地文件/目录
    if (-not [string]::IsNullOrWhiteSpace($modelPath)) {
        $mp = $modelPath.Trim().Trim('"')
        $files = @()
        if (Test-Path $mp -PathType Container) { $files = @(Get-ChildItem -Path $mp -Recurse -File -Filter "*.vrm" -ErrorAction SilentlyContinue) }
        elseif (Test-Path $mp -PathType Leaf) { $files = @(Get-Item $mp) }
        foreach ($f in $files) {
            $nm = $f.BaseName
            if ($seen.ContainsKey($nm)) { continue }
            $seen[$nm] = $true
            [void]$list.Add([pscustomobject]@{
                Name=$nm; Local=$f.FullName; Cached=$true; Remote=$false; Asset=""; Url=""
                SizeMB=[math]::Round($f.Length/1MB,1); Sha256=(Get-File-Sha256OrEmpty $f.FullName); Vrm=$f.FullName; VrmFile=$f.Name
                Desc="（-ModelPath 指定的本地文件）"; Settings=$null; Source="local"
            })
        }
    }
    # 4) 缓存里有、但清单/包里没有的（手工塞进去的）
    foreach ($k in $cache.Keys) {
        if ($seen.ContainsKey($k)) { continue }
        $seen[$k] = $true
        $v = $cache[$k].Vrm
        [void]$list.Add([pscustomobject]@{
            Name=$k; Local=$v; Cached=$true; Remote=$false; Asset=""; Url=""
            SizeMB=[math]::Round((Get-Item $v).Length/1MB,1); Sha256=(Get-File-Sha256OrEmpty $v); Vrm=$v; VrmFile=(Split-Path $v -Leaf)
            Desc="（本机缓存）"; Settings=$cache[$k].Settings; Source="cache"
        })
    }
    # 显示顺序 = 清单顺序（已取消「默认模型」：清单里 default 为空就完全不重排，避免和参考图编号错位）
    $defName = ""
    if ($man -and $man.default) { $defName = "" + $man.default }
    $script:ModelDefaultName = $defName      # 展示时给这个模型打「← 默认」；为空则不打（本版已取消默认）
    if ($defName) {
        $head = @($list | Where-Object { $_.Name -eq $defName })
        if ($head.Count -gt 0) {
            $tail = @($list | Where-Object { $_.Name -ne $defName })
            $new = New-Object System.Collections.ArrayList
            foreach ($x in $head) { [void]$new.Add($x) }
            foreach ($x in $tail) { [void]$new.Add($x) }
            $list = $new
        }
    }
    # 注意：用 unary comma 返回，保证单元素时调用方拿到的仍是数组（PS 会展开管道结果）
    # 注意：用 ,@ 保证调用方拿到数组（哪怕只有 1 个元素）；调用方**不要再套一层 @()**，否则会变成"数组套数组"
    return ,@($list)
}

# ---------- 下载 ----------
# 私有仓库附件：走 GitHub API（token 鉴权）→ 拿 asset id → 用 octet-stream 下
function Test-AssetRangeOk([string]$uri, [string]$token) {
    # 先要 1 个字节看看服务器理不理 Range：回 206 = 支持分段，回 200 = 无视 Range（分段会白下 N 倍）
    try {
        $req = [System.Net.HttpWebRequest]::Create($uri)
        $req.Headers.Add("Authorization", "Bearer $token")
        $req.Accept = "application/octet-stream"
        $req.UserAgent = "makabaka-install"
        $req.Timeout = 30000
        $req.ReadWriteTimeout = 30000
        $req.AddRange(0, 0)
        $resp = $req.GetResponse()
        $code = [int]$resp.StatusCode
        $resp.Close()
        return ($code -eq 206)
    } catch { return $false }
}

# 分段下载器：每段一个 runspace（真并行，且令牌不出进程 —— 不用 Start-Job 那种子进程）
function Save-AssetSegmented {
    param(
        [string]$Api, [string]$Token, [string]$OutFile,
        [int64]$Total, [int]$Threads
    )
    $per = [int64][math]::Ceiling($Total / $Threads)
    $pool = [runspacefactory]::CreateRunspacePool(1, $Threads)
    $pool.Open()
    $jobs = @()
    for ($i = 0; $i -lt $Threads; $i++) {
        $from = [int64]($i * $per)
        $to   = [int64][math]::Min($i * $per + $per - 1, $Total - 1)
        $part = "$OutFile.part$i"
        if (Test-Path $part) { Remove-Item $part -Force -ErrorAction SilentlyContinue }
        $ps = [powershell]::Create()
        $ps.RunspacePool = $pool
        $null = $ps.AddScript($script:SegScript).AddArgument($Api).AddArgument($Token).AddArgument($from).AddArgument($to).AddArgument($part).AddArgument($script:ModelSegmentTries)
        $jobs += [pscustomobject]@{ PS = $ps; H = $ps.BeginInvoke(); Out = $part; Want = ($to - $from + 1) }
    }
    # 进度用"各段文件在磁盘上的大小"聚合 —— 不需要跨 runspace 传状态
    $t0 = Get-Date; $last = 0.0
    while (@($jobs | Where-Object { -not $_.H.IsCompleted }).Count -gt 0) {
        Start-Sleep -Milliseconds 400
        $done = 0L
        foreach ($j in $jobs) { if (Test-Path $j.Out) { try { $done += (Get-Item $j.Out).Length } catch {} } }
        $sec = ((Get-Date) - $t0).TotalSeconds
        if (($sec - $last) -ge 1) {
            $last = $sec
            $spd = if ($sec -gt 0) { [math]::Round($done / 1MB / $sec, 2) } else { 0 }
            $pct = if ($Total -gt 0) { [int](100 * $done / $Total) } else { 0 }
            Write-Host ("`r          $pct%  $([math]::Round($done/1MB,1))/$([math]::Round($Total/1MB,1)) MB  $spd MB/s（$Threads 条连接）   ") -NoNewline
        }
    }
    Write-Host ""
    $sec = ((Get-Date) - $t0).TotalSeconds
    $msgs = @()
    $got = 0L
    foreach ($j in $jobs) {
        try {
            $r = $j.PS.EndInvoke($j.H)
            if ($r) { $msgs += ("" + $r[0]) }
        } catch { $msgs += ("invoke:" + $_.Exception.Message) }
        try { $j.PS.Dispose() } catch {}
        if (Test-Path $j.Out) { try { $got += (Get-Item $j.Out).Length } catch {} }
    }
    try { $pool.Close(); $pool.Dispose() } catch {}
    $bad = @($msgs | Where-Object { $_ -notlike "ok:*" })
    if ($got -ne $Total -or $bad.Count -gt 0) {
        Say ("        [×] 分段下载没成（收到 $got / 应有 $Total" + $(if ($bad.Count) { "；$($bad[0])" } else { "" }) + "）") "DarkGray"
        foreach ($j in $jobs) { Remove-Item $j.Out -Force -ErrorAction SilentlyContinue }
        return $false
    }
    # 合并（按段顺序拼；流必须显式关闭，否则文件被占用删不掉）
    try {
        $out = [System.IO.File]::Create($OutFile)
        foreach ($j in $jobs) {
            $in = [System.IO.File]::OpenRead($j.Out)
            $in.CopyTo($out)
            $in.Close(); $in.Dispose()
        }
        $out.Close(); $out.Dispose()
    } catch {
        Say "        [×] 合并分段失败：$($_.Exception.Message)" "Yellow"
        return $false
    } finally {
        foreach ($j in $jobs) { Remove-Item $j.Out -Force -ErrorAction SilentlyContinue }
    }
    $sz = (Get-Item $OutFile).Length
    $avg = if ($sec -gt 0) { [math]::Round(($sz / 1MB) / $sec, 2) } else { 0 }
    Say ("        下载完成：$([math]::Round($sz/1MB,1)) MB，耗时 $([math]::Round($sec,1)) 秒（$Threads 条连接平均 $avg MB/s）") "Green"
    return ($sz -eq $Total)
}

# 单段下载脚本（在独立 runspace 里跑）：支持段内断点续传
$script:SegScript = {
    param($Api, $Token, $From, $To, $Out, $Tries)
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $want = $To - $From + 1
    for ($k = 1; $k -le $Tries; $k++) {
        $have = 0L
        if (Test-Path $Out) { try { $have = (Get-Item $Out).Length } catch { $have = 0 } }
        if ($have -ge $want) { return "ok:$have" }
        try {
            $req = [System.Net.HttpWebRequest]::Create($Api)
            $req.Headers.Add("Authorization", "Bearer $Token")
            $req.Accept = "application/octet-stream"
            $req.UserAgent = "makabaka-install"
            $req.Timeout = 60000
            $req.ReadWriteTimeout = 120000
            if ($have -gt 0) { $req.AddRange([int64]($From + $have), [int64]$To) }
            else { $req.AddRange([int64]$From, [int64]$To) }
            $resp = $req.GetResponse()
            $code = [int]$resp.StatusCode
            if ($code -ne 206) { throw "服务器返回 $code（不支持分段）" }
            $in = $resp.GetResponseStream()
            $mode = if ($have -gt 0) { [System.IO.FileMode]::Append } else { [System.IO.FileMode]::Create }
            $fs = [System.IO.File]::Open($Out, $mode, [System.IO.FileAccess]::Write, [System.IO.FileShare]::None)
            try {
                $buf = New-Object byte[] (256KB)
                while (($n = $in.Read($buf, 0, $buf.Length)) -gt 0) { $fs.Write($buf, 0, $n) }
            } finally {
                $fs.Close(); $fs.Dispose(); $in.Close(); $resp.Close()
            }
        } catch {
            Start-Sleep -Milliseconds (500 * $k)
        }
    }
    $have = 0L
    if (Test-Path $Out) { try { $have = (Get-Item $Out).Length } catch { $have = 0 } }
    if ($have -ge $want) { return "ok:$have" }
    return "err:$have/$want"
}

function Save-ModelFromGitHub([string]$repo, [string]$tag, [string]$assetName, [string]$outFile, [string]$token, [string]$label = "") {
    if ([string]::IsNullOrWhiteSpace($token)) { return $false }
    $api = "https://api.github.com/repos/$repo/releases/tags/$tag"
    try {
        $rel = Invoke-RestMethod -Uri $api -Headers @{ Authorization = "Bearer $token"; "User-Agent" = "makabaka-install"; Accept = "application/vnd.github+json" } -TimeoutSec 30
    } catch {
        Say "        [×] 取 Release 失败（$repo / $tag）：$($_.Exception.Message)" "Yellow"
        return $false
    }
    $asset = $null
    foreach ($a in $rel.assets) { if ($a.name -eq $assetName) { $asset = $a; break } }
    if (-not $asset) { Say "        [×] 这个 Release 里没有附件 $assetName" "Yellow"; return $false }
    $uri = "https://api.github.com/repos/$repo/releases/assets/$($asset.id)"
    $total = [double]$asset.size
    Say "        下载 $assetName（$([math]::Round($total/1MB,1)) MB，私有仓库）…" "Gray"

    # ① 优先分段并发（私有附件按连接限速，6 段约 7 倍；8 段不再变快）
    if (($script:ModelDownloadThreads -gt 1) -and ($total -ge $script:ModelSegmentMinBytes)) {
        if (Test-AssetRangeOk $uri $token) {
            if (Save-AssetSegmented -Api $uri -Token $token -OutFile $outFile -Total ([int64]$total) -Threads $script:ModelDownloadThreads) {
                return $true
            }
            Say "        分段下载没成 → 退回单连接方式（多试一次总比失败好）。" "Yellow"
        } else {
            Say "        这个附件不支持分段（服务器没回 206）→ 用单连接下载。" "DarkGray"
        }
    }

    # ② 单连接兜底（永远可用；也是老版本的行为）
    try {
        $req = [System.Net.HttpWebRequest]::Create($uri)
        $req.Headers.Add("Authorization", "Bearer $token")
        $req.Accept = "application/octet-stream"   # 受限头，必须用属性（Headers.Add 会抛异常）
        $req.UserAgent = "makabaka-install"
        $req.Timeout = 60000
        $req.ReadWriteTimeout = 600000
        $resp = $req.GetResponse()
        $in = $resp.GetResponseStream()
        $fs = [System.IO.File]::Create($outFile)
        $buf = New-Object byte[] (1MB)
        $done = 0; $t0 = Get-Date; $lastSay = 0
        while (($n = $in.Read($buf, 0, $buf.Length)) -gt 0) {
            $fs.Write($buf, 0, $n); $done += $n
            $sec = ((Get-Date) - $t0).TotalSeconds
            if ($sec - $lastSay -ge 1) {
                $lastSay = $sec
                $pct = if ($total -gt 0) { [math]::Round($done * 100.0 / $total, 1) } else { 0 }
                $spd = if ($sec -gt 0) { [math]::Round($done / 1MB / $sec, 2) } else { 0 }
                Write-Host ("`r          进度 $pct%  $([math]::Round($done/1MB,1))/$([math]::Round($total/1MB,1)) MB  $spd MB/s   ") -NoNewline
            }
        }
        $fs.Close(); $in.Close(); $resp.Close()
        Write-Host ""
        return $true
    } catch {
        Say "        [×] 下载失败：$($_.Exception.Message)" "Yellow"
        return $false
    }
}

# 把一个候选下载进缓存并校验：成功返回 @{Vrm=路径; Settings=路径}，失败返回 $null
function Save-ModelToCache {
    param(
        [Parameter(Mandatory=$true)] $Cand,
        [string]$cacheDir,
        [string]$packRoot = "",
        [string]$repo = "",
        [string]$tag = "",
        [string]$token = "",
        [switch]$NoVerify
    )
    if (-not $cacheDir) { return $null }
    $dstDir = Join-Path $cacheDir $Cand.Name
    New-Item -ItemType Directory -Path $dstDir -Force | Out-Null

    # 已在缓存里且哈希对得上 → 直接用
    $existing = Get-ChildItem -Path $dstDir -File -Filter "*.vrm" -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($existing) {
        if (-not $Cand.Sha256 -or (Get-File-Sha256OrEmpty $existing.FullName) -eq $Cand.Sha256) {
            Say "        [缓存] $($Cand.Name) 已在本机（$([math]::Round($existing.Length/1MB,1)) MB），不重新下载" "DarkGray"
            $sE = Join-Path $dstDir "settings.txt"
            return @{ Vrm = $existing.FullName; Settings = $(if (Test-Path $sE) { $sE } else { $null }) }
        }
        Say "        [缓存] $($Cand.Name) 哈希不符，重新下载…" "Yellow"
        Remove-Item $existing.FullName -Force -ErrorAction SilentlyContinue
    }

    $tmpDir = Join-Path $env:TEMP ("makabaka_model_" + (Get-Date -Format "HHmmss"))
    New-Item -ItemType Directory -Path $tmpDir -Force | Out-Null
    $zip = Join-Path $tmpDir ($Cand.Asset)
    $ok = $false

    if ($Cand.Url) {
        # 直链（网盘/自建服务器都行；走镜像）
        $ok = Save-FileWithMirrors $Cand.Url $zip ("模型 " + $Cand.Name)
    } else {
        $r = if ($repo) { $repo } else { $ModelRepoDefault }
        $t = if ($tag) { $tag } else { $ModelReleaseTag }
        $ok = Save-ModelFromGitHub -repo $r -tag $t -assetName $Cand.Asset -outFile $zip -token $token -label $Cand.Name
        if (-not $ok) {
            # 兜底：公开直链（仓库若被设为公开时可用）
            $u = "https://github.com/$r/releases/download/$t/$($Cand.Asset)"
            Say "        （改用直链试一次：$u）" "DarkGray"
            $ok = Save-FileWithMirrors $u $zip ("模型 " + $Cand.Name)
        }
    }
    if (-not $ok -or -not (Test-Path $zip)) { Say "        [×] $($Cand.Name)：下载失败（可稍后重试，或用 -ModelPath 手动给文件）" "Yellow"; return $null }

    # 解压：压缩包内可能是 <名>\<名>.vrm，也可能是根下直接一个 .vrm
    $ex = Join-Path $tmpDir "x"
    try {
        New-Item -ItemType Directory -Path $ex -Force | Out-Null
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        [System.IO.Compression.ZipFile]::ExtractToDirectory($zip, $ex)
    } catch {
        Say "        [×] 解压失败：$($_.Exception.Message)" "Yellow"; return $false
    }
    $vrm = Get-ChildItem -Path $ex -Recurse -File -Filter "*.vrm" -ErrorAction SilentlyContinue | Sort-Object Length -Descending | Select-Object -First 1
    if (-not $vrm) { Say "        [×] 压缩包里没有 .vrm：$($Cand.Asset)" "Yellow"; return $null }

    # 校验（清单里给的是 .vrm 的 sha256）
    if ((-not $NoVerify) -and $Cand.Sha256) {
        $got = Get-File-Sha256OrEmpty $vrm.FullName
        if ($got -ne $Cand.Sha256) {
            Say "        [×] 校验失败：$($Cand.Name) 下载到的文件 sha256 与清单不符" "Red"
            Say "            期望 $($Cand.Sha256)" "DarkGray"
            Say "            实际 $got" "DarkGray"
            return $null
        }
        Say "        [校验] $($Cand.Name) sha256 一致 ✓" "Green"
    }

    Copy-Item $vrm.FullName (Join-Path $dstDir $vrm.Name) -Force
    $setInZip = Get-ChildItem -Path $ex -Recurse -File -Filter "settings*.txt" -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($setInZip) { Copy-Item $setInZip.FullName (Join-Path $dstDir "settings.txt") -Force }
    else {
        $def = Join-Path (Join-Path $packRoot "Models") "默认settings.txt"
        if (Test-Path $def) { Copy-Item $def (Join-Path $dstDir "settings.txt") -Force }
    }
    Remove-Item $tmpDir -Recurse -Force -ErrorAction SilentlyContinue
    Say "        [完成] $($Cand.Name) → $dstDir" "Green"
    $dstVrm = Join-Path $dstDir $vrm.Name
    $dstSet = Join-Path $dstDir "settings.txt"
    return @{ Vrm = $dstVrm; Settings = $(if (Test-Path $dstSet) { $dstSet } else { $null }) }
}

# ---------- 列表展示 ----------
function Show-ModelCandidates($list, [string]$cacheDir = "") {
    Say ""
    Say "        可选模型（★=本机已缓存，可直接用；↓=需要下载）："
    for ($i = 0; $i -lt $list.Count; $i++) {
        $m = $list[$i]
        $mark = if ($m.Cached) { "★" } else { "↓" }
        $size = if ($m.SizeMB) { "$($m.SizeMB) MB" } else { "大小未知" }
        $tail = if ($m.Cached) { "（已缓存）" } else { "（需下载 $size）" }
        $def = if ($script:ModelDefaultName -and $m.Name -eq $script:ModelDefaultName) { "   ← 默认" } else { "" }
        Say ("          {0}) {1} {2} {3}{4}" -f ($i + 1), $mark, $m.Name, $tail, $def)
        if ($m.Desc) { Say ("              " + $m.Desc) "DarkGray" }
    }
    if ($cacheDir) { Say "        缓存目录：$cacheDir" "DarkGray" }
}


# ---------- 打开参考图（挑模型时看）----------
function Show-ModelPreview {
    param(
        [string]$PackRoot = "",
        [int]$Index = 0,
        [switch]$NoOpen
    )
    $dir = Join-Safe $PackRoot "Models\预览"
    $target = $null
    if (Test-Path $dir) {
        if ($Index -gt 0) {
            foreach ($pat in @(("{0:D2}_*.jpg" -f $Index), ("{0}_*.jpg" -f $Index), ("{0:D2}_*" -f $Index))) {
                $hit = Get-ChildItem -LiteralPath $dir -Filter $pat -File -ErrorAction SilentlyContinue | Select-Object -First 1
                if ($hit) { $target = $hit; break }
            }
        } else {
            $target = Get-ChildItem -LiteralPath $dir -Filter "_总览*.jpg" -File -ErrorAction SilentlyContinue | Select-Object -First 1
            if (-not $target) {
                $target = Get-ChildItem -LiteralPath $dir -Filter "*.jpg" -File -ErrorAction SilentlyContinue | Sort-Object Name | Select-Object -First 1
            }
        }
    }
    if ($NoOpen) { if ($target) { return $target.FullName } else { return $null } }
    if (-not (Test-Path $dir)) { return $false }
    try {
        if ($target) { Start-Process -FilePath $target.FullName | Out-Null; return $true }
        Start-Process -FilePath "explorer.exe" -ArgumentList ('"' + $dir + '"') | Out-Null
        return $false
    } catch {
        return $false
    }
}

# ---------- 配置文件：只改某一项的值（保留注释/行尾/BOM）----------
# 用途：像 ChestFlow 的 AllowConcurrentChestUse 这种不带 [Synced with Server] 的开关，
#       升级模式会保留玩家自己的 config，必须在安装后强制校正，才能保证人人一致。
function Set-IniValue([string]$path, [string]$section, [string]$key, [string]$value) {
    try {
        $bytes = [System.IO.File]::ReadAllBytes($path)
        $hasBom = ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF)
        $raw = [System.IO.File]::ReadAllText($path, [System.Text.Encoding]::UTF8)
        $nl = if ($raw -match "`r`n") { "`r`n" } else { "`n" }
        $lines = New-Object System.Collections.Generic.List[string]
        foreach ($l in ($raw -split "`r?`n")) { [void]$lines.Add($l) }
        $secIdx = -1; $keyIdx = -1
        for ($i = 0; $i -lt $lines.Count; $i++) {
            $tl = $lines[$i].Trim()
            if ($tl -eq "[$section]") { $secIdx = $i; continue }
            if ($secIdx -ge 0) {
                if ($tl -match ("^\s*" + [regex]::Escape($key) + "\s*=")) { $keyIdx = $i; break }
                if ($tl.StartsWith("[") -and $tl.EndsWith("]")) { break }
            }
        }
        $line = "$key = $value"
        if ($keyIdx -ge 0) {
            if ($lines[$keyIdx].Trim() -eq $line) { return $false }
            $lines[$keyIdx] = $line
        } elseif ($secIdx -ge 0) {
            $lines.Insert($secIdx + 1, $line)
        } else {
            if ($lines.Count -gt 0 -and $lines[$lines.Count - 1].Trim() -ne "") { [void]$lines.Add("") }
            [void]$lines.Add("[$section]")
            [void]$lines.Add($line)
        }
        $enc = New-Object System.Text.UTF8Encoding($hasBom)
        [System.IO.File]::WriteAllText($path, ($lines -join $nl), $enc)
        return $true
    } catch { return $false }
}
