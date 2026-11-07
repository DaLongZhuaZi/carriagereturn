/**
 * 回车 · 收藏详情页（§3）+ 沉浸式（§2.10）
 *
 * 顶部 side 大图；中部 keyboard 与 carriage 特写左右并排；下部史实文字 15vp/行高 24vp；
 * 底部「设为当前机器」深色按钮（全宽 48vp，底距 = bottomInset）。
 * 锁定态铁律：本页只对已解锁机器开放（入口在 CollectionPage 已拦）。
 */

import { PageShell } from './PageShell';

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
  @State topInset: number = 28;
  @State bottomInset: number = 0;
  onBack: () => void = (): void => {};
  onSetCurrent: (kind: string) => void = (): void => {};

  @State revealN: number = 0;

  aboutToAppear(): void {
    // D6：收藏详情补入场动画（60ms 逐块）
    this.revealN = 0;
    for (let i = 0; i < 3; i++) {
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
      content: (): void => { this.body() },
    })
  }
}
