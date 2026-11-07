/**
 * 回车 · 提示条 HintBar（D3，§3 解锁提示）
 *
 * 顶部下滑、3 秒自动消失、点按关闭；锁定提示与解锁达成提示共用这一条。
 */

@Component
export struct HintBar {
  @Prop text: string = '';
  @Prop topInset: number = 28;
  @State shown: boolean = false;
  @State ty: number = -60;
  onDismiss: () => void = (): void => {};
  private timer: number = -1;

  aboutToAppear(): void {
    if (this.text.length > 0) {
      this.play();
    }
  }

  aboutToDisappear(): void {
    if (this.timer >= 0) {
      clearTimeout(this.timer);
    }
  }

  /** 由父组件在文案变化时调用：下滑出现，3 秒后自动收起。 */
  play(): void {
    this.shown = true;
    this.ty = -60;
    setTimeout(() => { this.ty = 0; }, 16);
    if (this.timer >= 0) {
      clearTimeout(this.timer);
    }
    this.timer = setTimeout(() => { this.dismiss(); }, 3000);
  }

  private dismiss(): void {
    this.ty = -60;
    setTimeout(() => {
      this.shown = false;
      this.onDismiss();
    }, 200);
  }

  build() {
    if (this.shown) {
      Row() {
        Text(this.text).fontSize(15).fontColor('#e8ddc9').maxLines(2)
      }
      .width('90%')
      .padding({ left: 18, right: 18, top: 12, bottom: 12 })
      .borderRadius(12).backgroundColor('#211b16')
      .position({ x: '5%', y: this.topInset + 8 + this.ty })
      .animation({ duration: 200, curve: Curve.EaseOut })
      .onClick(() => { this.dismiss(); })
    }
  }
}
