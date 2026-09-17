#!/bin/bash
# 把仓库里的脚本/文档同步到分享包目录（打包前先跑这个，避免"仓库改了、包还是旧脚本"）
# 用法: bash tools/同步到分享包.sh ["分享包目录"]
set -u
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SHARE="${1:-/mnt/i/000工作台/英灵神殿mod分享_MAKABAKA}"

if [ ! -d "$SHARE/MAKABAKA" ]; then
  echo "[x] 分享包目录里没有 MAKABAKA 文件夹：$SHARE" >&2
  exit 1
fi

echo "仓库: $REPO"
echo "分享包: $SHARE"
echo

changed=0; same=0
for f in install.ps1 ModelLib.ps1 一键安装.bat 换模型.bat 换模型.ps1 README.md 校验值.txt 安装步骤.txt \
         安装指南.txt 键位自定义指南.txt 游戏内功能速查.txt r2modman使用说明.txt \
         Mod清单_MAKABAKA.txt 版本号.txt 模型说明.txt EpicLoot游玩指南.md EpicLoot游玩指南.txt; do
  src="$REPO/$f"; dst="$SHARE/$f"
  [ -f "$src" ] || { echo "  [跳过] 仓库里没有 $f"; continue; }
  if [ -f "$dst" ] && cmp -s "$src" "$dst"; then
    echo "  [一致] $f"
    same=$((same+1))
  else
    oldsz="$([ -f "$dst" ] && stat -c%s "$dst" || echo 新)"
    cp -p "$src" "$dst"
    echo "  [已更新] $f  ($oldsz → $(stat -c%s "$src") 字节)"
    changed=$((changed+1))
  fi
done
# 模型清单：跟着仓库走（模型实体走私有仓库 Release 附件，不同步）
SRC_MAN="$REPO/Models/models.json"; DST_MAN="$SHARE/Models/models.json"
if [ -f "$SRC_MAN" ]; then
  mkdir -p "$SHARE/Models"
  if [ -f "$DST_MAN" ] && cmp -s "$SRC_MAN" "$DST_MAN"; then
    echo "  [一致] Models/models.json"; same=$((same+1))
  else
    cp -p "$SRC_MAN" "$DST_MAN"
    echo "  [已更新] Models/models.json（$(stat -c%s "$SRC_MAN") 字节）"; changed=$((changed+1))
  fi
fi

# 更新说明（Release notes 与包内文案保持一致）
for src in "$REPO"/更新说明_*.txt; do
  [ -f "$src" ] || continue
  b="$(basename "$src")"; dst="$SHARE/$b"
  if [ -f "$dst" ] && cmp -s "$src" "$dst"; then same=$((same+1)); else
    cp -p "$src" "$dst"; echo "  [已更新] $b（$(stat -c%s "$src") 字节）"; changed=$((changed+1)); fi
done

# 模型参考图（Models/预览/*.jpg）：随包分发，跟着仓库走
SRC_PV="$REPO/Models/预览"; DST_PV="$SHARE/Models/预览"
if [ -d "$SRC_PV" ]; then
  mkdir -p "$DST_PV"
  for f in "$SRC_PV"/*.jpg; do
    [ -f "$f" ] || continue
    b="$(basename "$f")"
    if [ -f "$DST_PV/$b" ] && cmp -s "$f" "$DST_PV/$b"; then same=$((same+1)); else
      cp -p "$f" "$DST_PV/$b"; echo "  [已更新] Models/预览/$b（$(stat -c%s "$f") 字节）"; changed=$((changed+1)); fi
  done
  # 删掉分享包里已不在仓库的旧参考图
  for f in "$DST_PV"/*.jpg; do
    [ -f "$f" ] || continue
    b="$(basename "$f")"
    [ -f "$SRC_PV/$b" ] || { rm -f "$f"; echo "  [已删除] Models/预览/$b（仓库里已没有）"; changed=$((changed+1)); }
  done
fi

echo
echo "完成：更新 $changed 个，一致 $same 个。"
echo "提醒：角色模型实体不在本流程里 —— 用 tools/发布模型.py --pack / --upload 走私有仓库附件。"
echo "提醒：更新说明_*.txt 里的本版说明只写在分享包/Release notes 里，脚本清单不含它们（要带就手动确认）。"
