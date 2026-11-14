import io
p = 'entry/src/main/ets/services/AppPreferences.ets'
s = io.open(p, encoding='utf-8', newline=None).read()

def rep(old, new):
    global s
    if old not in s:
        raise SystemExit('MISS: %r' % old[:100])
    s = s.replace(old, new, 1)

rep("""  /** 第 6 批 F10：删除方式稳定 id（direct/ask/trash）。 */
  static readonly DELETE_MODE: string = 'delete_mode';""",
"""  /** 第 6 批 F10：删除方式稳定 id（direct/ask/trash）。 */
  static readonly DELETE_MODE: string = 'delete_mode';
  /** 第 16 批 Phase2：Canvas 主屏回滚开关（true=Canvas 主屏，false=ArkUI 主屏）。 */
  static readonly CANVAS_ENABLED: string = 'canvas.enabled';""")

rep("""      { key: PrefKeys.ACHIEVE_PREFIX, type: 'boolean', defaultValue: 'false', owner: 'F5', note: '成就达成状态（行为绑定口径：`achieve.<行为 id>`，例 `achieve.words_1000`；第 9 批起不再用机型 id）' },
    ];""",
"""      { key: PrefKeys.ACHIEVE_PREFIX, type: 'boolean', defaultValue: 'false', owner: 'F5', note: '成就达成状态（行为绑定口径：`achieve.<行为 id>`，例 `achieve.words_1000`；第 9 批起不再用机型 id）' },
      { key: PrefKeys.CANVAS_ENABLED, type: 'boolean', defaultValue: 'false', owner: 'Phase2', note: 'Canvas 主屏回滚开关（2A/2B 实施期 false，2B 验收后 true）', removeAfter: 'Phase 2 完成后' },
    ];""")

rep("""      PrefKeys.CUSTOM_ENABLED, PrefKeys.CUSTOM_FONT_IMPORTED, PrefKeys.CUSTOM_PAPER_PRESETS,
    ];""",
"""      PrefKeys.CUSTOM_ENABLED, PrefKeys.CUSTOM_FONT_IMPORTED, PrefKeys.CUSTOM_PAPER_PRESETS,
      PrefKeys.CANVAS_ENABLED,
    ];""")

io.open(p, 'w', encoding='utf-8', newline='\r\n').write(s)
print('canvas.enabled added')
