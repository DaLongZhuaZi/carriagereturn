# 批 64：在 Index.measureStage 里调用 StageLayout 打点（真机对账五区高度）
# 注意：本脚本已做幂等（MARK 区块只插一次），重复运行不会再叠一份（2026-11-21 被误跑打断过构建）。
import io

P = r'entry/src/main/ets/pages/Index.ets'
s = io.open(P, encoding='utf-8').read()

IMP = "import { Stage26, StageLayout } from '../components/type26/Stage26';\n"
if IMP not in s:
    legacy = "import { StageLayout } from '../components/type26/Stage26';\n"
    if legacy in s:
        s = s.replace(legacy, IMP, 1)
    else:
        anchor = "import { PaperRow } from '../ui/PaperSheet';\n"
        if anchor not in s:
            raise SystemExit('import anchor missing')
        s = s.replace(anchor, anchor + IMP, 1)

MARK = "      // 批 38（平板竖屏首验）：几何打点——k／居中偏移／画布／纸面板宽，与 Carriage26 的 geom 行对账"
ADD = """      // 批 64 阶段 1：舞台容器换算表打点（真机对账五区高度，与设计稿 §3.2 表比对）
      const stageL: StageLayout = new StageLayout(stageW, this.winHeightVp > 0 ? this.winHeightVp : winH);
      hilog.info(DOMAIN, TAG, 'stage26 %{public}s', stageL.describe());
"""
if "stage26 %{public}s" not in s:
    if MARK not in s:
        raise SystemExit('geom26 mark missing')
    s = s.replace(MARK, ADD + MARK, 1)

io.open(P, 'w', encoding='utf-8').write(s)
print('stage26 probe ensured (idempotent)')
