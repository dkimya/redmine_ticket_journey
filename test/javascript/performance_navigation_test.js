const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const test = require('node:test');
const source = fs.readFileSync(require('node:path').join(__dirname, '../../assets/javascripts/performance_navigation.js'), 'utf8');

function page(url, referrer, storage, initialState = null, length = 3) {
  let listener;
  const history = { state: initialState, length, go: function (steps) { this.destination = steps; },
    replaceState: function (state) { this.state = state; } };
  vm.runInNewContext(source, {
    URL, Date, Number, Object, JSON,
    window: { location: { href: url }, history, sessionStorage: {
      getItem: key => storage.get(key), removeItem: key => storage.delete(key), setItem: (key, value) => storage.set(key, value)
    } },
    document: { referrer, addEventListener: (_name, callback) => { listener = callback; } }
  });
  return { history, click(href, back = false, modifiers = {}, target = '') {
    const link = { href, target, hasAttribute: name => name === 'data-performance-back' && back };
    const event = Object.assign({ target: { closest: () => link }, button: 0, defaultPrevented: false,
      preventDefault() { this.defaultPrevented = true; } }, modifiers);
    listener(event);
    return event;
  } };
}
const dashboard = 'https://example.test/projects/a/performance?owner_id=1';
const details = dashboard + '&metric=open';

test('default new-tab drill downs leave dashboard history untouched and Back uses its normal URL', () => {
  const storage = new Map();
  const report = page(dashboard, '', storage, { otherFeature: true });
  const event = report.click(details, false, {}, '_blank');
  assert.equal(event.defaultPrevented, false);
  assert.equal(storage.size, 0);
  assert.deepEqual(report.history.state, { otherFeature: true });
  const drill = page(details, dashboard, storage, null, 3);
  assert.equal(drill.click(dashboard, true).defaultPrevented, false);
  assert.equal(drill.history.destination, undefined);
});

test('return skips sorting entries and preserves existing history state', () => {
  const storage = new Map();
  page(dashboard, '', storage).click(details);
  const drill = page(details, dashboard, storage, { otherFeature: true }, 4);
  assert.equal(drill.history.state.otherFeature, true);
  assert.equal(drill.history.state.performanceReturn.steps, 1);
  const sorted = details + '&sort=due';
  drill.click(sorted);
  const next = page(sorted, details, storage, null, 5);
  assert.equal(next.click(dashboard, true).defaultPrevented, true);
  assert.equal(next.history.destination, -2);
});

test('direct visits and modified clicks retain ordinary link behavior', () => {
  const storage = new Map();
  const direct = page(details, '', storage);
  assert.equal(direct.click(dashboard, true).defaultPrevented, false);
  page(dashboard, '', storage).click(details, false, { ctrlKey: true });
  assert.equal(storage.size, 0);
});

test('new tabs cannot claim a history return even with a copied handoff', () => {
  const storage = new Map();
  page(dashboard, '', storage).click(details);
  const tab = page(details, dashboard, storage, null, 1);
  assert.equal(tab.click(dashboard, true).defaultPrevented, false);
});

test('mismatched referrer does not adopt stale navigation handoff', () => {
  const storage = new Map();
  page(dashboard, '', storage).click(details);
  const direct = page(details, 'https://example.test/other', storage);
  assert.equal(direct.click(dashboard, true).defaultPrevented, false);
});
