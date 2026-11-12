import io, re
p = 'entry/src/main/ets/model/MachineCatalog.ets'
s = io.open(p, encoding='utf-8').read()
# 字段：heroRawfile -> frontRawfile（注释同步）
s = s.replace("""  /** 解锁庆祝背景（主屏不用，见 §8.1）。 */
  heroRawfile: string;""", """  /** 第 13 批 ⑤：主页 hero 整机全图（正面全貌，Contain 呈现；运行期按静态分支取字面量）。 */
  frontRawfile: string;""")
# 四处注册值
pairs = [
    ("heroRawfile: 'machine/1920s-upright-hero-3q.jpg',", "frontRawfile: 'machine/1920s-upright-front.jpg',"),
    ("heroRawfile: 'machine/1930s-portable-hero.jpg',", "frontRawfile: 'machine/1930s-portable-front.jpg',"),
    ("heroRawfile: 'machine/1950s-streamlined-hero.jpg',", "frontRawfile: 'machine/1950s-streamlined-front.jpg',"),
    ("heroRawfile: 'machine/1960s-electric-hero.jpg',", "frontRawfile: 'machine/1960s-electric-front.jpg',"),
]
for a, b in pairs:
    assert a in s, a
    s = s.replace(a, b)
assert 'heroRawfile' not in s
io.open(p, 'w', encoding='utf-8').write(s)
print('catalog ok')
