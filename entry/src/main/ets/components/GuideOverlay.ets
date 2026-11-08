/**
 * 回车 · 引导浮层（第 0 批：渲染器；第 1 批接 seen-state 与各页文案）。
 *
 * 只做渲染：文案与步骤由使用方传入（与功能同处一源，各页声明自己的提示），
 * 本组件不内置任何页面知识。锚点用语义锚（组件 id／role），不写死布局坐标。
 *
 * 层级规则（AGENTS 弹窗教训）：遮罩与卡片是 Stack 的兄弟节点——点遮罩关闭，
 * 点卡片不关闭（卡片自己吞点击）。
 */

/** 语义锚：优先 id，其次 role（role 的解析由第 1 批的页面注册表提供）。 */
export interface GuideAnchor {
  id?: string;
  role?: string;
}

/** 一条提示。 */
export interface GuideStep {
  text: string;
  /** 该条提示指向的语义锚（可选）。 */
  anchor?: GuideAnchor;
}

@Component
export struct GuideOverlay {
  @Prop visible: boolean = false;
  @Prop title: string = '';
  @Prop steps: GuideStep[] = [];
  @Prop anchor: GuideAnchor = {};
  /** 第 1 批接入 seen-state 后由页面传入；本批默认只显示"知道了"。 */
  @Prop showSkip: boolean = false;
  onNext: () => void = (): void => {};
  onSkip: () => void = (): void => {};
  onClose: () => void = (): void => {};

  private anchorText(): string {
    if (this.anchor.id !== undefined && this.anchor.id.length > 0) {
      return 'id=' + this.anchor.id;
    }
    if (this.anchor.role !== undefined && this.anchor.role.length > 0) {
      return 'role=' + this.anchor.role;
    }
    return 'none';
  }

  build() {
    if (this.visible) {
      Stack({ alignContent: Alignment.Bottom }) {
        // 遮罩：独立兄弟节点，点它关闭；点卡片不冒泡到遮罩
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor('rgba(0,0,0,0.45)')
          .onClick(() => { this.onClose(); })

        // 卡片：吞掉点击（空 onClick 阻止冒泡）
        Column() {
          Text(this.title)
            .fontSize(18)
            .fontWeight(FontWeight.Medium)
            .fontColor('#e8ddc9')
            .width('100%')
            .margin({ bottom: 10 })
          ForEach(this.steps, (step: GuideStep, idx: number) => {
            Row({ space: 8 }) {
              Text((idx + 1).toString() + '.')
                .fontSize(13)
                .fontColor('#c9a45c')
                .width(18)
              Text(step.text)
                .fontSize(14)
                .fontColor('rgba(232,221,201,0.85)')
                .layoutWeight(1)
            }
            .width('100%')
            .alignItems(VerticalAlign.Top)
            .margin({ bottom: 8 })
          }, (step: GuideStep, idx: number) => idx.toString() + step.text)
          Row() {
            if (this.showSkip) {
              Text('跳过')
                .fontSize(14)
                .fontColor('rgba(232,221,201,0.55)')
                .padding({ left: 8, right: 8, top: 6, bottom: 6 })
                .onClick(() => { this.onSkip(); })
            }
            Blank()
            Text('知道了')
              .fontSize(14)
              .fontColor('#171310')
              .backgroundColor('#c9a45c')
              .borderRadius(16)
              .padding({ left: 16, right: 16, top: 6, bottom: 6 })
              .onClick(() => { this.onNext(); })
          }
          .width('100%')
          .margin({ top: 4 })
        }
        .width('100%')
        .padding({ left: 20, right: 20, top: 18, bottom: 18 })
        .backgroundColor('#2b2621')
        .borderRadius({ topLeft: 16, topRight: 16 })
        .onClick(() => {})
      }
      .width('100%')
      .height('100%')
      .zIndex(100)
    }
  }
}