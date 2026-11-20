# 批 64：把 hilog import 移到 Stage26.ets 顶部（ArkTS 不许 import 出现在语句之后）
import io

P = r'entry/src/main/ets/components/type26/Stage26.ets'
s = io.open(P, encoding='utf-8').read()

IMP = "import { hilog } from '@kit.PerformanceAnalysisKit';"
# 删掉文件中部那行 import
s = s.replace(IMP + "\n", "", 1)
# 放到文件最前面
s = IMP + "\n\n" + s
io.open(P, 'w', encoding='utf-8').write(s)
print('first line:', s.splitlines()[0])
print('import count:', s.count(IMP))
