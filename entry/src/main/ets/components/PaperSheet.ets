/**
 * 回车 · 纸面渲染组件（阶段1）
 *
 * 实现依据：调研报告 §2（纸面渲染）+ 风格板 §2/§5。
 *
 * 硬性分层（素材调研报告定稿）：
 * - **纸纹只作背景**：整张纸铺纸纹图，四个 paperKind 走四个编译期静态分支
 *   （$rawfile() 只接受编译期字符串常量，不能写变量）；
 * - **格线 / 边距 / 红格 / 页眉一律代码层画**：竖线与页眉画在固定在纸面背后的
 *   Canvas 上；横线由每一行自己的 1vp 下边线画——横线必须随行一起滚动，
 *   固定 Canvas 画不了"跟着行走的横线"。
 *
 * 渲染结构（自下而上）：
 *   纸纹 Image → 代码层 Canvas（竖格线 / 红边距线 / 页眉细线）→ List 行文字 → 引导行
 *
 * List + LazyForEach + @Reusable：
 * - 每一行是一个 ListItem，行组件 @Reusable，cachedCount 取"约半屏"（见 cachedRows 注释）；
 * - 数据源 getData 只做下标读取，见 paper/PaperDataSource.ets。
 *
 * 光标行锚定（调研报告 §2）：
 * - 只在 activeLine 变化（换行 / 光标换行）时才滚动，同一行内打字绝不动整张纸；
 * - 当前行逼近可视区下沿时才重新锚定，锚到打字区高度（innerH 的 55%）；
 * - 换行用 Scroller.scrollTo 的 springCurve 弹簧动画，一次到位，不做逐字位移。
 *
 * 文案：本组件不含任何字面文案，所有展示文本来自 PaperRow.text 与 hintText。
 */

import { curves } from '@kit.ArkUI';
import { CursorPos, PaperKind, RibbonKind } from '../model/DocModel';
import { findPaper, findRibbon, RibbonSpec } from '../model/MachineCatalog';
import { PaperRow, PaperViewSpec } from '../ui/PaperSheet';
import { PaperDataSource } from './paper/PaperDataSource';

/** 纸色兜底（风格板 §2 纸色主色，已取色锁定）。纸纹缺失时也不至于透出深色底。 */
const PAPER_TONE: string = '#eee4ce';
/** 组件兜底纸面参数：调用方总会传 spec，这里只保证 @Prop 有初值、且默认与「信纸 + 默认机」一致。 */
const DEFAULT_SPEC: PaperViewSpec = {
  paperKind: PaperKind.LETTER,
  paperTexture: 'paper/paper-letter.jpg',
  paperWidthVp: 360,
  fontSizeVp: 16,
  lineHeightRatio: 1.7,
  marginHVp: 28,
  marginVVp: 32,
  fontFamily: 'CourierPrime',
  hasGrid: false,
  hasHeader: true,
};

/** 格线：墨色 10% 透明，只做结构不抢视线（风格板 §2「界面辅助色只用灰阶做结构」）。 */
const GRID_LINE_COLOR: string = '#1a15120e';
/** 红格 / 边距线：取色带红 #6d1f18 的 35% 透明。 */
const MARGIN_RULE_COLOR: string = '#596d1f18';
/** 页眉细线：墨色 20% 透明。 */
const HEADER_RULE_COLOR: string = '#3315120e';
/** 打字区高度占比：当前行固定锚在可视区这个高度上（0.55 略低于中线，给下一行留预告空间）。 */
const TYPING_ZONE_RATIO: number = 0.55;

/** 取字号（不正则回落到 16vp）。 */
function fontSizeOf(spec: PaperViewSpec): number {
  return spec.fontSizeVp > 0 ? spec.fontSizeVp : 16;
}

/** 行高 = 字号 × 行高倍率，全部来自 PaperViewSpec（各台机器纸面适配不同）。 */
function lineHeightOf(spec: PaperViewSpec): number {
  const ratio: number = spec.lineHeightRatio > 0 ? spec.lineHeightRatio : 1.6;
  return fontSizeOf(spec) * ratio;
}

/** 纸张枚举归一化：PaperRow / PaperViewSpec 里 paperKind 是 string，转回枚举后查目录。 */
function paperKindOf(value: string): PaperKind {
  if (value === PaperKind.MANUSCRIPT) {
    return PaperKind.MANUSCRIPT;
  }
  if (value === PaperKind.POSTCARD) {
    return PaperKind.POSTCARD;
  }
  if (value === PaperKind.MEMO) {
    return PaperKind.MEMO;
  }
  return PaperKind.LETTER;
}

/** 色带枚举归一化：遇到未知值一律按黑色（默认色带）处理，绝不崩。 */
function ribbonKindOf(value: string): RibbonKind {
  if (value === RibbonKind.BLUE) {
    return RibbonKind.BLUE;
  }
  if (value === RibbonKind.RED) {
    return RibbonKind.RED;
  }
  return RibbonKind.BLACK;
}

/** 该行的墨色：查 model/MachineCatalog 的色带目录，组件内不另扣色表。 */
function inkColorOf(row: PaperRow): string {
  const ribbon: RibbonSpec = findRibbon(ribbonKindOf(row.ribbon));
  return ribbon.inkColor;
}

/**
 * 该行的做旧深浅：以"行"为单位微调透明度（风格板 §5：
 * 到字为单位的浓淡才需要 Canvas 或做旧纹理字体，这里不做字级）。
 * 用行号做确定性抖动，滚动回来深浅不变，不会闪。
 */
function inkOpacityOf(row: PaperRow): number {
  const ribbon: RibbonSpec = findRibbon(ribbonKindOf(row.ribbon));
  const jitter: number = 0.88 + ((row.line * 37) % 12) / 100;
  const value: number = ribbon.inkAlpha * jitter;
  return value > 1 ? 1 : value;
}

/** Length（number | string | Resource）统一转 vp 数值，测不到时返回 0。 */
function lengthToVp(value: Length): number {
  if (typeof value === 'number') {
    return value;
  }
  if (typeof value === 'string') {
    const parsed: number = Number.parseFloat(value);
    return Number.isFinite(parsed) ? parsed : 0;
  }
  return 0;
}

/**
 * 单行组件：@Reusable，随 List 滚动复用的最小单位。
 *
 * 一行 = 一个单元格：文本用 Text 排版（换行、字体、行距由原生文本引擎给），
 * 行高严格等于 PaperViewSpec.fontSizeVp × lineHeightRatio，保证
 * "第 i 行"在纸面上的纵向坐标可被组件直接算出来（滚动锚定依赖这一点）。
 */
@Reusable
@Component
struct PaperRowView {
  @Prop row: PaperRow = { line: 0, text: '', ribbon: RibbonKind.BLACK, active: false };
  @Prop spec: PaperViewSpec = DEFAULT_SPEC;

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      // 横格线：只在该纸型画格线时出现，1vp 贴在单元格下沿 —— 随行滚动，天然对齐。
      if (this.spec.hasGrid) {
        Column()
          .width('100%')
          .height(1)
          .backgroundColor(GRID_LINE_COLOR)
          .position({ x: 0, y: lineHeightOf(this.spec) - 1 })
      }

      Text(this.row.text)
        .width('100%')
        .height(lineHeightOf(this.spec))
        .lineHeight(lineHeightOf(this.spec))
        .fontSize(fontSizeOf(this.spec))
        .fontFamily(this.spec.fontFamily)
        .fontColor(inkColorOf(this.row))
        .opacity(inkOpacityOf(this.row))
        .textAlign(TextAlign.Start)
        .maxLines(1)

      // 光标：只画在当前行，2vp 墨条贴在行首（不做整纸横移，风格板 §5）。
      if (this.row.active) {
        Column()
          .width(2)
          .height(fontSizeOf(this.spec))
          .backgroundColor(inkColorOf(this.row))
          .opacity(0.55)
          .margin({ top: (lineHeightOf(this.spec) - fontSizeOf(this.spec)) / 2 })
      }
    }
    .width('100%')
    .height(lineHeightOf(this.spec))
  }
}

@Component
export struct PaperSheet {
  /** 纸面显示参数（换纸 / 换机 / 三态切换只换这个，不重建组件实例）。 */
  @Prop @Watch('onSpecChanged') spec: PaperViewSpec = DEFAULT_SPEC;
  /** 行数据。调用方每次重建数组后赋回，本组件做增量 diff，不整表重建。 */
  @Prop @Watch('onRowsChanged') rows: PaperRow[] = [];
  /** 常驻引导行（每张新纸一行、输入后消失）。由调用方判定并解析文案，'' 表示不显示。 */
  @Prop hintText: string = '';
  /** 当前光标所在行下标；变化时把该行滚入可见区（不每敲一字移动整张纸）。 */
  @Prop @Watch('onActiveLineChanged') activeLine: number = 0;

  private dataSource: PaperDataSource = new PaperDataSource();
  private scroller: Scroller = new Scroller();
  private gridCtx: CanvasRenderingContext2D = new CanvasRenderingContext2D(new RenderingContextSettings(true));
  private canvasReady: boolean = false;
  /** 最近一次量到的可视区高度（vp），用于滚动锚定与 cachedCount 估算。 */
  private viewportHeightVp: number = 0;
  /** 首次布局完成后是否已经做过"打开即定位到光标行"。 */
  private initialLocated: boolean = false;

  /** 约半屏的行缓存上限，随可视区高度重算。 */
  @State private cachedRows: number = 6;

  aboutToAppear(): void {
    this.dataSource.sync(this.rows);
  }

  // ---------------- 对外接口（PaperSheetExposed） ----------------

  /** 行数据变化后调用：与 @Prop rows 的 watch 等价，保留给阶段3 的命令式调用。 */
  refresh(): void {
    this.dataSource.sync(this.rows);
  }

  /** 光标移动后调用：把 pos.line 滚入可见区（阶段3 文档库 / 点纸面定位用）。 */
  followCursor(pos: CursorPos): void {
    this.ensureLineVisible(pos.line, true);
  }

  // ---------------- 状态驱动 ----------------

  onRowsChanged(): void {
    this.dataSource.sync(this.rows);
  }

  onActiveLineChanged(): void {
    // 让 List 先把新增行排完版，再按行号算目标偏移，避免用到上一帧的 contentHeight。
    setTimeout(() => {
      this.ensureLineVisible(this.activeLine, true);
    }, 0);
  }

  onSpecChanged(): void {
    // 纸型参数变了：格线 / 页眉 / 边距都要重画（Canvas 尺寸不变不会再触发 onReady）。
    if (this.canvasReady) {
      this.drawPaperLayer();
    }
  }

  // ---------------- 纸面几何（全部来自 PaperViewSpec） ----------------

  private marginHVp(): number {
    if (this.spec.marginHVp > 0) {
      return this.spec.marginHVp;
    }
    return findPaper(paperKindOf(this.spec.paperKind)).marginH;
  }

  private marginVVp(): number {
    if (this.spec.marginVVp > 0) {
      return this.spec.marginVVp;
    }
    return findPaper(paperKindOf(this.spec.paperKind)).marginTop;
  }

  /** 页眉带高度：有页眉时让出整整一行，页眉线画在这条带的下沿。 */
  private headerHeightVp(): number {
    return this.spec.hasHeader ? lineHeightOf(this.spec) : 0;
  }

  /** List 内容区上内边距 = 页眉带 + 上边距。 */
  private topInsetVp(): number {
    return this.headerHeightVp() + this.marginVVp();
  }

  /** 内容区（去掉页眉带与上下边距）的可用高度。 */
  private innerHeightVp(): number {
    const inner: number = this.viewportHeightVp - this.topInsetVp() - this.marginVVp();
    return inner > 0 ? inner : 0;
  }

  private clampOffset(offset: number): number {
    const content: number = this.dataSource.totalCount() * lineHeightOf(this.spec);
    const max: number = content - this.innerHeightVp();
    if (max <= 0) {
      return 0;
    }
    if (offset < 0) {
      return 0;
    }
    return offset > max ? max : offset;
  }

  /**
   * 光标行锚定：把第 line 行锁在"打字区高度"（内容区高度的 55%）。
   *
   * 只在 activeLine 变化（换行 / 光标换行）时被调用——同一行内继续打字根本不会进来，
   * 所以绝不会每敲一个字就移动整张纸；一旦行号变化，纸张按行高做一次弹簧上移，
   * 位移量与一个行高同阶，视觉上是"纸往上走一行"，不是整页跳。
   *
   * 误差在半行以内直接跳过，避免亚像素抖动反复触发滚动。
   */
  private ensureLineVisible(line: number, smooth: boolean): void {
    const inner: number = this.innerHeightVp();
    const rowHeight: number = lineHeightOf(this.spec);
    if (inner <= 0 || rowHeight <= 0) {
      return;
    }
    const offset: number = this.currentOffsetVp();
    const target: number = this.clampOffset(line * rowHeight - inner * TYPING_ZONE_RATIO);
    if (Math.abs(target - offset) < rowHeight * 0.5) {
      return;
    }
    this.scrollToOffset(target, smooth);
  }

  /** 当前滚动偏移（vp）。Scroller 未绑定容器时按 0 处理，避免首帧取值异常。 */
  private currentOffsetVp(): number {
    try {
      return this.scroller.currentOffset().yOffset;
    } catch (err) {
      return 0;
    }
  }

  private scrollToOffset(target: number, smooth: boolean): void {
    if (smooth) {
      this.scroller.scrollTo({
        xOffset: 0,
        yOffset: target,
        animation: { duration: 340, curve: curves.springCurve(0, 1, 190, 22) },
      });
    } else {
      this.scroller.scrollTo({ xOffset: 0, yOffset: target });
    }
  }

  private handleAreaChange(area: Area): void {
    const height: number = lengthToVp(area.height);
    if (height <= 0) {
      return;
    }
    this.viewportHeightVp = height;

    // cachedCount 约半屏：可见行数 n = 内容区高 / 行高，缓存 n/2（官方建议 n/2）。
    const visible: number = Math.ceil(this.innerHeightVp() / lineHeightOf(this.spec));
    const half: number = Math.ceil(visible / 2);
    const next: number = half > 3 ? half : 3;
    if (next !== this.cachedRows) {
      this.cachedRows = next;
    }
    if (this.canvasReady) {
      // 纸面尺寸变了：格线 / 页眉 / 红格按新尺寸重画。
      this.drawPaperLayer();
    }
    if (!this.initialLocated) {
      this.initialLocated = true;
      // 打开已有文档：先把光标行直接摆到打字区，不做动画。
      this.ensureLineVisible(this.activeLine, false);
    }
  }

  // ---------------- 代码层：格线 / 边距 / 红格 / 页眉 ----------------

  private drawPaperLayer(): void {
    const ctx: CanvasRenderingContext2D = this.gridCtx;
    const width: number = ctx.width;
    const height: number = ctx.height;
    if (!(width > 0) || !(height > 0)) {
      return;
    }
    ctx.clearRect(0, 0, width, height);

    const rowHeight: number = lineHeightOf(this.spec);
    const marginH: number = this.marginHVp();
    const headerH: number = this.headerHeightVp();

    // 页眉（信纸）：两条细线，纯代码画，绝不吃进纸纹。
    if (this.spec.hasHeader) {
      const ruleTop: number = headerH - rowHeight * 0.30;
      ctx.strokeStyle = HEADER_RULE_COLOR;
      ctx.lineWidth = 1;
      ctx.beginPath();
      ctx.moveTo(marginH, ruleTop);
      ctx.lineTo(width - marginH, ruleTop);
      ctx.stroke();
      ctx.beginPath();
      ctx.moveTo(marginH, ruleTop + 4);
      ctx.lineTo(width - marginH, ruleTop + 4);
      ctx.stroke();
    }

    // 稿纸方格：竖线由固定 Canvas 画（纵向滚动时竖线本来就不动，天然对齐）；
    // 横线交给每一行自己的下边线，才能跟着行一起滚。
    if (this.spec.hasGrid) {
      const cell: number = rowHeight;
      ctx.strokeStyle = GRID_LINE_COLOR;
      ctx.lineWidth = 1;
      let x: number = marginH + cell;
      while (x < width - marginH) {
        ctx.beginPath();
        ctx.moveTo(x, headerH);
        ctx.lineTo(x, height);
        ctx.stroke();
        x += cell;
      }
      // 红格：左侧边距线。
      ctx.strokeStyle = MARGIN_RULE_COLOR;
      ctx.beginPath();
      ctx.moveTo(marginH, headerH);
      ctx.lineTo(marginH, height);
      ctx.stroke();
    }
  }

  // ---------------- 纸面背景（静态分支，$rawfile 只接受编译期常量） ----------------

  @Builder
  paperTexture() {
    if (this.spec.paperKind === PaperKind.MANUSCRIPT) {
      Image($rawfile('paper/paper-manuscript.jpg'))
        .width('100%')
        .height('100%')
        .objectFit(ImageFit.Cover)
        .opacity(0.92)
    } else if (this.spec.paperKind === PaperKind.POSTCARD) {
      Image($rawfile('paper/paper-postcard.jpg'))
        .width('100%')
        .height('100%')
        .objectFit(ImageFit.Cover)
        .opacity(0.92)
    } else if (this.spec.paperKind === PaperKind.MEMO) {
      Image($rawfile('paper/paper-memo.jpg'))
        .width('100%')
        .height('100%')
        .objectFit(ImageFit.Cover)
        .opacity(0.92)
    } else {
      Image($rawfile('paper/paper-letter.jpg'))
        .width('100%')
        .height('100%')
        .objectFit(ImageFit.Cover)
        .opacity(0.92)
    }
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      // 1) 纸纹：只作背景，格线/边距/红格/页眉一律不 baked 进纹理。
      this.paperTexture()

      // 2) 代码层：竖格线 / 红边距线 / 页眉细线（固定，纵向滚动时竖线不动）。
      Canvas(this.gridCtx)
        .width('100%')
        .height('100%')
        .hitTestBehavior(HitTestMode.None)
        .onReady(() => {
          this.canvasReady = true;
          this.drawPaperLayer();
        })

      // 3) 行：List + LazyForEach + @Reusable，cachedCount 约半屏。
      List({ scroller: this.scroller }) {
        LazyForEach(this.dataSource, (item: PaperRow) => {
          ListItem() {
            PaperRowView({ row: item, spec: this.spec })
          }
        }, (item: PaperRow) => item.line.toString())
      }
      .width('100%')
      .height('100%')
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.None)
      .cachedCount(this.cachedRows)
      .padding({
        top: this.topInsetVp(),
        bottom: this.marginVVp(),
        left: this.marginHVp(),
        right: this.marginHVp(),
      })
      .onAreaChange((_oldValue: Area, newValue: Area) => {
        this.handleAreaChange(newValue);
      })

      // 4) 常驻引导行：每张新纸一行、输入后由调用方置 ''，不占文档行。
      if (this.hintText.length > 0) {
        Text(this.hintText)
          .width('100%')
          .height(lineHeightOf(this.spec))
          .lineHeight(lineHeightOf(this.spec))
          .fontSize(fontSizeOf(this.spec))
          .fontFamily(this.spec.fontFamily)
          .fontColor(findRibbon(RibbonKind.BLACK).inkColor)
          .opacity(0.38)
          .maxLines(1)
          .textAlign(TextAlign.Start)
          .padding({ left: this.marginHVp(), right: this.marginHVp() })
          .position({ x: 0, y: this.topInsetVp() })
          .hitTestBehavior(HitTestMode.None)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(PAPER_TONE)
    .clip(true)
  }
}