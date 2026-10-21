(function () {
  'use strict';
  function initialize() {
    document.querySelectorAll('[data-performance-leaderboard]').forEach(function (root) {
      if (root.dataset.leaderboardInitialized) return;
      root.dataset.leaderboardInitialized = 'true';
      var buttons = Array.from(root.querySelectorAll('[data-leaderboard-toggle]'));
      function updateTargets() {
        var visibleOwners = buttons.filter(function (button) {
          return button.getAttribute('aria-pressed') === 'true';
        }).map(function (button) { return button.dataset.leaderboardToggle; });
        root.querySelectorAll('[data-leaderboard-target]').forEach(function (target) {
          var owners = target.dataset.targetOwners.split(',');
          target.classList.toggle('is-hidden', !owners.some(function (id) { return visibleOwners.indexOf(id) !== -1; }));
        });
      }
      buttons.forEach(function (button) {
        button.addEventListener('click', function () {
          var visible = button.getAttribute('aria-pressed') !== 'true';
          button.setAttribute('aria-pressed', String(visible));
          button.setAttribute('aria-label', (visible ? 'Hide ' : 'Show ') + button.dataset.ownerName + ' ' + (button.dataset.lineDescription || 'line'));
          root.querySelectorAll('[data-leaderboard-series]').forEach(function (series) {
            if (series.dataset.leaderboardSeries === button.dataset.leaderboardToggle) {
              series.classList.toggle('is-hidden', !visible);
            }
          });
          updateTargets();
        });
      });
      updateTargets();
    });
  }
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', initialize);
  else initialize();
}());
