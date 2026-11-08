#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""回车 · 图标审计（O1，第 0 批定方法）。

三路检查（AGENTS「图标」）：
  1) SymbolGlyph 直用点：只允许 AppIcon.ets 一处（其余必须经 AppIcon 封装）。
  2) 文字符号当图标：Text('‹'/'›'/'⋯'/'✓'/'×' 等)。
  3) emoji 扫描（键盘可打字符 ★☆○●◆※ 属内容，不算图标；仍列出供人工核对）。
另外核对：代码里用到的 AppIcon kind 是否都在 IconKind 注册表里。

用法：python tools/audit-icons.py [--json docs/evidence/icon-audit.json]
退出码：0=无违规（emoji 只提示）；1=有违规。
"""
from __future__ import annotations

import json
import os
import re
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
ETS_ROOT = os.path.join(ROOT, "entry/src/main/ets")
ALLOWED_SYMBOL_GLYPH = {"entry/src/main/ets/components/AppIcon.ets"}
SYMBOL_CHARS = "‹›⋯✓✕✖×÷→←↑↓"
EMOJI_RE = re.compile("[\U0001F300-\U0001FAFF\u2600-\u27BF]")

violations = []
emoji_hits = []
symbol_glyph_hits = []
kinds_used = set()
kinds_registered = set()


def relpath(p: str) -> str:
    return os.path.relpath(p, ROOT).replace("\\", "/")


for dirpath, dirnames, filenames in os.walk(ETS_ROOT):
    dirnames[:] = [d for d in dirnames if d not in ("node_modules", "oh_modules", "build")]
    for fn in filenames:
        if not fn.endswith(".ets"):
            continue
        full = os.path.join(dirpath, fn)
        rel = relpath(full)
        with open(full, "r", encoding="utf-8", errors="replace") as fh:
            lines = fh.readlines()
        for i, line in enumerate(lines, 1):
            stripped = line.strip()
            is_comment = stripped.startswith("//") or stripped.startswith("*")
            if "SymbolGlyph(" in line and rel not in ALLOWED_SYMBOL_GLYPH:
                symbol_glyph_hits.append(f"{rel}:{i}: {stripped[:120]}")
                violations.append(f"SymbolGlyph 直用（应走 AppIcon）: {rel}:{i}")
            if not is_comment:
                m = re.search(r"Text\(\s*['\"]([" + re.escape(SYMBOL_CHARS) + r"])['\"]", line)
                if m:
                    violations.append(f"文字符号当图标: {rel}:{i}: {stripped[:100]}")
                if EMOJI_RE.search(line):
                    emoji_hits.append(f"{rel}:{i}: {stripped[:100]}")
            m2 = re.search(r"AppIcon\(\{[^}]*kind:\s*['\"]([A-Za-z0-9_]+)['\"]", line)
            if m2:
                kinds_used.add(m2.group(1))

appicon = os.path.join(ETS_ROOT, "components/AppIcon.ets")
with open(appicon, "r", encoding="utf-8", errors="replace") as fh:
    text = fh.read()
for m in re.finditer(r"static readonly [A-Z_]+: string = '([^']+)'", text):
    kinds_registered.add(m.group(1))
missing = sorted(kinds_used - kinds_registered)
if missing:
    violations.append("AppIcon kind 未注册: " + ", ".join(missing))

report = {
    "symbolGlyphDirectUses": symbol_glyph_hits,
    "textSymbolIcons": [v for v in violations if v.startswith("文字符号")],
    "emojiHits": emoji_hits,
    "kindsUsed": sorted(kinds_used),
    "kindsRegistered": sorted(kinds_registered),
    "violations": violations,
    "verdict": "PASS" if not violations else "FAIL",
}

print("== 图标审计（O1）==")
print(f"SymbolGlyph 直用点: {len(symbol_glyph_hits)}（允许仅 AppIcon.ets）")
print(f"AppIcon kind：使用 {len(kinds_used)} 种 / 注册 {len(kinds_registered)} 种")
if emoji_hits:
    print(f"emoji/符号字符命中 {len(emoji_hits)} 处（需人工确认是内容还是图标；键盘 ★☆○●◆※ 属内容）")
    for h in emoji_hits:
        print("  - " + h)
for v in violations:
    print("  FAIL " + v)
print(f"结论: {report['verdict']}")

args = sys.argv[1:]
if "--json" in args:
    out = args[args.index("--json") + 1]
    os.makedirs(os.path.dirname(os.path.abspath(out)), exist_ok=True)
    with open(out, "w", encoding="utf-8") as fh:
        json.dump(report, fh, ensure_ascii=False, indent=2)
    print("JSON: " + out)
sys.exit(0 if not violations else 1)