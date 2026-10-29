# Known issues and evidence

Live owner-time comparison added below Area 3, with independent 90% default PM
estimate share setting. Uses each ticket's current owner's booked hours only,
with active balance/SV and active/Ongoing/Archived reconciliation. Model coverage
added; Ruby/test Redmine runtime, query performance, permissions and desktop/mobile
rendering remain unverified. Existing all-contributor Area 3 is retained.

Spent breakdown labels now read “on Active tickets”, “on Ongoing tickets” and
“on Archived tickets” to clarify ticket-based hours. The narrow-layout sum wording
also refers to time on tickets. Calculations unchanged; deployed layout verification
pending for the longer labels.

Spent-summary alignment: the user screenshot confirms the brace renders. The
total now aligns to the top of the summary row, matching the other cards' main
values; the equals sign and brace retain their alignment with the breakdown.
Implemented locally; deployed alignment verification pending.

Live Time spent summary now uses an equals sign and a subtle brace spanning the
three categories instead of the vertical divider. Narrow layouts show the total
above the categories with “Total = Active + Ongoing + Archived” below. Decorative
symbols are hidden from assistive technology. Calculations unchanged; implemented
locally, deployed visual verification pending.

Live Time spent card layout: total is on the left, Active/Ongoing/Archived detail
on the right with a light divider, aligned numeric hours and muted zero rows.
Narrow cards stack detail below the total. Calculation and permission disclosure
are unchanged. Implemented locally; deployed visual verification pending.

Live Time Area 3: added active/Ongoing/Archived spent-hour reconciliation, active-only
PM estimate/balance/SV contributor sets, explicit labels and actual/planned/estimate
bar order. Archived hours now enter the displayed spent total only. Regression
tests added; Ruby/host runtime and deployed visuals remain unverified.

Live Time age-distribution tables now add 8px spacing on both sides of their
colored markers, separating circles from age labels in both normal and priority
tables. Implemented locally; deployed visual verification pending.

Returns alignment follow-up: a later last-child CSS rule overrode the earlier
centering fix. Removed that right-alignment override so the last ratio column
inherits the same centered alignment as all other numeric cells, including Total.
Implemented locally; deployed visual verification pending.

Live Returns Return Types: initially collapsed owner/team table added after the
leaderboard and before Combined Results, using existing open-ticket event sets.
Includes R1–R5 tooltips, returned/open percentage and tied top incident reasons;
omits Rework Time. Regression coverage added; Ruby/host Redmine tests and deployed
visual verification remain pending.

## V5 Part 4 — local implementation, 2026-10-28

The remaining six Time answers are incorporated; see the current
[Time spec](periodic-time-spec.md). The 90% ratio is tentative and configurable.
Trend presentation is provisionally accepted pending joint deployed review.
Activity visibility shows recorded effort, not proof of logging compliance. The
archive/replace policy is operational; this change does not enforce it in editing.
Ruby tests and deployed layout, full requests, source totals and performance remain
unverified. Earlier dated notes below retain historical implementation states.

## Periodic owner-trend legend — local change, 2026-10-28

Tickets/Complexity Weight owner charts now reuse the Live/Time selectable right
legend, with paired Expected/Completed groups and a short line-style key. Existing
responsive styles place the legend below on narrow screens. Breakdown values and
report calculations are unchanged. Eleven JavaScript checks and diff checks pass;
updated Ruby request assertions and deployed visual/request checks remain pending.

## Part 3 Time additions — local implementation, 2026-10-28

Reviewed Time formulas are retained, with new activity/user evidence and archived
paid-effort disclosure. Personal total/daily hours now include separately classified
Archived and On-Hold/Ongoing effort; delivery and expected efficiency still exclude
these tickets. Main selected-user, all-contributor expected-package, and archived
owner-ticket scopes overlap and are not summed. Tracker/owner/user observations
support calibration, not automatic target changes. [Time specification](periodic-time-spec.md)
supersedes older status-excluded personal total and four-category statements below.

Development mapping is an optional existing-activity ID selection; no mapping is
guessed. Without it, development ratios are N/A and all raw activity shares remain
available. The 90% working estimate is not a new default. The operating policy to
archive/replace on necessary owner change is documented but not enforced by field
patches or automatic ticket creation. Current owner-change diagnostics are not a
log-creation sequencing audit. No schema/native-event/field changes.

Trend definitions were not explicitly confirmed in Part 3; plain completion versus
work-date labels/examples are added to the same page, with owner details collapsed
for executive reading. Presentation still needs review after deployment. Ruby
unit/loader/settings/helper/request tests are added/updated but unrun locally;
eleven JavaScript checks and diff checks pass. New panels, source-data, installed-
plugin requests/layout and performance are not server-verified. Period activity
aggregation retains all contributors needed for expected/archived packages and can
grow with issue/user/activity/day combinations; measure memory and latency.

## Part 2 Returns applied locally — 2026-10-28

Confirmed answers and the user's N/A clarification are implemented. Non-Merge
uses known non-merge incidents / ALL returned tickets, including merge-only
tickets, on Live and Periodic populations. No percentage multiplier/all-open
denominator remains. Cards, owner/team comparisons, trends and numerator/
denominator/unknown-reason audits share the formula. Full through-RED history and
completion cohorts are confirmed. Archived/on-hold history has a separate list
including later-reactivated tickets. [Current Returns rules](periodic-returns-spec.md)
supersede older provisional/legacy statements below; Time remains provisional.

Empty returned populations show N/A (not applicable) with 0 counts; known zero
non-Merge incidents among returned tickets show 0. Missing/hidden reasons remain
unavailable. Live consecutive populations remain open at the selected date;
Periodic lagging populations remain completed expected tickets. Native counters
are unchanged. Eleven JavaScript checks and diff checks pass locally. Ruby model/
helper/request tests are unrun without Ruby/test Redmine. Full request, deployed
visual/source-data/performance verification is pending; no server evidence yet
confirms these revisions. No new migrations/fields/counters/settings.

## Hadi Part 1 confirmed and applied locally — 2026-10-28

Confirmed source: Q&A Part 1.docx plus the user's follow-up answers. Tickets now
uses latest current-owner To-Do, mandatory hotfix deadlines, current exclusions
and current-Done delivery checks. Extraordinary/current-status and missing-data
audits explain changes to past results. New scheduled-work review subsets and
per-owner Other Done Extra/Unplanned are distinct from logged Other Work. Returns
and Time inherit corrected populations. PMO RSD debt/delivery boundaries align
with Hadi's explicit request. [Current rules](periodic-tickets-spec.md) supersede
older assumptions below; Returns/Time-specific questions remain open.

Eleven JavaScript checks pass; diff whitespace checks pass. Ruby is unavailable,
so added/updated Ruby history/model/request and PMO tests are unrun. Full requests,
source-data reconciliation and deployed visuals/performance remain pending.
The user supplied a Periodic Time screenshot too: it confirms rendering and
displayed arithmetic, not source-ticket/time-entry correctness. None of the new
Part 1 revisions are server-confirmed. No fields/counters/native events changed.

Extraordinary detection covers recorded owner/due edits, repeated To-Do and
reopening; it cannot infer unspecified or missing irregular activities. Later
history is retained for those diagnostics, increasing report work: batch bounds
alone do not prove safe memory or latency. Missing initial To-Do journals remain
missing evidence; they are not reconstructed from creation timestamps.

## Periodic Time — local implementation, 2026-10-28

All three Periodic sections are now implemented provisionally. Time adds eight
metrics, optional blank targets/share, owner/team comparisons, paired coverage,
personal-hour reconciliation including unfinished work, completion/work-date
trends and contributor lists. Booked users (`TimeEntry.user_id`) determine
personal time; entry creators and ticket reassignment do not transfer it. See
[Time specification](periodic-time-spec.md) for Hadi-pending rules, especially
calendar DTC, lifetime ticket cost, share denominator, Extra Work and CW/h A−P.
Older Time Planned statements below are superseded.

Eleven JavaScript navigation/legend checks pass locally. Added Ruby model/entry/
settings/helper/request tests are unrun: Ruby and a configured test Redmine are
unavailable here. Full requests, deployed Time layout, source-data reconciliation
and measured memory/latency remain pending. Batch scans alone do not establish
safe report performance. Time totals intentionally omit unlinked/excluded/outside
hierarchy entries; partial visibility limits comparison with full capacity.

User screenshots confirm Tickets and Returns page rendering and displayed
arithmetic, not source-ticket eligibility. The revised Live metric and Periodic
Time have no user-confirmed server verification yet. No schema/data changes.

## Periodic Returns and revised Live metric — 2026-10-28

Implemented locally on user authorization: Periodic Returns with exact Tickets
completed populations, collapsed owner/team tables, primary/total-done metrics,
correct return/repeat distributions, completion-cohort team/owner trends and
new-tab audited contributor lists. Live's primary metric is now incidents per
returned open ticket, without percentage units or old threshold lines. The prior
non-Merge percentage remains separately labelled legacy. Actual configured
`Merge / Integration Conflict` reasons are now recognized for audits and that
legacy exclusion measure. Primary incidents remain unchanged by reason handling.
See [the specification](periodic-returns-spec.md) for provisional event timing,
cohort interpretation and N/A choices awaiting Hadi.

Ruby model/history/helper/request tests were added/updated but are not run locally
because Ruby and test Redmine are unavailable. Ten JavaScript navigation/legend
tests pass, including keeping the team line visible while hiding all individual
owners. Full requests, data checks, deployed layout and measured performance are
pending. A user screenshot previously confirmed Periodic Tickets page rendering
and displayed arithmetic, not ticket-level eligibility. Earlier statements that
both Periodic Returns and Time are Planned are superseded; Time remains Planned.

## Periodic Tickets — provisional implementation, 2026-10-27

User-authorized provisional Tickets calculations, collapsed summary/owner/team
tables, KPI flow, comparison/completion/debt charts, individual/team period trends
and new-tab contributor lists are implemented locally. Ranges and owners survive
section navigation/Apply; Live retains its separate As of Date. Periodic
Returns/Time remain Planned. See [the specification](periodic-tickets-spec.md)
for the exact assumptions awaiting Hadi, including status exclusion removal and
unverified completion treatment. This supersedes earlier disabled/Planned
Tickets statements. Unit/history/helper/request tests were added but Ruby/test
Redmine are unavailable locally; those tests, full web requests, deployed layout
and measured performance remain unverified. Initial navigation still avoids
scans; Apply retains compact selected-owner rows and performs per-owner/trend
calculations, so batch bounds alone do not establish safe production memory or
latency. No schema changes.

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

- Returns comparison developer rows now highlight every cell pale yellow (#fff8dc) on hover. The rule applies only to the table body, preserving the blue Total footer. Deployed hover verification pending.

- Both Returns ratio cards now use shared green/orange/red thresholds (<10%, 10%-50% inclusive, >50%) and gray for N/A, with a shared legend. Thresholds use unrounded ratios. Helper boundary tests added but not run without local Ruby; deployed color/contrast verification pending.

- User screenshot confirms both 31.3% cards use orange as intended. The orange legend marker was oversized; replaced generic warning/negative/unavailable marker classes with plugin-specific names to avoid host style collisions. Marker fix awaits deployed visual verification.

- Consecutive-return donut center now reads Tickets with Consecutive Returns instead of With Repeats, with constrained centered wrapping inside the donut. Deployed visual verification pending.

- Tickets delivery-ratio trend implemented below Section 2, using three completed month-end snapshots, count/weight lines and the configured target. Shared due/exclusion rules and batched history are reused. Unit/request/geometry tests added but unrun without local Ruby/Redmine. Full web rendering, deployed visuals and latency/memory impact remain unverified.

- Both Tickets and Returns trends now use five completed months, superseding earlier three-month trend notes. Dates share TREND_MONTHS=5, graph points/labels are evenly spaced dynamically, and owner-history loading extends to the first month-end in the same batched scan. Monthly output averages remain three months. Date/geometry/request coverage updated; Ruby tests and deployed visual/timing/memory checks remain pending.

- Tickets now shows delivery ratios on the left and two stacked rolling monthly-output charts on the right. Five month-end points each use a 3-month average, with per-owner means and current monthly targets; snapshots/scans are reused. Expanded values table includes windows/totals/missing completions. Unit/request/geometry coverage added but not run without Ruby/host Redmine; deployed visual and performance checks pending.

- Monthly output charts now show each month's actual deliveries (per owner for multiple selection), superseding rolling trend averages; upper 3-month cards are unchanged. Added a conditional distinct-ticket owner-change note and paginated audit of selected-owner changes within the five full months. Owner history expands to the first month's start in the same scan. Unit/request tests updated but unrun without Ruby/host Redmine. Deployed calculations, audit visibility/navigation, layout and performance remain unverified.

- User screenshot confirms owner-change audit renders but its owner selector fell back to native multi-select. Added the missing shared performance_owner_picker script on that page. Deployed searchable-picker/chip verification pending.

- Owner-change note/audit now exclude initial No owner to owner assignments, including bulk ownership backfills. Existing-owner reassignments and removals still count. Tooltip/audit wording and blank/nil regression cases updated. Local Ruby tests and deployed count verification pending.

- Monthly delivery trend table headings now explicitly distinguish Total Delivered Tickets/Points from Avg. Delivered Tickets/Points per Owner, including single-owner reports. Labels only; deployed visual verification pending.

- Hadi-confirmed current Ticket Owner attribution implemented for Performance cards/trends/Returns/drill-downs, PMO RSD/RED commitments/debt/delivery/activity/returns/rework and Status Snapshot. Historical ownership no longer controls metric attribution; current blank stays unassigned. PMO adds a report-period change audit; Performance audit remains. Recorded journal/time users are unchanged, but ticket activity/time aggregates follow current owner. Labels/tooltips and regression coverage updated; Ruby tests, full web/installed-plugin and server performance verification remain pending.

- Audit availability extended: Tickets and Returns always show owner-change count/link after Apply, including zero; Performance drill-down headers and shared PMO navigation link to the audit. PMO Ticket Owner Performance retains an expandable zero-change state. Returns audit routing/back/pagination preserves its tab. Existing five-month/PMO-period scopes and initial-assignment exclusion stay unchanged. Request tests updated; Ruby tests and deployed verification pending.

- Multi-owner Leaderboards implemented after comparison tables on Tickets/Returns, with team heading renamed. Tickets shows actual monthly delivered points per individual; Returns shows individual raw return ratios including Merge Conflict. Stable owner colors, toggleable legend, hover counts and an expandable values table reuse current-owner snapshot/event aggregates without extra scans. JavaScript tests pass; Ruby/request tests, deployed visuals and latency/memory validation remain pending.

- Leaderboard owner legend now sits vertically to the right of the chart on both tabs, stacking below on narrow screens. Long names wrap and large selections scroll within the legend. Existing hide/show buttons and colors are unchanged. Deployed layout/keyboard verification pending.

- Leaderboard target lines implemented: Tickets uses individual current monthly point targets with matching owner colors, grouped hide/show, legend/table values and missing-target notes. Returns uses shared 10%/50% thresholds. Scales include reference lines and target lookups reuse existing permission checks. Four JS tests pass; Ruby target/threshold request tests added but unrun locally; deployed visual/permission verification pending.

- User screenshot shows two-line owner/target legend text overflowing the host-sized buttons. Set automatic button height, a 52px minimum, explicit line height and block label to contain wrapped text. Deployed visual verification pending.

- Leaderboard point targets now deduplicate by numeric value into thin gray dashed lines; target visibility follows whether any associated owner remains visible. Legend target values are small muted parentheses and the diagram title is bold. Four JavaScript tests pass, including shared-target hide/restore; Ruby equal/missing-target request checks updated but unrun. Deployed visual verification pending.

- Team monthly delivery trend headings/subtitle now say average of selected owners for multi-owner reports, replacing the less explicit per owner wording. Calculations and single-owner labels are unchanged. Deployed visual verification pending.

- Replaced ID-hashed leaderboard hues after a screenshot showed near-identical brown lines. Selected owners now get distinct qualitative palette slots, consistent across both tabs and row sorting for the same selection, with extra hues beyond 12 owners. Targets/10%-50% thresholds and calculations are unchanged. Helper coverage added but Ruby tests unrun locally; deployed visual verification pending.

- Tightened Leaderboard vertical axes to reduce excess headroom using nearby readable ceilings and adaptive tick counts. No hard cap: all data and targets remain included. Helper coverage added for 300/125% examples, high targets/future data and empty ratios; Ruby tests unrun locally and deployed visual verification pending.


- Performance Live Time and configurable calendar/thresholds implemented locally after Hadi's three Q&A rounds and user approval. Includes working-day age, Priority/Immediate lists, visible direct time, paired estimate balance/SV with linked insufficiency reviews and five monthly completed-ticket points/hour values. Current owner/schedule/settings apply to past dates. Earlier notes calling Live Time Planned are superseded; Periodic Time remains Planned. No migrations/fields/counters added. Existing JS navigation/leaderboard suite passes (8 tests); new Ruby calculation/settings/entry/request tests are unrun without Ruby and a test Redmine host. Full requests, installed-plugin compatibility, settings-save/permission behavior, deployed layout, and latency/memory remain unverified.

- User screenshot confirms Live Time renders. Added a prominent missing-estimate hours explanation to reconcile overall visible spent versus Estimate Balance contributors, plus explicit ticket counts/missing-or-future-start explanations for empty age distributions and a Priority-only exclusion link. Report formulas remain unchanged. Ruby regression coverage added but unrun locally; deployed visual verification of these clarifications is pending.

- Performance drill-down links now open a new browser tab across Tickets/Returns/Time, including numeric comparisons, card/chart links, exclusions, monthly productivity lists and owner-change audits. Shared link helper preserves URLs/classes and adds target="_blank", rel="noopener" and a new-tab tooltip. Existing navigation script already skips these links, so filters/sorts/pagination and new-tab Back behavior remain native. Nine JavaScript tests pass including new-tab dashboard-history isolation; deployed browser and Ruby-render verification remain pending.

Returns comparison last-column presentation: heading now reads Incidents (excl. merge conflicts) / Returned Open Tickets. The linked returned-ticket count uses the same block-level second-line styling as the preceding ratio column, including the Total row. Calculations are unchanged. Implemented locally; deployed visual verification pending.

Returns individual-owner trend direction now shows a bold dark-green “↓ Lower is better” badge on a pale green background. Removed the confusing sentence about old percentage thresholds from this chart. Calculations are unchanged. Implemented locally; deployed visual verification pending.

User screenshot confirms the updated Returns heading and second-line denominator render, but the last column remains right-aligned. Both final ratio columns now explicitly center their values and denominator lines for owner rows and Total. Implemented locally; deployed alignment verification pending.

Combined Results for selected owners (team) now uses a shared light-blue heading banner with dark bold text and a blue left accent on Tickets, Returns and Time. Implemented locally; deployed visual verification pending.
