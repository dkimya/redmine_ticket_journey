# Periodic Performance — Tickets

Status: implemented locally with provisional defaults, 2026-10-27. The user
explicitly authorized implementation of the recommendations while awaiting Hadi.
This authorization is not Hadi's confirmation of each business definition.
Tickets calculations, charts, comparison tables and drill-downs are implemented;
Periodic Returns and Time remain Planned. Runtime/deployment verification is pending.

## Sources and precedence

The user's instructions govern the work. Hadi's explanation RTF supplies the
business intent; Periodic Dashboard_Tables.xlsx supplies metric labels and
deviation directions; the developer TXT supplies supporting implementation
ideas. The two PNG designs are overview references, not exact specifications.
Conflicts between sources are recorded rather than silently resolved by a formula
or sample number. Existing confirmed policies in reporting-rules.md remain in
force unless explicitly changed.

## Implemented foundation

- Periodic sections accept Report Start Date (`rsd`), Report End Date (`red`) and
  the existing multiple-owner selection under the Performance permission.
- Dates default to the month containing the retained Live As of Date, through
  that date. An explicit RED without RSD defaults RSD to RED's first day of month.
- Dates must parse as ISO dates, RSD must be on/before RED, and RED cannot be in
  the future. Equal dates are valid, including same-day completions.
- Section navigation and Apply retain the period. Live As of Date is separate;
  switching back to Live retains that snapshot date. Live links do not carry
  Periodic range parameters. A later switch from Live starts a fresh default range.
- Initial Tickets and all Planned pages use the lightweight active-member
  selector without issue/history scans. Tickets Apply performs an uncached
  100-issue batch scan with visible owner/weight values. Only selected owners'
  scalar histories are queried and compact report rows retained. Inactive saved
  owner links work only for owners discoverable from visible in-scope tickets.
  Full Issue objects are loaded only for the 100-row detail page. No time or
  employee-target scan is added. Selected-owner retained memory still grows with
  ticket count, and repeated owner/trend calculations add CPU work.

## Implemented calculation approach

Use current Ticket Owner #57, current due dates and current visible Complexity
Weight #70, including historical reruns. A blank current owner remains unassigned.
Reconstruct status and recorded completion dates from history. Do not implement
TXT section 23's historical owner/due-date/weight policy. Preserve current tracker
mappings, visible project hierarchy, issue and field permissions. Verify actual
tracker names against the existing Performance mapping before adding aliases.

Each metric owns a distinct ticket contributor set reused by counts, weights,
charts, tables and drill-downs. Missing/hidden/unusable weights contribute no
points and must have visible coverage notes. Missing data is not a real zero.
No new custom fields, counters or migrations are currently proposed.

Expected workload is the distinct, non-overlapping union of beginning-debt work,
planned assigned tasks and assigned hotfixes. Completed from Expectation is the
qualifying completed subset. Other Done is qualifying completed work outside
that union. Total Actual Done is their distinct union.

Debt at RED is the unfinished subset of the expectation package at RED, confirmed
by the user on 2026-10-27. Still Open Now is the currently open subset of that
Debt-at-RED population. Tickets outside the expectation package cannot enter
either debt metric. This Periodic definition does not change PMO's existing
open-and-due-by-RED debt calculation. Expected tickets without valid period
completion evidence remain unresolved in debt, even when their RED status is
Done; missing completion history is explicitly disclosed and drill-downable.
This evidence treatment is provisional and awaits Hadi's review.

Beginning debt has two different uses: its undesirable balance has target zero,
but its ticket population contributes to expected workload. Do not sum the zero
debt target into the workload as the workbook's sample formula does.

Other Done never improves expected-work completion or deviation. Apply A-P to
expected-work completion and P-A to debt and Other Done, following the supplied
Tickets metric directions. Positive deviation is good, negative bad and zero
neutral. Divide deviation by a meaningful nonzero plan; otherwise percentage is
N/A. Team counts, weights and plan are sums of distinct contributors, with team
deviations calculated from those totals. Owner averages, if shown, are explicitly
separate from team totals. Live monthly per-owner averages remain unchanged.

## Implemented layout

1. Shared Performance navigation, title, RSD/RED and owner filters.
2. Collapsible summary tables near the beginning, following the RTF's explicit
   note about Ali's preference. Default collapsed. Single-owner tables separate
   ticket and weight results. Multiple-owner tables show actuals by owner, team
   plan/actual totals and owner deviations.
3. KPI flow: beginning debt + planned tasks + hotfixes = expected workload;
   completed expected work + Other Done = total actual done.
4. Expected/completed comparisons for tickets and weight, expected-work completion
   percentage, and end-debt/current-follow-up cards. Borrow V02's visual grouping
   and V01's owner comparison structure within the existing Performance styling.
5. Period expected/completed trends for tickets and weight. Multiple-owner mode
   also compares individual trends as requested in the RTF, not only team trends.

Chart-specific breakdowns sit below charts. Values and details share exact sets.
Contributor links use the existing new-tab convention and preserve period,
selected owners, metric and trend bucket. Details support sorting, optional
grouping, 100-row pagination and whole-set native Issues handoff. Detail columns
are fixed for the Periodic audit; the native Issues handoff has its usual column
options. Existing large-ID-list URL length limitations also apply here.

## Provisional defaults awaiting Hadi's review

Server configuration evidence supplied by the user on 2026-10-27 confirms:
included tracker names already match Performance: Bug (1), Feature (2), Task
(Business Jobs) (7), Change Request / Improvement (16). Ticket Owner is User field
57 and Complexity Weight is integer field 70. Priority 7 is explicitly named
Immediate/Hot Fix; priority 6 is Urgent/Current Week. The model matches the exact
current priority name Immediate/Hot Fix, without treating priority 6 as hotfix or
introducing a field. The mapping's presence is confirmed; its business use is
provisional. The metadata command completed and returned JSON despite startup
Group::HABTM_Users constant warnings; this does not verify dashboard web requests.

- Assignment uses the latest genuine recorded transition of Ticket Owner #57
  into the current owner on/before RED, including initial assignments. No-op edits
  do not count, and absent history has no creation-date fallback. Current owner
  still controls attribution regardless of the historical owner at RED.
- Beginning debt: open, eligible status immediately before RSD, with current due
  date before RSD. Planned tasks: current due within RSD–RED, including earlier
  assignments; exclude tickets already closed before RSD. Thus missing assignment
  history does not remove scheduled planned tasks.
- Hotfix: current named priority, recorded assignment during RSD–RED, and not
  closed before RSD. Qualifies with missing or out-of-period due date. Category
  precedence: beginning debt, then hotfix, then planned task. An in-period due
  date schedules a hotfix; otherwise its recorded assignment date does.
- Boundaries include all of RSD through RED. The opening snapshot is RSD−1 end
  of day. This intentionally differs from legacy PMO's RSD end-of-day convention
  without changing PMO calculations.
- Delivery requires Done / Closed at RED with latest recorded completion within
  the inclusive period. Each ticket counts once. Reopening before RED removes
  delivery; reopening after RED does not. Other Done uses the same delivery test
  outside the expectation package, independent of due date.
- Archived/Ongoing/On-Hold at RED remove tickets from the entire package, with a
  linked exclusion list. Beginning debt also checks opening eligibility. New is
  not excluded in Periodic. Current status is used only for Still Open Now,
  which remains a subset of Debt at RED.
- Trends use the final RED package, current due dates for expected work, and
  recorded completion dates for actual expected-work delivery. Opening debt is
  present at the opening point. Weekly points are Sunday ends (Monday-based
  weeks) plus the partial final period. Periods over 120 days use month ends.
  Individual-owner expected/actual lines use the same definitions. No linear
  allocation, owner-count division or averaged percentages are used.
- Missing completion evidence cannot improve delivery. Expected work with no
  qualifying completion remains unresolved in debt; missing records are shown
  separately for investigation. Other Done has zero plan and negative P−A
  deviation. Total Actual Done has a separate output deviation versus expected;
  it never changes expected-work deviation.

## Verification

Test distinct component sets, debt target/workload separation, current-owner
reassignment and blank owners, period boundaries, reopened/late completions,
exclusions, hidden fields, missing weights and dates, Other Done separation,
zero-plan percentages, zero-output owners and aggregated ratios. Test all
contributors against their drill-down sets and final trend points against cards.
Preserve bounded uncached scans and page-only full Issue loading. Measure full
request latency and peak memory with installed plugins.

Unit/history/helper/request coverage has been added for the provisional rules,
reconciliation, missing data, current attribution with historical status,
boundary dates, initial no-scan behavior, multi-owner links and details. Local
Ruby and a configured test Redmine root are unavailable, so this Ruby coverage
has not been executed. Deployed rendering, keyboard/mobile layout, full requests,
installed-plugin compatibility and measured latency/memory remain unverified.
