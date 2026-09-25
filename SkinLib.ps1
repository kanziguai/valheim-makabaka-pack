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
            Type     = ""
            Preview  = ""
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
                ZipSize = [int]$m.zipSize; Desc = $ds; Type = [string]$m.type; Preview = [string]$m.preview
            }
        }
    }
    # 清单里的 type/preview 补到对应条目；没有 type 就用建议目标猜
    $lm2 = Get-SkinManifest -LibDir $LibDir
    if ($lm2 -and $lm2.models) {
        foreach ($mm in $lm2.models) {
            foreach ($e in $out) {
                if ($e.Name -ne [string]$mm.dir) { continue }
                if ($mm.type)    { $e.Type = [string]$mm.type }
                if ($mm.preview) { $e.Preview = [string]$mm.preview }
            }
        }
    }
    foreach ($e in $out) {
        if ([string]::IsNullOrEmpty($e.Type) -and $e.Suggest) { $e.Type = Get-SkinKindFromPrefab $e.Suggest }
    }
    return $out
}

# 按 prefab 名猜武器类型（清单里写了 | 类型 就以清单为准）
function Get-SkinKindFromPrefab {
    param([string]$Prefab)
    if ([string]::IsNullOrEmpty($Prefab)) { return "" }
    if ($Prefab -match '^Battleaxe') { return "战斧" }
    if ($Prefab -match '^Bow')       { return "弓" }
    if ($Prefab -match '^Crossbow')  { return "弩" }
    if ($Prefab -match '^THSword')   { return "双手剑" }
    if ($Prefab -match '^Sword')     { return "剑" }
    if ($Prefab -match '^Knife')     { return "刀" }
    if ($Prefab -match '^Axe')       { return "斧" }
    if ($Prefab -match '^Mace|^Club'){ return "锤" }
    if ($Prefab -match '^Atgeir')    { return "戟" }
    if ($Prefab -match '^Spear')     { return "矛" }
    if ($Prefab -match '^Sledge')    { return "大锤" }
    if ($Prefab -match '^Shield')    { return "盾" }
    if ($Prefab -match '^Pickaxe')   { return "镐" }
    if ($Prefab -match '^Staff')     { return "法杖" }
    if ($Prefab -match '^Fist')      { return "拳套" }
    if ($Prefab -match '^(Hammer|Hoe|Cultivator|Scythe|FishingRod|Tankard|Feaster|Torch|GrapplingHook)') { return "工具" }
    return ""
}

# 读目标清单（<prefab> = <显示名> [| <类型>]，可自行增删；# 开头是注释）
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
        $pf = $s.Substring(0, $i).Trim()
        $lbl = $s.Substring($i + 1).Trim()
        $kind = ""
        $bar = $lbl.IndexOf("|")
        if ($bar -ge 0) { $kind = $lbl.Substring($bar + 1).Trim(); $lbl = $lbl.Substring(0, $bar).Trim() }
        if ([string]::IsNullOrEmpty($kind)) { $kind = Get-SkinKindFromPrefab $pf }
        $list += [pscustomobject]@{ Prefab = $pf; Label = $lbl; Kind = $kind }
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

# 打开模型预览图（<库>\预览\<模型名>.jpg，或 <库>\<模型名>\预览.jpg）；没有图就打开文件夹
function Show-SkinPreview {
    param([string]$LibDir, [string]$ModelName = "")
    $pv = Join-Path $LibDir "预览"
    if ([string]::IsNullOrEmpty($ModelName)) {
        if (Test-Path -LiteralPath $pv) { Start-Process -FilePath "explorer.exe" -ArgumentList ('"' + $pv + '"') | Out-Null; return $true }
        return $false
    }
    foreach ($cand in @((Join-Path $pv ($ModelName + ".jpg")), (Join-Path $pv ($ModelName + ".jpeg")),
                        (Join-Path (Join-Path $LibDir $ModelName) "预览.jpg"))) {
        if (Test-Path -LiteralPath $cand) {
            try { Start-Process -FilePath $cand | Out-Null; return $true } catch { return $false }
        }
    }
    foreach ($d in @((Join-Path $LibDir $ModelName), $pv)) {
        if (Test-Path -LiteralPath $d) { Start-Process -FilePath "explorer.exe" -ArgumentList ('"' + $d + '"') | Out-Null; break }
    }
    return $false
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
    param([string]$LibDir, $ReadHost = "Read-Host")   # 可以是 Read-Host 名字，也可以是脚本块（测试/自动化）
    $targets = @(Get-SkinTargets -LibDir $LibDir)
    $models  = @(Get-SkinModels -LibDir $LibDir)
    $res = [pscustomobject]@{ Prefab = ""; Model = ""; Display = "" }

    if ($models.Count -eq 0) {
        Write-Host "  [外观] 模型库里没有任何模型（Models\\武器替换\\）→ 跳过这一步" -ForegroundColor Yellow
        return $res
    }

    Write-Host ""
    Write-Host "  ── 武器/物品外观替换（纯外观，不改数值；别人没装看到的还是原版）──" -ForegroundColor Cyan
    Write-Host "     第 1 步：用哪个模型？（标注了它是什么类型的武器）"
    $n = 0
    foreach ($m in $models) {
        $n++
        $line = "       {0,2}) {1}" -f $n, $m.Display
        if ($m.Type)    { $line += "   · " + $m.Type }
        if ($m.Preview) { $line += "     [预览：" + $m.Preview + " → 按 p$n 打开]" }
        if ($m.Remote)  { $line += "     （需凭据从私有仓库下载 ~" + [math]::Round($m.ZipSize / 1MB, 1) + " MB）" }
        Write-Host $line
        if ($m.Desc) { Write-Host ("           " + $m.Desc) -ForegroundColor DarkGray }
    }
    Write-Host "        0) 不替换（保持原版外观）"
    Write-Host "     输入编号选模型；p1/p2… 打开对应预览；f 打开预览文件夹；回车 = 不替换" -ForegroundColor DarkGray

    $chosen = $null
    while ($true) {
        $sel = & $ReadHost "    模型"
        if ([string]::IsNullOrWhiteSpace($sel)) { return $res }
        $s = $sel.Trim()
        if ($s -eq "f" -or $s -eq "F") { Show-SkinPreview -LibDir $LibDir -ModelName "" | Out-Null; continue }
        if ($s.Length -ge 2 -and ($s.Substring(0,1) -eq "p" -or $s.Substring(0,1) -eq "P")) {
            $k = 0
            if ([int]::TryParse($s.Substring(1).Trim(), [ref]$k) -and $k -ge 1 -and $k -le $n) {
                Show-SkinPreview -LibDir $LibDir -ModelName $models[$k - 1].Name | Out-Null
            } else {
                Write-Host "    用法：p1 / p2 …（编号见上）；f 打开预览文件夹" -ForegroundColor Yellow
            }
            continue
        }
        $idx = 0
        if ([int]::TryParse($s, [ref]$idx) -and $idx -ge 1 -and $idx -le $n) {
            $chosen = $models[$idx - 1]
            break
        }
        Write-Host "    已选择不替换" -ForegroundColor DarkGray
        return $res
    }

    $res.Model = $chosen.Name
    $res.Display = $chosen.Display

    # 第 2 步：要替换的物品（同类型排最前、标建议）
    $kind = $chosen.Type
    # 弓/弩算一家：选了弓类模型，弩也排在前面（反之亦然）
    $fam = @($kind)
    if ($kind -eq "弓") { $fam += "弩" } elseif ($kind -eq "弩") { $fam += "弓" }
    $same = @()
    $other = @()
    foreach ($tg in $targets) {
        if ($kind -and ($fam -contains $tg.Kind)) { $same += $tg } else { $other += $tg }
    }
    $ord = @($same + $other)
    Write-Host ""
    $hint = ""
    if ($kind) { $hint = "（模型是「$kind」类，同类物品排在最前并标 ★建议）" }
    Write-Host "     第 2 步：把「$($chosen.Display)」的外观换到哪件物品上？$hint"
    $k2 = 0
    foreach ($tg in $ord) {
        $k2++
        $mark = ""
        if ($kind -and ($fam -contains $tg.Kind)) { $mark = "   ★建议" }
        elseif ($chosen.Suggest -and $chosen.Suggest -eq $tg.Prefab) { $mark = "   ★模型声明用于此" }
        Write-Host ("       {0,2}) {1}  [{2}]{3}" -f $k2, $tg.Label, $tg.Prefab, $mark)
    }
    Write-Host "        0) 不替换（保持原版外观）"
    Write-Host "     输入编号，或直接输入 prefab 名（如 BowHuntsman）；回车 = 不替换" -ForegroundColor DarkGray
    $sel2 = & $ReadHost "    目标"
    if ([string]::IsNullOrWhiteSpace($sel2)) { $res.Model = ""; $res.Prefab = ""; $res.Display = ""; return $res }
    $s2 = $sel2.Trim()
    $i2 = 0
    if ([int]::TryParse($s2, [ref]$i2)) {
        if ($i2 -lt 1 -or $i2 -gt $k2) {
            Write-Host "    已选择不替换" -ForegroundColor DarkGray
            $res.Model = ""; $res.Prefab = ""; $res.Display = ""
            return $res
        }
        $res.Prefab = $ord[$i2 - 1].Prefab
    } else {
        $res.Prefab = $s2
    }
    return $res
}
