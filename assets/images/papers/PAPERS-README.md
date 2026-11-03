# 回车 CarriageReturn · 纸纹素材说明

位置：`assets/images/papers/`（本地素材，未推远端，与机器图/音效同一口径）。

## 主用 4 种（AI 生成，2026-11-03 定稿）

四张全部空白无字、无格线无边距（格线类仍由代码层画），均有真实纸感
（纤维、纹理、纸面起伏），与程序化噪点拉开差距。

- `paper-letter.jpg`：信纸，Gemini 生成（用户 19:27 上传原图归档），
  2048×2048，暖奶油底 + 做旧边角 + 竖向 laid 线 + 细纤维。
- `paper-manuscript.jpg`：稿纸，自有生图工具生成，1600×1600，
  亮米白 #ece9e4，细冷压纹理 + 稀疏纤维，最干净一张。
- `paper-postcard.jpg`：明信片，自有生图工具生成，1920×1280 横幅
  （明信片本身横向，App 侧 cover 裁切），暖奶油 #e6d8bd，
  粗纤维 + 明显纸面齿感，四张里质感最粗。
- `paper-memo.jpg`：便签，自有生图工具生成，1600×1600，
  浅暖黄 #f7e49b，细颗粒 + 淡纤维。

## 程序化 4 种（已降级为备用底色，2026-11-03 用户直言其为模糊单色噪点、无特点）

生成脚本：`gen-paper-textures.py`（细颗粒噪点 + 低频斑驳 + 稀疏纤维短线；
格线/边距/红格/页眉一律不 baked 进纹理，由 App 代码层绘制，素材调研报告定稿）。
规格：2048×2560 JPG q92，整页背景用。
用户 verdict：程序化噪点只有颗粒层、没有纸的特征（纤维、纹理、纸感），
不作主用纸纹，仅留作兜底纯色背景；主用纸纹改走 Gemini 生成（见下）。

- `paper-letter.jpg`：信纸，底色 #eee4ce（风格板纸主色），1,436,530 字节
- `paper-manuscript.jpg`：稿纸，底色 #f2ede0（稍亮稍白），1,432,756 字节
- `paper-postcard.jpg`：明信片，底色 #e8dcc2（卡纸感，颗粒与纤维稍强），1,609,596 字节
- `paper-memo.jpg`：便签，底色 #f2e6bd（淡暖黄），1,432,178 字节

4 张同 generator、仅底色与颗粒强度不同，区分主要靠底色 + 代码层绘制的
格线/页眉；纹理本身保持克制，不抢正文 legibility。中心区域均值实测与目标
底色一致（±1）。

## CC0 照片纹理（备用）

- `cc0-paper001-color.jpg`：ambientCG Paper 001 Color 图，2048×1201，近白纸面
  细颗粒，1,413,518 字节；可作稿纸提亮版或照片颗粒备选。
- 来源：https://ambientcg.com/view?id=Paper001（页面明示 CC0，可商用无需署名）
  下载：https://ambientcg.com/get?file=Paper001_2K-JPG.zip（原包留存 paper001-2k.zip；
  3D 专用 Normal/Roughness/Displacement 等图已删，只留 Color 图）。
- Poly Haven 本轮沙箱内不可达（Cloudflare 522，两次重试均失败），未采用；
  ambientCG API 的 full_json 搜索参数（query/queryString/POST 体）均被忽略返回
  全量，故改走 view 页直链下载，已验真。

## 待后续

- 主用纸纹已齐（2026-11-03）：信纸走 Gemini（用户侧唯一成功的一张），
  其余三张 Gemini 反复失败后改走自有生图工具兜底；程序化 4 张全部降级
  为 `*-procedural.jpg` 备用底色。
- 明信片/便签装饰图案（边框、花纹类）：按素材调研报告走 AI 生成，不属本批
  底纹；需要时用 Gemini 按提示词出图（示例：Vintage postcard illustration,
  old paper texture, simple botanical border, muted warm colors, no text,
  no letters, no watermark），再归档。
