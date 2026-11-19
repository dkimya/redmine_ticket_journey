(function () {
  'use strict';

  var selector = '[data-report-refresh-status]';
  var navigationSelector = '[data-report-refresh-navigation]';
  var navigationTimer;

  function clearNavigationTimer() {
    window.clearTimeout(navigationTimer);
  }

  function start(form, event) {
    var status = form.querySelector(selector);
    if (!status) return;
    if (status.textContent) {
      event.preventDefault();
      return;
    }
    status.textContent = status.dataset.reportRefreshStatus;
  }

  document.addEventListener('submit', function (event) {
    if (!event.defaultPrevented) start(event.target, event);
  });

  document.addEventListener('click', function (event) {
    if (event.defaultPrevented || event.button !== 0 ||
        event.ctrlKey || event.metaKey || event.shiftKey || event.altKey) return;
    var link = event.target.closest && event.target.closest(navigationSelector + ' a[href]');
    if (!link || (link.target && link.target !== '_self') || link.hasAttribute('download') ||
        link.href === window.location.href) return;

    var status = link.closest(navigationSelector).querySelector(selector);
    if (!status) return;
    clearNavigationTimer();
    navigationTimer = window.setTimeout(function () {
      if (!event.defaultPrevented) status.textContent = status.dataset.reportRefreshStatus;
    }, 200);
  });

  // Redmine's query Apply triggers a jQuery submit event. Its Save link
  // repoints the form to the saved-query editor before submitting.
  var query = document.getElementById('query_form');
  if (window.jQuery && query && query.querySelector(selector)) {
    var reportAction = query.action;
    window.jQuery(query).on('submit', function (event) {
      if (!event.originalEvent && !event.isDefaultPrevented() && query.action === reportAction) {
        start(query, event);
      }
    });
  }

  window.addEventListener('pagehide', clearNavigationTimer);
  window.addEventListener('pageshow', function () {
    clearNavigationTimer();
    document.querySelectorAll(selector).forEach(function (status) {
      status.textContent = '';
    });
  });
}());
