/**
 * 回车 · 收藏详情页（§3）+ 沉浸式（§2.10）
 *
 * 顶部 side 大图；中部 keyboard 与 carriage 特写左右并排；下部史实文字 15vp/行高 24vp；
 * 底部「设为当前机器」深色按钮（全宽 48vp，底距 = bottomInset）。
 * 锁定态铁律：本页只对已解锁机器开放（入口在 CollectionPage 已拦）。
 */

import { applyImmersive, Insets } from '../services/Immersive';
import { hilog } from '@kit.PerformanceAnalysisKit';

const M_INFO: Record<string, string> = {
  '1920s-upright': '1920 年代直立式打字机：字杆篮在纸前扇形展开，每击一次抬起一根字杆，' +
    '经色带撞纸落墨。机身以木座承重，滚筒横置于纸后，换行时整条滚轮随字车滑回。',
  '1930s-portable': '1930 年代便携式：机身收进手提箱，字杆与键位被压缩到更紧凑的布局，' +
    '是记者与旅行作家随身的写作工具。',
  '1950s-streamlined': '1950 年代流线型：外壳改用一体成型的圆润金属，色彩取代了此前的黑与灰，' +
    '把打字机从办公器具变成了客厅里的物件。',
  '1960s-electric': '1960 年代电动式：以电机驱动字杆与滚筒，击键只需触发电路，' +
    '手感由机械阻力变为轻盈的回弹，是打字机时代最后的形态。',
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

  aboutToAppear(): void {
    this.applyInsets();
  }

  private async applyInsets(): Promise<void> {
    const ins: Insets = await applyImmersive(this.getUIContext());
    this.topInset = ins.top;
    this.bottomInset = ins.bottom;
    hilog.info(0x0000, 'CollectionDetail', 'insets top=%{public}s bottom=%{public}s',
      ins.top.toFixed(1), ins.bottom.toFixed(1));
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column() {
        // §2.10：顶部 side 大图顶距 = topInset
        Column().width('100%').height(this.topInset)
        Row() {
          Text('‹').fontSize(26).fontColor('#e8ddc9')
            .width(44).height(44).textAlign(TextAlign.Center)
            .onClick(() => { this.onBack(); })
        }.width('100%').padding({ left: 12, top: 4, bottom: 4 })

        Scroll() {
          Column() {
            // 顶部 side 大图
            Image($rawfile('machine/' + this.machineKind + '-side.jpg'))
              .width('100%').height(260).objectFit(ImageFit.Cover).borderRadius(12)

            // 中部两张特写并排
            Row() {
              Image($rawfile('machine/' + this.machineKind + '-keyboard.jpg'))
                .layoutWeight(1).height(150).objectFit(ImageFit.Cover).borderRadius(10)
              Column().width(12)
              Image($rawfile('machine/' + this.machineKind + '-carriage.jpg'))
                .layoutWeight(1).height(150).objectFit(ImageFit.Cover).borderRadius(10)
            }.width('100%').margin({ top: 12 })

            // 史实文字
            Text(M_INFO[this.machineKind])
              .fontSize(15).lineHeight(24).fontColor('rgba(232,221,201,0.82)')
              .width('100%').margin({ top: 16 })

            Column().width('100%').height(this.bottomInset)
          }
          .width('100%').padding({ left: 20, right: 20 })
        }
        .layoutWeight(1).width('100%').scrollBar(BarState.Off)

        // 底部「设为当前机器」（全宽 48vp，底距 = bottomInset）
        Text('设为当前机器')
          .fontSize(15).fontColor('#e8ddc9')
          .width('100%').height(48).textAlign(TextAlign.Center)
          .borderRadius(24).backgroundColor('#2e2620')
          .margin({ left: 20, right: 20, bottom: this.bottomInset })
          .onClick(() => { this.onSetCurrent(this.machineKind); })
      }
      .width('100%').height('100%')
    }
    .width(this.widthVp).height(this.heightVp)
    .linearGradient({ direction: GradientDirection.Bottom,
      colors: [['#171310', 0.0], ['#241c16', 1.0]] })
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }
}
