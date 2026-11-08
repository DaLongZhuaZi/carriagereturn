#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""回车 · 纯模型 .ets 的 TypeScript 类型检查（第 7 批后硬化）。

ArkTS 编译器在本机不可用；但 `model/` 下的纯逻辑文件不含 struct/ArkUI，
可以原样复制成 .ts 用 tsc --strict 检查类型（不是 ArkTS 编译，只补类型层证据）。
跳过含 `struct ` 或 `@kit.`/`@ohos.` import 的模型文件。

用法：python tools/check-model-types.py [--keep]
"""
from __future__ import annotations

import glob
import os
import shutil
import subprocess
import sys
import tempfile

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
SRC = os.path.join(ROOT, "entry/src/main/ets/model")


def main() -> int:
    keep = "--keep" in sys.argv
    tsc = shutil.which("tsc")
    if not tsc:
        print("SKIP: tsc not found")
        return 0
    tmp = tempfile.mkdtemp(prefix="cr-tscheck-")
    models = os.path.join(tmp, "model")
    os.makedirs(models)
    checked = []
    for path in sorted(glob.glob(os.path.join(SRC, "*.ets"))):
        text = open(path, encoding="utf-8", errors="replace").read()
        if "struct " in text or "from '@kit." in text or "from '@ohos." in text:
            continue
        name = os.path.basename(path)[:-4] + ".ts"
        with open(os.path.join(models, name), "w", encoding="utf-8", newline="\n") as fh:
            fh.write(text)
        checked.append(name)
    tsconfig = {
        "compilerOptions": {
            "target": "ES2020", "module": "ESNext", "strict": True,
            "noEmit": True, "skipLibCheck": True, "lib": ["ES2020"],
        },
        "include": ["model/*.ts"],
    }
    import json
    with open(os.path.join(tmp, "tsconfig.json"), "w", encoding="utf-8", newline="\n") as fh:
        json.dump(tsconfig, fh, indent=2)
    proc = subprocess.run([tsc, "-p", os.path.join(tmp, "tsconfig.json")],
                          cwd=ROOT, capture_output=True, text=True)
    out = (proc.stdout + proc.stderr).strip()
    if out:
        print(out)
    print(f"model files checked={len(checked)} tsc={'PASS' if proc.returncode == 0 else 'FAIL'}")
    if keep:
        print("kept:", tmp)
    else:
        shutil.rmtree(tmp, ignore_errors=True)
    return proc.returncode


if __name__ == "__main__":
    sys.exit(main())