/**
 * 第 27 批（23 号稿批 4／§5.4／R-m24）：标准件变体登记（10 件 × 4 机型 = 40 个持久化键的数据源）。
 *
 * 口径：变体只换 token 不换几何（§3.1）——换帽形不改帽心、换字篮档不改 Pw、换旋钮面不改任何动画量。
 * 本批登记 10 件（含设计稿 §3.2 第 10 件色带条；与 §3 的 9 件差异按冻结事项第 5 条如实记）。
 */
import { MachineKind } from './DocModel';

export interface PartVariantSpec {
  /** 件 id（与 PartContract.ets 的 id 对齐；色带条为 ribbon-strip）。 */
  part: string;
  /** 可选值（第一个为缺省）。 */
  values: string[];
  /** 每机缺省（键为 MachineKind 字符串）。 */
  defaults: Record<string, string>;
}

/** 10 件；环色带条单独一件（§3.2 #10）。 */
export const PART_VARIANTS: PartVariantSpec[] = [
  {
    part: 'paper-panel', values: ['letter', 'manuscript', 'postcard', 'memo'],
    defaults: { '1920s-upright': 'letter', '1930s-portable': 'letter', '1950s-streamlined': 'letter', '1960s-electric': 'letter' },
  },
  {
    part: 'key-grid', values: ['rounded-rect', 'round'],
    defaults: { '1920s-upright': 'rounded-rect', '1930s-portable': 'rounded-rect', '1950s-streamlined': 'rounded-rect', '1960s-electric': 'rounded-rect' },
  },
  {
    part: 'function-row', values: ['gold-line', 'gold-fill'],
    defaults: { '1920s-upright': 'gold-line', '1930s-portable': 'gold-line', '1950s-streamlined': 'gold-line', '1960s-electric': 'gold-line' },
  },
  {
    part: 'ruler', values: ['plain'],
    defaults: { '1920s-upright': 'plain', '1930s-portable': 'plain', '1950s-streamlined': 'plain', '1960s-electric': 'plain' },
  },
  {
    part: 'strike-guide', values: ['triangle'],
    defaults: { '1920s-upright': 'triangle', '1930s-portable': 'triangle', '1950s-streamlined': 'triangle', '1960s-electric': 'triangle' },
  },
  {
    part: 'basket', values: ['flat-line', 'metal-gradient'],
    defaults: { '1920s-upright': 'flat-line', '1930s-portable': 'flat-line', '1950s-streamlined': 'flat-line', '1960s-electric': 'flat-line' },
  },
  {
    part: 'lever', values: ['vertical-handle'],
    defaults: { '1920s-upright': 'vertical-handle', '1930s-portable': 'vertical-handle', '1950s-streamlined': 'vertical-handle', '1960s-electric': 'vertical-handle' },
  },
  {
    part: 'knob', values: ['metal-knurl', 'matte-black'],
    defaults: { '1920s-upright': 'metal-knurl', '1930s-portable': 'metal-knurl', '1950s-streamlined': 'metal-knurl', '1960s-electric': 'metal-knurl' },
  },
  {
    part: 'body-panel', values: ['1920s-black', '1930s-grey', '1950s-cream', '1960s-lightgrey'],
    defaults: { '1920s-upright': '1920s-black', '1930s-portable': '1930s-grey', '1950s-streamlined': '1950s-cream', '1960s-electric': '1960s-lightgrey' },
  },
  {
    part: 'ribbon-strip', values: ['black', 'red', 'blue'],
    defaults: { '1920s-upright': 'black', '1930s-portable': 'black', '1950s-streamlined': 'black', '1960s-electric': 'black' },
  },
];

/** 件 id 对应的机型缺省变体。 */
export function defaultVariant(part: string, machine: string): string {
  for (const s of PART_VARIANTS) {
    if (s.part === part) {
      const d: string | undefined = s.defaults[machine];
      return d !== undefined ? d : s.values[0];
    }
  }
  return '';
}

/** 变体合法性（非法值回缺省，不抛）。 */
export function sanitizeVariant(part: string, machine: string, value: string): string {
  for (const s of PART_VARIANTS) {
    if (s.part === part) {
      return s.values.indexOf(value) >= 0 ? value : defaultVariant(part, machine);
    }
  }
  return '';
}

/** 持久化键：ui.part.<part>.<machine>（40 键 = 10 件 × 4 机型）。 */
export function partPrefKey(part: string, machine: string): string {
  return 'ui.part.' + part + '.' + machine;
}

/** 机身配色变体 → 机身 slug（用于 bodypanel-<slug>-grain.png 与机身色）。 */
export function bodySlugOfVariant(variant: string): string {
  if (variant === '1930s-grey') { return '1930s'; }
  if (variant === '1950s-cream') { return '1950s'; }
  if (variant === '1960s-lightgrey') { return '1960s'; }
  return '1920s';
}

/** 机身配色变体 → 机身色（§2.5 第 5 条）。 */
export function bodyColorOfVariant(variant: string): string {
  if (variant === '1930s-grey') { return '#3d3732'; }
  if (variant === '1950s-cream') { return '#c8b9a6'; }
  if (variant === '1960s-lightgrey') { return '#928b82'; }
  return '#312b24';
}
