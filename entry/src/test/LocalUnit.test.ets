import { describe, beforeEach, it, expect } from '@ohos/hypium';
import { DocModel, emptyDoc } from '../main/ets/model/DocModelCore';
import { DocData, MachineKind, RibbonKind } from '../main/ets/model/DocModel';

/**
 * 回车 · 文档模型内核单测（本地单测，无需真机）
 *
 * 只测纯逻辑：落字、退格、跨行合并、换行、行末预告铃、纯文本视图、标题。
 * 存储 I/O（DocStore）依赖沙箱，放 ohosTest 真机测；本文件不 import 任何 @kit。
 */
export default function localUnitTest() {
  describe('DocModelCore', () => {
    let doc: DocModel = new DocModel();

    beforeEach(() => {
      doc = new DocModel();
    });

    it('empty_doc_has_one_blank_line', 0, () => {
      const d: DocModel = new DocModel();
      expect(d.getLines().length).assertEqual(1);
      expect(d.getLines()[0].text).assertEqual('');
      expect(d.getCursor().line).assertEqual(0);
      expect(d.getCursor().offset).assertEqual(0);
      expect(d.isEmpty()).assertTrue();
    });

    it('insert_char_advances_cursor', 0, () => {
      const out = doc.insertText('a', 40);
      expect(out.changed).assertTrue();
      expect(out.lineBreak).assertFalse();
      expect(doc.getLines()[0].text).assertEqual('a');
      expect(doc.getCursor().offset).assertEqual(1);
    });

    it('insert_multiple_chars_keeps_order', 0, () => {
      doc.insertText('a', 40);
      doc.insertText('b', 40);
      doc.insertText('c', 40);
      expect(doc.getLines()[0].text).assertEqual('abc');
      expect(doc.getCursor().offset).assertEqual(3);
      expect(doc.charCount()).assertEqual(3);
    });

    it('insert_at_middle_splices_text', 0, () => {
      doc.insertText('a', 40);
      doc.insertText('c', 40);
      doc.setCursor({ line: 0, offset: 1 });
      doc.insertText('b', 40);
      expect(doc.getLines()[0].text).assertEqual('abc');
      expect(doc.getCursor().offset).assertEqual(2);
    });

    it('empty_string_is_noop', 0, () => {
      const out = doc.insertText('', 40);
      expect(out.changed).assertFalse();
      expect(doc.getLines()[0].text).assertEqual('');
    });

    it('backspace_deletes_left_char', 0, () => {
      doc.insertText('a', 40);
      doc.insertText('b', 40);
      const out = doc.backspace();
      expect(out.changed).assertTrue();
      expect(doc.getLines()[0].text).assertEqual('a');
      expect(doc.getCursor().offset).assertEqual(1);
    });

    it('backspace_at_doc_start_is_noop', 0, () => {
      const out = doc.backspace();
      expect(out.changed).assertFalse();
      expect(doc.getLines().length).assertEqual(1);
      expect(doc.getCursor().offset).assertEqual(0);
    });

    it('backspace_at_line_start_merges_previous_line', 0, () => {
      doc.insertText('a', 40);
      doc.newline();
      doc.insertText('b', 40);
      expect(doc.getLines().length).assertEqual(2);
      expect(doc.getCursor().line).assertEqual(1);
      expect(doc.getCursor().offset).assertEqual(1);

      // 光标移到第二行行首，退格应把 "b" 并入第一行
      doc.setCursor({ line: 1, offset: 0 });
      const out = doc.backspace();
      expect(out.changed).assertTrue();
      expect(doc.getLines().length).assertEqual(1);
      expect(doc.getLines()[0].text).assertEqual('ab');
      expect(doc.getCursor().line).assertEqual(0);
      expect(doc.getCursor().offset).assertEqual(1);
    });

    it('newline_splits_at_cursor', 0, () => {
      doc.insertText('a', 40);
      doc.insertText('b', 40);
      doc.setCursor({ line: 0, offset: 1 });
      const out = doc.newline();
      expect(out.changed).assertTrue();
      expect(out.lineBreak).assertTrue();
      expect(doc.getLines().length).assertEqual(2);
      expect(doc.getLines()[0].text).assertEqual('a');
      expect(doc.getLines()[1].text).assertEqual('b');
      expect(doc.getCursor().line).assertEqual(1);
      expect(doc.getCursor().offset).assertEqual(0);
    });

    it('newline_carries_current_ribbon', 0, () => {
      doc.setRibbon(RibbonKind.RED);
      doc.insertText('a', 40);
      doc.newline();
      expect(doc.getLines()[1].ribbon).assertEqual(RibbonKind.RED);
    });

    it('margin_bell_rings_once_near_line_end', 0, () => {
      // charsPerLine = 20：第 12 个字落完后 remaining = 8，应响铃且只响一次
      let rang: number = 0;
      for (let i = 0; i < 15; i++) {
        const out = doc.insertText('x', 20);
        if (out.marginBell) {
          rang += 1;
        }
      }
      expect(rang).assertEqual(1);
    });

    it('margin_bell_does_not_ring_when_far_from_end', 0, () => {
      const out = doc.insertText('x', 80);
      expect(out.marginBell).assertFalse();
    });

    it('plain_text_joins_lines_with_newline', 0, () => {
      doc.insertText('a', 40);
      doc.newline();
      doc.insertText('b', 40);
      expect(doc.toPlainText()).assertEqual('a\nb\n');
    });

    it('chinese_chars_count_one_each', 0, () => {
      doc.insertText('中', 40);
      doc.insertText('文', 40);
      expect(doc.getLines()[0].text).assertEqual('中文');
      expect(doc.getCursor().offset).assertEqual(2);
      expect(doc.charCount()).assertEqual(2);
    });

    it('title_uses_first_non_empty_line', 0, () => {
      doc.newline();
      doc.insertText('题', 40);
      expect(doc.title('未命名')).assertEqual('题');
    });

    it('title_falls_back_when_empty', 0, () => {
      expect(doc.title('未命名')).assertEqual('未命名');
    });

    it('title_truncates_long_line', 0, () => {
      let s: string = '';
      for (let i = 0; i < 30; i++) {
        s += 'a';
      }
      doc.insertText(s, 80);
      expect(doc.title('x').length).assertEqual(24);
    });

    it('restore_from_doc_data_clamps_cursor', 0, () => {
      const data: DocData = {
        lines: [{ text: 'abc', ribbon: RibbonKind.BLACK }],
        cursor: { line: 5, offset: 99 },
        meta: emptyDoc().meta,
      };
      const restored: DocModel = new DocModel(data);
      expect(restored.getCursor().line).assertEqual(0);
      expect(restored.getCursor().offset).assertEqual(3);
      expect(restored.getLines()[0].text).assertEqual('abc');
    });

    it('restore_empty_lines_falls_back_to_one_line', 0, () => {
      const base = emptyDoc();
      const data: DocData = { lines: [], cursor: { line: 0, offset: 0 }, meta: base.meta };
      const restored: DocModel = new DocModel(data);
      expect(restored.getLines().length).assertEqual(1);
    });

    it('set_machine_and_paper_write_meta', 0, () => {
      doc.setMachine(MachineKind.ELECTRIC_1960S);
      expect(doc.getMeta().machine).assertEqual(MachineKind.ELECTRIC_1960S);
    });

    it('to_doc_data_roundtrip', 0, () => {
      doc.insertText('h', 40);
      doc.insertText('i', 40);
      const data: DocData = doc.toDocData();
      const again: DocModel = new DocModel(data);
      expect(again.getLines()[0].text).assertEqual('hi');
      expect(again.getCursor().offset).assertEqual(2);
    });
  });
}
