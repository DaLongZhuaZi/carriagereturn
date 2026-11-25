# -*- coding: utf-8 -*-
import os, re, io
shots = 'docs/shots'
files = sorted([f for f in os.listdir(shots) if re.match(r'^\d+_audit09_', f)], key=lambda s: int(re.match(r'^(\d+)', s).group(1)))
D = {
'home_start':'起始主页','dossier_page':'卷宗页','unfiled_page':'未归档内页','unfiled_guide_closed':'关闭卷宗内页引导',
'docview_ani':'文档视图「啊!尼」','docview_ani_clean':'文档视图（引导关闭）','export_enter_guide':'导出页自动引导第1步',
'export_guide_step2':'导出页引导第2步','export_guide_step3':'导出页引导第3步','export_clean':'导出页（引导关闭，整篇）',
'export_range_paper':'范围切「当前纸」','export_image_selected':'选中「图片」','export_share_png_panel':'图片分享面板',
'export_share_png_result':'分享后结果态','export_doc_pdf_selected':'整篇＋PDF 选中','export_doc_pdf_share_panel':'整篇 PDF 分享面板',
'export_paper_pdf_preview':'当前纸＋PDF 预览','export_paper_pdf_share_panel':'当前纸 PDF 分享面板',
'export_text_selected_paper':'纯文本（当前纸，未选中）','export_paper_txt_share_panel':'当前纸 TXT 面板','export_scrolled':'导出页滚动',
'export_text_selected':'选中纯文本','export_text_share_panel':'纯文本分享面板','export_doc_text_selected':'整篇＋纯文本 选中',
'export_doc_text_share_panel':'整篇 TXT 面板','export_doc_pdf_before_busyback':'busy 返回前','export_busy_back_ignored':'busy 返回（进度浮层）',
'export_busy_back_share_panel':'busy 后分享面板','export_busy_back_ignored2':'busy 返回（正确坐标）','export_busy_back_panel2':'busy 后分享面板2',
'export_help_guide':'页眉“?”引导','export_help_closed':'“?”引导关闭','export_back_to_docview':'返回文档视图',
'home_export_after_doc':'主页导出（沿用文档目标）','dossier_detail_test2':'测试卷宗二号内页','export_dossier_entry':'整卷宗导出入口',
'export_dossier_pdf_panel':'整卷宗 PDF 面板','export_dossier_scrolled':'卷宗导出页滚动','export_dossier_text_panel':'卷宗 TXT 面板（误触 PDF）',
'export_dossier_text_selected':'卷宗纯文本选中（未命中）','export_dossier_text_selected2':'卷宗纯文本选中','export_dossier_text_panel2':'卷宗 TXT 面板',
'back_dossier_detail':'返回卷宗内页','home_export_after_dossier':'主页导出（沿用整卷宗目标）','unfiled_again':'未归档内页',
'docview_ni':'文档视图「ni」','export_ni_entry':'「ni」导出页','export_ni_paper':'「ni」当前纸','export_ni_all_on_done':'空文档误判（O4）',
'export_ni_share2':'空文档下点分享无效','back_unfiled':'返回未归档','open_ni':'点「打开」载入 ni','docview_ni_after_open':'载入后文档视图',
'open_ni_footer':'「打开」日志取证','export_ni_entry2':'重进导出页','export_ni_paper2':'当前纸','export_ni_image_selected':'选中图片',
'docview_ni3':'文档视图 ni','export_ni_image_selected2':'选中图片','export_ni_image_share':'图片分享','export_ni_all_on_done2':'全开基线完成',
'export_custom_section':'自定义区','sw_title_off':'标题关（实际为日期关，见报告）','sw_title_on_again':'恢复操作（状态混用）','sw_title_off_correct':'标题关',
'export_filename_illegal':'文件名输入','export_save_picker_illegal':'保存选择器（键盘遮挡）','export_filename_after_kb':'收起键盘后文件名',
'export_save_picker_illegal2':'保存选择器（键盘又弹）','export_keyboard_closed':'键盘关闭','export_pdf_selected_for_save':'PDF 选中待保存',
'export_save_picker':'保存选择器（键盘弹）','export_kb_hide_caret':'键盘收起尝试','export_after_kb_hidden':'键盘仍在','export_pdf_after_kb':'PDF 选中（键盘仍在）',
'export_save_picker_final':'保存选择器（键盘仍在）','after_keyevent2':'系统返回收起键盘','export_save_picker_illegal3':'保存选择器（非法名已清理）',
'export_save_result':'保存成功结果态','export_fresh_blank_name':'重进导出页（留空名）','export_save_picker_blankname':'选择器自动名','export_save_cancelled':'取消保存回 idle',
'theme_page':'主题页','theme_2020s':'主题页（首次点 2020s 未命中）','export_target_2020s':'导出页（机器仍 1920s）','export_pdf_2020s_panel':'PDF 面板（机器仍 1920s）',
'theme_2020s_selected':'主题页 2020s 选中','export_2020s_page':'2020s 导出页','export_2020s_share_panel':'2020s PDF 分享面板','theme_back_1920s':'主题页恢复 1920s',
'home_after_export_tests':'主页（平板收工）',
'phone_dossier_page':'卷宗页','phone_unfiled_page':'未归档（未进入）','phone_unfiled_detail':'未归档内页（含引导）','phone_open_a':'点「打开」a',
'phone_docview_a':'文档视图 a（搜索框聚焦）','phone_docview_a2':'文档视图 a','phone_export_entry_guide1':'导出页（未进入）',
'phone_export_entry2':'导出页自动引导第1步','phone_export_guide_step2':'导出页引导第2步','phone_export_guide_step3':'导出页引导第3步',
'phone_export_clean':'导出页（引导关闭，整篇）','phone_export_range_paper':'范围切当前纸','phone_export_image_selected':'选图片（未命中）',
'phone_export_image_share_panel':'PDF 生成中','phone_export_paper_pdf_panel':'当前纸 PDF 分享面板','phone_export_panel_closed':'面板关闭',
'phone_export_image_selected2':'格式滚动后','phone_export_image_share2':'仍 PDF 构建','phone_export_pdf2_panel':'当前纸 PDF 分享面板2',
'phone_panel_closed2':'面板关闭2','phone_export_formats_scrolled':'格式区滚动','phone_export_image_selected3':'图片行可见',
'phone_export_image_selected4':'选中图片','phone_export_image_share4':'图片分享面板','phone_panel_closed3':'面板关闭3',
'phone_export_doc_pdf_selected':'整篇＋PDF 选中','phone_export_doc_pdf_panel':'整篇 PDF 分享面板','phone_after_back_panel':'返回关闭面板',
'phone_export_text_panel':'纯文本分享面板','phone_detail_back':'返回内页','phone_open_ni':'点「打开」ni','phone_docview_ni':'文档视图 ni',
'phone_export_ni':'「ni」导出页','phone_export_ni_paper':'「ni」当前纸','phone_export_ni_all_on_done':'全开基线完成',
'phone_recover_app':'冷启动恢复','phone_export_reentry':'重进导出页','phone_export_help_guide':'页眉“?”引导','phone_export_help_closed':'“?”关闭',
'phone_export_filename_typed':'文件名输入','phone_export_save_picker_illegal':'保存选择器（非法名清理）','phone_save_cancelled':'取消保存',
'phone_export_fresh_blank_name':'重进导出页（留空名）','phone_save_picker_blankname':'选择器自动名','phone_save_result':'保存成功结果态',
'phone_detail_for_busy':'内页（busy 前）','phone_export_a_for_busy':'「a」导出页','phone_export_busy_back':'busy 返回（进度浮层）',
'phone_export_busy_panel':'busy 后分享面板','phone_export_back_docview':'返回文档视图','phone_dossier_page2':'卷宗页2',
'phone_dossier_detail_header':'未归档内页','phone_dossier_menu':'未归档菜单','phone_dossier_page3':'卷宗页3','phone_dossier_test2_detail':'卷宗页（未进入内页）',
'phone_dossier_test2_menu':'卷宗页菜单（未开）','phone_test2_detail2':'文档视图（导航跑飞）','phone_dossier_page4':'卷宗页4',
'phone_test2_detail3':'文档视图（导航跑飞2）','phone_test2_menu':'文档视图（菜单未开）','phone_coldstart_home':'冷启动主页',
'phone_dossier_page5':'卷宗页5','phone_test2_detail4':'测试卷宗二号内页（无导出）','phone_test2_menu2':'测试卷宗二号⋯菜单（无导出）',
'phone_test2_menu3':'测试卷宗二号（⋯未开）','phone_test2_menu4':'测试卷宗二号⋯菜单（无导出）','phone_docview_nini':'文档视图「呢呢测试」',
'phone_export_from_doc':'文档导出入口','phone_home_before_export':'主页','phone_home_export_after_doc':'主页导出（目标残留）',
'phone_home2':'主页2','phone_home_export_after_doc2':'主页导出（doc 目标，R7）','phone_home3':'主页3','phone_theme_page':'主题页',
'phone_theme_2020s':'主题页 2020s 选中','phone_export_2020s':'2020s 导出页','phone_export_2020s_panel':'2020s PDF 分享面板','phone_theme_back_1920s':'恢复 1920s',
'phone_home_end':'收工主页',
'docview_ni2':'文档视图 ni（过程）','export_ni_entry3':'重进导出页（载入模型后）',
'home_end':'收工主页',
}
lines = ['| 编号 | 文件 | 内容 |', '|---|---|---|']
for f in files:
    num = int(re.match(r'^(\d+)', f).group(1))
    m = re.match(r'^\d+_audit09_(tablet|phone)_(.+)\.png$', f)
    dev, key = (m.group(1), m.group(2)) if m else ('?', f)
    devc = '平板' if dev == 'tablet' else ('手机' if dev == 'phone' else '')
    desc = D.get((dev + '_' + key) if dev else key) or D.get(key) or key.replace('_', ' ')
    lines.append('| %d | `%s` | %s %s |' % (num, f, devc, desc))
with io.open('docs/evidence/audit/item09-export.md', 'a', encoding='utf-8') as fp:
    fp.write('\n' + '\n'.join(lines) + '\n')
print('appended', len(lines) - 2, 'rows')
