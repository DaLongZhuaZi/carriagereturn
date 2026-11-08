# 最终验证总跑（第 7 批，2026-11-09T06:16:44+08:00）

| 项 | 命令 | 退出码 | 结果 |
|---|---|---|---|
| arkts-self-test | `node tools/check-arkts.mjs --self-test` | 0 | **PASS** |
| arkts-structural | `node tools/check-arkts.mjs --quiet` | 0 | **PASS** |
| contracts | `python tools/check-contracts.py` | 0 | **PASS** |
| unit-tests | `node --experimental-strip-types --test D:\HarmonyAPP\carriagereturn\tools\tests\app-icon.test.mjs D:\HarmonyAPP\carriagereturn\tools\tests\audio-packs.test.mjs D:\HarmonyAPP\carriagereturn\tools\tests\batch5-static.test.mjs D:\HarmonyAPP\carriagereturn\tools\tests\batch6-static.test.mjs D:\HarmonyAPP\carriagereturn\tools\tests\candidate-core.test.mjs D:\HarmonyAPP\carriagereturn\tools\tests\customize-core.test.mjs D:\HarmonyAPP\carriagereturn\tools\tests\customize-static.test.mjs D:\HarmonyAPP\carriagereturn\tools\tests\docstore-state.test.mjs D:\HarmonyAPP\carriagereturn\tools\tests\docstore-trash.test.mjs D:\HarmonyAPP\carriagereturn\tools\tests\export-core.test.mjs D:\HarmonyAPP\carriagereturn\tools\tests\export-pixels.test.mjs D:\HarmonyAPP\carriagereturn\tools\tests\export-static.test.mjs D:\HarmonyAPP\carriagereturn\tools\tests\guide-core.test.mjs D:\HarmonyAPP\carriagereturn\tools\tests\guide-keys.test.mjs D:\HarmonyAPP\carriagereturn\tools\tests\knob-static.test.mjs D:\HarmonyAPP\carriagereturn\tools\tests\lever-angle.test.mjs D:\HarmonyAPP\carriagereturn\tools\tests\lever-gate.test.mjs D:\HarmonyAPP\carriagereturn\tools\tests\lever-state.test.mjs D:\HarmonyAPP\carriagereturn\tools\tests\paper-change-static.test.mjs D:\HarmonyAPP\carriagereturn\tools\tests\settings-core.test.mjs D:\HarmonyAPP\carriagereturn\tools\tests\stats-core.test.mjs D:\HarmonyAPP\carriagereturn\tools\tests\stats-goal.test.mjs D:\HarmonyAPP\carriagereturn\tools\tests\stats-static.test.mjs` | 0 | **PASS** |
| gate-self-test | `python tools/gate-compare.py --self-test` | 0 | **PASS** |
| gate-500-vs-332 | `python tools/gate-compare.py docs/shots/332_metal3.jpeg docs/shots/500_gate.jpeg --scale 400x640` | 0 | **PASS** |
| gate-540-vs-332 | `python tools/gate-compare.py docs/shots/332_metal3.jpeg docs/shots/540_1920s_gate.jpeg --scale 400x640` | 1 | **EXPECTED-FAIL** |
| audio-verify | `python tools/audio-verify.py --json docs/evidence/audio-verify.json` | 0 | **PASS** |
| icon-audit | `python tools/audit-icons.py --json docs/evidence/icon-audit.json` | 0 | **PASS** |
| probes-dry-run | `python tools/probes/run_all.py --dry-run` | 0 | **PASS** |
| switch-audit | `python tools/audit-switches.py --json docs/evidence/switches.json` | 0 | **PASS** |
| audio-verify-all-packs | `python tools/audio-verify.py --json docs/evidence/audio-verify.json` | 0 | **PASS** |

## arkts-self-test — PASS
```
[self-test] string-brace: ok
[self-test] comment-brace: ok
[self-test] import-resolution: ok
[self-test] PASS（0 项失败）

[stderr]
(node:14660) [UNDICI-EHPA] Warning: EnvHttpProxyAgent is experimental, expect them to change at any time.
(Use `node --trace-warnings ...` to show where the warning was created)
```

## arkts-structural — PASS
```
[stderr]
(node:14912) [UNDICI-EHPA] Warning: EnvHttpProxyAgent is experimental, expect them to change at any time.
(Use `node --trace-warnings ...` to show where the warning was created)
```

## contracts — PASS
```
  PASS entry/src/main/ets/model/DocStoreStateCore.ets: 6 ��
  PASS entry/src/main/ets/model/LeverAngleCore.ets: 6 ��
  PASS entry/src/main/ets/services/AppPreferences.ets: 10 ��
  PASS entry/src/main/ets/services/DocStore.ets: 6 ��
  PASS Index.ets: ������ ShareService
  PASS Index.ets: ����ע���� FontService
  PASS DocStore.remove(): �ѷ�תΪ trash���� 6 ����
����: PASS��16 �� / 0 �ܣ�
```

## unit-tests — PASS
```
# cancelled 0
# skipped 0
# todo 0
# duration_ms 1286.2716

[stderr]
(node:15192) [UNDICI-EHPA] Warning: EnvHttpProxyAgent is experimental, expect them to change at any time.
(Use `node --trace-warnings ...` to show where the warning was created)
```

## gate-self-test — PASS
```
[self-test] left-region-detected: ok 
[self-test] region-isolation: ok 
[self-test] paper-excluded: ok 
[self-test] status-bar-excluded: ok 
[self-test] keyboard-detected: ok 
[self-test] boxes-non-empty: ok 
[self-test] frame-tiles-full-width: ok 
[self-test] PASS (0 ��ʧ��)
```

## gate-500-vs-332 — PASS
```
��ǰ: D:\HarmonyAPP\carriagereturn\docs\shots\500_gate.jpeg
�ߴ�: 400x640  ��ֵ: 30  �о�: ��������ֵ����ռ��ȫ��Ϊ 0.00% ��ͨ��
����                 ������      ��������      ռ��     ���ͨ����  ���
keyboard         92000         0   0.00%         0  PASS
frame_left       18612         0   0.00%         0  PASS
frame_mid        19176         0   0.00%         0  PASS
frame_right      18612         0   0.00%         0  PASS
����: PASS
```

## gate-540-vs-332 — EXPECTED-FAIL
```
��ǰ: D:\HarmonyAPP\carriagereturn\docs\shots\540_1920s_gate.jpeg
�ߴ�: 400x640  ��ֵ: 30  �о�: ��������ֵ����ռ��ȫ��Ϊ 0.00% ��ͨ��
����                 ������      ��������      ռ��     ���ͨ����  ���
keyboard         92000         0   0.00%        13  PASS
frame_left       18612         0   0.00%        28  PASS
frame_mid        19176         0   0.00%        15  PASS
frame_right      18612       370   1.99%       119  FAIL
����: FAIL
```

## audio-verify — PASS
```
key-alt-01            pack-1960    0.072   0.0890  0.839
key-transient         pack-1960    0.094   0.0394  0.613
space-01              pack-1960    0.357   0.0462  0.578
�ļ��� 80��SHA-256 Ψһ 80
���ڱ���������� 0.0184��key-04.ogg vs key-07.ogg���������ο������� FAIL
���ͬ��ɫ��С���� 0.0469��pack/bell vs pack-1950/bell����ֵ 0.03
����: PASS
JSON: docs/evidence/audio-verify.json
```

## icon-audit — PASS
```
== ͼ����ƣ�O1��==
SymbolGlyph ֱ�õ�: 0�������� AppIcon.ets��
AppIcon kind��ʹ�� 9 �� / ע�� 13 ��
emoji/�����ַ����� 1 �������˹�ȷ�������ݻ���ͼ�ꣻ���� �������� �����ݣ�
  - entry/src/main/ets/pages/Index.ets:125: '�� �� �� �� �� �� �� �� �� ��'.split(' '),
����: PASS
JSON: docs/evidence/icon-audit.json
```

## probes-dry-run — PASS
```
probe_file_picker                 UNVERIFIED_NO_DEVICE    ���豸����·ѡ���뱣��ɼ����޷�ȡ֤
probe_fold_angle                  UNVERIFIED_NO_DEVICE    ���۵��豸��ģ�������ܵ����Ự�� IDE/������ڣ��� Q3 ȱʡִ��
probe_test_clock                  UNVERIFIED_NO_DEVICE    ���豸�� SDK��֡�����޷�ʵ�飻�� fallback �������ߴ��������⣫AGENTS �ھ�
probe_verification_capabilities   UNVERIFIED_NO_DEVICE    �����С��ܡ����������Բֿ���������¼���������豸��δ���֣����� PASS

JSON: D:\HarmonyAPP\carriagereturn\docs\evidence\probe-results-2026-11-09.json
Markdown: D:\HarmonyAPP\carriagereturn\docs\evidence\̽�����.md
ȫ�����꣨�� FAIL��UNVERIFIED ���������� fallback�����֤�ݴ�����
```

## switch-audit — PASS
```
keys=30 switches=3 problems=0 head=94156c1
д�� docs/evidence/�����嵥-��7��.md
�˶� PASS
```

## audio-verify-all-packs — PASS
```
key-alt-01            pack-1960    0.072   0.0890  0.839
key-transient         pack-1960    0.094   0.0394  0.613
space-01              pack-1960    0.357   0.0462  0.578
�ļ��� 80��SHA-256 Ψһ 80
���ڱ���������� 0.0184��key-04.ogg vs key-07.ogg���������ο������� FAIL
���ͬ��ɫ��С���� 0.0469��pack/bell vs pack-1950/bell����ֵ 0.03
����: PASS
JSON: docs/evidence/audio-verify.json
```
