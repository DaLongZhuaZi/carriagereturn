// 回车 · 每机音效包静态断言（第 4 批 F8）
// 运行：node --test tools/tests/audio-packs.test.mjs
import { test } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.dirname(path.dirname(here));
const SOUND = path.join(root, 'entry/src/main/resources/rawfile/sound');
const PACKS = ['pack', 'pack-1930', 'pack-1950', 'pack-1960'];

test('四包齐全：基线 23 个 .ogg、新包 19 个 .ogg + SOURCE.txt', () => {
  for (const pack of PACKS) {
    const dir = path.join(SOUND, pack);
    assert.ok(fs.existsSync(dir), `缺包 ${pack}`);
    const files = fs.readdirSync(dir);
    const oggs = files.filter((f) => f.endsWith('.ogg'));
    const expected = pack === 'pack' ? 23 : 19;
    assert.equal(oggs.length, expected, `${pack} .ogg 数=${oggs.length}`);
    assert.ok(files.includes('SOURCE.txt'), `${pack} 缺 SOURCE.txt`);
  }
});

test('每包五类角色文件齐全（无前缀名）', () => {
  const roles = {
    key: (s) => s.startsWith('key-') && !s.startsWith('key-alt') && !s.startsWith('key-transient'),
    space: (s) => s.startsWith('space-'),
    bell: (s) => s.startsWith('bell-'),
    reset: (s) => s.startsWith('carriage-reset'),
    backspace: (s) => s.startsWith('key-alt'),
  };
  for (const pack of PACKS) {
    const stems = fs.readdirSync(path.join(SOUND, pack))
      .filter((f) => f.endsWith('.ogg')).map((f) => f.slice(0, -4));
    for (const [role, pred] of Object.entries(roles)) {
      assert.ok(stems.some(pred), `${pack} 缺角色 ${role}`);
    }
    assert.ok(stems.includes('key-transient'), `${pack} 缺 key-transient`);
  }
});

test('SOURCE.txt：新包两半齐全（原始素材＋逐文件切分映射），断言格式非具体作者', () => {
  // M1：旧断言硬编码 DSP 时代作者 ddohler/YleArkisto，替换后必然挂；改断言格式。
  // 另：只查 pack-1930 改为三包全查。
  for (const pack of ['pack-1930', 'pack-1950', 'pack-1960']) {
    const text = fs.readFileSync(path.join(SOUND, pack, 'SOURCE.txt'), 'utf8');
    for (const needle of ['§1 原始素材', '§2 逐文件切分映射', 'SHA-256', 'cut-sound-packs.py']) {
      assert.ok(text.includes(needle), `${pack} SOURCE 缺 ${needle}`);
    }
    // 19 条逐文件 SHA-256 映射（§1 原始素材的 SHA 另计，故用 >=19）
    const mappings = text.match(/SHA-256：[0-9a-f]{64}/g) || [];
    assert.ok(mappings.length >= 19, `${pack} SHA 映射=${mappings.length}`);
    // 至少一种许可证记录
    assert.ok(text.includes('CC0') || text.includes('CC BY') || text.includes('public domain'),
      `${pack} SOURCE 缺许可证记录`);
    // DSP 时代作者必须消失（证明包已替换，非改名）
    assert.ok(!text.includes('ddohler') && !text.includes('YleArkisto'),
      `${pack} SOURCE 仍含 DSP 时代作者`);
  }
});

test('AudioService：packForMachine 四机映射 + AudioTrace 有 pack 字段', () => {
  const audio = fs.readFileSync(path.join(root, 'entry/src/main/ets/services/AudioService.ets'), 'utf8');
  assert.ok(audio.includes("return 'pack-1930'"));
  assert.ok(audio.includes("return 'pack-1950'"));
  assert.ok(audio.includes("return 'pack-1960'"));
  assert.ok(audio.includes("return DEFAULT_PACK_NAME"));
  assert.ok(audio.includes('static packForMachine'));
  // 双缓冲：不再在 preload 开头 teardown
  const preloadStart = audio.indexOf('async preload(');
  const preloadEnd = audio.indexOf('static packForMachine');
  const body = audio.slice(preloadStart, preloadEnd);
  assert.ok(!body.includes('this.teardown();'), 'preload 仍先 teardown');
  assert.ok(audio.includes('preloadGeneration'));
  const trace = fs.readFileSync(path.join(root, 'entry/src/main/ets/services/AudioTrace.ets'), 'utf8');
  assert.ok(trace.includes('pack: string'));
});

test('Index：唯一 preload 入口且来自 packForMachine', () => {
  const index = fs.readFileSync(path.join(root, 'entry/src/main/ets/pages/Index.ets'), 'utf8');
  const calls = (index.match(/audioService\.preload\(/g) || []).length;
  assert.equal(calls, 1, `preload 调用数=${calls}`);
  assert.ok(index.includes('AudioService.packForMachine(kind as string)'));
});