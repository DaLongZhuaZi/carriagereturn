/**
 * 回车 · 回收站页（第 6 批 F10）— 已接入共享 PageShell（D2，§2.10）
 *
 * 数据只来自 `docStore.listTrashed()`（Index 以 docs prop 传入）：
 * 每行＝标题／入站时间（trashedAt，缺失按 updatedAt 兜底）／原卷宗名
 * （`dossierStore.find(origDossierId)`；查不到或 null → "未归档"）。
 *
 * 操作：恢复 → onRestore(id)；彻底删除 → AppDialog 二次确认 → onPurge(id)。
 * 空态显示 `trash_empty`；底部常驻保留期说明 `trash_keep_days`。
 * 本页不碰文件系统：removePermanently／restore 的调用都在 Index（页面只发意图）。
 *
 * 沉浸式（N-4）：PageShell 内已 applyImmersive，本页根 Stack 再补 expandSafeArea。
 * 弹窗结构守 AGENTS：AppDialog 的遮罩与卡片是 Stack 同层兄弟（点遮罩关、点卡片不关）。
 */

import { DocSummary } from '../model/DocModel';
import { dossierStore, Dossier } from '../services/DossierStore';
import { PageShell } from './PageShell';
import { AppDialog } from './AppDialog';
import { SpotlightStep } from './SpotlightOverlay';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { common } from '@kit.AbilityKit';

@Component
export struct TrashPage {
  @Prop widthVp: number = 673.7;
  @Prop heightVp: number = 720;
  /** 回收站文档（DocStore.listTrashed()；trashedAt/origDossierId 由 Lead 侧填充）。 */
  @Prop docs: DocSummary[] = [];
  onBack: () => void = (): void => {};
  onRestore: (id: string) => void = (id: string): void => {};
  onPurge: (id: string) => void = (id: string): void => {};
  /** 待二次确认的彻底删除目标（空＝弹窗关闭）。 */
  @State pendingPurge: string = '';
  @State revealN: number = 0;

  aboutToAppear(): void {
    this.revealN = 0;
    setTimeout(() => { this.revealN = 1; }, 16);
  }

  /** 日期时间：YYYY-MM-DD HH:mm（纯数字格式，不新增中文文案键）。 */
  private dateText(ts: number): string {
    const d: Date = new Date(ts);
    return d.getFullYear().toString() + '-' + this.pad2(d.getMonth() + 1) + '-' +
      this.pad2(d.getDate()) + ' ' + this.pad2(d.getHours()) + ':' + this.pad2(d.getMinutes());
  }

  private pad2(n: number): string {
    return n < 10 ? '0' + n.toString() : n.toString();
  }

  /** 入站时间：trashedAt 缺失（旧索引/半途崩溃）按 updatedAt 兜底（与 housekeeping 同口径）。 */
  private trashedAtOf(p: DocSummary): number {
    const t: number | undefined = p.trashedAt;
    return t === undefined || t <= 0 ? p.updatedAt : t;
  }

  /** 标题：空标题用资源键 doc_untitled（不在渲染里写硬编码中文）。 */
  private titleText(p: DocSummary): string {
    return p.title.length > 0 ? p.title : this.resolveString($r('app.string.doc_untitled'));
  }

  /** 原卷宗名：origDossierId 查不到／为 null → 资源键 trash_unknown_dossier。 */
  private origDossierText(p: DocSummary): string {
    const id: string | null | undefined = p.origDossierId;
    if (id === undefined || id === null || id.length === 0) {
      return this.resolveString($r('app.string.trash_unknown_dossier'));
    }
    const d: Dossier | null = dossierStore.find(id);
    if (d === null) {
      return this.resolveString($r('app.string.trash_unknown_dossier'));
    }
    return d.name;
  }

  /** Resource → 本地化字符串（与 ExportPage／SettingsPage 的 resolveString 同口径）。 */
  private resolveString(res: Resource): string {
    try {
      const ctx: common.UIAbilityContext | null = this.hostCtx();
      if (ctx !== null) {
        return ctx.resourceManager.getStringSync(res.id);
      }
    } catch (e) {
      // 资源缺失降级空串
    }
    return '';
  }

  private hostCtx(): common.UIAbilityContext | null {
    const host = this.getUIContext().getHostContext();
    if (host === undefined || host === null) {
      return null;
    }
    return host as common.UIAbilityContext;
  }

  @Builder
  trashRow(p: DocSummary) {
    Column() {
      Row() {
        Text(this.titleText(p))
          .fontSize(17).fontColor('#e8ddc9').maxLines(1).layoutWeight(1)
        Text($r('app.string.trash_restore')).fontSize(12).fontColor('#c9a45c')
          .padding({ left: 10, right: 6, top: 6, bottom: 6 })
          .id('restore_' + p.id)
          .onClick(() => {
            hilog.info(0x0000, 'TrashPage', 'restore tapped id=%{public}s', p.id);
            this.onRestore(p.id);
          })
        Text($r('app.string.trash_purge')).fontSize(12).fontColor('#a33327')
          .padding({ left: 6, right: 0, top: 6, bottom: 6 })
          .id('purge_' + p.id)
          .onClick(() => { this.pendingPurge = p.id; })
      }
      .width('100%')

      Text(this.dateText(this.trashedAtOf(p)))
        .fontSize(12).fontColor('rgba(232,221,201,0.6)').margin({ top: 6 })

      Row() {
        Text($r('app.string.trash_orig_dossier'))
          .fontSize(12).fontColor('rgba(232,221,201,0.4)')
        Text(this.origDossierText(p))
          .fontSize(12).fontColor('rgba(232,221,201,0.6)')
          .margin({ left: 6 }).maxLines(1).layoutWeight(1)
      }
      .width('100%').margin({ top: 4 })
    }
    .width('100%')
    .padding({ left: 14, right: 14, top: 12, bottom: 12 })
    .backgroundColor('#211b16')
    .borderRadius(12)
    .margin({ bottom: 10 })
  }

  @Builder
  body() {
    Column() {
      if (this.docs.length === 0) {
        Column() {
          Text($r('app.string.trash_empty'))
            .fontSize(12).fontColor('rgba(232,221,201,0.6)')
        }
        .width('100%').layoutWeight(1).justifyContent(FlexAlign.Center)
      } else {
        Scroll() {
          Column() {
            ForEach(this.docs, (p: DocSummary) => {
              this.trashRow(p)
            }, (p: DocSummary) => p.id)
          }
          .width('100%').padding({ left: 20, right: 20, top: 4 })
        }
        .width('100%').layoutWeight(1).scrollBar(BarState.Off)
        .id('trash__list')
      }

      // 底部常驻保留期说明（30 天＝TRASH_RETENTION_DAYS）
      Text($r('app.string.trash_keep_days'))
        .id('trash__hint')
        .fontSize(12).fontColor('rgba(232,221,201,0.4)')
        .width('100%').textAlign(TextAlign.Center)
        .padding({ left: 20, right: 20, top: 8, bottom: 12 })
    }
    .width('100%').height('100%')
    .opacity(this.revealN > 0 ? 1 : 0)
    .animation({ duration: 180, curve: Curve.EaseOut })
  }

  @Builder
  purgeBody() {
    Column() {
      Text($r('app.string.trash_purge')).fontSize(17).fontWeight(FontWeight.Bold).fontColor('#e8ddc9')
      Text($r('app.string.delete_direct_confirm'))
        .fontSize(12).fontColor('rgba(232,221,201,0.75)').margin({ top: 10 })
      Text($r('app.string.delete')).fontSize(15).fontColor('#a33327')
        .id('trash_dlg_purge')
        .width('100%').textAlign(TextAlign.Center).margin({ top: 18 })
        .onClick(() => {
          const id: string = this.pendingPurge;
          this.pendingPurge = '';
          if (id.length > 0) {
            this.onPurge(id);
          }
        })
      Text($r('app.string.cancel')).fontSize(15).fontColor('rgba(232,221,201,0.6)')
        .id('trash_dlg_cancel')
        .width('100%').textAlign(TextAlign.Center).margin({ top: 16 })
        .onClick(() => { this.pendingPurge = ''; })
    }.width('100%').alignItems(HorizontalAlign.Start)
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      PageShell({
        guidePage: 'trash',
        widthVp: this.widthVp,
        heightVp: this.heightVp,
        title: $r('app.string.trash_title'),
        onBack: () => { this.onBack(); },
        subtitle: $r('app.string.guide_trash_hint'),
        showSubtitle: true,
        content: (): void => { this.body() },
      })
      // 彻底删除二次确认（遮罩与卡片由 AppDialog 内部同层兄弟实现）
      AppDialog({
        visible: this.pendingPurge.length > 0,
        widthVp: this.widthVp,
        heightVp: this.heightVp,
        onClose: () => { this.pendingPurge = ''; },
        content: (): void => { this.purgeBody() },
      })
    }
    .width(this.widthVp).height(this.heightVp)
    // N-4：根 Stack 补 expandSafeArea（PageShell 内已 applyImmersive）
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }
}

/** Trash 页首次引导（与功能同处一源；文案键见 string.json）。 */
export function guideStepsForTrash(): SpotlightStep[] {
  return [
    { text: $r('app.string.guide_trash_1'), anchorId: 'trash__list' },
    { text: $r('app.string.guide_trash_2'), anchorId: 'trash__list' },
    { text: $r('app.string.guide_trash_3'), anchorId: 'trash__hint' },
  ];
}