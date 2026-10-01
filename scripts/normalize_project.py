#!/usr/bin/env python3
"""
把 XcodeGen 生成的 .xcodeproj 归一化成「当前 Xcode 能打开」的工程格式。

为什么需要：
  新版 XcodeGen（2.44+）默认按最新的 Xcode 工程格式生成，会写 objectVersion = 77。
  Xcode 15.x 看到 77 会直接拒绝打开：
      "The project 'TasksSteps' cannot be opened because it is in a future
       Xcode project file format (77)"
  于是 CI 里的 xcodebuild 连编译都没开始就退出（exit code 74）。

本脚本与 XcodeGen 的版本无关：读出工程里实际的 objectVersion，跟当前 xcodebuild
支持的版本比一下，只有「比 Xcode 新」时才降级。本项目是普通应用工程，没有 SPM
包依赖，也不使用 Xcode 16 的 PBXFileSystemSynchronizedRootGroup，降级不丢结构。

用法:
  normalize_project.py <Foo.xcodeproj> --auto     # 按本机 Xcode 版本自动决定（推荐）
  normalize_project.py <Foo.xcodeproj> 56         # 强制指定 objectVersion
"""
import re
import subprocess
import sys
from pathlib import Path

# objectVersion -> 引入它的 Xcode 大版本。
# 低于或等于当前 Xcode 的值都能被打开，取不超过当前 Xcode 的最大值最安全。
XCODE_MAX_OBJECT_VERSION = [
    (16, 77),
    (15, 60),
    (14, 56),
    (13, 55),
    (12, 54),
    (11, 52),
    (10, 51),
]
SAFE_FALLBACK = 56


def detect_xcode_major() -> int | None:
    """从 xcodebuild -version 里解析出主版本号，例如 'Xcode 15.4' -> 15。"""
    try:
        out = subprocess.run(
            ["xcodebuild", "-version"],
            capture_output=True,
            text=True,
            timeout=120,
            check=False,
        ).stdout
    except (OSError, subprocess.SubprocessError):
        return None

    m = re.search(r"Xcode\s+(\d+)", out)
    return int(m.group(1)) if m else None


def max_supported(major: int | None) -> int:
    if major is None:
        return SAFE_FALLBACK
    for ver, obj in XCODE_MAX_OBJECT_VERSION:
        if major >= ver:
            return obj
    return SAFE_FALLBACK


def main() -> int:
    if len(sys.argv) < 2:
        print("用法: normalize_project.py <Foo.xcodeproj> [--auto | objectVersion]", file=sys.stderr)
        return 2

    proj = Path(sys.argv[1])
    arg = sys.argv[2] if len(sys.argv) > 2 else "--auto"

    pbxproj = proj / "project.pbxproj"
    if not pbxproj.is_file():
        print(f"!! 找不到 {pbxproj}", file=sys.stderr)
        return 1

    xcode_major = detect_xcode_major()
    limit = max_supported(xcode_major)

    if arg == "--auto":
        target = limit
        print(f"==> 检测到 Xcode 主版本: {xcode_major}，允许的最大 objectVersion: {limit}")
    else:
        try:
            target = int(arg)
        except ValueError:
            print(f"!! 参数非法: {arg}", file=sys.stderr)
            return 2
        print(f"==> 手动指定目标 objectVersion: {target}")

    text = pbxproj.read_text(encoding="utf-8")

    found = re.search(r"objectVersion\s*=\s*(\d+)\s*;", text)
    if not found:
        if "archiveVersion" in text:
            text = re.sub(
                r"(archiveVersion\s*=\s*\d+\s*;)",
                r"\1\n\tobjectVersion = %d;" % target,
                text,
                count=1,
            )
            print(f"==> 工程里没有 objectVersion，已补为 {target}")
        else:
            print("!! 这看起来不是 pbxproj 文件，未做改动", file=sys.stderr)
            return 1
    else:
        current = int(found.group(1))
        if current <= target:
            # 这里是关键：Xcode 16 的 77 在 Xcode 16 上完全没问题，不要无谓地降级
            print(f"==> objectVersion = {current}，不超过 {target}，无需改动 ✓")
            print(f"==> {pbxproj} 保持原样")
            return 0
        text = re.sub(
            r"objectVersion\s*=\s*\d+\s*;",
            f"objectVersion = {target};",
            text,
            count=1,
        )
        print(f"==> objectVersion: {current} -> {target}")

    # compatibilityVersion 一起放宽，避免 Xcode 认为工程比它新
    text = re.sub(
        r'compatibilityVersion\s*=\s*"[^"]*"\s*;',
        'compatibilityVersion = "Xcode 14.0";',
        text,
        count=1,
    )

    pbxproj.write_text(text, encoding="utf-8")
    print(f"==> 已归一化 {pbxproj}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
