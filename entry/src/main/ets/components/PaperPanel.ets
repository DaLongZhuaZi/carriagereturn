/**
 * 第 24 批（23 号稿批 1／§4.4）：纸面板 —— 纸是 **UI 面板**，不是照片；打出来的字是面板里的 **Text**。
 *
 * 口径（23 号稿）：
 *  - 直角（Q13 缺省：效果图 01 的圆角卡片不取）；纸纹用仓内贴片 `ui-parts/paper-<kind>.png`；
 *  - 几何由契约推导：宽 Pw（Q16a＝stageW−2×panelMargin）、长 Ph＝Pw×1.414、可见高＝纸区高（容器 clip）；
 *  - 位置＝(paperBaseX＋V, 纸区顶)；V 由 Index 按模式算（批 1 只跟逻辑 O，帧时钟接线在批 3）；
 *  - 行首/行末的左右裁剪由父级 Stack 的屏边自然发生（D8／D24），本组件不额外遮罩。
 */
import { hilog } from '@kit.PerformanceAnalysisKit';

const PDOMAIN: number = 0x0000;
const PTAG: string = 'PaperPanel';

@Component
export struct PaperPanel {
  /** 纸面板左上角（vp，绝对坐标）。 */
  @Prop leftVp: number = 170;
  @Prop topVp: number = 294;
  /** 纸宽 Pw 与纸长 Ph（Ph 是整张纸，可见高由 containerVp 裁）。 */
  @Prop widthVp: number = 358;
  @Prop heightVp: number = 506.2;
  /** 可见高（＝纸区高 H_paperZone）。 */
  @Prop containerVp: number = 135;
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
  /** 落字点标记（相对纸面板左/顶，vp）：批 1 用细竖标代替旧 Canvas 三角（帧时钟接线在批 3）。 */
  @Prop cursorXVp: number = 0;
  @Prop cursorYVp: number = 0;
  @Prop cursorVisible: boolean = true;

  aboutToAppear(): void {
    hilog.info(PDOMAIN, PTAG, 'mount x=%{public}s y=%{public}s w=%{public}s ph=%{public}s box=%{public}s lines=%{public}d tex=%{public}s',
      this.leftVp.toFixed(1), this.topVp.toFixed(1), this.widthVp.toFixed(1), this.heightVp.toFixed(1),
      this.containerVp.toFixed(1), this.lines.length, this.textureRawfile);
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      // 纸纹贴片：满幅铺在面板上（直角，无圆角）；整张纸长 Ph，可见部分由容器裁
      Image($rawfile('ui-parts/' + this.textureRawfile))
        .width(this.widthVp)
        .height(this.heightVp)
        .objectFit(ImageFit.Fill)
        .borderRadius(0)
        .hitTestBehavior(HitTestMode.None)

      // 纸面文字：真 Text 逐行排（行高＝lineHeightVp），左内缩 marginH、顶内缩 marginT
      Column() {
        ForEach(this.lines, (line: string, i: number) => {
          Text(line.length > 0 ? line : ' ')
            .fontSize(this.fontSizeVp)
            .fontFamily(this.fontFamily)
            .fontColor(this.textColor)
            .lineHeight(this.lineHeightVp)
            .width(this.widthVp - 2 * this.marginHVp)
            .textAlign(TextAlign.Start)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Clip })
        }, (line: string, i: number) => i.toString() + ':' + line)
      }
      .width(this.widthVp - 2 * this.marginHVp)
      .alignItems(HorizontalAlign.Start)
      .position({ x: this.marginHVp, y: this.marginTVp })
      .hitTestBehavior(HitTestMode.None)

      // 落字点标记（批 1 过渡：细竖标；批 3 落字导件接管）
      if (this.cursorVisible) {
        Column()
          .width(2)
          .height(this.fontSizeVp + 6)
          .backgroundColor(this.textColor)
          .position({ x: this.cursorXVp, y: this.cursorYVp })
          .hitTestBehavior(HitTestMode.None)
      }
    }
    .width(this.widthVp)
    .height(this.containerVp)
    .clip(true)
    .borderRadius(0)
    .backgroundColor('#eee4ce')
    .hitTestBehavior(HitTestMode.None)
    // 定位由 Index 在挂载处用 .position 施加（自定义组件根节点上的 .position 会被父 Stack 对齐覆盖——第 24 批实测）
  }
}
