/**
 * 第 25 批（23 号稿 §3.2 #3／§2.5 第 2 条）：落字导件 —— 纸区中央的 UI 标记（**矢量例外**，不入库图片）。
 * 形态：1vp 竖向虚线（3 段）＋ 6×4vp 倒三角；锚点 x＝archFixX（写实固定）／模拟追踪落字点（批 3 帧时钟接线）。
 */
@Component
export struct StrikeGuide {
  @Prop lineHeightVp: number = 12;
  @Prop color: string = '#beb4a8';
  @Prop triangleW: number = 6;
  @Prop triangleH: number = 4;

  build() {
    Column() {
      ForEach([0, 1, 2], (i: number) => {
        Column()
          .width(1)
          .height(3)
          .backgroundColor(this.color)
          .margin({ top: i === 0 ? 0 : 1 })
      }, (i: number) => i.toString())
      Polygon({ width: this.triangleW, height: this.triangleH })
        .points([[0, 0], [this.triangleW, 0], [this.triangleW / 2, this.triangleH]])
        .fill(this.color)
        .margin({ top: 1 })
    }
    .width(this.triangleW)
    .alignItems(HorizontalAlign.Center)
    .hitTestBehavior(HitTestMode.None)
  }
}
