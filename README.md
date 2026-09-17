# 英灵神殿 MAKABAKA 整合档 · 一键安装

Valheim 1.0 联机整合档（r2modman profile）：**Thunderstore 42 个包（37 启用 / 5 禁用）**
＋ 自制插件 3 个（SafeBox 0.5.4、KeepBuffsOnDeath 1.0.1、VRMGhostFix）
＋ ChestFlow 及界面汉化 ＋ Azumatt-Hooked 1.1.1（已调平衡）＋ Achievement_Enabler_Plus 2.0.3。

**当前版本：v1.4（2026-09-17）** · 安装包约 60 MB（不含模型；模型按需下载）· 见 [Releases](../../releases)

> 仓库里只放脚本 + 文档（几百 KB）；安装包 zip 走 Release 附件，不进 git 历史。

**要发给朋友？直接发 [`安装步骤.txt`](安装步骤.txt) 就行** —— 从零到进游戏的完整步骤（含三种装法：
一行命令 / git clone + 双击 / 手动下 Release 附件），照做即可。

---

## 0. 前提（没这两样装不了）

1. **正版 Valheim 1.0**（Steam）
2. **[r2modman](https://thunderstore.io/c/valheim/p/ebkr/r2modman/)** 已安装，**并启动过一次、选好 Valheim 安装位置**
   （它得先建好 profiles 目录，安装脚本才能把档放进去）
3. Windows 10/11，预留约 1 GB（安装包 138 MB + 临时解压 + 档本体 + 角色模型；`%TEMP%` 里的临时文件装完会自动清）

---

## 1. 三种装法（挑一个就行）

### A. 一行命令（不用装 git，最省事）

PowerShell 窗口里把下面这几行整段粘进去、回车（镜像优先，失败自动改直连）：

```powershell
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$u = 'https://raw.githubusercontent.com/kanziguai/valheim-makabaka-pack/main/install.ps1'
$s = "$env:TEMP\makabaka-install.ps1"
$ms = @('https://ghfast.top/','https://ghproxy.net/','https://gh-proxy.com/','')
$ok = $false
foreach ($m in $ms) { $t = if ($m) { $m + $u } else { $u }; Write-Host "试：$t" -ForegroundColor DarkGray; try { Invoke-WebRequest -Uri $t -OutFile $s -TimeoutSec 15 -UseBasicParsing -ErrorAction Stop; if ((Get-Item $s).Length -gt 20000) { $ok = $true; break } } catch { Write-Host ("  这条不通：" + $_.Exception.Message.Split([char]10)[0]) -ForegroundColor DarkYellow } }
if ($ok) { powershell -NoProfile -ExecutionPolicy Bypass -File $s } else { Write-Host '四条线路都没连上 → 检查杀软/代理，或改用 C（手动下载 zip）' -ForegroundColor Yellow }
```

这段有意做成永不静默卡住：先开 TLS 1.2，再对 4 条线路（ghfast / ghproxy / gh-proxy / 直连）
逐条尝试，每条最多等 15 秒；连不上就明确打印「这条不通：原因」并换下一条。

- 之前那版用 `Net.WebClient` 同步下载：**它没有超时**，连接被网络或杀软黑洞掉时既不报错也不返回，
  表现就是卡在第 4 行一直等（它同时也没先开 TLS 1.2，部分 Windows 上会卡在握手）。
- 这里改用 `Invoke-WebRequest` + `-UseBasicParsing`：老版 PowerShell 的 `iwr` 默认走 IE 引擎解析页面，
  那才是有时卡十几分钟的原因；补上 `-UseBasicParsing` 和 `-TimeoutSec` 之后不会卡。
- 卡住了就 Ctrl+C，改用 B 或 C 两种装法。

> 在跑着 Clash / 机场加速器的机器上，脚本下载会先走系统代理、失败会自动绕开代理直连；
> 首装要下 138MB，几分钟属正常，别中途关窗口；**下载时会实时显示百分比、当前速度、剩余时间**。
> 镜像（ghfast / ghproxy）对 raw 文件有几分钟缓存：脚本刚更新完的头几分钟，
> 从镜像拿到的可能还是旧副本 —— 脚本开头会打印「脚本日期」，对不上就等几分钟或改用直连。

### B. git 一段命令（推荐，以后更新最方便）

先装 [git](https://git-scm.com/download/win)（一路默认「下一步」即可）。然后打开 PowerShell，
把下面这段**整段粘进去回车**：会自动 clone（目录已存在就 `git pull` 更新），**直接接着开始安装**
—— 不用手动 `cd`，也不用去双击 bat：

```powershell
$d = "$env:USERPROFILE\valheim-makabaka-pack"
if (-not (Test-Path "$d\.git") -and (Test-Path $d)) { $d = "$d-git" }
if (Test-Path "$d\.git") { git -C $d pull } else { git clone https://github.com/kanziguai/valheim-makabaka-pack.git $d }
& "$d\一键安装.bat"
```

> ⚠️ **别把 `if / elseif / else` 写成三行分开粘**：PowerShell 控制台是**逐行**执行的，
> `if (...) { ... }` 那一行本身就是完整语句，下一行的 `elseif` 会被当成新命令，报
> `无法将"elseif"项识别为 cmdlet…`。上面这段每一行都是完整语句，**逐行粘或整段粘都安全**。

也可以压成一行（`;` 分隔，效果一样）：

```powershell
$d="$env:USERPROFILE\valheim-makabaka-pack"; if (Test-Path "$d\.git") { git -C $d pull } else { git clone https://github.com/kanziguai/valheim-makabaka-pack.git $d }; & "$d\一键安装.bat"
```

代码放在 `C:\Users\<你的用户名>\valheim-makabaka-pack\`。**以后更新就是把同一段再粘一次**。
仓库里没有安装包 —— 脚本会自己从 Release 下最新版（镜像优先、失败自动换线路，下完核对 MD5 才解压；
**下载时会实时显示百分比、当前速度、剩余时间**）。
想手动来也行：`git clone` → 进目录 → 双击 `一键安装.bat`。

### C. 完全手动（不用 git、不用命令行）

到 **[Releases](../../releases)** 下载 `MAKABAKA_profile_vX.Y_YYYYMMDD.zip` → 解压 → 双击解压出来的 `一键安装.bat`。

> 这个 zip 是**自包含**的：档本体 + 脚本 + 全部说明文档 + `ValheimVRM_手动安装/` 都在里面。

---

## 2. 脚本会自动做什么

| 步骤 | 内容 |
|---|---|
| 1 | 找源档：同目录的 `MAKABAKA/` 文件夹 → 同目录的 zip → **都没有就从 GitHub 下载最新版**（首次运行会问「安装包放哪」，可换到别的盘，选过就记住 —— 见下）|
| 2 | 找 r2modman 的 profiles 目录（命令行 → 上次记住的 → r2modman 自己的记录 → 默认位置 → 扫盘 → 问你）。**找到多个数据文件夹时会列出来让你选**（有人每块盘都有一份），默认选上次那个，也可输 `9` 再扫盘、输 `0` 自己指定 |
| 3 | r2modman 正在运行就先关掉（它的退出会重写档信息）|
| 4 | 没装过 → 全新安装；装过 → **原地升级**（优先保留你的设置，旧文件先备份）|
| 5 | 复制（升级模式跳过 `BepInEx\config`，只补缺失的配置文件）|
| 6 | 校验：9 个关键文件 MD5 ＋ mod 启用/禁用计数 ＋ ChestFlow 版本 |
| 7 | 收尾：告诉你怎么启动（r2modman 里选 `MAKABAKA` → `Start modded`）+ 可选配置 ValheimVRM（见下） |

### ValheimVRM（角色换模型）：文件要落在两个不同位置

这是本包里唯一一个**不能只靠 r2modman 装**的 mod —— 它的文件分两处（选 Y 时脚本会全部自动做好）：

| 放什么 | 源目录 | 装到哪里 |
|---|---|---|
| 插件 `ValheimVRM.dll` + `ValheimVRM.shaders` | `ValheimVRM_手动安装\BepInEx_pluginsに入れるファイル\` | **r2modman 的档里**：`<档>\BepInEx\plugins\ValheimVRM_1.2.2\` |
| 运行时 dll（15 个，`VRM10.dll`/`UniGLTF.dll`/`MToon.dll`…） | `ValheimVRM_手动安装\valheim_Data_Managedに入れる文件\` | **游戏本体里**：`<游戏>\valheim_Data\Managed\`（覆盖前自动备份到 `<游戏>\_vrm_backup_<时间>\`） |
| 模型与设置 | 按需下载（见下）/ 本机缓存 / `-ModelPath` 指定的本地文件 | **游戏本体里**：`<游戏>\ValheimVRM\<角色名>.vrm` + `settings_<角色名>.txt` |

**从 v1.4 起，角色模型不再进安装包**（安装包只含 mod 本体+脚本+文档，日常更新只下几十 MB）：

| 你想干什么 | 怎么做 | 下载量 |
|---|---|---|
| 只更新 mod | 双击 `一键安装.bat`，最后一步答 `n`；或 `-ModsOnly` | 几十 MB |
| 装包 + 顺手装模型 | 走到模型那步，菜单里选一个或多个（如 `1,3`） | 每个 13–77 MB（按需） |
| 只换模型 / 换角色名 | 双击 `换模型.bat`（等价 `install.ps1 -VRMOnly`） | 已下载过 = **0**（秒切） |
| 只看有哪些可选 | `install.ps1 -ListModels`（不动任何文件） | 0 |

模型细节：
- 模型放在**私有仓库的 Release 附件**里，脚本按包内 `Models\models.json` 清单下载并核对 **sha256**；
  首次要一次凭据（只读 GitHub 令牌，脚本问一次并记住到 `模型凭据.txt`；也可用环境变量 `MAKABAKA_MODEL_TOKEN`）。
- 下载过的存本机缓存（`<你选的下载目录>\VRM_Models\` 或 `%LOCALAPPDATA%\MAKABAKA\VRM\Models`），
  换模型 = 从缓存复制并按你的角色名改名，所以**切换是秒级的**。
- 不想用私有仓库/凭据：把 `.vrm` 放本地，用 `-ModelPath <文件或目录>`，或用 `-Models "金乌-毛绒派对,辰星"` 预选。
- 角色名由脚本里自己输（`<角色名>.vrm` + `settings_<角色名>.txt`），**不用去文件夹里找文件或手动改名**；
  目录里已有以前用过的角色名时会列出来、输编号即可；旧模型默认留着，也可选一键收进 `_旧模型_<时间>\`。
- 完整说明见包内 **`模型说明.txt`**。

> 文件名规则（照上游源码确认）：`<游戏>\ValheimVRM\<角色名>.vrm` 与 `settings_<角色名>.txt`。
> 拼写必须与游戏里角色名一致（大小写无所谓，字母不能错），前缀必须是 `settings_`；
> 缺配置文件不会崩，插件会用默认值（模型大小 1.1、亮度 0.8…）。改完要完全重启游戏。

脚本对每个文件都比对 MD5：缺的补上、内容不一样的换掉（换之前先备份），装完还会打一份**三处自检**，
三行都得是 `[✓]`：`① 插件（档里）` / `② Managed dll（游戏里）` / `③ 模型（游戏里）`。
游戏目录没找到也不影响 ①，之后重跑一次就能补 ②③。

> 常见故障排查、手动三步做法、以及「改名要跟着角色名」这条，见 `ValheimVRM_手动安装\说明_ValheimVRM.txt`。

日志写到桌面：`MAKABAKA安装日志.txt`。

常用参数（详见 `install.ps1` 头部注释 / `安装指南.txt`）：

```
-ProfilesRoot <路径>  指定 profiles 目录        -Fresh      强制全新重装
-SkipVRM              跳过 ValheimVRM 那一步    -Offline    只用本地文件、不联网
-ModsOnly             只更新 mod（= -SkipVRM）    -ListModels 只列出可选模型后退出
-Models "名1,名2"      指定要下载并缓存的模型     -ModelPath <文件|目录>  用本地 .vrm
-ModelSource <url>    覆盖模型清单来源           -ModelToken <令牌>      私有仓库下载凭据
-PackFile <路径>      用指定的本地 zip          -PackUrl <url>  从指定 URL 下载包
-ReleaseRepo <o/r>    换仓库                   -ReleaseBase <url>  自建镜像/自测用
-DetectOnly           只探测路径、什么都不改
-DownloadDir <路径>   安装包下载/解压放哪（默认 %TEMP%\makabaka_pack；不喜欢 C 盘就换盘，
                      如 -DownloadDir D:\MAKABAKA_install）。选过一次会记住（download-path.txt）
```

> **安装包不想放 C 盘？** 首次运行时会问一次：
> ```
>   安装包放哪？（要下 138 MB、解压再占约 140 MB；装完脚本会自动清理）
>     1) C:\Users\你\AppData\Local\Temp\makabaka_pack   （默认；该盘剩余 65.8 GB）
>     2) D:\MAKABAKA_install   （另一个盘；剩余 ... GB）
>     0) 我自己输入一个路径
> ```
> 选完会记在脚本旁的 `download-path.txt`；想改就删掉它、或用 `-DownloadDir` 指定。
> 模型缓存（下载过的模型，每个 24–150MB）也会跟着放到你选的目录里的 `VRM_Models\`；用默认位置时则放
> `%LOCALAPPDATA%\MAKABAKA\VRM\Models`（因为临时目录会被系统清理）。没装模型的人这里就是空的。

---

## 3. 更新到新版

- **clone 的用户**：`git pull` → 重新双击 `一键安装.bat`
- **一行命令 / 手动下载的**：重跑一次即可（每次都会取最新版）
- 升级**保留**你自己的 F1 设置与收藏格；升级前的 `BepInEx\plugins` 与 `mods.yml`
  会备份到 `MAKABAKA_backup-<时间戳>`（在线安装时备份放在**桌面**，因为临时目录会被清理）

---

## 4. 校验与安全

- 每个 Release 都附 **`SHA256SUMS.txt`**（版本 / 文件名 / 字节数 / MD5 / SHA256）
- 脚本下载完**自动核对 MD5**：不一致就删文件、停止安装，绝不装可疑包
- 也想自己核的人：见 [`校验值.txt`](校验值.txt)

---

## 5. 两个"千万别做"

1. **别在 r2modman 里对某些 mod 点 Update / Reinstall** —— 会被官方版覆盖，丢掉汉化/自研修改：
   AzuExtendedPlayerInventory、Recycle_N_Reclaim（自编译）、MinimalUI / BetterUI / PetPantry /
   ChestFlow / TargetPortal / PlanBuild / InstantMonsterLootDrop（汉化或补丁）、Endurance（汉化版）、
   以及三个自制插件（SafeBox / KeepBuffsOnDeath / VRMGhostFix）。完整清单见 `安装指南.txt` 第 8 节。
2. **别在装完 ValheimVRM 的 dll 后点 Steam 的"验证游戏文件完整性"** —— 会清掉 `valheim_Data\Managed`
   里那些 dll（重跑脚本即可恢复）。

带 `[Synced with Server]` 的配置项（AzuEPI 快捷栏行数、EpicLoot baseconfig、Endurance 阈值/经验倍率…）
**必须在服务端改**，客户端改了不生效。

---

## 6. 仓库文件说明

| 文件 | 用途 |
|---|---|
| `install.ps1` | 安装/升级脚本（本仓库里是**最新版**，支持自动下载；Release 附件 zip 里那份是打包时的副本，用于完全离线） |
| `一键安装.bat` | Windows 双击入口（转发给 `install.ps1`） |
| `安装指南.txt` | 从零开始的图文步骤、排查、卸载还原 |
| `键位自定义指南.txt` | 客户端各自改键位/配置的说明 |
| `游戏内功能速查.txt` | 装完能干什么、快捷键、怎么还原官方数值 |
| `r2modman使用说明.txt` | 只讲 r2modman 怎么用 |
| `Mod清单_MAKABAKA.txt` | 42 个 Thunderstore 包 + 自制插件清单 |
| `EpicLoot游玩指南.md/.txt` | EpicLoot 附魔/词缀/合成玩法 |
| `更新说明_*.txt` | 每个版本的改动 |
| `版本号.txt` | 当前包版本与命名规则 |
| `校验值.txt` | 各版本安装包 MD5 / SHA256 |

---

## 7. 版本历史

- **v1.0（2026-09-15）** 首个分享版
  - 新增 `Azumatt-Hooked` 1.1.1（钓鱼玩法重做，已按"手感保留、收益收敛"调平衡）
  - 新增自制插件 `SafeBox` 0.5.4（随身 9 格保险柜，死亡不掉落、Ctrl+左键快速存取）、
    `KeepBuffsOnDeath` 1.0.1（死亡保留 Rested 等正面 buff）
  - 包内新增《键位自定义指南.txt》
  - 同步 09-14 之后更新的 mod（AzuEPI 2.4.13、MinimalUI、BuildCameraCHE、ConfigurationManager 等）

---

## 8. 免责 / 出处

整合了 Thunderstore 上**公开可下载**的 mod，以及自编译 / 本地汉化的文件（`Endurance` 汉化版、
`ChestFlow` 汉化版、`ChestFlowTweaks 0.3.1`、`SafeBox`、`KeepBuffsOnDeath`、`VRMGhostFix` 等）。
各 mod 版权归原作者，本仓库仅供朋友之间联机使用，**请勿用于商业用途**。
打包档里不含游戏本体、不含世界/角色存档。
