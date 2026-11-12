/** 回车 · 第 13 批 ⑥：导出目标的模块级传递（跨 @Prop 时序的可靠载体）。
 *
 * 为什么需要：Index 在点击回调里置 @State 后立刻 pushPage 时，子组件 @Prop 会拿到旧值
 * （实测 ExportPage 读到空 dossierId）；加 setTimeout 延迟又会让页面压栈与过渡交错。
 * 入口先写本模块，ExportPage 在 aboutToAppear 读一次，就不依赖 prop 时序。
 */

export interface ExportTargetData {
  docId: string;
  dossierId: string;
  scope: string;
}

const EMPTY_TARGET: ExportTargetData = { docId: '', dossierId: '', scope: '' };
let current: ExportTargetData = EMPTY_TARGET;

export function setExportTarget(t: ExportTargetData): void {
  current = { docId: t.docId, dossierId: t.dossierId, scope: t.scope };
}

export function getExportTarget(): ExportTargetData {
  return current;
}

export function clearExportTarget(): void {
  current = EMPTY_TARGET;
}
