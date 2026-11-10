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
const client = (address = '0xABC', workspace = 2, tags = [], extra = {}) => ({
  address, workspace: { id: workspace, name: extra.workspaceName || (workspace < 0 ? 'special:minimized' : String(workspace)) },
  tags, class: 'foot', title: 'Terminal', mapped: true, ...extra,
});
test('normal and minimized origins are distinct', () => {
  const records = M.normalizeClients([client('0xABC', 2, [], { focusHistoryID: 0 }), client('0xdef', -99, ['omarchy-minimized-from-12'])]);
  assert.equal(JSON.stringify(records.map(r => [r.address, r.origin, r.minimized, r.focused])), JSON.stringify([['0xabc', 2, false, true], ['0xdef', 12, true, false]]));
});
test('ambiguous, invalid or missing origin tags never guess', () => {
  for (const tags of [[], ['omarchy-minimized-from-0'], ['omarchy-minimized-from-2', 'omarchy-minimized-from-3'],
    ['omarchy-minimized-from-2oops'], ['omarchy-minimized-from-2', 'omarchy-minimized-from-03'], ['omarchy-minimized-from-1234567']]) {
    assert.equal(M.normalizeClients([client('0xabc', -99, tags)])[0].origin, null, JSON.stringify(tags));
  }
});
test('special workspaces, unmapped clients and invalid addresses are not normal windows', () => {
  const rows = M.normalizeClients([client('0xabc', -1, [], { workspaceName: 'special:scratchpad' }), client('0xdef', 2, [], { mapped: false }),
    client('bad; exec'), null, 'text']);
  assert.equal(rows.length, 1);
  assert.equal(rows[0].origin, null);
  assert.equal(rows[0].minimized, false);
  assert.equal(M.normalizeClients({ clients: [] }), null);
});
test('titles remain bounded plain data', () => {
  const rows = M.normalizeClients([client('0xabc', 2, [], { title: '<img src="https://invalid/">' + 'x'.repeat(5000) })]);
  assert.ok(rows[0].title.startsWith('<img'));
  assert.equal(rows[0].title.length, 4096);
});
test('restore chunk carries the path as data and rejects untrusted arguments', () => {
  const path = '/home/a "b"\\c\n/operations.lua';
  const chunk = M.restoreChunk(path, '0xABC', 12);
  assert.equal(chunk, 'dofile("/home/a \\034b\\034\\092c\\010/operations.lua").execute("restore", "0xabc", 12)');
  for (const [address, workspace] of [['0xabc;evil', 2], ['0xabc', -1], ['0xabc', '2'], ['0xabc', 2.5], ['0xabc', 1000000], [undefined, 2]]) {
    assert.equal(M.restoreChunk(path, address, workspace), '', `${address} ${workspace}`);
  }
});
test('restore chunk decodes to the original path in Lua', { skip: require('node:child_process').spawnSync('lua', ['-v']).error !== undefined }, () => {
  const path = '/tmp/a "b"\\c\n\u00e9/operations.lua';
  const literal = M.restoreChunk(path, '0xabc', 2).match(/^dofile\((".*")\)\.execute/s)[1];
  const result = require('node:child_process').spawnSync('lua', ['-e', `io.write(${literal})`], { encoding: 'utf8' });
  assert.equal(result.stdout, path);
});
test('window geometry is kept for the backdrop and malformed geometry is dropped', () => {
  const [row, bad] = M.normalizeClients([client('0xabc', 2, [], { at: [12, 470], size: [701, 418], monitor: 1 }),
    client('0xdef', 2, [], { at: 'x', size: [1], monitor: '1' })]);
  assert.equal(JSON.stringify([row.at, row.size, row.monitorId]), '[[12,470],[701,418],1]');
  assert.equal(JSON.stringify([bad.at, bad.size, bad.monitorId]), '[null,null,-1]');
});
test('blur options follow hyprctl batch output and fall back to off', () => {
  const text = ['{"option": "decoration:blur:enabled", "bool": true, "set": true }', '{"option": "decoration:blur:size", "int": 4, "set": true }',
    '{"option": "decoration:blur:passes", "int": 2, "set": true }', '{"option": "decoration:blur:brightness", "float": 0.750000, "set": true }',
    'garbage', '{"option": "decoration:blur:contrast", "float": 9, "set": true }'].join('\n\n\n');
  assert.equal(JSON.stringify(M.parseBlur(text)), '{"enabled":true,"size":4,"passes":2,"brightness":0.75,"contrast":2}');
  assert.equal(M.parseBlur('').enabled, false);
  assert.equal(M.parseBlur('{"option": "decoration:blur:enabled", "bool": false}').enabled, false);
  assert.equal(M.parseBlur('{"option": "decoration:blur:enabled", "int": 1}').enabled, true);
});
test('backdrop places the monitor wallpaper behind the window at preview scale', () => {
  const record = { at: [100, 50], size: [800, 600] };
  const monitor = { x: 0, y: 0, width: 2880, height: 1800, scale: 2, transform: 0 };
  assert.equal(JSON.stringify(M.backdropGeometry(record, monitor, 400)), JSON.stringify({ x: -50, y: -25, width: 720, height: 450, scale: 0.5 }));
  const rotated = M.backdropGeometry({ at: [1500, 0], size: [500, 500] }, { x: 1440, y: 0, width: 1920, height: 1080, scale: 1, transform: 1 }, 500);
  assert.equal(JSON.stringify(rotated), JSON.stringify({ x: -60, y: 0, width: 1080, height: 1920, scale: 1 }));
  for (const [r, m, w] of [[{}, monitor, 400], [record, null, 400], [record, { ...monitor, scale: 0 }, 400], [record, monitor, 0], [{ at: [0, 0], size: [0, 10] }, monitor, 400]])
    assert.equal(M.backdropGeometry(r, m, w), null);
});
test('blur radius follows the Hyprland setting and is off when blur is disabled', () => {
  const blur = { enabled: true, size: 4, passes: 2 };
  assert.equal(M.blurRadius(blur, 1), 16);
  assert.equal(M.blurRadius(blur, 0.5), 8);
  assert.equal(M.blurRadius(blur, 0.01), 1);
  assert.equal(M.blurRadius({ enabled: true, size: 64, passes: 8 }, 1), 64);
  assert.equal(M.blurRadius({ ...blur, enabled: false }, 1), 0);
});
