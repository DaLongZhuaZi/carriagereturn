import io
p = 'tools/audit-switches.py'
s = io.open(p, encoding='utf-8', newline=None).read()
old = 'SWITCH_KEYS = {"guide.enabled", "custom.enabled", "custom.knob.enabled"}'
new = 'SWITCH_KEYS = {"guide.enabled", "custom.enabled", "custom.knob.enabled", "canvas.enabled"}'
if old not in s:
    raise SystemExit('MISS')
io.open(p, 'w', encoding='utf-8', newline='\n').write(s.replace(old, new, 1))
print('audit switch added')
