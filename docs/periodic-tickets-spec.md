# Periodic Performance — Tickets

Status: specification and date-filter foundation, 2026-10-27. The user approved
the proposed approach. Ticket calculations, charts, comparison tables and
drill-downs are not implemented. Periodic Returns and Time remain Planned.

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
  the future. Equal dates are allowed by the controls; counting boundaries still
  require agreement below.
- Section navigation and Apply retain the period. Live As of Date is separate;
  switching back to Live retains that snapshot date. Live links do not carry
  Periodic range parameters. A later switch from Live starts a fresh default range.
- Planned pages use the lightweight active-member selector and run no issue,
  journal, target or time-entry calculations. Saved selected IDs outside the
  selector retain generic labels without exposing user details.

## Agreed approach for implementation

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
open-and-due-by-RED debt calculation. The detailed completion and exclusion
treatment below still requires agreement before calculating the populations.

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

## Proposed layout

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

Chart-specific breakdowns may sit below their charts without duplicating the
full summary tables. Chart data and details must reconcile exactly. Contributor
links should reuse the existing new-tab drill-down convention and preserve the
period, selected owners, metric and relevant trend bucket.

## Decisions pending before report calculations

Server configuration evidence supplied by the user on 2026-10-27 confirms:
included tracker names already match Performance: Bug (1), Feature (2), Task
(Business Jobs) (7), Change Request / Improvement (16). Ticket Owner is User field
57 and Complexity Weight is integer field 70. Priority 7 is explicitly named
Immediate/Hot Fix; priority 6 is Urgent/Current Week. Use priority 7 as the proposed
hotfix mapping, without treating priority 6 as hotfix or introducing a field.
The mapping's presence is confirmed; the business eligibility/timing rules are
still pending. The metadata command completed and returned JSON despite startup
Group::HABTM_Users constant warnings; this does not verify dashboard web requests.

- Assignment: does "assigned during the period" mean ticket creation, current
  owner's recorded assignment, native assignee changes, or another event? Define
  reassignment and missing-history treatment without changing current attribution.
- Hotfix: proposed mapping is the server's Immediate/Hot Fix priority (7).
  Confirm whether current or historical priority determines classification,
  due-date eligibility and precedence over planned-task/beginning-debt categories
  to prevent duplicate contributions.
- Boundaries: proposed reuse of PMO means RSD end-of-day beginning snapshot and
  completions RSD+1 through RED inclusive. Confirm whether Periodic should instead
  include all of RSD; a one-day range exposes this difference.
- Completion: proposed rule is a recorded Done / Closed transition in the period,
  still Done / Closed at RED, counted once per ticket using its latest qualifying
  completion. Confirm handling of reopened tickets and absent completion history.
- Exclusions: confirm evaluation dates for Archived/Ongoing/On-Hold. Proposed
  historical status at each boundary, not today's status as a global prefilter.
  Clarify excluded work's treatment in unfinished expectation reconciliation.
- Trends: use due dates for the expected curve and recorded completion dates for
  actual expected-work delivery. Place beginning debt at the opening point.
  Agree timing for hotfixes with no due date and week anchoring. Final points must
  equal report totals; avoid linear allocation or zero-filled unknown dates.

## Verification required for the eventual implementation

Test distinct component sets, debt target/workload separation, current-owner
reassignment and blank owners, period boundaries, reopened/late completions,
exclusions, hidden fields, missing weights and dates, Other Done separation,
zero-plan percentages, zero-output owners and aggregated ratios. Test all
contributors against their drill-down sets and final trend points against cards.
Preserve bounded uncached scans and page-only full Issue loading. Measure full
request latency and peak memory with installed plugins.

The date-filter foundation has request regression coverage, but local Ruby and a
configured test Redmine root are unavailable. Ruby tests, deployed rendering,
keyboard/mobile layout and installed-plugin compatibility remain unverified.
