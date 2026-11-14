---
name: hdc-screenrecord
description: "HarmonyOS 真机手动录屏并通过 mediatool + hdc 拉回 MP4。适用于动画/过渡验收；不要依赖设备上不存在的 screenrecord CLI。"
---

# HDC 手动录屏与视频拉回

## 适用场景

- 需要录屏验证动画、页面过渡、拨杆/字杆中间态；
- `uitest screenCap` / `snapshot_display` 只有约 2.1fps，不能替代录屏；
- HarmonyOS 设备没有 `screenrecord` 命令，系统录屏 App 也不能用 `aa start` 拉起（权限 10107102）。

## 前置

```bash
# 设备保持常亮，避免录屏中途锁屏
hdc -t [TARGET] shell "power-shell timeout -o 86400000"

# 确认 App 在前台
hdc -t [TARGET] shell "aa start -a EntryAbility -b [BUNDLE]"
```

`[TARGET]` 例如 `2UCUT24724009680`，`[BUNDLE]` 例如 `com.dlzz.carriagereturn`。

## 1. 从控制中心启动录屏

屏幕分辨率以 1224×2776 为例：

```bash
# 从顶部下拉控制中心（不要从右边缘起手，避免系统手势）
hdc -t [TARGET] shell "uitest uiInput swipe 1100 20 1100 1400 300"

# 点“录屏”图标（实测文字 bounds [639,2701][855,2755]，点图标中心）
hdc -t [TARGET] shell "uitest uiInput click 747 2520"
```

启动成功的标志：状态栏出现红色录制胶囊和计时。

> 若坐标不匹配，先 `uitest dumpLayout -p /data/local/tmp/cc.json`，在 dump 中查 `录屏` 的 bounds，再点图标中心（不是文字行）。

## 2. 录制与停止

正常执行要录的操作。停止：

```bash
hdc -t [TARGET] shell "uitest uiInput swipe 1100 20 1100 1400 300"
hdc -t [TARGET] shell "uitest uiInput click 747 2520"
```

停止成功的标志：红色胶囊/计时消失。

## 3. 找到录屏文件

系统录屏保存到媒体库 Photo 分桶，路径形如：

```text
/storage/media/100/local/files/Photo/[PHOTO_BUCKET]/VID_[EPOCH]_[SEQ].mp4
```

`[PHOTO_BUCKET]` 不固定（实测本次落在 `11`）。用 `mediatool` 枚举，**不要直接 `ls /storage/media`**（Permission denied）：

```bash
hdc -t [TARGET] shell 'for i in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16; do echo DIR:$i; mediatool ls -l /storage/media/100/local/files/Photo/$i 2>/dev/null | grep mp4; done'
```

选最新时间戳的文件。实测：

```text
DIR:11
-rw-rw---- 1 user_data_rw user_data_rw 15994348 2026-11-14 22:11 VID_1794665545_043.mp4
```

## 4. 复制到 /data/local/tmp

```bash
hdc -t [TARGET] shell "mediatool recv /storage/media/100/local/files/Photo/[PHOTO_BUCKET]/[VIDEO_NAME] /data/local/tmp/screenrec.mp4"
hdc -t [TARGET] shell "ls -l /data/local/tmp/screenrec.mp4"
```

`mediatool recv` 会打印 `Table Name: Photos` 和目标路径；成功后再拉回本地。

## 5. 拉回 PC

```bash
hdc -t [TARGET] file recv /data/local/tmp/screenrec.mp4 [LOCAL_PATH]
```

PowerShell 验证：

```powershell
Get-Item [LOCAL_PATH] | Select-Object Length
ffprobe -v error -show_entries format=duration,size -show_entries stream=codec_name,width,height,r_frame_rate -of default=noprint_wrappers=1 [LOCAL_PATH]
```

实测样例：`h264 + aac`、`848×1920`、`15,994,348` bytes。

## 6. 清理

```bash
hdc -t [TARGET] shell "rm -f /data/local/tmp/screenrec.mp4"
```

媒体库原片保留；如需删除用 `mediatool delete <media-uri>`，不要直接删文件。

## 常见坑

1. `hdc shell screenrecord` 不存在：`/bin/sh: screenrecord: inaccessible or not found`。
2. 系统录屏包 `com.huawei.hmos.screenrecorder` 已安装，但 `aa start ... SelectWindowAbility` 返回 `10107102`，只能手动控制中心启动。
3. `snapshot_display` 实测 5 帧 2416ms（约 2.1fps），只能录状态序列，不能录 90ms/350ms 动画。
4. `mediatool ls -l` 不接受 `/`、`/DCIM`、`/Video`、媒体库根目录；只对 `Photo/<bucket>` 这类系统媒体目录有效。
5. 控制中心滑动不要从屏幕右边缘起手，否则会触发系统手势把 App 切回桌面。
6. 录屏启动后坐标会变化：控制中心关闭、App 回前台；再次下拉后“录屏”按钮坐标通常不变，但换分辨率必须重新 dump。
7. 视频时间戳来自设备时钟（可能不是 PC 时间）；文件名 `VID_<epoch>_<seq>.mp4`，不要按 PC 时间猜。

## 验收检查

- [ ] 状态栏出现红色录制胶囊与计时；
- [ ] 停止后胶囊消失；
- [ ] `mediatool` 能列出新增 `VID_*.mp4`；
- [ ] `mediatool recv` 后 `/data/local/tmp/screenrec.mp4` 大小非 0；
- [ ] `hdc file recv` 到 PC 后 `ffprobe` 能读出 h264/aac、分辨率、时长；
- [ ] 录屏文件包含目标操作区间。
