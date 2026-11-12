/**
 * 功能行（§2.3；第 13 批 ③ 重做为扁平 HUD 键）：52vp，深底＋1px 描边＋圆角 0；
 * 六键等宽：中/EN、删除、换行、换纸、退行、字符。
 *
 * HUD 语言与门户面板一致（深底、1px 描边、圆角零、实用密度）；键床是拟物层，
 * 两层并存是有意的反差。常驻选中态：EN 键金描边 ⟺ langZh；字符键金描边 ⟺ symbolMode；
 * 换行键金色文字 ＝ 主操作。文案不动（语言键示当前态、字符键示返回动作）。
 *
 * 注意：键帽文字必须走子组件 @Prop（MetalKey），不要用 @Builder 按值传 label——
 * ArkUI 的 @Builder 按值传参不建立依赖，label 变化时 Text 不会刷新（2026-11-09 真机定位）。
 */
const HUD_BG: string = '#2e2823';
const HUD_BG_PRESSED: string = '#1f1a15';
const HUD_STROKE: string = '#6b6055';
const HUD_TEXT: string = '#dbccb3';
const HUD_GOLD: string = '#c9a45c';

@Component
struct MetalKey {
  @Prop keyId: string = '';
  @Prop label: string = '';
  /** 常驻选中态：描边金色（切换键的模式当前生效）。 */
  @Prop selected: boolean = false;
  /** 金色文字：标示主操作（仅换行键）。 */
  @Prop goldText: boolean = false;
  onPress: () => void = (): void => {};

  @State pressed: boolean = false;

  build() {
    Stack() {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(this.pressed ? HUD_BG_PRESSED : HUD_BG)
        .border({ width: 1, color: this.selected ? HUD_GOLD : HUD_STROKE })
      Text(this.label)
        .fontSize(14)
        .fontColor(this.goldText ? HUD_GOLD : HUD_TEXT)
        .maxLines(1)
        .translate({ y: this.pressed ? 1 : 0 })
    }
    .width('100%')
    .height('100%')
    .padding(6)
    .onTouch((e: TouchEvent) => {
      if (e.type === TouchType.Down) {
        this.pressed = true;
        this.onPress();
      } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) {
        this.pressed = false;
      }
    })
  }
}

@Component
export struct FunctionRow {
  @Prop heightVp: number = 52;
  @Prop langLabel: string = '';
  @Prop deleteLabel: string = '';
  @Prop newlineLabel: string = '';
  @Prop paperLabel: string = '';
  @Prop backLineLabel: string = '';
  @Prop charLabel: string = '';
  /** 中文态（langZh）：EN 键（文案「中」）金描边常亮。 */
  @Prop langActive: boolean = false;
  /** 符号键盘（symbolMode）：字符键（文案「字母」）金描边常亮。 */
  @Prop symbolActive: boolean = false;
  onLang: () => void = (): void => {};
  onDelete: () => void = (): void => {};
  onNewline: () => void = (): void => {};
  onPaperChange: () => void = (): void => {};
  onBackLine: () => void = (): void => {};
  onSymbols: () => void = (): void => {};

  build() {
    Row({ space: 6 }) {
      Column() {
        MetalKey({
          keyId: 'lang', label: this.langLabel, selected: this.langActive,
          onPress: (): void => { this.onLang(); },
        })
      }
      .layoutWeight(1)
      .height('100%')

      Column() {
        MetalKey({
          keyId: 'del', label: this.deleteLabel,
          onPress: (): void => { this.onDelete(); },
        })
      }
      .layoutWeight(1)
      .height('100%')

      Column() {
        MetalKey({
          keyId: 'nl', label: this.newlineLabel, goldText: true,
          onPress: (): void => { this.onNewline(); },
        })
      }
      .layoutWeight(1)
      .height('100%')

      // 换纸：一次性手动动作（§2.9 完整规格）
      Column() {
        MetalKey({
          keyId: 'paper', label: this.paperLabel,
          onPress: (): void => { this.onPaperChange(); },
        })
      }
      .layoutWeight(1)
      .height('100%')

      // 退行：回到上一行文字末尾（第 13 批 ② 起有音效）
      Column() {
        MetalKey({
          keyId: 'backline', label: this.backLineLabel,
          onPress: (): void => { this.onBackLine(); },
        })
      }
      .layoutWeight(1)
      .height('100%')

      // 字符 / 字母：符号键盘开关（按当前语言切换符号表）
      Column() {
        MetalKey({
          keyId: 'symbols', label: this.charLabel, selected: this.symbolActive,
          onPress: (): void => { this.onSymbols(); },
        })
      }
      .layoutWeight(1)
      .height('100%')
    }
    .width('100%')
    .height(this.heightVp)
    .padding({ left: 8, right: 8, top: 6, bottom: 6 })
    .backgroundColor('#241c16')
  }
}
