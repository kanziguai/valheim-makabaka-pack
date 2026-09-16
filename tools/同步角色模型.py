#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
把 I:\\000工作台\\英灵神殿mod\\工作区 里做好的角色模型放进整合包仓库 Models\\<模型名>\\<模型名>.vrm

规则（本次任务口径）：
  · 每个模型目录只放一个文件 —— 最终游戏用 VRM（单面 compat_v053；金乌取已验收的 armfix_v3）
  · 不带 _ds 双面变体、不带 tpose / blend / fbx / 检查报告
  · 每个文件先按 sha256 与"批量交付总表/交接报告"里记录的候选哈希核对，核对不过就不放
"""
import hashlib
import os
import shutil
import sys

WS = "/mnt/i/000工作台/英灵神殿mod/工作区"
REPO = os.path.expanduser("~/valheim-makabaka-pack")
DEST_ROOT = os.path.join(REPO, "Models")

# (工作区目录名, 输出里的 VRM 文件名, 期望 sha256)
MODELS = [
    ("太一·庚辰-海上的私语", "gengchen_armfix_v1_compat_v053.vrm",
     "b4a3704869894eb120cdc0161dc00ccecb4de63281e7a7b300532738243cbe2a"),
    ("安卡希雅-叶荫闲趣_权重裙", "anka_ye_wei_armfix_v1_compat_v053.vrm",
     "649cf7e9588c7a0f626f856d962231d2add2c6d1286a3e47ffced3090be3bb0f"),
    ("安卡希雅-叶荫闲趣_物理裙", "anka_ye_phys_armfix_v1_compat_v053.vrm",
     "853046478533cbdc85d671e7dde8e45b8ebb5785cbc038069fa9b85a63c16582"),
    ("安卡希雅-时之重奏 缘音回响", "ankaxiya_armfix_v1_compat_v053.vrm",
     "71121801feebbdd475d2327c023a66f865b1887334c3735a971f54b63d9ac573"),
    ("无常-必安", "wuchang_bian_armfix_v1_compat_v053.vrm",
     "a82710a3fd284159c441321b6b6555fa1489a7f0f310eaed07c2456213fa21f4"),
    ("无常-无咎", "wuchang_jiu_armfix_v1_compat_v053.vrm",
     "ee545deebcf73a39ebab75dddc5de9789f84863c6e19ecc148b130e6bab84231"),
    ("瑟瑞斯-碧波浮游", "seris_bi_armfix_v1_compat_v053.vrm",
     "f4b278e250b569b8edc9da9e818251e65ee4c00e5b3657bfbfc16f6ad678f9cb"),
    ("瑟瑞斯-霄倾君怀", "seris_xiao_armfix_v1_compat_v053.vrm",
     "7799425e5e97780e550eea905bb51f4d1747726664a724a99991a714655e0f9d"),
    ("绮幻-恋如花舞", "qihuan_armfix_v1_compat_v053.vrm",
     "c442f54191f9b5114789590639b2654f639f9733ec3cbc96ae8c4098c141bca7"),
    ("芬妮-颂夜欢歌", "fenni_armfix_v1_compat_v053.vrm",
     "79624f0bc253d4d3f2c5d64161b271d1809cf81456265a213154da841595d5a3"),
    ("茉莉安-纯白恋羽", "molian_armfix_v1_compat_v053.vrm",
     "190915db831a62ba80f79a7fbdfdb18e02f18d035afe79a47e3ef8a582ea13ef"),
    ("菲比-反和谐", "feibi_armfix_v1_compat_v053.vrm",
     "a42993e878e9411cc31950bcb674f1b5cafce79e8f3c71c9e67cb2fd32c56c27"),
    ("金乌-毛绒派对", "jinwu_armfix_v3_compat_v053.vrm",
     "d29aaca446add61572eb17a73ba592b3807efb142a0f82a75096bcc061e877d9"),
]


def sha256(path, buf=1 << 22):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        while True:
            b = f.read(buf)
            if not b:
                break
            h.update(b)
    return h.hexdigest()


def main():
    dry = "--apply" not in sys.argv
    print("模式:", "DRY-RUN（只核对，不写文件）" if dry else "APPLY（真的复制进仓库）")
    total = 0
    fails = 0
    for folder, fname, want in MODELS:
        src = os.path.join(WS, folder, "输出", fname)
        if not os.path.isfile(src):
            print(f"[缺失] {src}")
            fails += 1
            continue
        got = sha256(src)
        size = os.path.getsize(src)
        if got != want:
            print(f"[哈希不符] {folder}/{fname}\n   got  {got}\n   want {want}")
            fails += 1
            continue
        total += size
        dst_dir = os.path.join(DEST_ROOT, folder)
        dst = os.path.join(dst_dir, fname)
        print(f"[OK] {size/1048576:6.1f} MB  Models/{folder}/{fname}")
        if not dry:
            os.makedirs(dst_dir, exist_ok=True)
            shutil.copy2(src, dst)
            os.chmod(dst, 0o644)
    print(f"\n合计 {len(MODELS)-fails} 个 / {total/1048576:.1f} MB；核对失败 {fails} 个")
    if fails:
        sys.exit(1)


if __name__ == "__main__":
    main()
