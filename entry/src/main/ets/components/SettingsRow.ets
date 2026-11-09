/**
 * 回车 · 共享设置行（第 0 批，第 1／4／6 批共用）。
 *
 * 5 种形态（mode）：
 *   value   左标签＋右值（默认）
 *   chevron 左标签＋右值＋右箭头（可点）
 *   link    左标签＋右值（无箭头，整行可点，值用金色）
 *   switch  左标签＋右开关
 *   slider  左标签＋右滑杆（0..100）＋可选左侧回显文本（sliderValueText）
 *
 * 规范：行高 52vp、1vp 分割线由使用方加；D4 按压 0.97／120ms；D6 入场逐行淡入
 * 由使用方的 reveal 控制（false → 透明）。
 */

import { AppIcon } from './AppIcon';

@Component
export struct SettingsRow {
  @Prop label: ResourceStr = '';
  @Prop mode: string = 'value';
  @Prop value: string = '';
  @Prop valueColor: string = 'rgba(232,221,201,0.6)';
  @Prop switchOn: boolean = false;
  @Prop sliderValue: number = 0;
  @Prop sliderMin: number = 0;
  @Prop sliderMax: number = 100;
  @Prop sliderStep: number = 1;
  /** slider 模式在滑杆左侧显示的值回显（如 "500 字"）；空串不显示。 */
  @Prop sliderValueText: string = '';
  @Prop reveal: boolean = true;
  onToggle: () => void = (): void => {};
  onSlide: (v: number) => void = (v: number): void => {};
  onRowClick: () => void = (): void => {};

  @State pressed: boolean = false;

  build() {
    Row() {
      Text(this.label)
        .fontSize(15)
        .fontColor('#e8ddc9')
      Blank()
      if (this.mode === 'switch') {
        Toggle({ type: ToggleType.Switch, isOn: this.switchOn })
          .selectedColor('#c9a45c')
          .onChange((isOn: boolean) => {
            if (isOn !== this.switchOn) {
              this.onToggle();
            }
          })
      } else if (this.mode === 'slider') {
        // N-1：滑杆左侧回显当前值（"500 字"），非空才显示
        if (this.sliderValueText.length > 0) {
          Text(this.sliderValueText)
            .fontSize(14)
            .fontColor('#c9a45c')
            .margin({ right: 8 })
        }
        Slider({ value: this.sliderValue, min: this.sliderMin, max: this.sliderMax, step: this.sliderStep })
          .width(180)
          .trackThickness(2)
          .selectedColor('#c9a45c')
          .onChange((v: number, changeMode: SliderChangeMode) => {
            if (changeMode === SliderChangeMode.End || changeMode === SliderChangeMode.Click) {
              this.onSlide(Math.round(v));
            }
          })
      } else {
        Text(this.value)
          .fontSize(15)
          .fontColor(this.mode === 'link' ? '#c9a45c' : this.valueColor)
        if (this.mode === 'chevron') {
          AppIcon({ kind: 'chevron', iconSize: 18, color: 'rgba(232,221,201,0.6)' })
        }
      }
    }
    .width('100%')
    .height(52)
    .opacity(this.reveal ? 1 : 0)
    .animation({ duration: 180, curve: Curve.EaseOut })
    .scale({ x: this.pressed ? 0.97 : 1, y: this.pressed ? 0.97 : 1 })
    .animation({ duration: 120, curve: Curve.EaseOut })
    .onTouch((e: TouchEvent) => {
      if (e.type === TouchType.Down) {
        this.pressed = true;
      } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) {
        this.pressed = false;
      }
    })
    .onClick(() => {
      this.onRowClick();
    })
  }
}