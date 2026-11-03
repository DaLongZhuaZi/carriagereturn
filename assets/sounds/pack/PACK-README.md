# 回车 CarriageReturn · App 内音效包 v1

位置：`assets/sounds/pack/`（23 个文件，共 196,644 字节 ≈ 192KB，预算 <2MB，用量约 9%）。
格式：OGG Vorbis 单声道 44.1kHz，峰值归一化 -1.5dB（Vorbis 重建过冲留 headroom；
解码验真：全部峰值 ≤0.95，无削波）。
构建脚本：`../build-pack.py`（能量跃升检出 onset，时间均匀取段；单音首尾静音修剪）。
来源与协议见 `../bigsoundbank/SOURCE.txt` 与 `../freesound/SOURCE.txt`；CC BY 件
（ddohler、YleArkisto）进设置→关于→音效致谢页署名。

## 文件与用途

- `key-01.ogg`～`key-12.ogg`：主按键轮询变体，取自 BigSoundBank Hermes 打字床
  （`typewriter-bed-01.wav`，源偏移 0.23s～84.05s 均匀取段，时长 0.18～0.46s）。
  App 内按键时 round-robin 轮换，防机关枪感。
- `key-transient.ogg`：BMacZero 单键瞬态层（0.117s），可与床变体叠加做 attack。
- `key-alt-01.ogg`：ddohler 单键（CC BY，0.090s）。注意：该源按压本身就是紧凑
  瞬态，0.998s 文件其余部分是静音，故本变体短是源文件性质，不是切坏了。
- `space-01.ogg`：BigSoundBank 空格单键（0.344s）。
- `bell-01.ogg`：ramsamba 边际铃，主铃（0.890s，全长保留）。
- `bell-02.ogg`：BigSoundBank 边际铃，备用铃（1.232s）。
- `bell-03.ogg`：MasterNavigator 纯铃，备用铃（1.013s）。源文件峰值已达 -1dB，
  本包对其多降 3dB 防 Vorbis 过冲削波。
- `carriage-reset-01.ogg`：knufds 铃+回车复位一体（2.679s），作拨杆换行声。
- `pack2-key-01.ogg`～`pack2-key-04.ogg`：第二台机按键变体，取自 lyricalgirl
  旧打字机床（带走廊回声，源偏移 0.10s～186.08s，时长 0.19～0.61s）。

## 待后续（本包 v1 未含，需人工听辨时间戳再切）

- YleArkisto 271525（2:46）里的手动回车与卷纸段：作回车声补充。
- evsecrets 334458（1:26，每行末带叮的床）：可作第三台机床或行末铃补充。
- 实录真机到位后，以上占位变体逐步替换（替换时保持文件名与数量不变，
  App 侧无需改动）。
