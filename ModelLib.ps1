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
