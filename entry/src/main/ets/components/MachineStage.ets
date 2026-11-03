/**
 * 回车 · 机器舞台（阶段1）
 *
 * 只负责"把机器摆出来"：暖灰渐变底 + 机器 hero 图。
 * 纸面与键盘不在本组件内，由主屏纵向排布，纸面压在上沿形成
 * "纸从机器里出来"的层次（风格板 §1：一眼像一台真机器）。
 *
 * 注意：$rawfile() 只接受编译期字符串常量，故按 machineKind 做静态分支。
 */

import { MachineKind } from '../model/DocModel';

@Component
export struct MachineStage {
  /** 当前机器。阶段1 默认 1920s 直立式座机。 */
  @Prop machineKind: MachineKind = MachineKind.UPRIGHT_1920S;
  /** 机身主色，用于底部渐变压暗（风格板 §2 各台取色锁定）。 */
  @Prop bodyColor: string = '#312b24';
  /** 舞台高度（vp）。 */
  @Prop stageHeightVp: number = 220;

  build() {
    Stack({ alignContent: Alignment.Center }) {
      // 暖灰环境光：上暗下亮，纸面仍是画面最亮处（纸在下方由 PaperSheet 承担）
      Column()
        .width('100%')
        .height('100%')
        .linearGradient({
          direction: GradientDirection.Bottom,
          colors: [[this.bodyColor, 0.0], ['#8d7b68', 0.55], ['#cdc0af', 1.0]],
        })

      if (this.machineKind === MachineKind.UPRIGHT_1920S) {
        Image($rawfile('machine/1920s-upright-hero-3q.jpg'))
          .width('100%')
          .height('100%')
          .objectFit(ImageFit.Contain)
          .opacity(0.98)
      } else if (this.machineKind === MachineKind.PORTABLE_1930S) {
        Image($rawfile('machine/1930s-portable-hero.jpg'))
          .width('100%')
          .height('100%')
          .objectFit(ImageFit.Contain)
          .opacity(0.98)
      } else if (this.machineKind === MachineKind.STREAMLINED_1950S) {
        Image($rawfile('machine/1950s-streamlined-hero.jpg'))
          .width('100%')
          .height('100%')
          .objectFit(ImageFit.Contain)
          .opacity(0.98)
      } else {
        Image($rawfile('machine/1960s-electric-hero.jpg'))
          .width('100%')
          .height('100%')
          .objectFit(ImageFit.Contain)
          .opacity(0.98)
      }
    }
    .width('100%')
    .height(this.stageHeightVp)
    .clip(true)
  }
}
