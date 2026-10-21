(function () {
  'use strict';
  function initialize() {
    document.querySelectorAll('[data-performance-leaderboard]').forEach(function (root) {
      if (root.dataset.leaderboardInitialized) return;
      root.dataset.leaderboardInitialized = 'true';
      root.querySelectorAll('[data-leaderboard-toggle]').forEach(function (button) {
        button.addEventListener('click', function () {
          var visible = button.getAttribute('aria-pressed') !== 'true';
          button.setAttribute('aria-pressed', String(visible));
          button.setAttribute('aria-label', (visible ? 'Hide ' : 'Show ') + button.dataset.ownerName + ' ' + (button.dataset.lineDescription || 'line'));
          root.querySelectorAll('[data-leaderboard-series]').forEach(function (series) {
            if (series.dataset.leaderboardSeries === button.dataset.leaderboardToggle) {
              series.classList.toggle('is-hidden', !visible);
            }
          });
        });
      });
    });
  }
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', initialize);
  else initialize();
}());
