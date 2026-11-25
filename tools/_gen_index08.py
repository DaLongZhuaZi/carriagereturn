import os
import re
import sys

sys.stdout.reconfigure(encoding='utf-8')
SH = 'docs/shots'
files = [f for f in os.listdir(SH) if 'audit08' in f and f.endswith('.png')]


def num(f):
    m = re.match(r'(?:void_)?(\d+)([a-d]?)_', f)
    return (int(m.group(1)), m.group(2), f)


M = {
 'start': '起始主页', 'settings': '设置页',
 'settings_guide1': '设置引导第1步', 'settings_guide2': '设置引导第2步', 'settings_guide3': '设置引导第3步',
 'settings_guide_step1': '设置引导复拍第1步', 'settings_guide_step2': '设置引导复拍第2步',
 'settings_guide_step3': '设置引导复拍第3步', 'settings_guide_closed': '设置引导关闭',
 'sound_off': '音效关', 'sound_on': '音效开', 'vibrate_off': '按键震动关', 'vibrate_on': '按键震动开',
 'volume_low': '音量拉低', 'volume_restore': '音量回拖中间态', 'volume_70': '音量70%', 'volume_final': '音量最终(68%)',
 'a11y_on': '无障碍覆盖层开', 'a11y_after_restart': '重启后设置页(开关回关)', 'restart_home': '冷启动主页',
 'deletemode_ask': '删除方式=先问', 'deletemode_direct': '删除方式=直接删除',
 'deletemode_trash': '删除方式=进回收站', 'deletemode_ask_confirm': '删除方式=先问(复现)',
 'deletemode_trash_final': '删除方式回进回收站', 'deletemode_trash_again': '删除方式回进回收站(未生效)',
 'deletemode_direct_again': '删除方式=直接删除(复测)',
 'settings_back_home': '设置返回主页', 'dossier': '卷宗页', 'dossier_detail': '卷宗内页',
 'detail_three_test_papers': '内页三张测试纸',
 'paper_menu_ask': '纸卡菜单(ask)', 'paper_menu_trash': '纸卡菜单(trash)', 'paper_menu_direct': '纸卡菜单(direct)',
 'delete_confirm_ask': '删除确认(ask)', 'delete_confirm_trash': '删除确认(trash)',
 'delete_confirm_direct': '删除确认(direct)',
 'after_delete_ask': 'ask删除后', 'after_delete_trash': 'trash删除后', 'after_delete_direct': 'direct删除后',
 'detail_before_trash_delete': 'trash删除前内页', 'detail_for_trash_delete': 'trash删除前内页',
 'home_again': '主页(导航恢复)', 'after_backkey': '系统返回后(卷宗页)', 'home': '主页',
 'cn_system': '中文输入=系统输入法', 'cn_builtin': '中文输入=内置拼音',
 'cn_builtin_restored': '中文输入恢复内置拼音',
 'goal_800': '每日目标800(行文本仍500)', 'home_goal_refresh': '主页目标刷新800',
 'goal_row_800': '重进设置行800', 'goal_row_500': '恢复500',
 'goal_restore': '恢复目标(中间态400)',
 'machine_1930s': '默认机器1930s', 'machine_1950s': '默认机器1950s',
 'machine_1960s': '默认机器1960s', 'machine_1920s': '默认机器1920s',
 'theme': '主题页', 'theme_2020s': '主题页切2020s', 'home_2020s': '主页2020s',
 'settings_machine_2020s_fallback': '设置机名回落1920s',
 'settings_machine_after_2020s_tap': '点按后机器变1920s',
 'paper_manuscript': '默认纸张稿纸', 'paper_postcard': '默认纸张明信片',
 'paper_memo': '默认纸张便签', 'paper_letter': '默认纸张信纸',
 'trash_from_settings': '设置进回收站',
 'after_purge_1972': '彻底删除测试纸后', 'after_purge_7511': '彻底删除第二张后',
 'after_purge_2009': '彻底删除测试纸后', 'after_purge_7633': '彻底删除第二张后',
 'settings_before_replay': '重播页面引导前', 'settings_after_replay_novisible': '重播后画面无提示',
 'settings_guide_auto_after_replay': '重进设置自动引导', 'settings_guide_closed_again': '自动引导关闭',
 'onboarding_replay_page1': '重播启动引导第1页', 'onboarding_replay_page2': '启动引导第2页',
 'after_onboarding_skip': '跳过启动引导后',
 'settings_scrolled': '设置滚动到关于组', 'settings_bottom': '设置滚到底',
 'settings_bottom_again': '设置再次滚到底', 'settings_top_again': '设置回顶部',
 'pinyin_settings_entry_guide': '拼音设置进入(自动引导)',
 'pinyin_guide2': '拼音引导第2步', 'pinyin_guide3': '拼音引导第3步',
 'pinyin_guide_closed': '拼音引导关闭', 'pinyin_guide_manual': '拼音引导手动重拉',
 'pinyin_clean': '拼音设置页(无引导)',
 'cand_count_15': '候选数量15', 'cand_size_20': '候选字号20', 'cand_size_12': '候选字号12',
 'cand_settings_restored': '候选设置恢复9/15',
 'fuzzy_on': '模糊拼音开', 'fuzzy_off': '模糊拼音关',
 'typewriter': '打字机页', 'home_before_typing': '进入打字机前主页',
 'home_after_typing': '打字后主页', 'home_after_clean': '清空纸面后主页',
 'chinese_mode': '切中文模式', 'cand_ni': '候选ni(5个)',
 'cand_ni_count15_size20_fuzzy': '候选ni(数量15字号20模糊开)',
 'cand_ni_size12': '候选ni(字号12)',
 'cand_nin_fuzzy': '候选nin(模糊开，含宁)', 'cand_nin_fuzzy_off': '候选nin(模糊关)',
 'cand_si_fuzzy_off': '候选si(模糊关，无是)', 'paper_clean': '纸面已清空',
 'pinyin_back_to_settings': '拼音设置返回设置页', 'pinyin_reenter': '重进拼音设置',
 'addword_dialog': '添加词组弹窗', 'addword_cancel': '取消添加',
 'addword_typed': '输入审计词(自动拼音)', 'addword_pinyin_edited': '手改拼音shenjici2',
 'addword_added': '添加后2条',
 'manage_words': '我的词库弹窗', 'manage_after_delete': '删词后0条',
 'manage_closed': '完成关闭词库弹窗', 'clear_learn': '清除学习记录',
 'final_home': '收工主页',
}


def desc(suf):
    suf = suf.replace('.png', '')
    if suf == 'volume_restore' and False:
        pass
    m = re.match(r'purge_confirm_(\w+)', suf)
    if m:
        return '彻底删除确认(%s)' % m.group(1)
    return M.get(suf, suf.replace('_', ' '))


rows_t = []
rows_p = []
for f in sorted(files, key=num):
    if f.startswith('void_'):
        continue
    m = re.match(r'(\d+)([a-d]?)_audit08_(tablet|phone)_(.+)\.png$', f)
    if not m:
        continue
    n = int(m.group(1))
    b = m.group(2)
    dev = m.group(3)
    suf = m.group(4)
    d = desc(suf)
    if f.startswith('3086d_'):
        d = '音量恢复70%（有效）'
    row = '| %d%s | `%s` | %s |' % (n, b, f, d)
    (rows_t if dev == 'tablet' else rows_p).append(row)

out = []
out.append('### 9.1 平板（1600×2560）\n')
out.append('| 截图 | 文件 | 内容 |')
out.append('|---|---|---|')
out.extend(rows_t)
out.append('\n### 9.2 手机（1224×2776）\n')
out.append('| 截图 | 文件 | 内容 |')
out.append('|---|---|---|')
out.extend(rows_p)
out.append('\n### 9.3 作废图（`void_` 前缀）\n')
out.append('| 文件 | 作废原因 |')
out.append('|---|---|')
V = {
 '3076': '第二次点按落在引导气泡外，引导被关闭（非第3步）',
 '3086': '音量回拖到71%，非目标70%',
 '3086b': '音量回拖未到70%', '3086c': '音量回拖未到70%',
 '3101': '导航坐标错位，实际仍在卷宗内页', '3102': '导航错位后进入文档视图',
 '3103': '按错层后的中间页', '3141': '重播启动引导行在屏外，点击未命中',
 '3166': 'S键坐标错误，仅输入i', '3166b': 'S键坐标错误，未产生新拼音',
 '3166c': 'S键坐标错误，缓冲为ii', '3166d': 'S键未命中，缓冲为ii', '3167': 'S键命中错误，缓冲为isi',
 '3193': '手机音量回拖到69%', '3193b': '手机音量回拖到68%',
 '3193c': '手机音量最终68%（未达70%）',
 '3196': '冷启动后首次点击设置未命中，仍在主页',
 '3235': '滚动后重播引导行点击未命中', '3236': '未重置，仍为旧页',
 '3239': '按 dump 坐标点击落屏外', '3240': '未重置后的自动引导(无)',
 '3241': '未重置后的关闭(无)', '3242': '点击未命中，页面回顶',
 '3245': '重置成功后的重复点击', '3264': 'EN 键首次未命中，英文 ni 落纸',
 '3270': 'S键坐标错误，得到di', '3273': '目标恢复中间态400（最终500见3273b）',
}
for f in sorted([x for x in files if x.startswith('void_')], key=num):
    m = re.match(r'void_(\d+)([a-d]?)_', f)
    key = m.group(1) + m.group(2)
    out.append('| `%s` | %s |' % (f, V.get(key, '点击丢失/中间态')))
print('\n'.join(out))
