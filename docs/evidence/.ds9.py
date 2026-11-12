import io, json, collections

NEW_KEYS = [
    ('export_range_paper', '当前纸', 'Current paper'),
    ('export_range_doc', '整篇', 'Whole document'),
    ('export_range_dossier', '整卷宗', 'Whole dossier'),
    ('export_range_png_hint', '多页请用 PDF', 'Use PDF for multiple pages'),
]

for loc in ['base', 'zh_CN', 'en_US']:
    p = 'entry/src/main/resources/%s/element/string.json' % loc
    d = json.load(io.open(p, encoding='utf-8'), object_pairs_hook=collections.OrderedDict)
    existing = {item['name'] for item in d['string']}
    for name, zh, en in NEW_KEYS:
        if name in existing:
            continue
        val = zh if loc in ('base', 'zh_CN') else en
        d['string'].append(collections.OrderedDict([('name', name), ('value', val)]))
    io.open(p, 'w', encoding='utf-8').write(json.dumps(d, ensure_ascii=False, indent=2) + '\n')
    print(loc, 'strings ok')

# ---------------- ExportService.buildTxtFromText ----------------
p2 = 'entry/src/main/ets/services/ExportService.ets'
s = io.open(p2, encoding='utf-8', newline=None).read()
old = """  static buildTxt(docId: string): ExportResult {"""
new = """  /** 第 13 批 ⑥：任意纯文本 → UTF-8 字节（整卷宗 TXT 组装后走这条）。 */
  static buildTxtFromText(text: string): ExportResult {
    try {
      const encoded: Uint8Array = new util.TextEncoder().encodeInto(text);
      const words: ArrayBuffer = new ArrayBuffer(encoded.length);
      const view: Uint8Array = new Uint8Array(words);
      for (let i = 0; i < encoded.length; i++) {
        view[i] = encoded[i];
      }
      hilog.info(DOMAIN, TAG, 'buildTxtFromText ok bytes=%{public}s', encoded.length.toString());
      return { ok: true, bytes: words, error: '' };
    } catch (e) {
      const err: BusinessError = e as BusinessError;
      hilog.error(DOMAIN, TAG, 'buildTxtFromText failed: %{public}s', ExportService.errText(err));
      return { ok: false, bytes: null, error: ExportService.errText(err) };
    }
  }

  static buildTxt(docId: string): ExportResult {"""
assert old in s
s = s.replace(old, new, 1)
io.open(p2, 'w', encoding='utf-8', newline='\r\n').write(s)
print('service txt ok')
