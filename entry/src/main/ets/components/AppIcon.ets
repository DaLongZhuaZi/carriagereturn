/**
 * 回车 · 线形图标集（D10，§1.2）
 *
 * 统一 Path 画法（与 TopBar 的文件夹／汉堡同源）；stroke 1.6，24vp 设计网格。
 * 文字符号 ‹ › ⋯ ✓ 一律不许再当图标用（只许留在纸面文字里）。
 */

@Component
export struct AppIcon {
  @Prop kind: string = 'back';
  @Prop iconSize: number = 24;
  @Prop color: string = '#e8ddc9';

  private d(): string {
    if (this.kind === 'back') {
      return 'M15 4 L7 12 L15 20';
    }
    if (this.kind === 'folder') {
      return 'M3 7 L9 7 L11 9 L21 9 L21 19 L3 19 Z';
    }
    if (this.kind === 'menu') {
      return 'M4 7 L20 7 M4 12 L20 12 M4 17 L20 17';
    }
    if (this.kind === 'more') {
      return 'M5 12 L5.01 12 M12 12 L12.01 12 M19 12 L19.01 12';
    }
    if (this.kind === 'chevron') {
      return 'M9 6 L15 12 L9 18';
    }
    if (this.kind === 'check') {
      return 'M5 13 L10 18 L19 6';
    }
    if (this.kind === 'settings') {
      return 'M12 8 A4 4 0 1 1 12 16 A4 4 0 1 1 12 8 Z M12 2 L12 5 M12 19 L12 22 M2 12 L5 12 M19 12 L22 12';
    }
    if (this.kind === 'export') {
      return 'M12 3 L12 15 M8 7 L12 3 L16 7 M4 15 L4 20 L20 20 L20 15';
    }
    if (this.kind === 'rename') {
      return 'M4 20 L8 19 L20 7 L17 4 L5 16 Z';
    }
    if (this.kind === 'delete') {
      return 'M5 7 L19 7 M9 7 L9 4 L15 4 L15 7 M7 7 L8 20 L16 20 L17 7';
    }
    if (this.kind === 'lock') {
      return 'M6 11 L18 11 L18 20 L6 20 Z M8 11 L8 7 A4 4 0 0 1 16 7 L16 11';
    }
    return '';
  }

  build() {
    Stack() {
      Path()
        .width(this.iconSize)
        .height(this.iconSize)
        .commands(this.d())
        .fillOpacity(0)
        .stroke(this.color)
        .strokeWidth(1.6)
        .strokeLineCap(LineCapStyle.Round)
        .strokeLineJoin(LineJoinStyle.Round)
    }
    .width(this.iconSize)
    .height(this.iconSize)
  }
}
