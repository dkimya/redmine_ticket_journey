// Ticket Journey Plugin — ticket_journey.js
document.addEventListener('DOMContentLoaded', function () {
  var searchInput = document.getElementById('tj-search');
  if (!searchInput) return;

  searchInput.addEventListener('input', function () {
    var q = this.value.toLowerCase().trim();
    var rows = document.querySelectorAll('#tj-table tbody .tj-row');
    rows.forEach(function (row) {
      var text = row.getAttribute('data-search') || '';
      row.style.display = (!q || text.includes(q)) ? '' : 'none';
    });
  });
});
