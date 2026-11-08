/**
 * 回车 · 收藏详情页（§3）+ 沉浸式（§2.10）
 *
 * 顶部 side 大图；中部 keyboard 与 carriage 特写左右并排；下部史实文字 15vp/行高 24vp；
 * 史实之后是「进度」区（总字数／连续天数／用过纸张种类，F14 非阈值项）＋"待定"条件行；
 * 底部「设为当前机器」深色按钮（全宽 48vp，底距 = bottomInset）。
 * 锁定态铁律：本页只对已解锁机器开放（入口在 CollectionPage 已拦）。
 * 阈值项 Q2 未决期间一律显示"待定（阈值待批准）"，不显示 5000 字/7 天/3 次等数字。
 */

import { PageShell } from './PageShell';
import { GuideStep } from './GuideOverlay';

// P2-5：史实文字走 string.json
const M_INFO: Record<string, Resource> = {
  '1920s-upright': $r('app.string.machine_info_1920s'),
  '1930s-portable': $r('app.string.machine_info_1930s'),
  '1950s-streamlined': $r('app.string.machine_info_1950s'),
  '1960s-electric': $r('app.string.machine_info_1960s'),
};

@Component
export struct CollectionDetailPage {
  @Prop widthVp: number = 673.7;
  @Prop heightVp: number = 720;
  @Prop machineKind: string = '1920s-upright';
  /** 第 4 批 F14：进度区数据（StatsService 单一派生层；非阈值项）。 */
  @Prop totalWords: number = 0;
  @Prop streakDays: number = 0;
  @Prop paperKindsUsed: number = 0;
  @State topInset: number = 28;
  @State bottomInset: number = 0;
  onBack: () => void = (): void => {};
  onSetCurrent: (kind: string) => void = (): void => {};

  @State revealN: number = 0;

  aboutToAppear(): void {
    // D6：收藏详情补入场动画（60ms 逐块）；第 4 批扩到 4 块（进度区为第 4 块）
    this.revealN = 0;
    for (let i = 0; i < 4; i++) {
      setTimeout(() => { this.revealN = i + 1; }, i * 60);
    }
  }

  @Builder
  body() {
    Column() {
        Scroll() {
          Column() {
            // 顶部 side 大图
            Image($rawfile('machine/' + this.machineKind + '-side.jpg'))
              .width('100%').height(260).objectFit(ImageFit.Cover).borderRadius(12)
              .opacity(this.revealN > 0 ? 1 : 0)
              .animation({ duration: 180, curve: Curve.EaseOut })

            // 中部两张特写并排
            Row() {
              Image($rawfile('machine/' + this.machineKind + '-keyboard.jpg'))
                .layoutWeight(1).height(150).objectFit(ImageFit.Cover).borderRadius(10)
              Column().width(12)
              Image($rawfile('machine/' + this.machineKind + '-carriage.jpg'))
                .layoutWeight(1).height(150).objectFit(ImageFit.Cover).borderRadius(10)
            }.width('100%').margin({ top: 12 })
            .opacity(this.revealN > 1 ? 1 : 0)
            .animation({ duration: 180, curve: Curve.EaseOut })

            // 史实文字
            Text(M_INFO[this.machineKind])
              .fontSize(15).lineHeight(24).fontColor('rgba(232,221,201,0.75)')
              .width('100%').margin({ top: 16 })
              .opacity(this.revealN > 2 ? 1 : 0)
              .animation({ duration: 180, curve: Curve.EaseOut })

            // 进度区（F14）：只显示非阈值事实；阈值条件行统一"待定"（B-3）
            // 注：三行直接写在本页 build 里（不用 @Builder 按值传参——本仓 2026-11-09 真机定位
            // 过"@Builder 按值传参不建立依赖，值变化不刷新"，进度数字必须随 stats props 刷新）
            Column() {
              Column().width('100%').height(1).backgroundColor('rgba(232,221,201,0.25)')
              Row() {
                Text($r('app.string.collection_total_words'))
                  .fontSize(15).fontColor('rgba(232,221,201,0.75)')
                Blank()
                Text(this.totalWords.toString())
                  .fontSize(15).fontColor('#c9a45c')
              }.width('100%').height(40)
              Row() {
                Text($r('app.string.collection_streak'))
                  .fontSize(15).fontColor('rgba(232,221,201,0.75)')
                Blank()
                Text(this.streakDays.toString())
                  .fontSize(15).fontColor('#c9a45c')
              }.width('100%').height(40)
              Row() {
                Text($r('app.string.collection_paper_kinds'))
                  .fontSize(15).fontColor('rgba(232,221,201,0.75)')
                Blank()
                Text(this.paperKindsUsed.toString())
                  .fontSize(15).fontColor('#c9a45c')
              }.width('100%').height(40)
              Row() {
                Text($r('app.string.collection_pending'))
                  .fontSize(13).fontColor('rgba(232,221,201,0.5)')
              }
              .width('100%').height(32)
            }
            .width('100%').margin({ top: 16 })
            .opacity(this.revealN > 3 ? 1 : 0)
            .animation({ duration: 180, curve: Curve.EaseOut })
          }
          .width('100%').padding({ left: 20, right: 20 })
        }
        .layoutWeight(1).width('100%').scrollBar(BarState.Off)

        // 底部「设为当前机器」（底距交给 PageShell）
        Text('设为当前机器')
          .fontSize(17).fontColor('#e8ddc9')
          .width('100%').height(56).textAlign(TextAlign.Center)
          .borderRadius(28).backgroundColor('#2e2620')
          .margin({ left: 20, right: 20, bottom: 8 })
          .onClick(() => { this.onSetCurrent(this.machineKind); })
    }
    .width('100%').height('100%')
  }

  build() {
    PageShell({
      widthVp: this.widthVp,
      heightVp: this.heightVp,
      title: '收藏',
      onBack: () => { this.onBack(); },
      subtitle: $r('app.string.guide_collection_detail_hint'),
      showSubtitle: true,
      content: (): void => { this.body() },
    })
  }
}

/** CollectionDetail 页首次引导（与功能同处一源；文案键见 string.json）。 */
export function guideStepsForCollectionDetail(): GuideStep[] {
  return [
    { text: $r('app.string.guide_collection_detail_1') },
    { text: $r('app.string.guide_collection_detail_2') },
    { text: $r('app.string.guide_collection_detail_3') },
  ];
}
