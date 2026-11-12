import io, json, collections
p = 'entry/src/main/resources/base/element/string.json'
d = json.load(io.open(p, encoding='utf-8'), object_pairs_hook=collections.OrderedDict)
items = d['string']
existing = {it['name'] for it in items}
add = [
    ('guide_onboarding2_p1_title', '打字'),
    ('guide_onboarding2_p1_body', '敲下去，字就落在纸上；拉拨杆换行。'),
    ('guide_onboarding2_p2_title', '机器与换装'),
    ('guide_onboarding2_p2_body', '1920s／1930s／1950s／1960s 四台时代机在「收藏」里随时换；信纸／色带／字体在换装里选，即时生效，字体、纸张可导入自定义。'),
    ('guide_onboarding2_p3_title', '纸与卷宗'),
    ('guide_onboarding2_p3_body', '写过的纸存在卷宗里，同一类纸收在一起；删除的纸暂存回收站 30 天，可恢复。'),
    ('guide_onboarding2_p4_title', '导出与成就'),
    ('guide_onboarding2_p4_body', '导出成图片、PDF 或纯文本，可只存本地或直接分享；14 项行为成就，打字、分享、换装都会解锁。'),
    ('guide_onboarding2_p5_title', '中文输入'),
    ('guide_onboarding2_p5_body', '内置拼音输入法，候选栏、「我的词库」随手调。'),
    ('guide_onboarding2_start', '开始写作'),
]
for name, value in add:
    if name in existing:
        continue
    items.append(collections.OrderedDict([('name', name), ('value', value)]))
io.open(p, 'w', encoding='utf-8').write(json.dumps(d, ensure_ascii=False, indent=2) + '\n')
print('strings ok', len(add))
