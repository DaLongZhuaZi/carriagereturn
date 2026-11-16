/**
 * 第 24 批（23 号稿批 1）：UI 标准件契约表（纯数据，可被 Node 单测与工具脚本读取）。
 *
 * 口径来源：`docs/designs/23-App本身就是打字机-增量设计.md`
 *   §3.2 区域清单（10 个 UI 标准件）、§3.2.1 逐件几何契约实例、§3.2.2 变体维度、
 *   §3.3 六项契约通式、附录 A 的 D1–D24 推导式。
 *
 * 本批（批 1）只把 1920s 试点所需的三件填满实测值：纸面板、键盘网格、功能行；
 * 其余六件先登记几何公式与路径，数值在批 2 随件挂载时填满。
 * **本表登记 9 件**（键帽不是独立件，是键盘网格的 `capShape`／`capColor` 变体维度；
 * 设计稿 §3.2 的第 10 行「色带条」按实施提示词要求不计入本表的 9 件，随批 2 与其余件一并登记）。
 */

/** 一件六项契约（23 号稿 §3.3 通式）。 */
export interface PartContract {
  /** 件 id（小写连字符；也是 UI-件清单与换装页区域 id 的键）。 */
  id: string;
  /** 中文名（人读）。 */
  label: string;
  /** ① 几何：锚点／对齐／z 序（尺寸公式见 geometryFormula）。 */
  anchor: string;
  align: string;
  z: number;
  /** 尺寸公式（D 编号引用，数字由 measureStage 实测代入）。 */
  geometryFormula: string;
  /** ② 材质 token。 */
  material: string;
  color: string;
  finish: number;
  /** ③ 变体维度与可选值。 */
  variants: string[];
  /** ④ 替换规则（五条硬线，见设计稿 §3.3 第 4 项）。 */
  replaceRules: string[];
  /** ⑤ 动画行为（动什么量、跟谁走）。 */
  anim: string;
  /** ⑥ 交互 affordance。 */
  affordance: string;
  /** 本批状态：'filled' = 1920s 已填满实测值；'formula' = 仅登记公式与路径（批 2 填）。 */
  status: string;
  /** 贴片路径（相对 `entry/src/main/resources/rawfile/`；空串＝该件不走图片贴片）。 */
  rawfile: string;
  /** 色板采样点（相对坐标 [x,y]，0..1，取自贴片；§10.3 色板校验用）。 */
  colorSamples: number[][];
}

/** 1920s 手机口径的实测常量（measureStage 实测；换了机型/端由蓝图换算，不硬编码两套数）。 */
export interface StageMetrics {
  stageW: number;
  stageH: number;
  /** 行首落字点 archFixX（D1＝stageW/2）。 */
  archFixX: number;
  /** 纸基线 paperBaseX（D2＝archFixX−marginH）。 */
  paperBaseX: number;
  /** 纸面板宽 Pw（Q16(a)＝stageW−2×panelMargin）与纸长 Ph（＝Pw×1.414）。 */
  Pw: number;
  Ph: number;
  marginH: number;
  panelMargin: number;
  fontSizeVp: number;
  lineHeightVp: number;
  advanceEn: number;
  charsPerLine: number;
  lineWidth: number;
  maxRows: number;
  /** 五区高度（批 1 真机 measureStage 实测登记）。 */
  H_topBar: number;
  H_paperZone: number;
  H_basket: number;
  H_funcRow: number;
  H_keyGrid: number;
  /** 契约参数（设计稿 §3.2.1 缺省值）。 */
  gridMargin: number;
  leverW: number;
  leverMargin: number;
  knobMargin: number;
  knobD: number;
}

/** 实测常量（1920s／手机）。H_* 五区在批 1 真机 measureStage 里登记；此处为公式可算出的确定值。 */
export const STAGE_1920S_PHONE: StageMetrics = {
  stageW: 362.7,
  stageH: 822.5,
  archFixX: 181.35,
  paperBaseX: 156.35,
  Pw: 330.7,
  Ph: 467.61,
  marginH: 25,
  panelMargin: 16,
  fontSizeVp: 17,
  lineHeightVp: 30,
  advanceEn: 10.2,
  charsPerLine: 27,
  lineWidth: 275.4,
  maxRows: 13,
  // 五区：批 1 由 measureStage 实测后回填（此处先按设计稿 D22／D23 的定值占位，实测不同以实测为准）。
  H_topBar: 0,
  H_paperZone: 0,
  H_basket: 0,
  H_funcRow: 40,
  H_keyGrid: 0,
  gridMargin: 12,
  leverW: 10,
  leverMargin: 8,
  knobMargin: 8,
  knobD: 0,
};

/** 替换规则五条（23 号稿 §3.3 第 4 项，全件共用）。 */
export const REPLACE_RULES: string[] = [
  '几何契约逐项对齐，偏差 ≤1vp',
  '光影规范：左上顶光、5500K（§2.1）',
  '色板 ±10%（§2.1）',
  '无 baked 文字：键帽图例一律 Button 里的 Text，纸面文字一律 Text',
  '无品牌／型号／logo（风格板 §8 已定）',
];

/** 9 件契约（1920s 试点三件已填满，其余六件登记公式与路径）。 */
export const PARTS: PartContract[] = [
  {
    id: 'paper-panel',
    label: '纸面板',
    anchor: '左缘 paperBaseX（D2）',
    align: '顶缘对齐纸区顶缘；行首时左页边对准导件（D2）',
    z: 1,
    geometryFormula: 'w＝Pw（Q16a＝stageW−2×panelMargin）；h＝Ph＝Pw×1.414；paperLeft＝paperBaseX＋V（D4）',
    material: 'cream-paper-fiber',
    color: '#eee4ce',
    finish: 0,
    variants: ['texture: letter★/manuscript/postcard/memo', 'inkColor: black★/red/blue'],
    replaceRules: REPLACE_RULES,
    anim: '换行＝上滑一行高（D18）；整纸跟 V 平移（D3/D4），行末左缘被屏边裁剪（D8）',
    affordance: '不接受手势（纸只由键盘／拨杆驱动）——理由：纸面文字是选择/编辑目标，加手势会与候选栏、滚动冲突',
    status: 'filled',
    rawfile: 'ui-parts/paper-letter.png',
    colorSamples: [[0.5, 0.5], [0.2, 0.3], [0.8, 0.7]],
  },
  {
    id: 'key-grid',
    label: '键盘网格',
    anchor: '顶缘对齐功能行底缘',
    align: '帽心按 CapDef 比率×网格尺寸（硬契约 ≤2%）',
    z: 6,
    geometryFormula: 'w＝stageW−2×gridMargin；h＝H_keyGrid（D23＝帽高×行数＋行间距×(行数−1)＋上下边距＋候选栏 44vp）',
    material: 'keycap-ivory',
    color: '#f2ead6',
    finish: 0,
    variants: ['capShape: rounded-rect★/round', 'capColor: ivory★/dark/cream/lightgrey'],
    replaceRules: REPLACE_RULES,
    anim: '按下＝命中帽下沉 2vp 并换按下态图（§2.3 第 4 条）',
    affordance: '点按＝打一个字（hitAt 判定，PhotoKeybed L181 逻辑原样迁入）',
    status: 'filled',
    rawfile: 'ui-parts/keycap-face-1920s.png',
    colorSamples: [[0.5, 0.5], [0.35, 0.4], [0.65, 0.6]],
  },
  {
    id: 'function-row',
    label: '功能行',
    anchor: '全宽，顶缘贴字篮区底缘',
    align: '底缘贴键盘网格顶缘；圆角为零（UI 三铁律）',
    z: 5,
    geometryFormula: 'w＝stageW；h＝H_funcRow＝40vp（D22）',
    material: 'flat-hud-gold',
    color: '#c9a45c',
    finish: 0,
    variants: ['iconStyle: gold-line★/gold-fill'],
    replaceRules: REPLACE_RULES,
    anim: '不参与动画（功能行是 HUD，不随纸走）',
    affordance: '六个文字按钮：EN／删除／换行／换纸／退行／字符（真文字，不用图标）',
    status: 'filled',
    rawfile: '',
    colorSamples: [[0.5, 0.5], [0.1, 0.5], [0.9, 0.5]],
  },
  {
    id: 'ruler',
    label: '横尺与页边标记',
    anchor: '左缘 paperLeft(V)',
    align: '顶缘贴纸面板底缘 0vp；跟纸走（D11/D12）',
    z: 2,
    geometryFormula: 'w＝Pw；h＝8vp；页边三角：左＝paperLeft＋marginH、右＝paperRight−marginH（D12）',
    material: 'brass-ruler',
    color: '',
    finish: 0,
    variants: ['—（颜色由机身壳变体定）'],
    replaceRules: REPLACE_RULES,
    anim: '与纸面板同视觉位移 V（D11）',
    affordance: '不接受手势（刻度是标尺，不是控件）',
    status: 'formula',
    rawfile: 'ui-parts/ruler.png',
    colorSamples: [],
  },
  {
    id: 'strike-guide',
    label: '落字导件',
    anchor: 'x＝archFixX（D1）',
    align: '竖线顶缘贴纸面板顶缘；写实固定、模拟追踪（§4.2）',
    z: 3,
    geometryFormula: '竖线长 12vp、倒三角 6×4vp；模拟行末位置 min(archFixX＋0.7×accumW, stageW)（D10）',
    material: 'ink-guide',
    color: '',
    finish: 0,
    variants: ['—（形态固定：倒三角＋虚线）'],
    replaceRules: REPLACE_RULES,
    anim: '写实固定 archFixX；模拟跟落字点（D10）',
    affordance: '不接受手势（指示件）',
    status: 'formula',
    rawfile: '',
    colorSamples: [],
  },
  {
    id: 'basket',
    label: '字篮图形',
    anchor: '底缘对齐功能行顶缘',
    align: '扇形中心对齐 archFixX；底缘与功能行顶缘重合 0vp',
    z: 4,
    geometryFormula: 'w＝stageW×0.8；h＝H_basket（扇形几何，高≈宽×0.5）',
    material: 'basket-metal',
    color: '',
    finish: 0,
    variants: ['basketStyle: flat-line★/metal-gradient'],
    replaceRules: REPLACE_RULES,
    anim: '字杆绕左右向水平枢轴旋转、正面看纵向缩短（§4.3）；扇形底图不动',
    affordance: '不接受手势（机械件）',
    status: 'formula',
    rawfile: 'ui-parts/basket-fan-1920s.png',
    colorSamples: [],
  },
  {
    id: 'lever',
    label: '拨杆控件',
    anchor: 'x＝paperRight−leverW−leverMargin（D13）',
    align: '顶缘贴纸区顶缘下 20%；跟纸走（D13）',
    z: 7,
    geometryFormula: 'w＝10vp；h＝H_paperZone×0.6；angle＝rest＋ratio×swing（D16）',
    material: 'black-metal-matte',
    color: '',
    finish: 0,
    variants: ['leverShape: vertical-handle★'],
    replaceRules: REPLACE_RULES,
    anim: '被拖拽时按 dragRatio 摆动（D16）；过一次换行',
    affordance: '竖向拖拽：dragRatio＝clamp(dy/leverH,0,1)，过半触发换行',
    status: 'formula',
    rawfile: 'ui-parts/lever.png',
    colorSamples: [],
  },
  {
    id: 'knob',
    label: '旋钮控件',
    anchor: '左＝paperLeft＋knobMargin；右＝paperRight−knobD−knobMargin（D14）',
    align: '底缘贴纸面板底缘下 4vp；跟纸走（D14）',
    z: 7,
    geometryFormula: '直径 knobD＝H_paperZone×0.18；每进纸一行转 15°（D17，24 齿）',
    material: 'metal-knurl',
    color: '',
    finish: 0,
    variants: ['knobFace: metal-knurl★/matte-black'],
    replaceRules: REPLACE_RULES,
    anim: '换行时转 15°（D17）',
    affordance: '点按＝进纸一行（Q15(a)，批 2 挂载）',
    status: 'formula',
    rawfile: 'ui-parts/knob-metal.png',
    colorSamples: [],
  },
  {
    id: 'body-panel',
    label: '机身面板',
    anchor: '全屏',
    align: '底层（z＝0）；其余八件全部叠在它之上',
    z: 0,
    geometryFormula: 'w＝stageW；h＝stageH；按本端比例中心裁切（cover），铭牌位随裁切走',
    material: 'black-metal-matte',
    color: '',
    finish: 0,
    variants: ['colorway: 1920s-black★/1930s-grey/1950s-cream/1960s-lightgrey'],
    replaceRules: REPLACE_RULES,
    anim: '不动（底色层）',
    affordance: '不接受手势（背景）',
    status: 'formula',
    rawfile: 'ui-parts/bodypanel-1920s-grain.png',
    colorSamples: [],
  },
];

/** 按 id 取契约（找不到返回 null）。 */
export function partById(id: string): PartContract | null {
  for (let i = 0; i < PARTS.length; i++) {
    if (PARTS[i].id === id) {
      return PARTS[i];
    }
  }
  return null;
}


