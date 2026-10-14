# Known issues and evidence

Reviewed 2026-10-13. **Server-confirmed** means user output/screenshots or explicit confirmation in this conversation, not a fresh check of today's deployment.

| Issue | Solution and evidence |
| --- | --- |
| Missing `Issue#tj_return_count` on first boot | Removed nested preparation callback; guarded patch installation directly in `init.rb`. Server runner then returned 1 for #14405 and rendered the partial. Full issue navigation was not covered by that runner. |
| Kanban recursion in column discovery | Removed `available_columns` wrapper; register in `IssueQuery.available_columns`. Request trace alternated between Kanban and our patch. |
| Kanban recursion in filter initialization | Removed `initialize_available_filters` wrapper; add filter after `available_filters` calls `super`. User subsequently confirmed pages working; #13841 screenshot showed Block and Return Count 2 together. Other plugin combinations are not certified. |
| Return Count visually below Block | Implemented page-load relocation below literal label `Invoiced?`, otherwise main right column. New placement not explicitly server-confirmed; depends on DOM/label and JavaScript. |
| Completion/debt looked like one sum | Implemented two labelled tables with independent totals and Tickets/Points. Split layout and new summary Points columns lack explicit server confirmation. |
| Runtime checks | Regression tests cover dates, carry-over, points, native count/query/CSV, and legacy aliases. Local Ruby was unavailable during this work; test execution is unconfirmed. |
| Database portability | Native Return Count selects adapter-specific casts, but controller transition SQL still uses `CAST(... AS UNSIGNED)`. Whole-plugin PostgreSQL/SQLite support is not established. |

## Confirmation needed

- Meeting wording “more than X” differs from implemented inclusive minimum (default 3). Confirm whether to retain this threshold/wording.
- Complexity Weight tooltip specifies 5, 8, 13, 21; plugin accepts any positive finite parsed weight. Confirm whether strict plugin-side validation is wanted.
- “Separate table” became a report view over journals, not database storage. Confirm only if persistence was intended; no schema change is planned.

The old README's Redmine 4/Ruby 2.6 requirements, four-counter statement, status aliases, and duration list were inconsistent with current code. The README now links to maintained guidance. `init.rb` requires Redmine 6.0+; controller constants define current mappings. No new Ruby minimum or database guarantee is inferred.

Future return alarms are documented in [reporting rules](reporting-rules.md); restart/log instructions are maintained in [deployment](deployment.md).
