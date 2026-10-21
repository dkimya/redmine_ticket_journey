const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const test = require('node:test');
const source = fs.readFileSync(require('node:path').join(__dirname, '../../assets/javascripts/performance_leaderboard.js'), 'utf8');

function page(loading = false, empty = false) {
  const buttons = ['1', '2'].map(id => ({
    dataset: { leaderboardToggle: id, ownerName: 'Owner ' + id },
    attributes: { 'aria-pressed': 'true' }, listeners: [],
    getAttribute(name) { return this.attributes[name]; },
    setAttribute(name, value) { this.attributes[name] = value; },
    addEventListener(_name, callback) { this.listeners.push(callback); }
  }));
  const series = ['1', '2'].map(id => ({
    dataset: { leaderboardSeries: id }, hidden: false,
    classList: { toggle(_name, hidden) { series.find(item => item.dataset.leaderboardSeries === id).hidden = hidden; } }
  }));
  const root = { dataset: {}, querySelectorAll(selector) {
    return selector === '[data-leaderboard-toggle]' ? buttons : series;
  } };
  let ready;
  const context = { document: {
    readyState: loading ? 'loading' : 'complete',
    querySelectorAll: () => empty ? [] : [root],
    addEventListener(_name, callback) { ready = callback; }
  } };
  vm.runInNewContext(source, context);
  return { buttons, series, root, context, ready: () => ready() };
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

test('owner toggle announces the grouped delivery and target lines', () => {
  const p = page();
  p.buttons[0].dataset.lineDescription = 'delivery and target lines';
  p.buttons[0].listeners[0]();
  assert.equal(p.series[0].hidden, true);
  assert.equal(p.series[1].hidden, false);
  assert.equal(p.buttons[0].attributes['aria-label'], 'Show Owner 1 delivery and target lines');
});
