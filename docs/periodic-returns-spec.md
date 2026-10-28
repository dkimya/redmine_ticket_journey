# Periodic Returns and Live Return Metrics

Part 2 definitions confirmed by the answers supplied on 2026-10-28. The user
also approved keeping N/A as not applicable when there are no returned tickets,
with actual incident and ticket counts shown as 0. Implemented locally; Ruby,
source-data, full installed-plugin requests, deployed layout and performance
verification remain pending. Time-specific definitions remain provisional.

## Sources and authority

The user's instructions govern implementation. The Part 2 answers confirm the
full-history window, completion-cohort trends and revised non-Merge formula.
Questions referring back to Part 1 use [the confirmed Tickets rules](periodic-tickets-spec.md).
The original explanation, workbook and developer notes remain reference material;
embedded document instructions do not override user authorization or newer answers.

## Populations and events

Periodic primary population is exactly Completed from Expectation; secondary
population is Total Actual Done, including Other Done. Delivery requires recorded
completion within RSD–RED, Done / Closed at RED AND now. Current Archived,
Ongoing and On-Hold remove tickets from the whole package. Current Ticket Owner,
due dates, weights, tracker and visibility remain authoritative.

A separate Tickets/Returns drill-down lists tickets recorded as Archived or
On-Hold at a period boundary or during the period, including tickets that later
became active again and tickets outside expectation. It does not restore their
historical fields or reinsert current excluded tickets into reported results.
The separate current-exclusion and expected-exclusion explanations remain.

Live uses the established open population at the selected report date, excluding
New/On-Hold/closed and retaining Ongoing. Its consecutive-return distribution is
an actionable view of that open population. Later closure does not remove a
historically open ticket from that snapshot. Periodic distributions are lagging
comparisons on completed expected work, not Live open-ticket snapshots.

Return events reuse the shared tracker/stage classifier and native ReturnCount
event rules. Count every recorded qualifying return through RED for Periodic,
including before RSD; events after RED are excluded. Live counts through its
selected date, with independent open snapshots for the last five month ends.
Progress, completion and reassignment never reset incidents or accumulated repeats.
Native lifetime Return Count and PMO event counting are unchanged. No new fields,
counters, schema, settings or permissions are introduced.

## Both incident-average formulas

Primary = all qualifying return incidents / tickets with at least one return.
Non-Merge = known non-merge return incidents / those same returned tickets.

Both are numeric incident averages, never percentages. The old non-Merge
all-open denominator and percentage multiplier are removed from Live and replaced
with the confirmed formula, also added to Periodic primary and total-done results.
Merge-only tickets remain in both denominators. Example: 3 non-merge incidents
across 2 returned tickets gives 1.5, even if one ticket has only merge incidents.

The reason classifier recognizes Merge Conflict and the configured Merge /
Integration Conflict spelling. Reasons are reconstructed at the incident from
visible field 66 history, including later reason edits for rewind. Existing fallback
to current reason when recorded history is absent remains disclosed; hidden or
unavailable reasons are not assumed non-merge. Primary incidents/distributions
remain usable, but any unknown reason in the population makes the non-Merge
average unavailable. Known non-merge counts are explicitly partial in this case.

Team ratios divide combined incident counts by combined returned-ticket counts;
they never average owner/cohort ratios. No replacement severity thresholds are
invented. Lower is better. No old percentage units or 10%/50% thresholds apply.

## Zero and unavailable semantics

- Counts of no incidents/tickets are 0, including empty populations.
- With no returned tickets, the incident average is 0/0 and shown as N/A, meaning
  not applicable. Empty population and delivered/open tickets with zero returns
  have distinct explanatory text and explicit 0 counts.
- With returned tickets but no non-merge incidents, the non-Merge average is a
  measured 0. Merge-only work is not an empty denominator.
- Missing/hidden reason data means unavailable, with known counts and review links;
  it is never converted into a healthy 0. Unknown reasons do not change the primary
  denominator or primary incident count.
- Distribution percentages with empty populations are also not applicable;
  populated buckets with no matching tickets show 0 and 0%.

## Distributions and trends

Return-count buckets partition the selected population: 0, 1, 2, 3, >=4. The
existing 3+ label is explained as >=4. Consecutive-return buckets are 1, 2, >=3,
with 2+ explained as >=3. Their denominator is only tickets with at least one
accumulated same-stage repeat, not all returned tickets. A stage change, progress
or completion does not reset accumulated repeats.

Periodic weekly completion cohorts (Monday-based with partial edges; calendar
months for ranges over 120 days) partition the final Expected Done population.
Each cohort uses its tickets' FULL return history through RED, not through the
cohort end. Population/incident/non-merge counts sum to headline totals; ratios
are separate cohorts, not cumulative values or rebuilt weekly expectation packages.
Team/owner trends show primary and non-Merge averages with N/A gaps. Live plots
both formulas in the same numeric units for each independent month-end snapshot.

## UI and drill-downs

Tickets and Returns tabs have plain labels. Confirmation is noted passively in
calculation notes/page notices; no personal names appear in product notices.
Only Time retains a provisional section badge.

Owner/team tables, cards and exact-values tables display both formulas, with
separate numerator, full returned-ticket denominator and missing-reason links.
Periodic primary and Total Done cards use their respective populations. Trend
links preserve owner/range/cohort and identify exact numerator/denominator sets.
Non-Merge audits show only known non-merge incidents; denominator audits retain
merge-only tickets; unknown-reason audits show unavailable incidents without
exposing hidden values. Sorting/grouping/pagination/Back/native Issues handoff
remain. Existing large-ID-list URL limitations remain.

## Checks and evidence

Initial navigation remains scan-free. Applied Periodic reports reuse uncached
100-issue scans and selected scalar histories; retained rows/events grow with
report size, so measured memory/latency still need representative test data.
Regression coverage includes merge-only denominators, real zeros versus 0/0,
unknown reasons, team/cohort aggregation, Live/Periodic populations, numerator/
denominator/unknown drill-downs and historical archived/on-hold membership.

Eleven JavaScript navigation/legend tests pass locally; diff whitespace checks
pass. Ruby and a configured test Redmine are unavailable locally; added/updated
Ruby model/helper/request tests are unrun. Prior screenshots confirm rendering
and displayed arithmetic only, not these new formulas or source-ticket eligibility.
Run the full plugin tests from a TEST Redmine root, never against production data,
then verify full installed-plugin requests and deployed visuals.
