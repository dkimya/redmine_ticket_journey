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
| Tickets Time Report | Implemented table, activity selector, totals, tooltips, and separate CSV; unit/functional tests added. User screenshots confirm the table and controls render. Activity behavior, CSV, and calculations still need server verification. |
| Tickets Time Report header overlap | Server screenshots confirm the section renders, but scrolling shows body text through transparent sticky headers. Added opaque header-cell backgrounds, non-sticky footer label, wrapped notes, and spaced controls. Styling fix awaits server visual verification; calculations remain unverified by screenshots alone. |
| Database portability | Native Return Count selects adapter-specific casts, but controller transition SQL still uses `CAST(... AS UNSIGNED)`. Whole-plugin PostgreSQL/SQLite support is not established. |

## Confirmation needed

- User kernel output confirms global OOM killed a Redmine `bundle` process using about 2.3 GiB resident memory on the 3.7 GiB/no-swap host. This is consistent with the reported 502, but does not measure the request's incremental memory alone. Removed whole-project journal/detail eager loading: batches of 100 issues, compact status/owner history, uncached scan, selected-owner snapshot retention, and page-only drill-down Issue loading. Implemented locally; no claim of measured memory reduction or resolved server OOM until deployed verification.

- Slow initial Performance navigation: the controller previously reconstructed all in-scope issue histories even before Apply. Added an early filters-only render using project members for the initial owner selector. No issue/history scan on initial navigation; actual report execution still reconstructs histories and may require further optimization. Local change; server latency improvement unverified.

- Performance page request failed with `ActionView::SyntaxErrorInTemplate` in the user-supplied Puma trace on 2026-10-13. Fixed the missing outer array closing bracket in the monthly metric loop. The subsequent user screenshot confirms successful server rendering after the fix. The same request took about 12 seconds with 9,657 queries (mostly cached); performance needs separate investigation after rendering is restored.

- Performance Section 1 was deployed by the user; its first supplied full-request trace failed during template compilation as described above. The subsequent user screenshot confirms rendering and internally consistent displayed totals; historical calculations remain unverified. Local Ruby is unavailable, so its new tests remain unexecuted. Missing Extra Tasks rules leave cumulative targets unconfigured; monthly averages require Day 0 and User target-field setup. See [setup](performance-setup.md) and [Hadi questions](performance-hadi-questions.md).

- Meeting wording “more than X” differs from implemented inclusive minimum (default 3). Confirm whether to retain this threshold/wording.
- Complexity Weight tooltip specifies 5, 8, 13, 21; plugin accepts any positive finite parsed weight. Confirm whether strict plugin-side validation is wanted.
- “Separate table” became a report view over journals, not database storage. Confirm only if persistence was intended; no schema change is planned.

The old README's Redmine 4/Ruby 2.6 requirements, four-counter statement, status aliases, and duration list were inconsistent with current code. The README now links to maintained guidance. `init.rb` requires Redmine 6.0+; controller constants define current mappings. No new Ruby minimum or database guarantee is inferred.

Future return alarms are documented in [reporting rules](reporting-rules.md); restart/log instructions are maintained in [deployment](deployment.md).

- User confirmed the memory fix runs without error and much faster; peak memory and concurrent-load behavior remain unmeasured. Project inheritance is now implemented locally for all descendant levels and visible project members, with a Project drill-down column; deployment verification is pending.

- Hadi's Open Tickets feedback implemented locally: Not Touched now requires no In Progress evidence by report date; other development stages no longer imply Started. Stopped (On-Hold/Pending as of date) appears below Total Open Tickets with a drill-down while remaining in the existing groups. Server calculation/layout verification pending.

- Hadi resolved Extra Tasks: use one shared 90% delivery target for now. Implemented configurable Delivery Target (%) with numeric 0–100 validation for both delivery indicators. Prior notes about an unconfigured Extra Tasks target are superseded. Server settings-save/render verification is pending.

- Active-users-only filtering applies to both Performance dropdown paths. Per user clarification, inactive owner saved report/drill-down links remain usable with normal visibility/permission checks; the extra activity-based block was removed. Server verification pending.

- Hadi's Section 2 exclusions implemented: Archived and Ongoing are removed from delivery populations using as-of status, including due denominators and drill-downs. Ongoing remains in Section 1. Unit coverage added; runtime/server verification pending.
Automatic separate Day 0 rules implemented locally: account creation for monthly ticket count and earliest eligible weighted ticket Start date for monthly weight. Separate contributor links and displayed dates added; manual setting removed from UI and ignored. No valid start means N/A. Server verification pending.

- Performance drill-down project grouping and sortable headings implemented locally. Group totals span all pages, with page counts labelled. Runtime tests and deployed layout verification remain pending.

- Hadi's comparison-first layout implemented with an expanded collapsible table and multi-owner aggregate charts/drill-downs. Single batched history scan preserved. Multi-owner monthly averages/targets remain unavailable pending agreed aggregation; the three-month proposal is not applied by this layout change. Runtime/server verification pending.

- Performance owner selector enhanced with searchable checkbox dropdown, selected-count summary, removable chips, select-all-filtered and clear controls. Native multi-select is the no-JavaScript fallback. JS syntax check passed; deployed keyboard/mobile/visual verification pending.

- Owner picker rendering confirmed by user screenshots for small and large selections. Added stable top alignment for date, owner trigger and Apply, allowing chips/errors to grow below. Narrow screens stack controls. Alignment change awaits deployed visual verification.

- Back to Performance now uses browser history for tracked same-tab report-to-drill-down navigation, including skipping sort/pagination entries. The normal report URL remains the fallback for direct visits/new tabs/blocked storage. JavaScript navigation tests pass; browser back-forward cache restoration and deployed behavior still require verification.

- Slow Performance scans optimized locally using SQL selected-owner candidates, owner-only dropdown discovery, safe metric due-date filters, two-field batch values with an override-aware visibility fallback, and skipped comparison calculations on details. Historical reassignment and blank owner handling remain exact. Runtime tests and measured server timings are pending; no claimed latency reduction yet.
