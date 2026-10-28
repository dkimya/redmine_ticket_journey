const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const test = require('node:test');
const source = fs.readFileSync(require('node:path').join(__dirname, '../../assets/javascripts/performance_leaderboard.js'), 'utf8');

function page(loading = false, empty = false, targetOwners = [], includeTeam = false, pairedOwnerLines = false) {
  const buttons = ['1', '2'].map(id => ({
    dataset: { leaderboardToggle: id, ownerName: 'Owner ' + id },
    attributes: { 'aria-pressed': 'true' }, listeners: [],
    getAttribute(name) { return this.attributes[name]; },
    setAttribute(name, value) { this.attributes[name] = value; },
    addEventListener(_name, callback) { this.listeners.push(callback); }
  }));
  const ownerIds = pairedOwnerLines ? ['1', '1', '2', '2'] : ['1', '2'];
  const series = (includeTeam ? ['team', ...ownerIds] : ownerIds).map(id => {
    const item = { dataset: { leaderboardSeries: id }, hidden: false };
    item.classList = { toggle(_name, hidden) { item.hidden = hidden; } };
    return item;
  });
  const targets = targetOwners.map(owners => {
    const target = { dataset: { targetOwners: owners }, hidden: false };
    target.classList = { toggle(_name, hidden) { target.hidden = hidden; } };
    return target;
  });
  const root = { dataset: {}, querySelectorAll(selector) {
    if (selector === '[data-leaderboard-toggle]') return buttons;
    if (selector === '[data-leaderboard-series]') return series;
    if (selector === '[data-leaderboard-target]') return targets;
    return [];
  } };
  let ready;
  const context = { document: {
    readyState: loading ? 'loading' : 'complete',
    querySelectorAll: () => empty ? [] : [root],
    addEventListener(_name, callback) { ready = callback; }
  } };
  vm.runInNewContext(source, context);
  return { buttons, series, targets, root, context, ready: () => ready() };
}

test('legend toggles only the selected owner and updates accessible state', () => {
  const p = page();
  p.buttons[0].listeners[0]();
  assert.equal(p.series[0].hidden, true);
  assert.equal(p.series[1].hidden, false);
  assert.equal(p.buttons[0].attributes['aria-pressed'], 'false');
  assert.equal(p.buttons[0].attributes['aria-label'], 'Show Owner 1 line');
  p.buttons[0].listeners[0]();
  assert.equal(p.series[0].hidden, false);
  assert.equal(p.buttons[0].attributes['aria-label'], 'Hide Owner 1 line');
});

test('initialization waits for the DOM and avoids duplicate listeners', () => {
  const p = page(true);
  assert.equal(p.buttons[0].listeners.length, 0);
  p.ready();
  vm.runInNewContext(source, p.context);
  p.ready();
  assert.equal(p.buttons[0].listeners.length, 1);
});

test('single-owner and initial pages without leaderboards initialize safely', () => {
  assert.doesNotThrow(() => page(false, true));
});

test('Periodic Returns team line remains visible when every individual owner is hidden', () => {
  const p = page(false, false, [], true);
  p.buttons.forEach(button => button.listeners[0]());
  assert.equal(p.series.find(item => item.dataset.leaderboardSeries === 'team').hidden, false);
  assert.equal(p.series.find(item => item.dataset.leaderboardSeries === '1').hidden, true);
  assert.equal(p.series.find(item => item.dataset.leaderboardSeries === '2').hidden, true);
});

test('Periodic Time and Tickets toggle an owners paired lines together', () => {
  const p = page(false, false, [], false, true);
  p.buttons[0].dataset.lineDescription = 'lines';
  p.buttons[0].listeners[0]();
  assert(p.series.filter(item => item.dataset.leaderboardSeries === '1').every(item => item.hidden));
  assert(p.series.filter(item => item.dataset.leaderboardSeries === '2').every(item => !item.hidden));
  assert.equal(p.buttons[0].attributes['aria-label'], 'Show Owner 1 lines');
  p.buttons[0].listeners[0]();
  assert(p.series.every(item => !item.hidden));
});

test('shared target stays visible until every owner using it is hidden and restores on show', () => {
  const p = page(false, false, ['1,2', '2']);
  assert.equal(p.targets[0].hidden, false);
  p.buttons[0].listeners[0]();
  assert.equal(p.series[0].hidden, true);
  assert.equal(p.targets[0].hidden, false);
  assert.equal(p.targets[1].hidden, false);
  p.buttons[1].listeners[0]();
  assert.equal(p.targets[0].hidden, true);
  assert.equal(p.targets[1].hidden, true);
  p.buttons[0].listeners[0]();
  assert.equal(p.targets[0].hidden, false);
  assert.equal(p.targets[1].hidden, true);
});
