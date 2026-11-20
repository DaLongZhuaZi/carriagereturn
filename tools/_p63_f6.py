# 批 63 阶段 0 · 任务 4（F-6）：字号滑杆移到固定区（顶栏下方，不随列表滚动）
import io

P = r'entry/src/main/ets/components/CustomizePage.ets'
s = io.open(P, encoding='utf-8').read()

OLD = """              SettingsRow({
                label: '字号',
                mode: 'slider',
                sliderValue: this.sliderFontSize(),
                sliderMin: FONT_SIZE_MIN,
                sliderMax: FONT_SIZE_MAX,
                sliderStep: 1,
                // 批 62 收尾（任务 3）：滑杆补数值回显（与读回值同源，不会出现\"显示 17、实际 11.9\"）
                sliderValueText: this.sliderFontSize().toString(),
                reveal: this.revealN > 3,
                onSlide: (v: number): void => { this.onFontSize(v); },
              })
              Column().width('100%').height(1).backgroundColor('rgba(232,221,201,0.12)')
"""

FIX = """    // 批 63 阶段 0（任务 4／F-6）：字号滑杆移到固定区（顶栏下方、不随列表滚动）。
    // 原位置在 17 款字体之后；行级 onTouch 吞掉竖向拖拽 → 列表滚不到底、平板上不可达。
    Column() {
      SettingsRow({
        label: '字号',
        mode: 'slider',
        sliderValue: this.sliderFontSize(),
        sliderMin: FONT_SIZE_MIN,
        sliderMax: FONT_SIZE_MAX,
        sliderStep: 1,
        sliderValueText: this.sliderFontSize().toString(),
        reveal: true,
        onSlide: (v: number): void => { this.onFontSize(v); },
      })
      Column().width('100%').height(1).backgroundColor('rgba(232,221,201,0.12)')
    }
    .width('100%')
    .padding({ left: 14, right: 14 })
    .margin({ bottom: 8 })

"""

ANCHOR = "  @Builder\n  body() {\n        Scroll() {"

if OLD not in s:
    raise SystemExit('old block missing')
s = s.replace(OLD, '', 1)
if ANCHOR not in s:
    raise SystemExit('body anchor missing')
s = s.replace(ANCHOR, "  @Builder\n  body() {\n" + FIX + "        Scroll() {", 1)
io.open(P, 'w', encoding='utf-8').write(s)
print('patched F-6 slider to fixed area')
