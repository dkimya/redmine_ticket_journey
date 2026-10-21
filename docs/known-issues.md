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

Hadi’s latest open-ticket rule implemented: New and On-Hold excluded as of the selected date, including Section 1 counts, weights, groups, Due Soon, and drill-downs. Stopped is Pending only. Earlier notes including On-Hold/New are superseded. Historical-status and dashboard/drill-down regression tests added; Ruby tests unrun locally, server verification pending. Cumulative delivery/monthly rules unchanged.

Navigation hierarchy implemented: blue header contains Live Dashboard / Periodic Report, then Tickets / Returns / Time, above page title and filters. Periodic and unimplemented sections are Planned placeholders without report scans. Category/section links and Apply preserve date/owners; Live Dashboard remains a selected-date snapshot. Drill-down headers share the hierarchy without replacing their historical data. Ruby request tests added but not run locally; server visual/mobile/access verification pending.

Performance Tickets/Returns/Time navigation added. Returns and Time are planned pages only; no metrics or history scans. Date/owner context is retained, using generic labels for retained IDs outside the lightweight member selector. Shared header and tabs also appear on ticket drill-downs. Ruby request tests added but not run locally; server visual/access verification pending.

Combined monthly targets implemented: arithmetic mean of current usable targets across all distinct selected owners, paired with monthly per-owner actual means. Zero-delivery owners remain in both denominators. Missing/hidden/invalid/nonpositive target for any owner makes only that target/deviation unavailable, with owner names. Contributor sets remain intact. Metadata lookup is reused and selected-owner custom values are batch preloaded; drill-downs skip target lookup. Ruby tests updated but unrun locally; server verification pending.

Drill-down Priority, Title / Subject, PM Estimate, and Time Spent options implemented. PM Estimate means native Estimated time; spent hours are visible lifetime direct entries, not historical totals. Defaults retain the original nine fields. Ruby display/visibility tests added/updated but not run locally; server verification pending.

Open Tickets total-card alignment: user screenshot confirmed the total-above-three layout, but Stopped sat beside complexity weight. Updated the card to two columns, with Stopped directly under the ticket count on both desktop and mobile. Complexity weight stays on the right. This alignment fix awaits server visual verification.

Performance drill-down list options: implemented ungrouped default, selectable existing report columns, optional Project/Tracker/historical Owner/Status groups, context-preserving sort/pagination, and a full-set native Issues link labelled current values. No host templates/model patches added. Native handoff encodes ticket IDs in the URL; very large sets may hit browser/proxy URL limits (no truncation is applied). Standard native Issues columns/grouping are available there; the historical list has its original nine fields plus optional Priority, PM Estimate, and Time Spent. Title / Subject reuses Subject. Ruby tests updated but not run locally; server verification pending.

Open Tickets visual layout: implemented a larger responsive donut (about 320px at full size), labelled Ticket distribution, beside a shallow full-width Total Open Tickets rectangle above three equal breakdown cards (Not Overdue, Already Started, Not Touched). Desktop split is approximately 40% chart / 60% cards; narrower screens stack chart above cards. Total retains Stopped and complexity weight; Due Soon remains under Not Overdue. Small screens stack breakdown cards. Total Open Tickets outline is now 1px. Percentage-label positions scale with the chart; drill-down links/calculations are unchanged. Server visual verification pending, including small screens and adjacent small segments.

Developer comparison styling: Hadi requested stronger Tickets/Complexity Weight separation and lighter Total-row borders. Implemented a 3px divider before weights, 2px after weights, distinct pale group headings, and 1px horizontal total borders retaining bold numbers/shading. All boundaries span both headers, owner rows, and totals. Server visual verification pending.

- User kernel output confirms global OOM killed a Redmine `bundle` process using about 2.3 GiB resident memory on the 3.7 GiB/no-swap host. This is consistent with the reported 502, but does not measure the request's incremental memory alone. Removed whole-project journal/detail eager loading: batches of 100 issues, compact status/owner history, uncached scan, selected-owner snapshot retention, and page-only drill-down Issue loading. Implemented locally; no claim of measured memory reduction or resolved server OOM until deployed verification.

- Slow initial Performance navigation: the controller previously reconstructed all in-scope issue histories even before Apply. Added an early filters-only render using project members for the initial owner selector. No issue/history scan on initial navigation; actual report execution still reconstructs histories and may require further optimization. Local change; server latency improvement unverified.

- Performance page request failed with `ActionView::SyntaxErrorInTemplate` in the user-supplied Puma trace on 2026-10-13. Fixed the missing outer array closing bracket in the monthly metric loop. The subsequent user screenshot confirms successful server rendering after the fix. The same request took about 12 seconds with 9,657 queries (mostly cached); performance needs separate investigation after rendering is restored.

- Performance Section 1 was deployed by the user; its first supplied full-request trace failed during template compilation as described above. The subsequent user screenshot confirms rendering and internally consistent displayed totals; historical calculations remain unverified. Local Ruby is unavailable, so its new tests remain unexecuted. Missing Extra Tasks rules leave cumulative targets unconfigured; monthly averages now use a fixed three-completed-month window; targets require User target-field setup. See [setup](performance-setup.md) and [Hadi questions](performance-hadi-questions.md).

- Meeting wording “more than X” differs from implemented inclusive minimum (default 3). Confirm whether to retain this threshold/wording.
- Complexity Weight tooltip specifies 5, 8, 13, 21; plugin accepts any positive finite parsed weight. Confirm whether strict plugin-side validation is wanted.
- “Separate table” became a report view over journals, not database storage. Confirm only if persistence was intended; no schema change is planned.

The old README's Redmine 4/Ruby 2.6 requirements, four-counter statement, status aliases, and duration list were inconsistent with current code. The README now links to maintained guidance. `init.rb` requires Redmine 6.0+; controller constants define current mappings. No new Ruby minimum or database guarantee is inferred.

Future return alarms are documented in [reporting rules](reporting-rules.md); restart/log instructions are maintained in [deployment](deployment.md).

- User confirmed the memory fix runs without error and much faster; peak memory and concurrent-load behavior remain unmeasured. Project inheritance is now implemented locally for all descendant levels and visible project members, with a Project drill-down column; deployment verification is pending.

- Hadi's Open Tickets feedback implemented locally: Not Touched now requires no In Progress evidence by report date; other development stages no longer imply Started. Stopped (now Pending only, superseding the earlier On-Hold/Pending rule) appears below Total Open Tickets with a drill-down while remaining in the existing groups. Server calculation/layout verification pending.

- Hadi resolved Extra Tasks: use one shared 90% delivery target for now. Implemented configurable Delivery Target (%) with numeric 0–100 validation for both delivery indicators. Prior notes about an unconfigured Extra Tasks target are superseded. Server settings-save/render verification is pending.

- Active-users-only filtering applies to both Performance dropdown paths. Per user clarification, inactive owner saved report/drill-down links remain usable with normal visibility/permission checks; the extra activity-based block was removed. Server verification pending.

- Hadi's Section 2 exclusions implemented: Archived and Ongoing are removed from delivery populations using as-of status, including due denominators and drill-downs. Ongoing remains in Section 1. Unit coverage added; runtime/server verification pending.
Monthly Day 0 rules superseded on user approval: both metrics now use the three completed calendar months before the selected date’s month, divided by 3, with matching contributor links and displayed dates. Account creation/Start dates no longer affect the window; zero deliveries yields 0 for a single owner. Multi-owner monthly aggregation is now implemented as matching per-owner actual/target means; missing targets make that comparison unavailable. Ruby regression tests updated but not run locally; server verification pending.

- Performance drill-down project grouping and sortable headings implemented locally. Group totals span all pages, with page counts labelled. Runtime tests and deployed layout verification remain pending.

- Hadi's comparison-first layout implemented with an expanded collapsible table and multi-owner aggregate charts/drill-downs. Single batched history scan preserved. Multi-owner monthly averages/targets now use per-owner means on user instruction; the later monthly-window change now implements the three-completed-month proposal for single-owner monthly metrics. Runtime/server verification pending.

- Performance owner selector enhanced with searchable checkbox dropdown, selected-count summary, removable chips, select-all-filtered and clear controls. Native multi-select is the no-JavaScript fallback. JS syntax check passed; deployed keyboard/mobile/visual verification pending.

- Owner picker rendering confirmed by user screenshots for small and large selections. Added stable top alignment for date, owner trigger and Apply, allowing chips/errors to grow below. Narrow screens stack controls. Alignment change awaits deployed visual verification.

- Back to Performance now uses browser history for tracked same-tab report-to-drill-down navigation, including skipping sort/pagination entries. The normal report URL remains the fallback for direct visits/new tabs/blocked storage. JavaScript navigation tests pass; browser back-forward cache restoration and deployed behavior still require verification.

- Slow Performance scans optimized locally using SQL selected-owner candidates, owner-only dropdown discovery, safe metric due-date filters, two-field batch values with an override-aware visibility fallback, and skipped comparison calculations on details. Historical reassignment and blank owner handling remain exact. Runtime tests and measured server timings are pending; no claimed latency reduction yet.

- Performance Live Returns implemented locally after Hadi confirmed accumulated same-source-stage repeats and all four scope/layout decisions. Legacy lifetime counters are unchanged. Missing/hidden reason history makes adjusted ratio unavailable; no current-value-only merge exclusion is silently assumed. Unit/functional coverage added but not run without local Ruby. UI, full-request behavior, installed-plugin compatibility and memory measurements remain server verification work.

- Hadi confirmed Ongoing inclusion in Returns to align the denominator with Tickets. Both now share OPEN_EXCLUDED_STATUSES (New/On-Hold), with closed statuses excluded separately. Updated tooltips and regression coverage for open totals, zero-return buckets, prior return history and both ratios. Code implemented locally; deployed totals/ratios await verification. Earlier Returns-specific Ongoing exclusion is superseded.

- Hadi's Returns comparison readability feedback implemented: equal compact bucket columns, abbreviated 3+/2+ headers with explicit threshold tooltips, stronger group outlines and vertical cell dividers through owner/Total rows. Counts and links unchanged; deployed desktop/narrow-screen visual verification pending.

- Returns distribution tables now enforce consistent borders on all cells, including Total-row vertical dividers and identical footer backgrounds/outlines. CSS change implemented locally; deployed visual verification pending.

- Returns comparison table final columns changed to total incident count and raw incidents/open-ticket ratio, both including Merge Conflict. The lower adjusted ratio card is unchanged. Local implementation; deployed verification pending.

- Narrowed Returns comparison final columns to 10% (Total Return Incidents) and 14% (incident/open-ticket ratio), with wrapping full headings. Freed width goes to owner/open and equal bucket columns; widths total 100%. Existing borders, right-aligned values and sorting links retained. Deployed visual verification pending.

- Returns comparison readability refined: thin light horizontal rules, stronger vertical group dividers, a subtle double line only above Total, centered integer counts, left-aligned names, right-aligned percentages, regular body values and bold blue Total row. Added row padding and subtle alternating owner rows. Local CSS change; deployed visual verification pending.

- Returns comparison header/body separator now matches distribution tables (1px #b8c8db), including two-row-spanning headers. Other horizontal rules remain light; Total retains its double separator. Deployed visual verification pending.

- Added a shared consecutive-return definition tooltip to the Returns comparison heading, distribution heading and drill-down column. Uses the user's approved concise wording explaining same-stage repeats and accumulation, with Feedback → Feedback → Final Check → Final Check = 2 as the example. Detailed workflow rules remain in Calculation notes. Deployed tooltip verification pending.

- Returns Section 3 now includes both ratios over the preceding three completed month-end snapshots, with hover counts, a monthly-values table and gaps for unavailable values. It reuses the batched scan and historical events; three extra in-memory snapshots per candidate still add CPU work. Unit/request coverage added; local Ruby/host Redmine are unavailable, so tests, full web rendering, deployed visual verification and before/after latency/memory measurement remain pending.

- Returns comparison row fills now explicitly cover both header and data cells: odd developer rows white, even rows very light blue. This overrides the host's gray Ticket Owner row-header background; the Total footer remains blue and bold. CSS change implemented locally; deployed visual verification pending.
