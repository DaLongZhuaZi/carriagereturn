/**
 * 第 24 批（23 号稿批 1／§4.4）：纸面板 —— 纸是 **UI 面板**，不是照片；打出来的字是面板里的 **Text**。
 *
 * 口径（23 号稿）：
 *  - 直角（Q13 缺省：效果图 01 的圆角卡片不取）；纸纹用仓内贴片 `ui-parts/paper-<kind>.png`；
 *  - 几何由契约推导：宽 Pw（Q16a＝stageW−2×panelMargin）、长 Ph＝Pw×1.414、可见高＝纸区高（容器 clip）；
 *  - 位置＝(paperBaseX＋V, 纸区顶)；V 由 Index 按模式算（批 1 只用当前 O 静态跟，帧时钟接线在批 3）；
 *  - 行首/行末的左右裁剪由父级 Stack 的屏边自然发生（D8／D24），本组件不额外遮罩。
 */
@Component
export struct PaperPanel {
  /** 纸面板左上角（vp）。 */
  @Prop leftVp: number = 156.35;
  @Prop topVp: number = 0;
  /** 纸宽 Pw 与纸长 Ph（Ph 是整张纸，可见高由 containerVp 裁）。 */
  @Prop widthVp: number = 330.7;
  @Prop heightVp: number = 467.61;
  /** 可见高（＝纸区高）。 */
  @Prop containerVp: number = 400;
  /** 纸纹贴片名（不带目录），例 'paper-letter.png'。 */
  @Prop textureRawfile: string = 'paper-letter.png';
  /** 纸面上已打出来的行（每项一行文字）。 */
  @Prop lines: string[] = [];
  @Prop fontSizeVp: number = 17;
  @Prop lineHeightVp: number = 30;
  @Prop marginHVp: number = 25;
  @Prop marginTVp: number = 44;
  @Prop fontFamily: string = 'CourierPrime';
  @Prop textColor: string = '#1a1a1a';
  /** 光标所在行（0 基）与列，用作光标三角。 */
  @Prop cursorLine: number = 0;
  @Prop cursorCol: number = 0;

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      // 纸纹贴片：满幅铺在面板上（直角，无圆角）
      Image($rawfile('ui-parts/' + this.textureRawfile))
        .width(this.widthVp)
        .height(this.heightVp)
        .objectFit(ImageFit.Fill)
        .borderRadius(0)

      // 纸面文字：真 Text 逐行排（行高＝lineHeightVp），左内缩 marginH、顶内缩 marginT
      Column() {
        ForEach(this.lines, (line: string, i: number) => {
          Text(line)
            .fontSize(this.fontSizeVp)
            .fontFamily(this.fontFamily)
            .fontColor(this.textColor)
            .lineHeight(this.lineHeightVp)
            .width(this.widthVp - 2 * this.marginHVp)
            .textAlign(TextAlign.Start)
            .maxLines(1)
        }, (line: string, i: number) => i.toString() + ':' + line)
      }
      .width(this.widthVp - 2 * this.marginHVp)
      .alignItems(HorizontalAlign.Start)
      .position({ x: this.marginHVp, y: this.marginTVp })
    }
    .width(this.widthVp)
    .height(this.containerVp)
    .clip(true)
    .borderRadius(0)
    .backgroundColor('#eee4ce')
  }
}
