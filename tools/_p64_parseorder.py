# 批 64（T5 前半）：给 KeymapParser 加「去坐标」接口 parseOrder（不动老 parse，可回退）
import io

P = r'entry/src/main/ets/model/KeymapModel.ets'
s = io.open(P, encoding='utf-8').read()

IFACE = """
/** 批 64（阶段 1／T5）：去坐标后的键逻辑序（KeyGrid 按 flex 排布用）。 */
export interface CapOrder {
  row: number;
  col: number;
  label: string;
  shape: string;
  overlayColor: string;
  overlayFontSize: number;
}
"""

s = s.replace("export interface KeymapLayout {", IFACE.strip() + "\n\nexport interface KeymapLayout {", 1)

METHOD = """
  /**
   * 批 64（阶段 1／T5）：只输出键的**逻辑顺序与尺寸**，不输出 x／y 坐标。
   * KeyGrid 拿到后按 `Row`＋`justifyContent: SpaceBetween` 排布；老 `parse()` 保留给旧布局/回退用。
   * overlay 颜色与字号按本次调用统一给（批次内同一键位表共用一套 overlay）。
   */
  static parseOrder(jsonText: string, machine: string, fold: boolean,
    overlayColor: string, overlayFontSize: number): CapOrder[] {
    const raw: RawKeymap = JSON.parse(jsonText) as RawKeymap;
    const out: CapOrder[] = [];
    for (let r = 0; r < raw.rows.length; r++) {
      const row: RawRow = raw.rows[r];
      for (let c = 0; c < row.caps.length; c++) {
        const cap: RawCap = row.caps[c];
        const shape: string = (cap.shape === undefined || cap.shape.length === 0)
          ? 'circle' : cap.shape;
        out.push({
          row: r, col: c, label: cap.label, shape: shape,
          overlayColor: overlayColor, overlayFontSize: overlayFontSize,
        });
      }
    }
    return out;
  }
"""

anchor = "  static parse(jsonText: string, machine: string, fold: boolean, widthVp: number, heightVp: number,"
if anchor not in s:
    raise SystemExit('parse anchor missing')
s = s.replace(anchor, METHOD + "\n" + anchor, 1)

io.open(P, 'w', encoding='utf-8').write(s)
print('parseOrder added')
