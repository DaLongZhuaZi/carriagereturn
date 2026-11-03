/**
 * 回车 · 键帽字符表（键帽上的字符来源）
 *
 * 硬约束（开工提示词 §三 + 任务卡）：
 * - 键帽字符不写死在渲染逻辑里：全部来自 resources/rawfile/keyboard/keycaps.json，
 *   本模块只做「文本 -> 解析 -> 查表」，自身不内置任何字母 / 数字 / 符号；
 * - 功能键标签（Shift / 退格 / 回车 / 中 / EN）走 string.json 的 keyboard_* 资源键，不在本模块；
 * - ArkTS 显式类型，禁 any / unknown：JSON.parse 的结果一次性断言成
 *   Record<string, string[]>，再逐项做「数组 + 字符串」运行期校验，坏数据跳过不崩。
 *
 * 表结构固定为「对象 -> 字符串数组」：键是行键（row.*），值是这一行自左向右的键帽字符。
 */

/** 数字行：常规态字符。 */
export const ROW_DIGITS: string = 'row.digits';
/** 数字行：上档符号（Shift 锁定态提交）。 */
export const ROW_DIGITS_SHIFT: string = 'row.digits.shift';
/** QWERTY 上排字母。 */
export const ROW_QWERTY1: string = 'row.qwerty1';
/** QWERTY 中排字母。 */
export const ROW_QWERTY2: string = 'row.qwerty2';
/** QWERTY 下排字母。 */
export const ROW_QWERTY3: string = 'row.qwerty3';

/** 键帽表 rawfile 路径（相对 resources/rawfile/）。 */
export const KEYCAP_RAWFILE: string = 'keyboard/keycaps.json';

/** 键帽字符表：行键 -> 该行键帽字符数组。 */
export class KeycapTable {
  private readonly rows: Map<string, string[]> = new Map<string, string[]>();

  /** 写入一行（仅供 parseKeycapTable 使用）。 */
  put(rowKey: string, chars: string[]): void {
    this.rows.set(rowKey, chars);
  }

  /** 是否有该行。 */
  has(rowKey: string): boolean {
    return this.rows.has(rowKey);
  }

  /** 该行字符数组；缺行返回空数组（该行全部键帽留白，不上屏）。 */
  rowChars(rowKey: string): string[] {
    const chars: string[] | undefined = this.rows.get(rowKey);
    if (chars === undefined) {
      return [];
    }
    return chars;
  }

  /** 该行第 index 个字符；越界返回空串。 */
  charAt(rowKey: string, index: number): string {
    const chars: string[] | undefined = this.rows.get(rowKey);
    if (chars === undefined || index < 0 || index >= chars.length) {
      return '';
    }
    return chars[index];
  }

  /** 已解析的行数（自检与日志用）。 */
  rowCount(): number {
    return this.rows.size;
  }

  /** 是否一行都没解析出来。 */
  isEmpty(): boolean {
    return this.rows.size === 0;
  }
}

/**
 * 解析键帽表文本。
 *
 * 失败（空文本 / JSON 语法错 / 结构不符）一律返回空表或已收集到的部分，
 * 不抛异常、不崩溃；由调用方按 isEmpty 记日志并在回报里暴露。
 */
export function parseKeycapTable(jsonText: string): KeycapTable {
  const table: KeycapTable = new KeycapTable();
  if (jsonText.length === 0) {
    return table;
  }
  try {
    const parsed: Record<string, string[]> = JSON.parse(jsonText) as Record<string, string[]>;
    const rowKeys: string[] = Object.keys(parsed);
    for (let i = 0; i < rowKeys.length; i++) {
      const rowKey: string = rowKeys[i];
      if (rowKey.startsWith('_')) {
        continue;
      }
      const raw: string[] = parsed[rowKey];
      if (!Array.isArray(raw)) {
        continue;
      }
      const chars: string[] = [];
      for (let j = 0; j < raw.length; j++) {
        const ch = raw[j];
        if (typeof ch === 'string') {
          chars.push(ch);
        }
      }
      table.put(rowKey, chars);
    }
  } catch (e) {
    // 文本不是合法 JSON：返回已收集内容（此处为空表），错误由调用方记日志。
  }
  return table;
}
