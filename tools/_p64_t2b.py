# 批 64（T2 第二步）：把四个固定高区（字篮井／功能行／字体条／候选栏）搬进 Stage26 槽位。
# 做法：把现成的 mount 块（含 .id、不含 .position）原样挪进 Index 的 @Builder，
#       原位置留一行注释；再把四个 slot 参数加到 Stage26 调用上。
import io, re

P = 'entry/src/main/ets/pages/Index.ets'
s = io.open(P, encoding='utf-8').read()

ZONES = [
    ('Basket26', 'basketZone', 'stageBasket', 'p26_basket',
     '        // 批 64（T2）：字篮井已搬进 Stage26 的 basketZone 槽位（见 @Builder stageBasket）\n'),
    ('FunctionCaps26', 'funcRowZone', 'stageFuncRow', 'p26_function_caps',
     '        // 批 64（T2）：功能行六键已搬进 Stage26 的 funcRowZone 槽位（见 @Builder stageFuncRow）\n'),
    ('FontPlate26', 'fontBarZone', 'stageFontBar', 'p26_font_plate',
     '        // 批 64（T2）：字体条已搬进 Stage26 的 fontBarZone 槽位（见 @Builder stageFontBar）\n'),
    ('CandStrip26', 'candBarZone', 'stageCandBar', 'p26_cand_strip',
     '        // 批 64（T2）：候选栏已搬进 Stage26 的 candBarZone 槽位（见 @Builder stageCandBar）\n'),
]

builders = []
for comp, slot, bname, zid, note in ZONES:
    start = s.index('        ' + comp + '({')
    # 该 mount 的 .position 行（到行尾）
    pos = s.index('.position(', start)
    end = s.index('\n', pos) + 1
    block = s[start:end]
    # 去掉 .position 行
    call = block[:pos - start].rstrip() + '\n'
    # 缩进从 8 空格降到 4
    call4 = '\n'.join([ln[4:] if ln.startswith('    ') else ln for ln in call.split('\n')])
    if not call4.rstrip().endswith("')"):
        # .id(...) 行应当保留在最后；若没有 id 行则补
        pass
    builders.append('  /** %s 槽位：%s。 */\n  @Builder\n  %s() {\n%s  }\n' % (slot, comp, bname, call4))
    s = s[:start] + note + s[end:]

BUI = '\n'.join(builders)
anchor = '  build() {'
s = s.replace(anchor, BUI + '\n' + anchor, 1)

# Stage26 调用补四个槽位参数
old = "          paperZone: (): void => { this.stagePaper() },\n"
new = old + ("          basketZone: (): void => { this.stageBasket() },\n"
             "          funcRowZone: (): void => { this.stageFuncRow() },\n"
             "          fontBarZone: (): void => { this.stageFontBar() },\n"
             "          candBarZone: (): void => { this.stageCandBar() },\n")
assert old in s
s = s.replace(old, new, 1)

io.open(P, 'w', encoding='utf-8').write(s)
print('T2 zones moved:', len(ZONES))
