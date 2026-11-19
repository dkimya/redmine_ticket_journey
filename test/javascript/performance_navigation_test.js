const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const test = require('node:test');
const source = fs.readFileSync(require('node:path').join(__dirname, '../../assets/javascripts/performance_navigation.js'), 'utf8');
const refreshSource = fs.readFileSync(require('node:path').join(__dirname, '../../assets/javascripts/report_refresh.js'), 'utf8');

function page(url, referrer, storage, initialState = null, length = 3) {
  const listeners = {};
  const status = { textContent: '', dataset: { reportRefreshStatus: 'Refreshing report…' } };
  const navigationStatus = { textContent: '', dataset: status.dataset };
  const clickListeners = [];
  const timers = new Map();
  let nextTimer = 0;
  const query = { action: url, querySelector: () => status };
  let querySubmit;
  const history = { state: initialState, length, go: function (steps) { this.destination = steps; },
    replaceState: function (state) { this.state = state; } };
  vm.runInNewContext(source + '\n' + refreshSource, {
    URL, Date, Number, Object, JSON,
    window: { location: { href: url }, history, addEventListener: (name, callback) => { listeners[name] = callback; },
      setTimeout(callback, delay) {
        timers.set(++nextTimer, { callback, delay });
        return nextTimer;
      },
      clearTimeout: id => timers.delete(id),
      jQuery: () => ({ on: (_name, callback) => { querySubmit = callback; } }), sessionStorage: {
      getItem: key => storage.get(key), removeItem: key => storage.delete(key), setItem: (key, value) => storage.set(key, value)
    } },
    document: { referrer, getElementById: () => query, querySelectorAll: () => [status, navigationStatus],
      addEventListener(name, callback) {
        if (name === 'click') clickListeners.push(callback);
        else listeners[name] = callback;
      } }
  });
  return { history, status, navigationStatus, timers, listeners, query, querySubmit,
    click(href, back = false, modifiers = {}, target = '', navigation = false) {
    const link = { href, target, hasAttribute: name => name === 'data-performance-back' && back,
      closest: () => ({ querySelector: () => navigationStatus }) };
    const event = Object.assign({ target: { closest: selector => selector === 'a[href]' || navigation ? link : null },
      button: 0, defaultPrevented: false,
      preventDefault() { this.defaultPrevented = true; } }, modifiers);
    clickListeners.forEach(listener => listener(event));
    return event;
  } };
}
const dashboard = 'https://example.test/projects/a/performance?owner_id=1';
const details = dashboard + '&metric=open';

test('dashboard switches display the refresh indicator after a short delay and clear it on return', () => {
  const report = page(dashboard, '', new Map());
  const event = report.click(dashboard + '&dashboard_type=periodic', false, {}, '', true);
  assert.equal(event.defaultPrevented, false);
  assert.equal(report.navigationStatus.textContent, '');
  const [timer] = report.timers.values();
  assert.equal(timer.delay, 200);
  timer.callback();
  assert.equal(report.navigationStatus.textContent, 'Refreshing report…');
  assert.equal(report.status.textContent, '');
  report.listeners.pageshow();
  assert.equal(report.navigationStatus.textContent, '');
});

test('quick tab switches cancel the timer and modified links bypass it', () => {
  const tab = dashboard + '&tab=returns';
  const report = page(dashboard, '', new Map());
  report.click(tab, false, {}, '', true);
  assert.equal(report.timers.size, 1);
  report.listeners.pagehide();
  assert.equal(report.timers.size, 0);
  assert.equal(report.navigationStatus.textContent, '');

  report.click(tab, false, { ctrlKey: true }, '', true);
  report.click(tab, false, {}, '_blank', true);
  report.click(tab, false, { defaultPrevented: true }, '', true);
  report.click(dashboard, false, {}, '', true);
  report.click(details);
  assert.equal(report.timers.size, 0);
});

test('Apply shows a refresh indicator and allows submitting again after browser Back', () => {
  const report = page(dashboard, '', new Map());
  const event = {
    target: { querySelector: () => report.status }, defaultPrevented: false,
    preventDefault() { this.defaultPrevented = true; }
  };
  report.listeners.submit(event);
  assert.equal(event.defaultPrevented, false);
  assert.equal(report.status.textContent, 'Refreshing report…');
  report.listeners.submit(event);
  assert.equal(event.defaultPrevented, true);
  report.listeners.pageshow();
  assert.equal(report.status.textContent, '');
});

test('Redmine query Apply shows the indicator while Save and native events bypass the jQuery handler', () => {
  const report = page('https://example.test/projects/a/ticket_journey/owner_returns', '', new Map());
  const apply = {
    defaultPrevented: false,
    isDefaultPrevented() { return this.defaultPrevented; },
    preventDefault() { this.defaultPrevented = true; }
  };
  report.querySubmit({ ...apply, originalEvent: {} });
  assert.equal(report.status.textContent, '');

  report.querySubmit(apply);
  assert.equal(report.status.textContent, 'Refreshing report…');
  report.querySubmit(apply);
  assert.equal(apply.defaultPrevented, true);

  report.listeners.pageshow();
  report.query.action = 'https://example.test/projects/a/queries/new';
  report.querySubmit({ ...apply, defaultPrevented: false });
  assert.equal(report.status.textContent, '');
});

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
