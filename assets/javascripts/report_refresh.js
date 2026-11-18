(function () {
  'use strict';

  var selector = '[data-report-refresh-status]';

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

  window.addEventListener('pageshow', function () {
    document.querySelectorAll(selector).forEach(function (status) {
      status.textContent = '';
    });
  });
}());
