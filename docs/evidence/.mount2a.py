import io

p = 'entry/src/main/ets/pages/Index.ets'
s = io.open(p, encoding='utf-8', newline=None).read()

def rep(old, new):
    global s
    if old not in s:
        raise SystemExit('MISS %r' % old[:100])
    s = s.replace(old, new, 1)

# import
rep("import { ExportPage, guideStepsForExport } from '../components/ExportPage';",
    "import { ExportPage, guideStepsForExport } from '../components/ExportPage';\nimport { CanvasTypewriter } from '../components/CanvasTypewriter';")

# state
rep("""  /** 第 3 批：导出页 busy（系统返回拦截）。 */
  @State exportBusy: boolean = false;""",
"""  /** 第 3 批：导出页 busy（系统返回拦截）。 */
  @State exportBusy: boolean = false;
  /** 第 16 批 2A：Canvas 静态主屏调试页（临时入口，2B 切换后删除）。 */
  @State canvasDebugOpen: boolean = false;""")

# syncFromStack
rep("    this.exportOpen = has('export');",
    "    this.exportOpen = has('export');\n    this.canvasDebugOpen = has('canvasDebug');")

# helper for lines
rep("""  private currentLineText(): string {""",
"""  /** 第 16 批 2A：把 PaperRow[] 转成 Canvas 静态层需要的字符串数组。 */
  private docLineTexts(): string[] {
    const out: string[] = [];
    for (let i = 0; i < this.rows.length; i++) {
      out.push(this.rows[i].text);
    }
    return out;
  }

  private currentLineText(): string {""")

# mount branch after ExportPage block
rep("""          onBusyChange: (busy: boolean): void => { this.exportBusy = busy; },
        })
          .transition(TransitionEffect.move(TransitionEdge.END).animation({ duration: 250, curve: Curve.EaseOut }))
      }""",
"""          onBusyChange: (busy: boolean): void => { this.exportBusy = busy; },
        })
          .transition(TransitionEffect.move(TransitionEdge.END).animation({ duration: 250, curve: Curve.EaseOut }))
      }

      // 第 16 批 2A：Canvas 静态主屏调试页（临时；2B 切主屏后删除）
      if (this.canvasDebugOpen) {
        CanvasTypewriter({
          widthVp: this.winWidthVp > 0 ? this.winWidthVp : this.stageWidth,
          heightVp: this.winHeightVp > 0 ? this.winHeightVp : this.stageHeight,
          topInset: this.topInset,
          bottomInset: this.bottomInset,
          isTablet: this.isTablet,
          machineKind: this.machineKind,
          paperKind: this.paperKind,
          docTitle: this.docTitle,
          guideEnabled: this.guideEnabled,
          paperWidthVp: this.paperWidthVp,
          paperHeightVp: this.paperHeightVp,
          paperContainerVp: this.paperContainerVp,
          paperTopVp: this.paperTopVp,
          carriageTopVp: this.carriageTopVp,
          carriageHeightVp: this.carriageHeight,
          strikeLineVp: this.strikeLineVp,
          fontSizeVp: this.fontSizeVp,
          lineHeightVp: this.lineHeightVp,
          marginHVp: this.marginH(),
          marginTVp: this.marginT(),
          marginBVp: this.marginB(),
          pageNo: this.sheetNo,
          pageCount: this.sheetCount,
          hintText: this.hintText,
          lines: this.docLineTexts(),
          cursorXVp: this.marginH() + this.currentLineWidthVp(),
          cursorYVp: Math.max(0, this.strikeLineVp - this.paperTopVp - 8),
          keybedHeightVp: this.keybedHeight,
          functionRowHeightVp: this.functionRowHeight,
          fontBarHeightVp: this.fontBarHeight,
          candBarHeightVp: this.isTablet ? 0 : 44,
          langLabel: 'EN',
          deleteLabel: '删除',
          newlineLabel: '换行',
          paperLabel: '换纸',
          backLineLabel: '退行',
          charLabel: '字符',
          fontFamily: this.fontFamily,
          fontLabel: this.fontLabelOfCurrentMachine(),
          inkColor: this.inkColor,
          onOpenHome: (): void => { this.popTo('home'); },
          onOpenMenu: (): void => { this.menuOpen = true; },
        })
          .transition(TransitionEffect.move(TransitionEdge.END).animation({ duration: 250, curve: Curve.EaseOut }))
      }""")

# HomePage prop
rep("""          guideEnabled: this.guideEnabled,
          statsRev: this.statsRev,""",
"""          guideEnabled: this.guideEnabled,
          onOpenCanvas: (): void => { this.pushPage('canvasDebug'); },
          statsRev: this.statsRev,""")

io.open(p, 'w', encoding='utf-8', newline='\r\n').write(s)
print('index canvas debug mount ok')

# HomePage entry
p2 = 'entry/src/main/ets/components/HomePage.ets'
s2 = io.open(p2, encoding='utf-8', newline=None).read()

def rep2(old, new):
    global s2
    if old not in s2:
        raise SystemExit('MISS home %r' % old[:80])
    s2 = s2.replace(old, new, 1)

rep2("""  onContinue: () => void = (): void => {};""",
"""  onContinue: () => void = (): void => {};
  /** 第 16 批 2A：Canvas 静态主屏临时入口（2B 切主屏后删除）。 */
  onOpenCanvas: () => void = (): void => {};""")

rep2("""          Column().width('100%').height(24)
        }
        .width('100%')
        .opacity(this.op)""",
"""          // 第 16 批 2A 临时调试入口（Canvas 静态主屏；2B 切主屏后删除）
          Text('Canvas 2A（临时）')
            .id('home__canvas_debug')
            .fontSize(12).fontColor('rgba(232,221,201,0.6)').decoration({ type: TextDecorationType.Underline })
            .width('100%').textAlign(TextAlign.Center).margin({ top: 10, bottom: 4 })
            .onClick(() => { this.onOpenCanvas(); })

          Column().width('100%').height(24)
        }
        .width('100%')
        .opacity(this.op)""")

io.open(p2, 'w', encoding='utf-8', newline='\r\n').write(s2)
print('homepage canvas entry ok')
