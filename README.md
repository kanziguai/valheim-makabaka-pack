# 英灵神殿 MAKABAKA 整合档 · 一键安装

Valheim 1.0 联机整合档（r2modman profile）：**Thunderstore 42 个包（37 启用 / 5 禁用）**
＋ 自制插件 3 个（SafeBox 0.5.4、KeepBuffsOnDeath 1.0.1、VRMGhostFix）
＋ ChestFlow 及界面汉化 ＋ Azumatt-Hooked 1.1.1（已调平衡）＋ Achievement_Enabler_Plus 2.0.3。

**当前版本：v1.0（2026-09-15）** · 安装包 117.6 MB（自包含）· 见 [Releases](../../releases)

> 仓库里只放脚本 + 文档（几百 KB）；安装包 zip 走 Release 附件，不进 git 历史。

---

## 0. 前提（没这两样装不了）

1. **正版 Valheim 1.0**（Steam）
2. **[r2modman](https://thunderstore.io/c/valheim/p/ebkr/r2modman/)** 已安装，**并启动过一次、选好 Valheim 安装位置**
   （它得先建好 profiles 目录，安装脚本才能把档放进去）
3. Windows 10/11，预留约 350 MB（安装包 118 MB + 解压后约 120 MB）

---

## 1. 三种装法（挑一个就行）

### A. 一行命令（不用装 git，最省事）

PowerShell 窗口里粘这一行、回车（走镜像，国内直连 raw 常常连不上）：

```powershell
$s="$env:TEMP\makabaka-install.ps1"; iwr "https://ghfast.top/https://raw.githubusercontent.com/kanziguai/valheim-makabaka-pack/main/install.ps1" -OutFile $s; powershell -NoProfile -ExecutionPolicy Bypass -File $s
```

镜像不行就换这几个前缀（也可以直接用 `raw.githubusercontent.com` 直连）：

```powershell
$u="https://ghproxy.net/https://raw.githubusercontent.com/kanziguai/valheim-makabaka-pack/main/install.ps1"
$u="https://raw.githubusercontent.com/kanziguai/valheim-makabaka-pack/main/install.ps1"   # 直连
```

> 在跑着 Clash / 机场加速器的机器上，脚本下载会先走系统代理、失败会自动绕开代理直连；
> 首装要下 117MB，几分钟属正常，别中途关窗口。

### B. clone 仓库 + 双击（推荐，以后更新最方便）

```powershell
git clone https://github.com/kanziguai/valheim-makabaka-pack.git
cd valheim-makabaka-pack
```

然后**双击 `一键安装.bat`**。仓库里没有安装包 —— 脚本会自动去 Release 下最新版
（镜像优先、失败自动换线路，下完核对 MD5 才解压安装）。

### C. 完全手动（不用 git、不用命令行）

到 **[Releases](../../releases)** 下载 `MAKABAKA_profile_vX.Y_YYYYMMDD.zip` → 解压 → 双击解压出来的 `一键安装.bat`。

> 这个 zip 是**自包含**的：档本体 + 脚本 + 全部说明文档 + `ValheimVRM_手动安装/` 都在里面。

---

## 2. 脚本会自动做什么

| 步骤 | 内容 |
|---|---|
| 1 | 找源档：同目录的 `MAKABAKA/` 文件夹 → 同目录的 zip → **都没有就从 GitHub 下载最新版** |
| 2 | 找 r2modman 的 profiles 目录（命令行 → 上次记住的 → r2modman 自己的记录 → 默认位置 → 扫盘 → 问你）|
| 3 | r2modman 正在运行就先关掉（它的退出会重写档信息）|
| 4 | 没装过 → 全新安装；装过 → **原地升级**（优先保留你的设置，旧文件先备份）|
| 5 | 复制（升级模式跳过 `BepInEx\config`，只补缺失的配置文件）|
| 6 | 校验：9 个关键文件 MD5 ＋ mod 启用/禁用计数 ＋ ChestFlow 版本 |
| 7 | 收尾：告诉你怎么启动（r2modman 里选 `MAKABAKA` → `Start modded`）+ 可选配置 ValheimVRM |

日志写到桌面：`MAKABAKA安装日志.txt`。

常用参数（详见 `install.ps1` 头部注释 / `安装指南.txt`）：

```
-ProfilesRoot <路径>  指定 profiles 目录        -Fresh      强制全新重装
-SkipVRM              跳过 ValheimVRM 那一步    -Offline    只用本地文件、不联网
-PackFile <路径>      用指定的本地 zip          -PackUrl <url>  从指定 URL 下载包
-ReleaseRepo <o/r>    换仓库                   -ReleaseBase <url>  自建镜像/自测用
-DetectOnly           只探测路径、什么都不改
```

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
