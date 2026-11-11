#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""第 10 批 · 引导验收的安全导航（防"不在 App 里还继续点"）。

规则（2026-11-11 用户要求，写死）：
1. 每次点击前：aa start 把 App 拉回前台 → dumpLayout → 必须看到 App 自己的文案；
2. 返回只用页内返回箭头（PageShell 坐标固定），不连按系统返回；
3. 每步后重新 dump 判断当前页，不在预期页就中止（抛出异常），不盲点。

用法：
  python tools/guide-verify.py page            # 打印当前页
  python tools/guide-verify.py home            # 回到主页（页内返回）
  python tools/guide-verify.py click X Y       # 前台校验后点击
  python tools/guide-verify.py shot docs/shots/xxx.png
"""
import json
import subprocess
import sys
import time

HDC = r"G:\DevEco Studio 26\DevEco Studio\sdk\default\openharmony\toolchains\hdc.exe"
T = ["-t", "192.168.5.133:42355"]
APP = "com.dlzz.carriagereturn"
DUMP = "/data/local/tmp/_guard_dump.json"

APP_MARKERS = ["回车", "继续写作", "开始打字", "未命名", "新建卷宗", "新建纸张",
               "字体管理", "纸张自定义", "重播页面引导", "收藏", "换装", "设置", "导出"]


def sh(cmd, timeout=120):
    return subprocess.run([HDC] + T + ["shell", cmd], capture_output=True, text=True,
                          timeout=timeout).stdout


def front():
    """把 App 拉到前台。"""
    sh("aa start -a EntryAbility -b " + APP)
    time.sleep(1.2)


def dump():
    sh("uitest dumpLayout -p " + DUMP)
    # dump 落盘与 recv 之间有延迟，必须等一下，否则会读到上一页的旧文件（本次踩过的坑）
    time.sleep(0.8)
    subprocess.run([HDC] + T + ["file", "recv", DUMP, "docs/evidence/.tmp-guard.json"],
                   capture_output=True, text=True, timeout=60)
    with open("docs/evidence/.tmp-guard.json", "r", encoding="utf-8") as f:
        return json.load(f)


def texts(d):
    out = []

    def walk(n):
        a = n.get("attributes", {}) or {}
        x = a.get("text", "")
        if x:
            out.append(x)
        for c in (n.get("children") or []):
            walk(c)
    walk(d)
    return out


def current_page(d):
    t = texts(d)
    if "继续写作" in t or "开始打字" in t:
        return "home"
    if "重播页面引导" in t:
        return "settings"
    if "新建卷宗" in t:
        return "dossier"
    if "新建纸张" in t:
        return "dossier_detail"
    if "字体管理" in t and "纸张自定义" in t:
        return "customize"
    if "我的词库" in t or "候选栏" in t:
        return "pinyin_settings"
    if "导入字体" in t or "font_import" in t:
        return "font_manager"
    if "纸纹" in t or "预设" in t:
        return "paper_custom"
    if "导出不加水印" in t or "保存到本地" in t:
        return "export"
    if "没有纸" in t or "还没有纸" in t:
        return "dossier_detail"
    if "设为当前机器" in t or "已拥有" in t:
        return "collection_detail"
    if "当前总字数" in t or "四台机" in t:
        return "collection"
    if "回收站" in t and ("天" in t or "恢复" in t):
        return "trash"
    if "加页" in t or "分享·待实现" in t:
        return "document_view"
    if "换行" in t or "换纸" in t:
        return "typewriter"
    return "unknown"


def assert_app(d):
    t = texts(d)
    if not any(m in t for m in APP_MARKERS):
        raise SystemExit("ABORT: App 不在前台（dump 里没有 App 文案）")
    return current_page(d)


def click(x, y, expect=None):
    front()
    d = dump()
    page = assert_app(d)
    sh("uitest uiInput click %d %d" % (x, y))
    time.sleep(1.5)
    d2 = dump()
    p2 = assert_app(d2)
    if expect is not None and p2 != expect:
        raise SystemExit("ABORT: 期望页 %s，实际 %s" % (expect, p2))
    return p2


def home():
    """只用页内返回箭头回主页。"""
    for _ in range(5):
        front()
        d = dump()
        p = assert_app(d)
        if p == "home":
            return "home"
        # PageShell 返回箭头固定 (69,170)；打字机用顶栏左侧 (69,170) 亦可
        sh("uitest uiInput click 69 170")
        time.sleep(1.3)
    raise SystemExit("ABORT: 回不到主页")


def shot(path):
    sh("uitest screenCap -p /data/local/tmp/_guard_shot.png")
    subprocess.run([HDC] + T + ["file", "recv", "/data/local/tmp/_guard_shot.png", path],
                   capture_output=True, text=True, timeout=60)
    print("shot", path)


if __name__ == "__main__":
    cmd = sys.argv[1]
    if cmd == "page":
        print(current_page(dump()))
    elif cmd == "home":
        print(home())
    elif cmd == "click":
        print(click(int(sys.argv[2]), int(sys.argv[3]), sys.argv[4] if len(sys.argv) > 4 else None))
    elif cmd == "shot":
        shot(sys.argv[2])
    else:
        raise SystemExit("unknown cmd")
