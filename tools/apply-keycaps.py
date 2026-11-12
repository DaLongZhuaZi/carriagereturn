"""第 13 批 ①：把量测结果写入 keymap 两副本（wRatio/hRatio/rRatio/shape + space.rRatio）。

母版尺寸：phone 带 2048×975。hRatio 一律按 975 换算（fold 带 parse 时按 975/853 重算）。
宽键用实测 w/h；普通键用基准格；1930s 两个未检出帽（0、-）回落基准格。
空格圆角：目视估计（1920s≈16px、1930s≈20px、1950s≈28px、1960s≈12px），写入 rRatio。
"""
import json, io, collections

BAND_W = 2048.0
BAND_H = 975.0
MEAS = json.load(io.open('docs/evidence/keycap_measure.json', encoding='utf-8'))
SPACE_R_PX = {
    '1920s-upright': 16.0,
    '1930s-portable': 20.0,
    '1950s-streamlined': 28.0,
    '1960s-electric': 12.0,
}

def r4(v):
    return round(v, 4)

for m in MEAS:
    kind = m['kind']
    base_w = m['base_w_px']; base_h = m['base_h_px']
    shape = m['shape']
    hr = base_h / BAND_H
    wr = base_w / BAND_W
    if shape == 'circle':
        rr = (base_w / 2.0) / BAND_W
    else:
        rr = (base_h / 2.0) / BAND_W
    wide = {}
    for cap in m['wide_caps']:
        wide[(cap['x'], cap['label'])] = (cap['w'], cap['h'])
    rratio_space = SPACE_R_PX[kind] / BAND_W
    for copy in ['entry/src/main/resources/rawfile/keymap', 'assets/images/machines']:
        p = f'{copy}/{kind}-keymap.json'
        d = json.load(io.open(p, encoding='utf-8'), object_pairs_hook=collections.OrderedDict)
        for row in d['rows']:
            for cap in row['caps']:
                w, h = base_w, base_h
                hit = wide.get((int(cap['x']), cap['label']))
                if hit is not None:
                    w, h = hit
                cap['shape'] = shape
                cap['wRatio'] = r4(w / BAND_W)
                cap['hRatio'] = r4(h / BAND_H)
                cap['rRatio'] = r4((w / 2.0) / BAND_W if shape == 'circle' else (h / 2.0) / BAND_W)
        d['space']['rRatio'] = r4(rratio_space)
        io.open(p, 'w', encoding='utf-8').write(json.dumps(d, ensure_ascii=False, indent=2) + '\n')
    print(kind, 'shape', shape, 'base', base_w, base_h, 'wr', r4(wr), 'hr', r4(hr), 'rr', r4(rr), 'wide', len(wide))
print('keymaps updated')
