const { test } = require('node:test');
const assert = require('node:assert/strict');
const vm = require('node:vm');
const fs = require('node:fs');
const path = require('node:path');
const M = vm.createContext({});
vm.runInContext(fs.readFileSync(path.join(__dirname, '../Model.js'), 'utf8'), M);
const rows = [
  { address: '0x1', origin: 2, minimized: false },
  { address: '0x2', origin: 12, minimized: true },
  { address: '0x3', origin: 2, minimized: true },
  { address: '0x4', origin: null, minimized: true },
];
test('workspace filter keeps monitor blocks distinct', () => {
  assert.equal(M.windowsFor(rows, 2, false).map(x => x.address).join(), '0x1,0x3');
  assert.equal(M.windowsFor(rows, 12, true).map(x => x.address).join(), '0x2');
});
test('overflow mode contains only minimized windows of the requested workspace', () => {
  assert.equal(M.windowsFor(rows, 2, true).map(x => x.address).join(), '0x3');
  assert.equal(M.windowsFor(rows, -1, false).length, 0);
});
test('selection survives list updates and clamps when its window disappears', () => {
  assert.equal(M.selectionIndex(rows, '0x3', 0), 2);
  assert.equal(M.selectionIndex(rows.slice(0, 2), '0x3', 2), 1);
  assert.equal(M.selectionIndex([], '0x3', 2), 0);
});
test('plain-text tooltip preserves titles literally and includes application name', () => {
  assert.equal(M.tooltipText('<img src="https://invalid/"> & Notes', 'Browser'), 'Browser\n<img src="https://invalid/"> & Notes');
});
const hostPath = '/usr/share/omarchy/shell/plugins/bar/Bar.qml';
test('installed shared tooltip explicitly renders PlainText', {skip: !fs.existsSync(hostPath)}, () => {
  assert.match(fs.readFileSync(hostPath, 'utf8'), /id:\s*tooltipLabel\s+textFormat:\s*Text\.PlainText/);
});
test('tag-only changes refresh workspace provenance', () => {
  assert.equal(M.shouldRefresh('tagwindow'), true);
  assert.equal(M.shouldRefresh('movewindowv2'), true);
  assert.equal(M.shouldRefresh('unrelated'), false);
});
test('desktop numbering uses local monitor slot and icon overflow is bounded', () => {
  assert.equal(M.slot(12), 2);
  assert.equal(M.slot(10), 10);
  assert.equal(M.barItems(Array.from({length: 9}, (_, i) => ({address: String(i)})), 6).length, 7);
  const overflow = M.barItems(rows, 2)[2];
  assert.equal(overflow.overflow, 2);
});
