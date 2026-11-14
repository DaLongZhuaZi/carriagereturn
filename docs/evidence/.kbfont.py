import io
p = 'entry/src/main/ets/components/CanvasTypewriter.ets'
s = io.open(p, encoding='utf-8', newline=None).read()
old = "this.keymap.overlayFontSize.toString() + 'vp ' + this.canvasFont()"
new = "this.keymap.overlayFontSize.toString() + 'vp sans-serif'"
assert old in s
s = s.replace(old, new, 1)
io.open(p, 'w', encoding='utf-8', newline='\r\n').write(s)
print('overlay font sans ok')
