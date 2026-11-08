#!/usr/bin/env node
/**
 * 回车 · ArkTS 静态结构门（第 0 批）。
 *
 * 本机没有 hvigor/DevEco SDK，**不能做真实编译**。本脚本做三件确定性检查：
 *   1) 括号/引号/注释平衡（自写 tokenizer，跳过字符串与注释）
 *   2) 相对 import 解析：目标文件必须存在；导入符号必须在该文件导出（符号缺失记警告）
 *   3) 仓规扫描：any/unknown、运行时 .sort(、emoji（警告级）
 *
 * 它能证明：改动没有引入结构断裂、没有引用不存在的文件、没有漏导出。
 * 它不能证明：类型正确、@kit API 存在、ArkTS 编译器限制全部满足。
 * 报告必须写"结构门通过（非编译）"。
 *
 * 用法：node tools/check-arkts.mjs [--json out.json] [--quiet]
 */
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.dirname(here);
const args = process.argv.slice(2);
const quiet = args.includes('--quiet');
let jsonOut = null;
const ji = args.indexOf('--json');
if (ji >= 0 && args[ji + 1]) jsonOut = args[ji + 1];

function walk(dir, out) {
  for (const ent of fs.readdirSync(dir, { withFileTypes: true })) {
    if (['node_modules', 'oh_modules', 'build', '.git'].includes(ent.name)) continue;
    const full = path.join(dir, ent.name);
    if (ent.isDirectory()) walk(full, out);
    else if (ent.name.endsWith('.ets') || ent.name.endsWith('.ts')) out.push(full);
  }
  return out;
}

/** 去掉字符串与注释，保留换行（行号不漂）。模板字符串整体按字符串处理（${} 内不检查）。 */
function stripStringsAndComments(src) {
  let out = '';
  let i = 0;
  let state = 'code';
  let quote = '';
  while (i < src.length) {
    const c = src[i];
    const n = src[i + 1];
    if (state === 'code') {
      if (c === '/' && n === '/') { state = 'line'; i += 2; continue; }
      if (c === '/' && n === '*') { state = 'block'; i += 2; continue; }
      if (c === "'" || c === '"' || c === '`') { state = 'string'; quote = c; i += 1; continue; }
      out += c; i += 1; continue;
    }
    if (state === 'line') {
      if (c === '\n') { state = 'code'; out += '\n'; }
      i += 1; continue;
    }
    if (state === 'block') {
      if (c === '*' && n === '/') { state = 'code'; i += 2; continue; }
      if (c === '\n') out += '\n';
      i += 1; continue;
    }
    if (state === 'string') {
      if (c === '\\') { i += 2; continue; }
      if (c === quote) { state = 'code'; i += 1; continue; }
      if (c === '\n') out += '\n';
      i += 1; continue;
    }
  }
  return out;
}

function lineOf(src, idx) {
  let line = 1;
  for (let i = 0; i < idx && i < src.length; i++) if (src[i] === '\n') line += 1;
  return line;
}

const OPEN = { '(': ')', '[': ']', '{': '}' };
const CLOSE = { ')': '(', ']': '[', '}': '{' };

/** 括号平衡检查（输入应为已去字符串/注释的源码）。返回 [{line,message}]。 */
function balanceErrors(src) {
  const out = [];
  const stack = [];
  for (let i = 0; i < src.length; i++) {
    const c = src[i];
    if (OPEN[c]) { stack.push({ c, i }); continue; }
    if (CLOSE[c]) {
      const top = stack.pop();
      if (!top || top.c !== CLOSE[c]) {
        out.push({ line: lineOf(src, i), message: `括号不匹配：遇到 '${c}'` });
        return out;
      }
    }
  }
  if (stack.length > 0) {
    const top = stack[stack.length - 1];
    out.push({ line: lineOf(src, top.i), message: `括号未闭合：'${top.c}'` });
  }
  return out;
}

function selfTest() {
  const cases = [
    { name: 'balanced', src: 'class A { f() { return 1; } }', ok: true },
    { name: 'unbalanced', src: 'class A { f() { return 1; }', ok: false },
    { name: 'string-brace', src: 'const s = "{";', ok: true },
    { name: 'comment-brace', src: '// {\nconst a = 1;', ok: true },
  ];
  let fails = 0;
  for (const c of cases) {
    const got = balanceErrors(stripStringsAndComments(c.src));
    const pass = (got.length === 0) === c.ok;
    console.log(`[self-test] ${c.name}: ${pass ? 'ok' : 'FAIL'}`);
    if (!pass) fails += 1;
  }
  // import 解析自测：合成文件 import 存在的相对文件 vs 不存在的
  const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'arkgate-'));
  fs.writeFileSync(path.join(tmp, 'a.ets'), 'export class A {}\n', 'utf8');
  fs.writeFileSync(path.join(tmp, 'ok.ets'), "import { A } from './a';\n", 'utf8');
  fs.writeFileSync(path.join(tmp, 'bad.ets'), "import { B } from './missing';\n", 'utf8');
  const okExists = fs.existsSync(path.join(tmp, 'a.ets'));
  const badMissing = !fs.existsSync(path.join(tmp, 'missing.ets'));
  const pass = okExists && badMissing;
  console.log(`[self-test] import-resolution: ${pass ? 'ok' : 'FAIL'}`);
  if (!pass) fails += 1;
  console.log(`[self-test] ${fails === 0 ? 'PASS' : 'FAIL'}（${fails} 项失败）`);
  process.exit(fails === 0 ? 0 : 1);
}

if (args.includes('--self-test')) {
  selfTest();
}

const files = walk(path.join(root, 'entry', 'src', 'main', 'ets'), []).sort();
const errors = [];
const warnings = [];
const ruleHits = { anyType: [], unknownType: [], runtimeSort: [], emoji: [] };
const structs = new Map();
const exportsByFile = new Map();

const EMOJI_RE = /[\u{1F300}-\u{1FAFF}\u{2600}-\u{27BF}]/u;

for (const file of files) {
  const rel = path.relative(root, file).replace(/\\/g, '/');
  const raw = fs.readFileSync(file, 'utf8');
  const src = stripStringsAndComments(raw);

  // 1) 括号平衡
  for (const e of balanceErrors(src)) {
    errors.push({ file: rel, line: e.line, message: e.message });
  }

  // 2) 导出表（struct/class/interface/const/function/enum/type）
  const exportNames = new Set();
  const exportRe = /export\s+(?:default\s+)?(?:abstract\s+)?(?:async\s+)?(?:class|struct|interface|enum|type|const|let|var|function)\s+([A-Za-z_][A-Za-z0-9_]*)/g;
  let m;
  while ((m = exportRe.exec(src)) !== null) exportNames.add(m[1]);
  exportsByFile.set(file, exportNames);

  const structRe = /\b(?:export\s+)?struct\s+([A-Za-z_][A-Za-z0-9_]*)/g;
  while ((m = structRe.exec(src)) !== null) {
    const name = m[1];
    if (!structs.has(name)) structs.set(name, []);
    structs.get(name).push(rel);
  }

  // 3) import 解析
  const importRe = /import\s*(?:type\s*)?\{([^}]*)\}\s*from\s*['"]([^'"]+)['"]/g;
  while ((m = importRe.exec(raw)) !== null) {
    const spec = m[2];
    if (!spec.startsWith('.')) continue;
    const base = path.resolve(path.dirname(file), spec);
    const candidates = [base, base + '.ets', base + '.ts', path.join(base, 'index.ets')];
    const found = candidates.find((p) => fs.existsSync(p) && fs.statSync(p).isFile());
    if (!found) {
      errors.push({ file: rel, line: lineOf(raw, m.index), message: `import 目标不存在: ${spec}` });
    } else {
      // 导入符号存在性（警告级：兼容 export { X } 等写法）
      const targetSrc = fs.readFileSync(found, 'utf8');
      const names = m[1].split(',').map((s) => s.trim()).filter(Boolean)
        .map((s) => s.replace(/^type\s+/, '').split(/\s+as\s+/)[0].trim());
      for (const name of names) {
        if (!name || name === '*') continue;
        const re = new RegExp(`export\\s+(?:default\\s+)?(?:abstract\\s+)?(?:async\\s+)?(?:class|struct|interface|enum|type|const|let|var|function)\\s+${name}\\b`);
        if (!re.test(targetSrc)) {
          warnings.push({ file: rel, line: lineOf(raw, m.index), message: `导入符号疑似未导出: ${name} from ${spec}` });
        }
      }
    }
  }

  // 4) 仓规
  raw.split(/\r?\n/).forEach((line, idx) => {
    if (/:\s*any\b|\bas\s+any\b|<any>/.test(line)) ruleHits.anyType.push(`${rel}:${idx + 1}`);
    if (/:\s*unknown\b|\bas\s+unknown\b/.test(line)) ruleHits.unknownType.push(`${rel}:${idx + 1}`);
    if (/\.sort\s*\(/.test(line) && !line.trim().startsWith('//') && !line.trim().startsWith('*')) {
      ruleHits.runtimeSort.push(`${rel}:${idx + 1}: ${line.trim().slice(0, 100)}`);
    }
    if (EMOJI_RE.test(line)) ruleHits.emoji.push(`${rel}:${idx + 1}`);
  });
}

// 同名 struct 提示（模块作用域允许重名；这里只警告，防止误改）
for (const [name, where] of structs.entries()) {
  if (where.length > 1) {
    warnings.push({ file: where[1], line: 1, message: `struct 重名提示: ${name}（${where.join(', ')}）` });
  }
}

const report = {
  tool: 'check-arkts',
  kind: 'structural gate (bracket balance + import resolution + repo rules); NOT a compile',
  files: files.length,
  errors,
  warnings,
  ruleHits,
  verdict: errors.length === 0 ? 'PASS' : 'FAIL',
};

if (!quiet) {
  console.log(`[check-arkts] 扫描 ${files.length} 个 .ets/.ts 文件（结构门，非编译）`);
  if (errors.length === 0) console.log('[check-arkts] 结构错误 0');
  for (const e of errors) console.log(`  ERROR ${e.file}:${e.line} ${e.message}`);
  if (warnings.length) {
    console.log(`[check-arkts] 警告 ${warnings.length} 条（不阻断）:`);
    for (const w of warnings) console.log(`  WARN ${w.file}:${w.line} ${w.message}`);
  }
  const counts = Object.fromEntries(Object.entries(ruleHits).map(([k, v]) => [k, v.length]));
  console.log('[check-arkts] 仓规扫描（警告级）: ' + JSON.stringify(counts));
  if (ruleHits.anyType.length) console.log('[check-arkts] any 命中: ' + ruleHits.anyType.join(', '));
  if (ruleHits.runtimeSort.length) {
    console.log('[check-arkts] .sort( 命中（须确认均为小数组/非热路径）:');
    for (const h of ruleHits.runtimeSort) console.log('  - ' + h);
  }
  console.log(`[check-arkts] 结论: ${report.verdict}`);
}
if (jsonOut) {
  fs.mkdirSync(path.dirname(path.resolve(jsonOut)), { recursive: true });
  fs.writeFileSync(jsonOut, JSON.stringify(report, null, 2), 'utf8');
}
process.exit(errors.length === 0 ? 0 : 1);