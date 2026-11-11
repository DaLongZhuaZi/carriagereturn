/**
 * 回车 · 引导入口桥（第 10 批）：让各页页壳的 "?" 能调到 Index 的 showPageGuide。
 * 静态单例，Index 启动时注册；未注册时点击无副作用。
 */
export class GuideBridge {
  static enabled: boolean = true;
  static handler: (page: string) => void = (_page: string): void => {};

  static set(enabled: boolean, handler: (page: string) => void): void {
    GuideBridge.enabled = enabled;
    GuideBridge.handler = handler;
  }

  static request(page: string): void {
    if (GuideBridge.enabled && page.length > 0) {
      GuideBridge.handler(page);
    }
  }
}
