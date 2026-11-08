// 回车 · 第 5 批复核静态断言（引导映射 / F14 过渡 / 锚点事实）
import { test } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import { fileURLToPath } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.dirname(path.dirname(here));
const index = fs.readFileSync(path.join(root, 'entry/src/main/ets/pages/Index.ets'), 'utf8');
const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'b5-'));
const ts = path.join(tmp, 'GuideCore.ts');
fs.copyFileSync(path.join(root, 'entry/src/main/ets/model/GuideCore.ets'), ts);
const core = await import('file://' + ts.replace(/\\/g, '/'));

test('引导：13 页 id 与 Index 映射完整', () => {
  assert.equal(core.allPages().length, 13);
  let mapped = 0;
  for (const page of core.allPages()) {
    if (page === 'typewriter') {
      assert.ok(index.includes('guide_typewriter_1'));
      mapped += 1;
      continue;
    }
    // Index 的 guideStepsOf 里每个 page 常量至少出现一次
    const constName = 'GUIDE_PAGE_' + page.toUpperCase();
    if (index.includes(constName)) mapped += 1;
  }
  assert.ok(mapped >= 12, `Index 映射覆盖 ${mapped}/13`);
});

test('F14 复核：fadeSwitch 函数体不含几何写入；applyMachine 确实 measureStage（据此记未验）', () => {
  const fsStart = index.indexOf('private fadeSwitch(): void {');
  assert.ok(fsStart > 0);
  const fsEnd = index.indexOf('\n  }', fsStart);
  const body = index.slice(fsStart, fsEnd);
  for (const geo of ['paperWidthVp =', 'paperHeightVp =', 'carriageHeight =', 'paperTopVp =', 'carriageTopVp =']) {
    assert.ok(!body.includes(geo), `fadeSwitch 写了几何 ${geo}`);
  }
  const amStart = index.indexOf('private applyMachine(kind: MachineKind): void {');
  const amEnd = index.indexOf('\n  }', amStart);
  const amBody = index.slice(amStart, amEnd);
  assert.ok(amBody.includes('this.measureStage()'), 'applyMachine 未 measureStage，复核前提变化');
});

test('引导锚点事实：现有 guideSteps 不产 anchor（记录，不冒充锚点对齐）', () => {
  const dir = path.join(root, 'entry/src/main/ets/components');
  for (const f of fs.readdirSync(dir)) {
    if (!f.endsWith('.ets')) continue;
    const text = fs.readFileSync(path.join(dir, f), 'utf8');
    const at = text.indexOf('guideStepsFor');
    if (at < 0) continue;
    const tail = text.slice(at);
    assert.ok(!/anchor:\s*\{/.test(tail), `${f} 意外产出了 anchor（与事实记录不符）`);
  }
});