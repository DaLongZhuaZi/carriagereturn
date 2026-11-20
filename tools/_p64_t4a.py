# 批 64（T2/T4 起手）：黑井＋键网格搬进 Stage26 的 keyZone 槽位。
#  - 两者外包一层 Stack（井在下、键在上），原点由「屏坐标 keyGridTopVp」改为「槽内 0」；
#  - KeyGrid 宽改机器宽（N2 的最后一处越界：1836 → ≤1365）；
#  - 逐键 flex（Row+SpaceBetween）留给 T4 后半，本轮只收容器口径。
import io

P = 'entry/src/main/ets/pages/Index.ets'
s = io.open(P, encoding='utf-8').read()

blocks = []
for comp, zid, marker in [('KeyWell', 'p33_key_well', '.position({ x: 8 * this.xk() + this.machineOffsetX26(), y: this.keyGridTopVp() })'),
                          ('KeyGrid', 'p25_key_grid', '.position({ x: 0 + this.machineOffsetX26(), y: this.keyGridTopVp() })')]:
    start = s.index('        ' + comp + '({')
    pos_at = s.index(marker, start)
    end = s.index('\n', pos_at) + 1
    block = s[start:end]
    # 去掉 .position 行
    call = block[:pos_at - start].rstrip() + '\n'
    call4 = '\n'.join([ln[4:] if ln.startswith('    ') else ln for ln in call.split('\n')])
    blocks.append(call4)

body = '      Stack({ alignContent: Alignment.TopStart }) {\n' + \
       '\n'.join(['  ' + ln if ln.strip() else ln for ln in b.split('\n') for _ in [0]][:0]) if False else ''
joined = ''
for b in blocks:
    for ln in b.split('\n'):
        joined += ('  ' + ln if ln.strip() else ln) + '\n'

builder = ('  /** keyZone 槽位：黑井＋键网格（井为底、键陷在井里；逐键 flex 属 T4 后半）。 */\n'
           '  @Builder\n'
           '  stageKeys() {\n'
           '    Stack({ alignContent: Alignment.TopStart }) {\n'
           + joined +
           '    }\n'
           '    .width(\'100%\')\n'
           '    .height(\'100%\')\n'
           '  }\n')

# 删掉两个 mount，留注释
first = s.index('        KeyWell({')
last_marker = '.position({ x: 0 + this.machineOffsetX26(), y: this.keyGridTopVp() })'
last = s.index(last_marker, first)
last_end = s.index('\n', last) + 1
s = s[:first] + '        // 批 64（T2/T4）：黑井＋键网格已搬进 Stage26 的 keyZone 槽位（见 @Builder stageKeys）\n' + s[last_end:]

# 原点改槽内 0；宽改机器宽
s = s.replace('originYVp: this.keyGridTopVp(),', 'originYVp: 0,', 1)
s = s.replace('          widthVp: this.canvasWidthVp(),\n          heightVp: this.keybedHeight,',
              '          widthVp: this.machineWidth26(),\n          heightVp: this.keybedHeight,', 1)

s = s.replace('  build() {', builder + '\n  build() {', 1)
old = "          candBarZone: (): void => { this.stageCandBar() },\n"
assert old in s
s = s.replace(old, old + "          keyZone: (): void => { this.stageKeys() },\n", 1)

io.open(P, 'w', encoding='utf-8').write(s)
print('keyZone wired')

