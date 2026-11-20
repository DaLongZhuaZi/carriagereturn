import io
import sys

p = 'docs/evidence/.prefs2.xml'
s = io.open(p, encoding='utf-8').read()
n = s.replace('key="cn_engine">system<', 'key="cn_engine">builtin<')
if n == s:
    print('no change needed / pattern missing')
else:
    io.open('docs/evidence/.prefs_fix.xml', 'w', encoding='utf-8').write(n)
    print('cn_engine -> builtin, written .prefs_fix.xml', len(n))
