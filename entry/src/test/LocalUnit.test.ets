import { describe, beforeAll, beforeEach, afterEach, afterAll, it, expect } from '@ohos/hypium';

// 脚手架占位测试: 功能开发阶段, 纯逻辑的单元测试在此目录补齐 (见开工提示词阶段 1 与阶段 4)。
export default function localUnitTest() {
  describe('localUnitTest', () => {
    beforeAll(() => {
    });
    beforeEach(() => {
    });
    afterEach(() => {
    });
    afterAll(() => {
    });
    it('scaffold_smoke', 0, () => {
      let a: string = 'CarriageReturn';
      expect(a).assertContain('Carriage');
    });
  });
}
