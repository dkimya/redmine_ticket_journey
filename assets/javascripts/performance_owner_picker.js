(function () {
  'use strict';
  function initialize() {
    document.querySelectorAll('[data-performance-owner-picker]').forEach(function (select) {
      if (select.dataset.enhanced) return;
      select.dataset.enhanced = 'true';
      function element(tag, className, text) {
        var node = document.createElement(tag);
        if (className) node.className = className;
        if (text) node.textContent = text;
        return node;
      }
      var wrapper = element('div', 'performance-owner-picker');
      var dropdown = element('details', 'performance-owner-dropdown');
      var summary = element('summary', 'performance-owner-trigger');
      summary.id = 'performance-owner-trigger';
      summary.setAttribute('aria-labelledby', 'performance-owner-label performance-owner-trigger');
      var panel = element('div', 'performance-owner-panel');
      var search = element('input', 'performance-owner-search');
      search.type = 'search';
      search.placeholder = 'Search owners…';
      search.setAttribute('aria-label', 'Search Ticket Owners');
      var actions = element('div', 'performance-owner-actions');
      function button(text) { var node = element('button', '', text); node.type = 'button'; return node; }
      var selectAll = button('Select all filtered');
      var clear = button('Clear selection');
      actions.append(selectAll, clear);
      var list = element('div', 'performance-owner-options');
      list.setAttribute('role', 'group');
      list.setAttribute('aria-label', 'Ticket Owners');
      var empty = element('p', 'performance-owner-empty', 'No matching owners.');
      var chips = element('div', 'performance-owner-chips');
      var status = element('p', 'performance-owner-status');
      status.setAttribute('role', 'status');
      var error = element('p', 'performance-owner-error');
      error.id = 'performance-owner-error';
      error.setAttribute('role', 'alert');
      summary.setAttribute('aria-describedby', error.id);
      var items = Array.from(select.options).map(function (option) {
        var label = element('label', 'performance-owner-option');
        var checkbox = element('input');
        checkbox.type = 'checkbox';
        checkbox.checked = option.selected;
        label.append(checkbox, document.createTextNode(option.textContent));
        list.append(label);
        checkbox.addEventListener('change', sync);
        return { option: option, label: label, checkbox: checkbox };
      });
      function sync() {
        chips.replaceChildren();
        var selected = items.filter(function (item) {
          item.option.selected = item.checkbox.checked;
          return item.checkbox.checked;
        });
        summary.textContent = selected.length ? selected.length + ' owner' + (selected.length === 1 ? '' : 's') + ' selected' : 'Select owners';
        status.textContent = selected.length + ' selected';
        error.textContent = '';
        summary.removeAttribute('aria-invalid');
        selected.forEach(function (item) {
          var chip = button(item.option.textContent + ' ×');
          chip.className = 'performance-owner-chip';
          chip.setAttribute('aria-label', 'Remove ' + item.option.textContent);
          chip.addEventListener('click', function () {
            item.checkbox.checked = false;
            sync();
            summary.focus();
          });
          chips.append(chip);
        });
      }
      function filter() {
        var query = search.value.trim().toLocaleLowerCase();
        var count = 0;
        items.forEach(function (item) {
          item.label.hidden = !item.option.textContent.toLocaleLowerCase().includes(query);
          if (!item.label.hidden) count++;
        });
        empty.hidden = count > 0;
        selectAll.disabled = count === 0;
      }
      search.addEventListener('input', filter);
      selectAll.addEventListener('click', function () {
        items.forEach(function (item) { if (!item.label.hidden) item.checkbox.checked = true; });
        sync();
      });
      clear.addEventListener('click', function () {
        items.forEach(function (item) { item.checkbox.checked = false; });
        sync();
      });
      dropdown.addEventListener('toggle', function () { if (dropdown.open) search.focus(); });
      wrapper.addEventListener('keydown', function (event) {
        if (event.key === 'Escape' && dropdown.open) {
          dropdown.open = false;
          summary.focus();
          event.preventDefault();
        }
        if (event.key === 'Enter' && event.target === search) event.preventDefault();
        if (event.key === 'ArrowDown' || event.key === 'ArrowUp') {
          var visible = items.filter(function (item) { return !item.label.hidden; }).map(function (item) { return item.checkbox; });
          var index = visible.indexOf(document.activeElement);
          if (visible.length && (event.target === search || index >= 0)) {
            var next = index < 0 ? 0 : (index + (event.key === 'ArrowDown' ? 1 : -1) + visible.length) % visible.length;
            visible[next].focus();
            event.preventDefault();
          }
        }
      });
      document.addEventListener('click', function (event) {
        if (!wrapper.contains(event.target)) dropdown.open = false;
      });
      select.form.addEventListener('submit', function (event) {
        if (!items.some(function (item) { return item.checkbox.checked; })) {
          event.preventDefault();
          error.textContent = 'Select at least one Ticket Owner.';
          summary.setAttribute('aria-invalid', 'true');
          dropdown.open = true;
          summary.focus();
        }
      });
      panel.append(search, actions, list, empty);
      dropdown.append(summary, panel);
      wrapper.append(dropdown, chips, status, error);
      select.after(wrapper);
      select.hidden = true;
      select.required = false; // Custom validation focuses the visible picker.
      select.parentElement.querySelector('.performance-owner-fallback').hidden = true;
      document.getElementById('performance-owner-label').htmlFor = summary.id;
      sync();
      filter();
    });
  }
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', initialize);
  else initialize();
}());
