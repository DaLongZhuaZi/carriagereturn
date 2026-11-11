/**
 * 回车 · 引导纯数据/纯函数（第 1 批）。
 *
 * 与渲染器解耦：GuideOverlay 保持 props-only；本文件只提供 page id 清单、
 * 资源键命名、每页期望条数与合法性校验，可 Node 单测。
 */

/** 13 个页面 id（顺序固定；与 docs/evidence/文案资源约定.md 一致）。 */
export const GUIDE_PAGE_HOME: string = 'home';
export const GUIDE_PAGE_DOSSIER: string = 'dossier';
export const GUIDE_PAGE_DOSSIER_DETAIL: string = 'dossier_detail';
export const GUIDE_PAGE_DOCUMENT_VIEW: string = 'document_view';
export const GUIDE_PAGE_COLLECTION: string = 'collection';
export const GUIDE_PAGE_COLLECTION_DETAIL: string = 'collection_detail';
export const GUIDE_PAGE_CUSTOMIZE: string = 'customize';
export const GUIDE_PAGE_SETTINGS: string = 'settings';
export const GUIDE_PAGE_EXPORT: string = 'export';
export const GUIDE_PAGE_PINYIN_SETTINGS: string = 'pinyin_settings';
export const GUIDE_PAGE_TYPEWRITER: string = 'typewriter';
/** 第 6 批 F10：回收站页。 */
export const GUIDE_PAGE_TRASH: string = 'trash';
/** 第 2 批 F3：自定义下的两个新覆盖层页（字体管理／纸张自定义）。 */
export const GUIDE_PAGE_FONT_MANAGER: string = 'font_manager';
export const GUIDE_PAGE_PAPER_CUSTOM: string = 'paper_custom';

export function allPages(): string[] {
  return [
    GUIDE_PAGE_HOME, GUIDE_PAGE_DOSSIER, GUIDE_PAGE_DOSSIER_DETAIL,
    GUIDE_PAGE_DOCUMENT_VIEW, GUIDE_PAGE_COLLECTION, GUIDE_PAGE_COLLECTION_DETAIL,
    GUIDE_PAGE_CUSTOMIZE, GUIDE_PAGE_SETTINGS, GUIDE_PAGE_EXPORT,
    GUIDE_PAGE_PINYIN_SETTINGS, GUIDE_PAGE_TYPEWRITER,
    GUIDE_PAGE_FONT_MANAGER, GUIDE_PAGE_PAPER_CUSTOM, GUIDE_PAGE_TRASH,
  ];
}

export function isValidPage(page: string): boolean {
  return allPages().indexOf(page) >= 0;
}

/** 每页提示条数（2–4；本批统一 3）。 */
export function stepsExpected(page: string): number {
  return isValidPage(page) ? 3 : 0;
}

/** 页面提示的资源键：guide_<page>_<n>（string.json）。 */
export function pageStepKey(page: string, n: number): string {
  return 'guide_' + page + '_' + n.toString();
}

/** 页面常驻说明行的资源键：guide_<page>_hint。 */
export function pageHintKey(page: string): string {
  return 'guide_' + page + '_hint';
}

/** 页面标题资源键：guide_<page>_title。 */
export function pageTitleKey(page: string): string {
  return 'guide_' + page + '_title';
}

/** 启动引导 4 条的资源键。 */
export function onboardingKeys(): string[] {
  return [
    'guide_onboarding_1', 'guide_onboarding_2', 'guide_onboarding_3', 'guide_onboarding_4',
  ];
}

/** 所有页面提示资源键（含启动与按钮；供 guide-keys 测试）。 */
export function allResourceKeys(): string[] {
  const out: string[] = [];
  const pages: string[] = allPages();
  for (let i = 0; i < pages.length; i++) {
    const n: number = stepsExpected(pages[i]);
    for (let k = 1; k <= n; k++) {
      out.push(pageStepKey(pages[i], k));
    }
    out.push(pageTitleKey(pages[i]));
    // 打字机页不加常驻说明行（总纲）；主页常驻说明行是死键（第 10 批 D5 删除），均无 hint 键
    if (pages[i] !== GUIDE_PAGE_TYPEWRITER && pages[i] !== GUIDE_PAGE_HOME) {
      out.push(pageHintKey(pages[i]));
    }
  }
  const onboard: string[] = onboardingKeys();
  for (let i = 0; i < onboard.length; i++) {
    out.push(onboard[i]);
  }
  out.push('guide_onboarding_title');
  out.push('guide_btn_skip');
  out.push('guide_btn_ok');
  out.push('guide_btn_prev');
  out.push('guide_btn_next');
  return out;
}
