/**
 * 照片键区（§2.3）：手机带 2048×975（2.1:1）/ 折叠带 2048×853（2.4:1），满宽铺底。
 * **只允许用 keyband-phone / keyband-fold**，绝不用 keyboard.jpg 裁带、绝不用 hero 整机图。
 * 本步（第 1 步）只铺照片；键帽叠字与触摸命中在第 3 步接入 keymap。
 */
import { MachineKind } from '../model/DocModel';

@Component
export struct PhotoKeybed {
  @Prop machineKind: MachineKind = MachineKind.UPRIGHT_1920S;
  @Prop foldBand: boolean = false;
  @Prop heightVp: number = 186;

  build() {
    Stack() {
      if (this.machineKind === MachineKind.UPRIGHT_1920S) {
        if (this.foldBand) {
          Image($rawfile('machine/1920s-upright-keyband-fold.jpg')).width('100%').height('100%').objectFit(ImageFit.Fill)
        } else {
          Image($rawfile('machine/1920s-upright-keyband-phone.jpg')).width('100%').height('100%').objectFit(ImageFit.Fill)
        }
      } else if (this.machineKind === MachineKind.PORTABLE_1930S) {
        // 1930s 折叠带复用手机带（keymap bands.fold 已注明）
        Image($rawfile('machine/1930s-portable-keyband-phone.jpg')).width('100%').height('100%').objectFit(ImageFit.Fill)
      } else if (this.machineKind === MachineKind.STREAMLINED_1950S) {
        if (this.foldBand) {
          Image($rawfile('machine/1950s-streamlined-keyband-fold.jpg')).width('100%').height('100%').objectFit(ImageFit.Fill)
        } else {
          Image($rawfile('machine/1950s-streamlined-keyband-phone.jpg')).width('100%').height('100%').objectFit(ImageFit.Fill)
        }
      } else {
        if (this.foldBand) {
          Image($rawfile('machine/1960s-electric-keyband-fold.jpg')).width('100%').height('100%').objectFit(ImageFit.Fill)
        } else {
          Image($rawfile('machine/1960s-electric-keyband-phone.jpg')).width('100%').height('100%').objectFit(ImageFit.Fill)
        }
      }
    }
    .width('100%')
    .height(this.heightVp)
    .clip(true)
  }
}
