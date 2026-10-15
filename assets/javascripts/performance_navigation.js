(function () {
  'use strict';
  var key = 'performance-navigation-pending';
  var current = new URL(window.location.href);
  var isDetails = current.searchParams.has('metric');
  // A hand-off is written only for an ordinary same-tab click. Verify both the
  // target and referrer before trusting it, so bookmarks/new tabs use the href.
  try {
    var raw = window.sessionStorage.getItem(key);
    window.sessionStorage.removeItem(key);
    var pending = raw ? JSON.parse(raw) : null;
    if (isDetails && pending && pending.target === current.href &&
        pending.source === document.referrer && Date.now() - pending.at < 30000 &&
        Number.isInteger(pending.steps) && pending.steps > 0 &&
        window.history.length > pending.steps) {
      window.history.replaceState(Object.assign({}, window.history.state, {
        performanceReturn: { steps: pending.steps, path: current.pathname }
      }), '');
    }
  } catch (_) { /* Storage restrictions leave the normal link fully usable. */ }

  document.addEventListener('click', function (event) {
    var link = event.target.closest && event.target.closest('a[href]');
    if (!link || event.defaultPrevented || event.button !== 0 ||
        event.ctrlKey || event.metaKey || event.shiftKey || event.altKey ||
        (link.target && link.target !== '_self') || link.hasAttribute('download')) return;
    var target = new URL(link.href, window.location.href);
    if (target.origin !== current.origin || target.pathname !== current.pathname) return;
    var state = window.history.state && window.history.state.performanceReturn;
    if (link.hasAttribute('data-performance-back')) {
      if (isDetails && state && state.path === current.pathname &&
          Number.isInteger(state.steps) && state.steps > 0 && window.history.length > state.steps) {
        event.preventDefault();
        // Skip drill-down sorting/pagination entries to the original report.
        window.history.go(-state.steps);
      }
      return;
    }
    if (!target.searchParams.has('metric')) return;
    var steps = !isDetails ? 1 : (state && state.path === current.pathname ? state.steps + 1 : null);
    if (!steps) return;
    try {
      window.sessionStorage.setItem(key, JSON.stringify({
        target: target.href, source: window.location.href, steps: steps, at: Date.now()
      }));
    } catch (_) { /* The report URL remains the fallback. */ }
  });
}());
