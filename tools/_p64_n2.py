# 批 64（T2 前哨／N2）：Carriage26 与 TopZone26 的容器宽改成机器宽（362.7·k），不再用整画布宽
import io

P = r'entry/src/main/ets/pages/Index.ets'
s = io.open(P, encoding='utf-8').read()

HELPER = """  /** 批 64（N2）：机器宽＝362.7·k（打字页三容器的基准，不再用整画布宽）。 */
  private machineWidth26(): number {
    return 362.7 * this.xk();
  }

"""
anchor = "  private machineOffsetX26(): number {"
if 'private machineWidth26(): number' not in s and anchor in s:
    s = s.replace(anchor, HELPER + anchor, 1)

# 只改 Carriage26 与 TopZone26 两处（其余 mount 不动，避免影响机身底纹等）
OLD_C = """        Carriage26({
          machine: this.machineKind,
          widthVp: this.canvasWidthVp(),"""
NEW_C = """        Carriage26({
          machine: this.machineKind,
          // 批 64（N2）：容器宽＝机器宽（475.3vp），右缘落在机器右缘内（不再按整画布 673.7vp 越界）
          widthVp: this.machineWidth26(),"""
OLD_T = """        TopZone26({
          machine: this.machineKind,
          widthVp: this.canvasWidthVp(),"""
NEW_T = """        TopZone26({
          machine: this.machineKind,
          // 批 64（N2）：同上，顶区宽＝机器宽
          widthVp: this.machineWidth26(),"""

if OLD_C in s:
    s = s.replace(OLD_C, NEW_C, 1)
else:
    raise SystemExit('Carriage26 anchor missing')
if OLD_T in s:
    s = s.replace(OLD_T, NEW_T, 1)
else:
    raise SystemExit('TopZone26 anchor missing')

io.open(P, 'w', encoding='utf-8').write(s)
print('N2 width patch applied; helper:', 'private machineWidth26' in s)
