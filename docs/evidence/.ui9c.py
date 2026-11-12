import io
p = 'entry/src/main/ets/components/ExportPage.ets'
s = io.open(p, encoding='utf-8', newline=None).read()
old = """            Column().width('100%').height(16)

            this.formatRows()"""
new = """            Column().width('100%').height(16)

            this.rangeRow()

            this.formatRows()"""
assert old in s
s = s.replace(old, new, 1)
io.open(p, 'w', encoding='utf-8', newline='\r\n').write(s)
print('range row inserted')
