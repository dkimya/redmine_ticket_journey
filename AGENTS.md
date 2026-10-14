# Project guidance

Redmine PMO Dashboard plugin; `init.rb` requires Redmine 6.0+. Runtime checks need a host Redmine installation, not this repository alone.

- Read [reporting rules](docs/reporting-rules.md), [deployment](docs/deployment.md), and [known issues](docs/known-issues.md) before related changes. Keep business rules in one place.
- Main calculations and status/tracker/custom-field mappings: `app/controllers/ticket_journey_controller.rb`. Native Return Count: `lib/ticket_journey/return_count.rb`. Keep SQL and report event counting consistent.
- Preserve current due dates/current complexity weights when reconstructing past periods. Do not silently restore old values or reset return totals.
- Configured field IDs include Ticket Owner 57, Original Sprint 68, Complexity Weight 70. Verify mappings before changing them; do not create duplicate fields or stored counters by default.
- Redmine runs `init.rb` inside preparation. Install patches directly there with duplicate guards; do not nest another `config.to_prepare` callback.
- Audit overrides against installed plugins. Kanban legacy aliases recurse with prepended wrappers of `available_columns` and `initialize_available_filters`. Use the column registry and existing post-initialization filter approach; preserve other plugins' fields.
- Avoid replacing host templates or modifying other plugins to reposition fields. The Return Count partial currently moves its field on page load.

## Checks

- Run `git diff --check`. Reporting tests are in `test/unit/`; native issue display/CSV tests are in `test/functional/`.
- From a configured **test Redmine root**, run:
  ```bash
  bundle exec rake redmine:plugins:test NAME=redmine_ticket_journey RAILS_ENV=test
  ```
- Never run tests against production data. This workspace previously lacked Ruby; report checks actually run and any unverified behavior.
- Verify on the installed plugin set: ticket page, My page, Issues, saved queries, numeric filters/sorting, selected-column CSV, and affected reports. A successful runner/partial render does not prove full web requests work.
- Visually verify layout changes after deployment. Diagnose actual request exceptions, not generic Internal Error pages or startup warnings.

Distinguish implemented code, user-confirmed server behavior, and future plans in documentation and responses.
