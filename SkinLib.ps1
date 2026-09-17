# ============================================================
#  SkinLib.ps1 —— 一键安装的「武器/物品外观替换」模块
#  目标：把某个原版物品的模型换成模型库里的模型（或选择不替换）
#  依赖：包内 Models\武器替换\<模型名>\（*.obj + textures\*.png + 可选 模型.json）
#       包内 profile 里的 BepInEx\plugins\ItemSkin\ItemSkin.dll（插件本体）
# ============================================================

function Get-SkinLibDir {
    param([string]$PackRoot)
    $a = Join-Path $PackRoot "Models\武器替换"
    if (Test-Path -LiteralPath $a) { return $a }
    # 兼容：脚本同目录直接放 武器替换 文件夹
    $b = Join-Path (Split-Path $PackRoot -Parent) "武器替换"
    if (Test-Path -LiteralPath $b) { return $b }
    return $null
}

# 读下载清单（models.json：模型实体不进公开包，从这里按需取自私有仓库）
function Get-SkinManifest {
    param([string]$LibDir)
    if ([string]::IsNullOrEmpty($LibDir)) { return $null }
    $f = Join-Path $LibDir "models.json"
    if (-not (Test-Path -LiteralPath $f)) { return $null }
    try { return (Get-Content -LiteralPath $f -Raw -Encoding UTF8 | ConvertFrom-Json) } catch { return $null }
}

# 扫描模型库 → 每个模型一个对象；本地模型 Remote=$false，仅清单有实体的 Remote=$true（安装时下载）
function Get-SkinModels {
    param([string]$LibDir)
    $out = @()
    if ([string]::IsNullOrEmpty($LibDir) -or -not (Test-Path -LiteralPath $LibDir)) { return $out }
    foreach ($d in (Get-ChildItem -LiteralPath $LibDir -Directory -ErrorAction SilentlyContinue | Sort-Object Name)) {
        $objs = @(Get-ChildItem -LiteralPath $d.FullName -Filter "*.obj" -File -ErrorAction SilentlyContinue)
        if ($objs.Count -eq 0) { continue }
        $man = $null
        $mp = Join-Path $d.FullName "模型.json"
        if (Test-Path -LiteralPath $mp) {
            try { $man = (Get-Content -LiteralPath $mp -Raw -Encoding UTF8 | ConvertFrom-Json) } catch { $man = $null }
        }
        $disp = $d.Name
        if ($man -and $man.displayName) { $disp = [string]$man.displayName }
        $sug = ""
        if ($man -and $man.targetPrefab) { $sug = [string]$man.targetPrefab }
        $out += [pscustomobject]@{
            Name     = $d.Name
            Display  = $disp
            Dir      = $d.FullName
            Obj      = $objs[0].Name
            Suggest  = $sug
            Manifest = $man
            Remote   = $false
            Asset    = ""
            Sha      = ""
            ZipSize  = 0
            Desc     = ""
        }
    }
    $lm = Get-SkinManifest -LibDir $LibDir
    if ($lm -and $lm.models) {
        foreach ($m in $lm.models) {
            $have = @($out | Where-Object { $_.Name -eq [string]$m.dir })
            if ($have.Count -gt 0) { continue }
            $dn = [string]$m.dir
            if ($m.name) { $dn = [string]$m.name }
            $dt = ""
            if ($m.defTarget) { $dt = [string]$m.defTarget }
            $ds = ""
            if ($m.desc) { $ds = [string]$m.desc }
            $out += [pscustomobject]@{
                Name = [string]$m.dir; Display = $dn; Dir = $null; Obj = $null; Suggest = $dt
                Manifest = $null; Remote = $true; Asset = [string]$m.asset; Sha = [string]$m.sha256
                ZipSize = [int]$m.zipSize; Desc = $ds
            }
        }
    }
    return $out
}

# 读目标清单（<prefab> = <显示名>，可自行增删；# 开头是注释）
function Get-SkinTargets {
    param([string]$LibDir)
    $list = @()
    if ([string]::IsNullOrEmpty($LibDir)) { return $list }
    $f = Join-Path $LibDir "目标清单.txt"
    if (-not (Test-Path -LiteralPath $f)) { return $list }
    foreach ($l in (Get-Content -LiteralPath $f -Encoding UTF8)) {
        $s = "$l".Trim()
        if ($s.Length -eq 0 -or $s.StartsWith("#")) { continue }
        $i = $s.IndexOf("=")
        if ($i -lt 1) { continue }
        $list += [pscustomobject]@{ Prefab = $s.Substring(0, $i).Trim(); Label = $s.Substring($i + 1).Trim() }
    }
    return $list
}

# 写插件配置：只写我们管的那几项，其余交给插件首次运行自动补全（BepInEx 会保留已有值）
function Write-SkinConfig {
    param(
        [string]$ProfileDir,
        [bool]$EnabledState,
        [string]$Prefab,
        [string]$ModelName,
        [string]$GlowTint = ""
    )
    $cfgDir = Join-Path $ProfileDir "BepInEx\config"
    if (-not (Test-Path -LiteralPath $cfgDir)) { New-Item -ItemType Directory -Path $cfgDir -Force | Out-Null }
    $cfg = Join-Path $cfgDir "local.itemskin.cfg"
    $nl = "`r`n"
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.Append("## Settings file was created by plugin Item Skin Replacer v1.0.0$nl")
    [void]$sb.Append("## Plugin GUID: local.itemskin$nl")
    [void]$sb.Append("## 由一键安装写入；游戏里按 F1 也能改。$nl$nl")
    [void]$sb.Append("[General]$nl$nl")
    [void]$sb.Append("## 是否启用外观替换（选择「不替换」时这里是 false）$nl")
    [void]$sb.Append("Enabled = " + $(if ($EnabledState) { "true" } else { "false" }) + "$nl$nl")
    [void]$sb.Append("## 要替换的原版物品 prefab 名$nl")
    [void]$sb.Append("TargetPrefab = " + $Prefab + "$nl$nl")
    [void]$sb.Append("## 模型目录名：插件目录下 Models\<这个名字>\$nl")
    [void]$sb.Append("Model = " + $ModelName + "$nl$nl")
    [void]$sb.Append("## 隐藏原版物品上额外的渲染器$nl")
    [void]$sb.Append("HideExtraRenderers = true$nl$nl")
    [void]$sb.Append("## 详细调试日志$nl")
    [void]$sb.Append("Verbose = false$nl$nl")
    [void]$sb.Append("[Glow]$nl$nl")
    [void]$sb.Append("## 原版发光颜色改成这个（空 = 不改）$nl")
    [void]$sb.Append("GlowColorHex = " + $GlowTint + "$nl$nl")
    [System.IO.File]::WriteAllText($cfg, $sb.ToString(), (New-Object System.Text.UTF8Encoding($true)))
    return $cfg
}

# 统一的日志出口：$Log 可以是脚本块（install.ps1 传入）也可以是空
function Write-SkinLine {
    param($Log, [string]$Text)
    if ($Log) { try { & $Log $Text } catch { Write-Host $Text } } else { Write-Host $Text }
}

# 执行安装：把模型复制进档 + 写配置。Prefab 为空 = 不替换（只把插件置为不启用）
function Install-Skin {
    param(
        [string]$ProfileDir,
        [string]$LibDir,
        [string]$Prefab,
        [string]$ModelName,
        [string]$PackProfileDir,   # 包内 profile（提供 ItemSkin 插件本体）
        [string]$PackRoot = "",     # 包根（找 models.json）
        [string]$Token = "",        # 私有模型仓库凭据
        [scriptblock]$Log = $null
    )
    $pluginDir = Join-Path $ProfileDir "BepInEx\plugins\ItemSkin"
    if (-not (Test-Path -LiteralPath $pluginDir)) { New-Item -ItemType Directory -Path $pluginDir -Force | Out-Null }

    # 插件本体：包内 profile 有就用包里的（升级会覆盖），没有就沿用档里已有的
    $srcPlugin = Join-Path $PackProfileDir "BepInEx\plugins\ItemSkin\ItemSkin.dll"
    $dstPlugin = Join-Path $pluginDir "ItemSkin.dll"
    if (Test-Path -LiteralPath $srcPlugin) { Copy-Item -LiteralPath $srcPlugin -Destination $dstPlugin -Force }

    if ([string]::IsNullOrEmpty($Prefab) -or [string]::IsNullOrEmpty($ModelName)) {
        $cfg = Write-SkinConfig -ProfileDir $ProfileDir -EnabledState $false -Prefab "BowDraugrFang" -ModelName "default"
        Write-SkinLine -Log $Log -Text "        [外观] 已选择不替换（插件保留但 Enabled=false）"
        return [pscustomobject]@{ Ok = $true; Skipped = $true; Cfg = $cfg; ModelDir = $null }
    }

    # 模型实体：本地有就直接用；本地没有但清单登记了 → 从私有仓库按需下载（校验 sha256）
    $srcDir = Join-Path $LibDir $ModelName
    $tmpExpand = ""
    $info = $null
    foreach ($mm in (Get-SkinModels -LibDir $LibDir)) { if ($mm.Name -eq $ModelName) { $info = $mm } }
    if (-not (Test-Path -LiteralPath $srcDir)) {
        if (-not $info -or [string]::IsNullOrEmpty($info.Asset)) {
            Write-SkinLine -Log $Log -Text "        [×] 模型库里的「$ModelName」不存在 → 跳过"
            return [pscustomobject]@{ Ok = $false; Skipped = $true; Cfg = $null; ModelDir = $null }
        }
        $lm = Get-SkinManifest -LibDir $LibDir
        $tk = $Token
        if ([string]::IsNullOrEmpty($tk) -and (Get-Command Get-ModelToken -ErrorAction SilentlyContinue)) {
            $tk = Get-ModelToken -given "" -packRoot $PackRoot
        }
        if ([string]::IsNullOrEmpty($tk)) {
            Write-SkinLine -Log $Log -Text "        [×] 模型「$ModelName」要从私有仓库下载，但没找到模型凭据 → 跳过（放 模型凭据.txt 或加 -ModelToken）"
            return [pscustomobject]@{ Ok = $false; Skipped = $true; Cfg = $null; ModelDir = $null }
        }
        $zip = Join-Path $env:TEMP ("makabaka-skin-" + [Guid]::NewGuid().ToString("N").Substring(0, 8) + ".zip")
        Write-SkinLine -Log $Log -Text "        [外观] 从私有仓库下载模型「$ModelName」…"
        $okDl = Save-ModelFromGitHub -repo $lm.repo -tag $lm.tag -assetName $info.Asset -outFile $zip -token $tk -label ("外观模型 " + $ModelName)
        if (-not $okDl) {
            Write-SkinLine -Log $Log -Text "        [×] 模型「$ModelName」下载失败 → 跳过"
            return [pscustomobject]@{ Ok = $false; Skipped = $true; Cfg = $null; ModelDir = $null }
        }
        if (-not [string]::IsNullOrEmpty($info.Sha)) {
            $h = Get-File-Sha256OrEmpty $zip
            if ($h -ne ([string]$info.Sha).ToLower()) {
                Remove-Item -LiteralPath $zip -Force -ErrorAction SilentlyContinue
                Write-SkinLine -Log $Log -Text "        [×] 模型「$ModelName」sha256 校验失败（下载不完整）→ 跳过"
                return [pscustomobject]@{ Ok = $false; Skipped = $true; Cfg = $null; ModelDir = $null }
            }
        }
        $tmpExpand = Join-Path $env:TEMP ("makabaka-skin-" + [Guid]::NewGuid().ToString("N").Substring(0, 8))
        New-Item -ItemType Directory -Path $tmpExpand -Force | Out-Null
        try { Expand-Archive -LiteralPath $zip -DestinationPath $tmpExpand -Force -ErrorAction Stop }
        catch {
            Remove-Item -LiteralPath $zip -Force -ErrorAction SilentlyContinue
            Write-SkinLine -Log $Log -Text "        [×] 模型「$ModelName」解压失败 → 跳过"
            return [pscustomobject]@{ Ok = $false; Skipped = $true; Cfg = $null; ModelDir = $null }
        }
        Remove-Item -LiteralPath $zip -Force -ErrorAction SilentlyContinue
        $srcDir = $tmpExpand
    }
    $dstModel = Join-Path (Join-Path $pluginDir "Models") $ModelName
    if (-not (Test-Path -LiteralPath $dstModel)) { New-Item -ItemType Directory -Path $dstModel -Force | Out-Null }
    Copy-Item -Path (Join-Path $srcDir "*") -Destination $dstModel -Recurse -Force
    if (-not [string]::IsNullOrEmpty($tmpExpand)) { Remove-Item -LiteralPath $tmpExpand -Recurse -Force -ErrorAction SilentlyContinue }

    $glow = ""
    $mp = Join-Path $dstModel "模型.json"
    if (Test-Path -LiteralPath $mp) {
        try { $m = Get-Content -LiteralPath $mp -Raw -Encoding UTF8 | ConvertFrom-Json; if ($m.glowTintHex) { $glow = [string]$m.glowTintHex } } catch { }
    }
    $cfg = Write-SkinConfig -ProfileDir $ProfileDir -EnabledState $true -Prefab $Prefab -ModelName $ModelName -GlowTint $glow
    Write-SkinLine -Log $Log -Text "        [外观] $Prefab  ←  $ModelName（模型已复制到档内，配置已写入）"
    return [pscustomobject]@{ Ok = $true; Skipped = $false; Cfg = $cfg; ModelDir = $dstModel }
}

# 交互式选择：目标物品 → 模型（0 = 不替换）。返回 @{Prefab=..;Model=..}（都为空 = 不替换）
function Select-SkinInteractive {
    param([string]$LibDir, [string]$ReadHost = "Read-Host")
    $targets = Get-SkinTargets -LibDir $LibDir
    $models  = Get-SkinModels -LibDir $LibDir
    $res = [pscustomobject]@{ Prefab = ""; Model = ""; Display = "" }

    if ($models.Count -eq 0) {
        Write-Host "  [外观] 模型库里没有任何模型（Models\武器替换\）→ 跳过这一步" -ForegroundColor Yellow
        return $res
    }

    Write-Host ""
    Write-Host "  ── 武器/物品外观替换（纯外观，不改数值；别人没装看到的还是原版）──" -ForegroundColor Cyan
    Write-Host "     想换哪件东西？" 
    $n = 0
    foreach ($t in $targets) { $n++; Write-Host ("       {0,2}) {1}  [{2}]" -f $n, $t.Label, $t.Prefab) }
    Write-Host ("        0) 不替换（保持原版外观）")
    Write-Host "     输入编号，或直接输入 prefab 名（如 BowHuntsman）；回车 = 不替换" -ForegroundColor DarkGray
    $sel = & $ReadHost "    目标"
    if ([string]::IsNullOrWhiteSpace($sel)) { return $res }
    $sel = $sel.Trim()
    $idx = 0
    if ([int]::TryParse($sel, [ref]$idx)) {
        if ($idx -le 0 -or $idx -gt $n) { Write-Host "    已选择不替换" -ForegroundColor DarkGray; return $res }
        $res.Prefab = $targets[$idx - 1].Prefab
        $label = $targets[$idx - 1].Label
    } else {
        $res.Prefab = $sel
        $label = $sel
    }

    Write-Host ""
    Write-Host "     要给「$label」用哪个模型？"
    $n2 = 0
    foreach ($m in $models) {
        $n2++
        $hint = ""
        if ($m.Suggest -and $m.Suggest -ne $res.Prefab) { $hint = "（清单建议用于 $($m.Suggest)）" }
        if ($m.Remote) {
            $mb = [math]::Round($m.ZipSize / 1MB, 1)
            $hint = "（需凭据从私有仓库下载 ~$mb MB）" + $hint
        }
        Write-Host ("       {0,2}) {1}  {2}" -f $n2, $m.Display, $hint)
    }
    Write-Host ("        0) 不替换（保持原版外观）")
    Write-Host "     输入编号；回车 = 不替换" -ForegroundColor DarkGray
    $sel2 = & $ReadHost "    模型"
    if ([string]::IsNullOrWhiteSpace($sel2)) { $res.Prefab = ""; return $res }
    $idx2 = 0
    if (-not [int]::TryParse($sel2.Trim(), [ref]$idx2) -or $idx2 -le 0 -or $idx2 -gt $n2) {
        Write-Host "    编号无效 → 按不替换处理" -ForegroundColor Yellow
        $res.Prefab = ""
        return $res
    }
    $res.Model = $models[$idx2 - 1].Name
    $res.Display = $models[$idx2 - 1].Display
    return $res
}
