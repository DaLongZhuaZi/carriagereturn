/**
 * 回车 · 键盘键位布局（纯逻辑，无 UI 依赖，可离线自测）
 *
 * 结构（6 行 41 键，调研报告 §1 + 任务卡第 7/9 点）：
 *   行 0 顶栏功能位：左「中 / EN」切换，右「退格 + 回车」
 *   行 1 数字行 10 键（上档符号取 keycaps.json 的 row.digits.shift）
 *   行 2 QWERTY 上排 10 键
 *   行 3 QWERTY 中排  9 键（整体居中缩进，复刻真实打字机的错位排布）
 *   行 4 QWERTY 下排  7 键 + 左侧 Shift
 *   行 5 空格 6 键宽
 *
 * 两个不变量：
 * 1. 键帽字符一律来自 KeycapTable（keycaps.json），本模块不含任何键帽文案，
 *    也不含功能键标签（标签走 string.json 的 keyboard_* 资源键，由组件取 $r）；
 * 2. 绘制与命中测试共用同一份矩形（KeyDef.x/y/w/h），二者不可能漂移。
 */

import { KeyAction } from '../../ui/KeyboardPanel';
import { KeycapTable, ROW_DIGITS, ROW_DIGITS_SHIFT, ROW_QWERTY1, ROW_QWERTY2, ROW_QWERTY3 } from './Keycaps';

/** 键缝（vp）。命中容差小于半个键缝，指腹略偏也能按到，但不会与邻键抢键。 */
export const KEY_GAP_VP: number = 6;
/** 命中容差（vp）：坐标落在键外 1.5vp 内仍算按到该键。 */
export const KEY_HIT_TOLERANCE_VP: number = KEY_GAP_VP * 0.25;

/** Shift 键 id：组件维护锁定态时要按 id 找它的运行时状态。 */
export const KEY_ID_SHIFT: string = 'k.shift';
/** 空格键提交的字符（不可见的控制字符，不是界面文案）。 */
export const SPACE_CHAR: string = ' ';

/** 键盘行数。 */
export const KEYBOARD_ROW_COUNT: number = 6;

/** 基准列数：一行最多 10 个标准键宽，所有行的单位宽度都按它换算。 */
const UNIT_COLUMNS: number = 10;
/** 容器内边距（vp）：左右 / 上下。 */
const PAD_H_VP: number = 8;
const PAD_V_VP: number = 6;
/** 单位键宽下限（vp），防止容器过窄时算出 0 或负数。 */
const MIN_UNIT_VP: number = 4;
/** 单行高度上限（vp）：容器再高也不把键拉成方块，多余的竖向空间上下均分。 */
const MAX_ROW_H_VP: number = 62;
/** 缩放比上限：键帽高光条 / 圆角等视觉派生值的夹取范围。 */
const MAX_RADIUS_VP: number = 12;
const MIN_RADIUS_VP: number = 2;

const DIGIT_COUNT: number = 10;
const QWERTY1_COUNT: number = 10;
const QWERTY2_COUNT: number = 9;
const QWERTY3_COUNT: number = 7;
const LANG_UNITS: number = 1.5;
const BACKSPACE_UNITS: number = 1.5;
const RETURN_UNITS: number = 2;
const SHIFT_UNITS: number = 1.5;
const SPACE_UNITS: number = 6;

/** 一行的水平对齐方式。 */
enum RowAlign {
  LEFT = 0,
  RIGHT = 1,
  CENTER = 2,
}

/**
 * 布局分组号 -> 对齐方式。
 * 顶栏是一行两组：组 0 左（中 / EN），组 1 右（退格 + 回车），故分组与视觉行号分开。
 */
const GROUP_ALIGN: RowAlign[] = [
  RowAlign.LEFT,
  RowAlign.RIGHT,
  RowAlign.LEFT,
  RowAlign.LEFT,
  RowAlign.CENTER,
  RowAlign.CENTER,
  RowAlign.CENTER,
];

/**
 * 一个键位：结构 + 字符 + 几何 + 已算好的视觉派生值。
 *
 * 字段全是基础类型（字符串 / 数字 / 枚举），且本类不提供任何方法：
 * 组件把 KeyDef 按 @Prop 传给键帽子组件时，@Prop 的深拷贝（官方文档明确会丢类型）
 * 不会影响渲染——子组件只读字段，不调方法。
 */
export class KeyDef {
  /** 键 id（结构标识，不是键帽文案）。 */
  readonly id: string;
  /** 该键的语义动作。 */
  readonly action: KeyAction;
  /** 常规态提交字符；空串表示纯功能键。 */
  readonly charBase: string;
  /** 上档态（Shift 锁定）提交字符。 */
  readonly charShift: string;
  /** 视觉行号，0 = 顶栏功能行。 */
  readonly row: number;
  /** 布局分组号，见 GROUP_ALIGN。 */
  readonly group: number;
  /** 键宽单位，1 = 标准键宽。 */
  readonly units: number;
  /** 是否显示（spec.showLanguageKey 为 false 时中 / EN 切换键不显示）。 */
  readonly visible: boolean;

  /** 矩形（vp）：相对键盘容器左上角。 */
  x: number = 0;
  y: number = 0;
  w: number = 0;
  h: number = 0;
  /** 键帽圆角（vp）。 */
  radius: number = MIN_RADIUS_VP;
  /** 键帽字符字号（vp）。 */
  labelSize: number = 12;
  /** 键帽顶面高光条几何（vp），相对键帽左上角，做浮雕受光面。 */
  hlX: number = 0;
  hlY: number = 0;
  hlW: number = 0;
  hlH: number = 1;
  /** 按下时键帽下沉距离（vp）。 */
  sink: number = 1.6;
  /** 静止时键槽阴影相对键帽的下移距离（vp）。 */
  shadowDrop: number = 2;

  constructor(id: string, action: KeyAction, charBase: string, charShift: string, row: number, group: number, units: number, visible: boolean) {
    this.id = id;
    this.action = action;
    this.charBase = charBase;
    this.charShift = charShift;
    this.row = row;
    this.group = group;
    this.units = units;
    this.visible = visible;
  }
}

/**
 * 生成整套键位表（含几何）。
 *
 * @param widthVp 键盘容器宽（vp）；<= 0 时只出结构，几何留 0（组件在拿到真实尺寸前不画键）。
 * @param heightVp 键盘容器高（vp）。
 * @param table 键帽字符表；缺行时对应键帽留白（但结构仍在，功能键照常工作）。
 * @param showLanguageKey 是否显示中 / EN 切换键（契约 KeyboardViewSpec.showLanguageKey）。
 */
export function buildKeyLayout(widthVp: number, heightVp: number, table: KeycapTable, showLanguageKey: boolean): KeyDef[] {
  const defs: KeyDef[] = [];

  // 行 0：顶栏功能位（左：中 / EN；右：退格 + 回车）
  defs.push(new KeyDef('k.lang', KeyAction.SWITCH_LANGUAGE, '', '', 0, 0, LANG_UNITS, showLanguageKey));
  defs.push(new KeyDef('k.back', KeyAction.BACKSPACE, '', '', 0, 1, BACKSPACE_UNITS, true));
  defs.push(new KeyDef('k.ret', KeyAction.RETURN, '', '', 0, 1, RETURN_UNITS, true));

  // 行 1：数字行（字符与上档符号都来自 keycaps.json）
  for (let i = 0; i < DIGIT_COUNT; i++) {
    defs.push(new KeyDef('k.d' + String(i), KeyAction.INSERT, table.charAt(ROW_DIGITS, i), table.charAt(ROW_DIGITS_SHIFT, i), 1, 2, 1, true));
  }

  // 行 2 / 3：QWERTY 上排、中排
  pushLetterRow(defs, table, ROW_QWERTY1, QWERTY1_COUNT, 'k.r1', 2, 3);
  pushLetterRow(defs, table, ROW_QWERTY2, QWERTY2_COUNT, 'k.r2', 3, 4);

  // 行 4：Shift + QWERTY 下排（Shift 先入，故排在行首）
  defs.push(new KeyDef(KEY_ID_SHIFT, KeyAction.SHIFT, '', '', 4, 5, SHIFT_UNITS, true));
  pushLetterRow(defs, table, ROW_QWERTY3, QWERTY3_COUNT, 'k.r3', 4, 5);

  // 行 5：空格
  defs.push(new KeyDef('k.space', KeyAction.SPACE, SPACE_CHAR, SPACE_CHAR, 5, 6, SPACE_UNITS, true));

  layoutGeometry(defs, widthVp, heightVp);
  return defs;
}

/** 坐标到键位：命中返回键 id，落空返回空串（机架缝上不压任何键）。 */
export function hitTestKey(defs: KeyDef[], xVp: number, yVp: number, toleranceVp: number): string {
  for (let i = 0; i < defs.length; i++) {
    const def: KeyDef = defs[i];
    if (!def.visible) {
      continue;
    }
    if (xVp < def.x - toleranceVp || xVp > def.x + def.w + toleranceVp) {
      continue;
    }
    if (yVp < def.y - toleranceVp || yVp > def.y + def.h + toleranceVp) {
      continue;
    }
    return def.id;
  }
  return '';
}

/** 按行键推入一行的字符键（上档字符 = 大写，由代码从键帽字符派生，不在资源里重复字母表）。 */
function pushLetterRow(defs: KeyDef[], table: KeycapTable, rowKey: string, count: number, idPrefix: string, row: number, group: number): void {
  for (let i = 0; i < count; i++) {
    const base: string = table.charAt(rowKey, i);
    defs.push(new KeyDef(idPrefix + '.' + String(i), KeyAction.INSERT, base, base.toUpperCase(), row, group, 1, true));
  }
}

/** 几何：由容器尺寸算出每个键的矩形；分组内按 units 比例排布，再按对齐方式落位。 */
function layoutGeometry(defs: KeyDef[], widthVp: number, heightVp: number): void {
  if (widthVp <= 0 || heightVp <= 0) {
    return;
  }
  const contentW: number = Math.max(0, widthVp - PAD_H_VP * 2);
  const contentH: number = Math.max(0, heightVp - PAD_V_VP * 2);
  const unit: number = Math.max(MIN_UNIT_VP, (contentW - (UNIT_COLUMNS - 1) * KEY_GAP_VP) / UNIT_COLUMNS);
  const rowH: number = Math.min(MAX_ROW_H_VP, Math.max(0, (contentH - (KEYBOARD_ROW_COUNT - 1) * KEY_GAP_VP) / KEYBOARD_ROW_COUNT));
  const blockH: number = rowH * KEYBOARD_ROW_COUNT + (KEYBOARD_ROW_COUNT - 1) * KEY_GAP_VP;
  const topVp: number = PAD_V_VP + Math.max(0, (contentH - blockH) / 2);

  for (let group = 0; group < GROUP_ALIGN.length; group++) {
    const members: KeyDef[] = groupMembers(defs, group);
    if (members.length === 0) {
      continue;
    }
    const rowVp: number = topVp + members[0].row * (rowH + KEY_GAP_VP);
    let usedW: number = 0;
    for (let i = 0; i < members.length; i++) {
      usedW += members[i].units * unit;
    }
    usedW += (members.length - 1) * KEY_GAP_VP;
    const leftover: number = Math.max(0, contentW - usedW);
    let cursor: number = PAD_H_VP;
    if (GROUP_ALIGN[group] === RowAlign.RIGHT) {
      cursor = PAD_H_VP + leftover;
    } else if (GROUP_ALIGN[group] === RowAlign.CENTER) {
      cursor = PAD_H_VP + leftover / 2;
    }
    for (let i = 0; i < members.length; i++) {
      const def: KeyDef = members[i];
      def.x = cursor;
      def.y = rowVp;
      def.w = def.units * unit;
      def.h = rowH;
      cursor += def.w + KEY_GAP_VP;
    }
  }
  for (let i = 0; i < defs.length; i++) {
    applyKeyVisual(defs[i]);
  }
}

/** 取出同一布局分组的键（保持数组顺序 = 行内从左到右）。 */
function groupMembers(defs: KeyDef[], group: number): KeyDef[] {
  const members: KeyDef[] = [];
  for (let i = 0; i < defs.length; i++) {
    if (defs[i].group === group) {
      members.push(defs[i]);
    }
  }
  return members;
}

/** 视觉派生值：圆角、字号、高光条几何、下沉量。全部只依赖矩形，避免渲染期再算。 */
function applyKeyVisual(def: KeyDef): void {
  const shortSide: number = Math.min(def.w, def.h);
  def.radius = clamp(shortSide * 0.18, MIN_RADIUS_VP, MAX_RADIUS_VP);
  def.hlW = def.w * 0.78;
  def.hlH = clamp(def.h * 0.06, 1, 3);
  def.hlX = def.w * 0.11;
  def.hlY = clamp(def.h * 0.11, 1.5, 5);
  def.sink = clamp(def.h * 0.07, 1, 2.2);
  def.shadowDrop = clamp(def.h * 0.08, 1, 2.6);
  if (def.action === KeyAction.INSERT) {
    def.labelSize = clamp(def.h * 0.42, 10, 20);
  } else if (def.action === KeyAction.SWITCH_LANGUAGE) {
    def.labelSize = clamp(def.h * 0.24, 7, 11);
  } else {
    def.labelSize = clamp(def.h * 0.30, 8, 13);
  }
}

/** 夹取到 [min, max]。 */
function clamp(value: number, min: number, max: number): number {
  if (value < min) {
    return min;
  }
  if (value > max) {
    return max;
  }
  return value;
}
