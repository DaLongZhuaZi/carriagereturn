import io
p = 'tools/tests/export-static.test.mjs'
s = io.open(p, encoding='utf-8', newline=None).read()
old = "    const guard = block.indexOf('this.onBeforeExport()');"
new = "    const guard = block.indexOf('this.onBeforeExport(this.range, this.dossierId)');"
assert old in s
s = s.replace(old, new, 1)
io.open(p, 'w', encoding='utf-8', newline='\r\n').write(s)
print('test updated')
