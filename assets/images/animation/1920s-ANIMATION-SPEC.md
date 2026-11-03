# 1920s 默认机 · 动画素材一套规格

> 目标：服务主屏字杆摆起击打、字车滑动、拨杆换行三段动画（动画层叠加在
> 主屏机器区 / 纸面字车区上方）。本套只做默认机 1920s 直立式座机，验真
> 后再扩到其余 3 台。生成沿用机器图流程：用户在 Gemini 生成，我方验
> 一致性、抠图、归档。

## 部件清单（4 件）

| 文件 | 内容 | 用途 |
|---|---|---|
| typebar-single | 字杆单体：侧面单根裸金属字杆 + 空白字头（无字） | 代码绕支点旋转，摆起击打 |
| carriage-layer | 字车层：字车 + 压纸卷 + 纸（正面） | 代码横移，字车滑动 |
| lever-single | 拨杆单体：弯曲金属杆 + 圆头手柄 | 代码摆动，换行 |
| swing-frames | 摆动关键帧参考：4 格（静止→摆起中→击中→回弹） | 运动调参参考，不一定进包 |

## 生成规则（沿用机器图已验证的格式）

- 每件单独开 Gemini 对话，不混用；附图只附 1920s hero
  （`../machines/1920s-upright-hero-3q.jpg`）。
- 每条提示词是一整块可直接复制的代码块，角度句做主句开头；
  参考图只定外观，不复刻构图。
- 禁品牌名、型号名；字头空白无字（字由代码落在纸上，不 baked 进字头）；
  无可读文字、无 Logo；方形或 4:3。
- 背景一律纯色暖灰（便于抠图去背）。

## 验收

- 与 hero 同机：黑皱纹漆语境、裸金属质感、磨损感一致。
- 字头空白；无文字、无 Logo；背景纯色；4 件齐全。

## 后处理（图片到后执行）

1. 一致性检查（与 hero 比对，不撞 Valentine / Selectric 禁用组合；
   部件为通用金属件，撞脸风险低，仍要过一遍）。
2. 抠图去背：首选 rembg（图片到后装包、下模型再验）；兜底 PIL 纯色
   背景抠图（故提示词要求纯色背景）。
3. 归档：`assets/images/animation/1920s-upright/`，命名
   `typebar-single.png`、`carriage-layer.png`、`lever-single.png`、
   `swing-frames.jpg`；来源与尺寸记本目录 README。

## 待真机调参（不是图片，但属本套齐全项）

- 摆动时长、角度、回弹次数；字车滑动距离与纸 creep 幅度；
  叠加对齐：部件图角度按部件自身最清楚的角度出（字杆侧面、字车
  正面），与 hero 的 3/4 视图不完全同角，叠加时以代码支点 / 位置
  对齐为准，真机上调；若叠加后穿帮，改走关键帧序列（自成一体，
  不依赖叠加对齐）。

## 生成记录

- 2026-11-03 字杆单体首版两张验真结论：不能作部件层（整机特写、杆与
  篮子机身互遮、两张杆形不一致、第二张字头疑似有 X 刻痕），转作摆动
  参考，归档 `1920s-upright/ref/swing-ref-01.jpg`、`swing-ref-02.jpg`；
  字杆单体按修订提示词重出（隔离句：alone in the frame, nothing else，
  并钉死直杆 + 底部支点孔 + 字头全空）。

## 生成记录（2026-11-03 21:07–21:12）
- 三件全部重新生成并通过验收：字杆干净版（无重影，支点孔+空白字头完整）、拨杆（弯曲杆+圆头手柄+支点端完整）、字车层（压纸卷+空白纸+两侧旋钮+纸挡杆完整，中心标尺仅不可读刻度）。
- 归档：typebar-single.jpg（干净版；带重影旧版移至 ref/typebar-single-ghost.jpg）、lever-single.jpg、carriage-layer.jpg，均为 2048×2048。
- 抠图：rembg u2net（默认 bria 模型 1.02GB 曾被重启打断，改 u2net 176MB），三张透明 PNG 已验边（深色底合成目视干净）：typebar-single.png、lever-single.png、carriage-layer.png。
- 实现方式前提：三层角度各自独立（字杆侧面、字车正面、拨杆斜侧），不能直接贴回 hero 整机照片做像素级对齐；动画走“独立舞台”（主屏动画区内三层按时序动，文档纸面字由代码文本层同步落字）。若要“杆从 hero 篮子里摆出来”的合体效果，需另出同角度机身层+篮子层+杆层整机分层素材。

## 合体路线（2026-11-03 21:13 用户定：杆从篮子里摆出来）
- 路线：hero 整机照片作底 + 一张 hero 同视角字杆层叠在篮子区，代码绕支点旋转（静止角藏进篮子、击打角字头到纸面击打点），击打瞬间同步音效+落字+字车微移。独立舞台三层退位：字杆侧面版作备用；字车层、拨杆先留着（以后要做 hero 视角版时同方法再出）。
- 新件：typebar-hero-angle（hero 三-quarter 视角单根字杆，斜向上姿态，纯色暖灰底，支点孔+空白字头）。
- 到货后我方量算：① hero 图上篮子支点像素 + 纸面击打点像素；② 层图上支点孔像素 + 字头像素；③ 缩放 = hero 支点→击打点距离 ÷ 层支点→字头距离；④ 对齐 = 两支点重合；⑤ 静止角/击打角由旋转定。抠图走 rembg u2net。对不上（杆够不着纸、角度差太多）调提示词重出，不硬凑。
- 提示词（单独开对话，附图只附 1920s hero）：
```
A single typebar spare part from a vintage 1920s upright standard typewriter, seen from the same three-quarter front view as the reference image, tilted diagonally upward: one long straight slender flat bare-metal arm, a small round pivot hole at the bottom end, a small blank rectangular type slug head at the top end, the slug face completely blank with no letter, no engraved mark, no text anywhere, no logo, no brand name. The part floats alone in the frame, centered, on a plain solid warm gray background with generous empty margin around it. No machine body, no keyboard, no paper roller, no carriage, no other typebars, no basket. Use the reference only for the machine's appearance, camera angle and proportions: black crinkle-paint metal, worn bare steel, the same long slender typebar proportions as the typebars in the reference image. Soft diffused top light, macro product photography, high detail
```

## hero 视角字杆首版未过（2026-11-03 21:18 用户发，判怪）
- 画面：单根斜置字杆，支点孔端完整、纯色暖灰底、无文字，隔离与空白字头这两点是对的。
- 怪在三处：① 字头过大过亮过干净，跟磨损杆身不像同一件东西，看着像顶了块小镜子；② 杆身过长过细，整体像根长柄工具，不像打字机字杆；③ 角度没按 hero 走——纯侧面斜置，不是 hero 的 3/4 视角，叠到篮子里透视对不上。
- 根因：提示词里“斜向上”与“同视角”打架，模型取了最省事的斜置画法；字头尺寸没钉死，画大画亮了。修正方向：姿态改回篮子里静止的样子（摆动交给代码旋转），字头钉死为“仅比杆身略宽、同款做旧不抛光”。

## hero 视角字杆第二版仍未过（2026-11-03 21:21 用户发，判区别不大）
- 画面：斜置悬浮单体如故（字头略小略暗是唯一变化），透视仍未贴上 hero。两次实证结论：单体隔离提示词这条路，模型画不出 hero 视角的杆——再出第三版同类提示词只是重复。
- 改走编辑法：不再凭空出单体，改以 hero 原图为底直接编辑出一根摆起的杆（同图同透视同坐标，对齐天然精确）。到货后验三点：① 机器其余部分与原 hero 一致未被改；② 摆起的杆单根、字头空白；③ 量杆支点像素（与原 hero 同坐标系，直接对齐）。抠出杆层后，静止角由代码旋转回去。编辑法不行再退回侧面版特写舞台。

## 编辑法在 Gemini 侧失败（2026-11-03 21:23 用户报）
- 编辑 hero 出摆起杆：Gemini 直接回了原图（编辑指令未生效、原样回显）。教训：“keep everything exactly the same”锚定过强可能导致模型回显；下次改动指令放前面、保留指令放后面。
- 用户令：改用我方图片生成工具试一次。

## 我方工具编辑 hero 出摆起杆（2026-11-03 21:23–21:30）
- 编辑本身成功（Gemini 回显原图的问题没复现）：机身基本保住（hero 与编辑图整体平均色差 8.7，杆区外仅 7.1，属重绘噪声量级；编辑图 1600×1600，低于 hero 的 2048）。
- 杆层提取三轮：① rembg 整图 = 整台机器（u2net 认机器为主体，不可用）；② 差异区掩码 = 漏风扇/色带/铭牌/按键（编辑重绘了细部结构，阈值分不开）；③ 收窄+多边形掩码 = 杆柱干净，但叉头右侧被切、残留 2–3 根色带细线 + 1 个螺丝点。结论：合体在原理上已通（杆确实在 hero 透视里竖起来了），瓶颈只剩图层提取的边缘干净度。
- 待用户选：再精修一轮掩码 / 就用当前 draft 层 / 退回侧面版特写舞台。draft 层文件：typebar-hero-edit-layer-draft.png（多边形版）、typebar-hero-edit-layer-tight-draft.png（收窄版，含篮子盘泄漏，仅作对比）。

## 独立杆第三版提示词（2026-11-03 21:28 用户令再试）
- 前两版教训：“同视角”这个要求模型做不到——单根杆没有正侧面可言，模型只能画默认斜置；再要求透视只是重复失败。
- 第三版改弦：去掉视角要求，改成竖直正视图（杆在击打瞬间本来就是竖直的，这个姿态模型画得准）；比例用数字钉死（杆宽约杆长 1/12，字头实心块约杆宽 2 倍、同款做旧不抛光、杆身笔直无弯曲）；透视差由代码摆放与旋转消化，不靠生成一次到位。这次不用附 hero，免得模型又去对透视。
- 提示词（单独开对话，出一张）：
```
A single typebar spare part from a vintage 1920s upright standard typewriter, standing perfectly vertical in the center of the frame, front view: one perfectly straight, flat, broad bare-metal arm, about one-twelfth as wide as it is long, a small round pivot hole at the bottom end, a small solid rectangular type slug block at the top end, about twice as wide as the arm, the slug face completely blank with no letter, no engraved mark, no text anywhere, no logo, no brand name, the slug with the same worn dark finish as the arm, not polished, not bright. The part floats alone in the frame on a plain solid warm gray background with generous empty margin around it. No machine body, no keyboard, no paper roller, no carriage, no other typebars, no basket. Worn bare steel, soft diffused top light, macro product photography, high detail
```

## 独立杆第三版通过（2026-11-03 21:30 用户发，判成功）
- 三项全过：竖直正视图居中、杆身笔直磨损、实心字头空白且同款做旧、底端支点孔完整、无文字无 Logo。
- 归档：typebar-vertical.jpg + typebar-vertical.png（rembg u2net 抠图，深色底验边干净，地面阴影已干净去掉）。
- 动画参数：支点 = 底端圆孔中心，约 (1024, 1776)（2048×2048 层坐标）；代码绕该点旋转即摆动；击打姿态即本图竖直态，静止姿态由旋转回去得到。
