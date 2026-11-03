/**
 * 回车 · 多点触控路由（触点 id -> 键 id）
 *
 * 调研报告 §1 的两条硬性要求，全部落在本类：
 * - TouchEvent.touches 不保证按 id 排序：所以一律「按 id 查表」，任何数组顺序都不影响结果；
 * - 手指抬起后系统会复用 TouchObject.id：所以 Up / Cancel 必须清理该 id 的条目，
 *   否则同一 id 再来时会以为该键还按着，出现「按键卡住 / 少一次落字」。
 *
 * 纯逻辑、无 UI 依赖，可离线自测。
 */

export class TouchRouter {
  /** 触点 id -> 键 id。同一触点最多对应一个键；同一键最多被一个触点按住。 */
  private readonly active: Map<number, string> = new Map<number, string>();

  /**
   * 按下登记。
   * 返回 true 表示这是一次新的按压（调用方据此起动画 / 播音 / 上屏）；
   * 返回 false 表示忽略：该触点已在按住某个键，或该键已被别的手指按住（一键不可双压）。
   */
  press(touchId: number, keyId: string): boolean {
    if (keyId.length === 0) {
      return false;
    }
    if (this.active.has(touchId)) {
      return false;
    }
    if (this.isHeld(keyId)) {
      return false;
    }
    this.active.set(touchId, keyId);
    return true;
  }

  /** 抬手 / 取消该触点：清理并返回它原来按住的键；没有登记过则返回空串。 */
  release(touchId: number): string {
    const keyId: string | undefined = this.active.get(touchId);
    if (keyId === undefined) {
      return '';
    }
    this.active.delete(touchId);
    return keyId;
  }

  /** Cancel：清空整张表，返回被清掉的全部键 id（调用方逐个做视觉回弹）。 */
  releaseAll(): string[] {
    const keys: string[] = [];
    this.active.forEach((keyId: string, touchId: number) => {
      keys.push(keyId);
    });
    this.active.clear();
    return keys;
  }

  /** 该触点当前按住的键；没按住任何键返回空串。 */
  keyOf(touchId: number): string {
    const keyId: string | undefined = this.active.get(touchId);
    if (keyId === undefined) {
      return '';
    }
    return keyId;
  }

  /** 该键是否已被任何触点按住。 */
  isHeld(keyId: string): boolean {
    return this.findTouchOf(keyId) >= 0;
  }

  /** 该键是否已被「除 touchId 以外」的触点按住。 */
  heldByOther(keyId: string, touchId: number): boolean {
    const holder: number = this.findTouchOf(keyId);
    return holder >= 0 && holder !== touchId;
  }

  /** 当前按住的触点数（自检与日志用）。 */
  activeCount(): number {
    return this.active.size;
  }

  /** 找该键的持有触点 id；没有返回 -1。 */
  private findTouchOf(keyId: string): number {
    let found: number = -1;
    this.active.forEach((value: string, key: number) => {
      if (found < 0 && value === keyId) {
        found = key;
      }
    });
    return found;
  }
}
