import io
import re

s = io.open('docs/evidence/.prefs2.xml', encoding='utf-8').read()
print('len', len(s))
pat = re.compile(r'<[^>]*key="([^"]+)"[^>]*>')
for m in pat.finditer(s):
    k = m.group(1)
    if 'custom' in k or k == 'cn_engine' or 'paper' in k:
        print(m.group(0)[:140])
