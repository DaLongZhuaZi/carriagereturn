import json, io, collections

EDITS = {
    '1930s-portable': [(246, 1076, 'Shift', 'Caps Lock')],
    '1950s-streamlined': [(215, 981, 'extra', 'Tab'), (240, 1111, 'Shift', 'Caps Lock'),
                          (1765, 1238, 'extra', 'Shift')],
    '1960s-electric': [(1853, 786, 'extra', 'Backspace'), (190, 919, 'extra', 'Tab'),
                       (1612, 919, 'extra', '|'), (1821, 919, 'Backspace', '\\'),
                       (213, 1050, 'Shift', 'Caps Lock')],
}

for m, edits in EDITS.items():
    for copy in ['entry/src/main/resources/rawfile/keymap', 'assets/images/machines']:
        p = f'{copy}/{m}-keymap.json'
        d = json.load(io.open(p, encoding='utf-8'), object_pairs_hook=collections.OrderedDict)
        done = set()
        for row in d['rows']:
            for cap in row['caps']:
                for (x, y, old, new) in edits:
                    if int(cap['x']) == x and int(row['y']) == y and cap['label'] == old:
                        cap['label'] = new
                        done.add((x, y))
        assert len(done) == len(edits), (m, done, edits)
        io.open(p, 'w', encoding='utf-8').write(json.dumps(d, ensure_ascii=False, indent=2) + '\n')
    print(m, 'labels ok')
print('done')
