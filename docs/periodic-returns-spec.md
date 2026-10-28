# Periodic Returns and revised Live Return Ticket Metric

Implemented locally on user authorization, 2026-10-28. Business choices marked
provisional await Hadi's confirmation. Ruby/request, deployed visual and service
performance checks remain unverified. Periodic Time remains Planned.

## Sources and scope

Hadi's Returns RTF supplies business intent and explicitly requests the Live
denominator change too. The developer TXT supports the formulas, mutually
exclusive bucket boundaries and aggregate-first team metrics. The PNG is an
overview, not a source of production values. The user approved the recommendations
and corrections, including provisional choices below. No instructions embedded
in these references supersede the user's instructions or confirmed project rules.

## Periodic populations and return events

- Primary population is exactly Periodic Tickets' Completed from Expectation.
  Secondary population is exactly Total Actual Done (Expected + Other Done).
  Reuse TicketJourneyPeriodicTickets rather than rebuilding expectation here.
- Same current Ticket Owner, project hierarchy, issue/owner-field visibility,
  tracker mappings and reconstructed completion/status eligibility apply.
  Archived/Ongoing/On-Hold at RED are excluded, as in Periodic Tickets. Missing
  completion records cannot increase completed populations. Tickets' provisional
  eligibility choices remain provisional for Returns too.
- Qualifying return events and accumulated same-source-stage repeats reuse
  TicketJourneyPerformanceReturns.events_for and TicketJourney::ReturnCount.events.
  No new counters, migrations, fields, permissions or backfill are added. Native
  lifetime Return Count and PMO event rules are unchanged.
- Provisional timing: all recorded qualifying returns through RED for each
  completed ticket, including returns before RSD. This measures delivered-ticket
  return history, not incidents occurring only in the selected period. Progress,
  reassignment and completion do not reset totals. Events after RED are excluded.
- Merge Conflict stays in primary counts and distributions. Hidden/missing reasons
  do not remove incidents and are unavailable in the audit. Scalar reason history
  includes edits after RED so earlier reasons can be reconstructed without notes.
- Actual configured reason `Merge / Integration Conflict` is now recognized by
  the same shared classifier as `Merge Conflict`. Raw incident counts are
  unaffected; audit flags and the legacy non-Merge measure can be corrected.

## Metric and distributions

Return Ticket Metric = total incidents / tickets with at least one return.
Display an average incident count (8/5 = 1.6), never 160%. Lower is better; no
replacement severity thresholds are invented. Team numerator and denominator are
summed before division. Do not average owner ratios or cohort ratios.

No returned tickets gives N/A, with explicit zero incidents and population counts.
An empty completed population is labelled separately from delivered tickets with
zero returns. This N/A choice is provisional; the TXT also proposes zero on PMO
approval. No new adjusted metric is added to Periodic Returns.

Return count buckets: 0, 1, 2, 3, >=4. Keep `3+` with its >=4 tooltip. They
partition all Expected Done tickets. Consecutive buckets: 1, 2, >=3. Keep `2+`
with its >=3 tooltip. Their denominator and donut center include only tickets
with at least one accumulated repeat, not all tickets with any return. This
corrects the PNG denominator label and preserves the existing repeat definition.

## Completion-cohort trends — provisional

Within the selected RSD–RED range, Monday-based weekly cohorts partition the
final Expected Done population by latest qualifying completion date. Partial
first/last weeks are retained; periods over 120 days use calendar-month cohorts.
No opening-debt cohort or future points appear. A cohort uses each ticket's full
return history through RED, not only returns before its own cohort end date.

The team line and individual-owner lines use the same cohorts. Cohort population,
returned-ticket and incident counts sum to the headline counts; ratios are not
cumulative and are never averaged into the team result. N/A points leave gaps.
This is an explicit alternative to rebuilding each week's expectation package;
that interpretation and full historical period-to-period comparisons await Hadi.

## Live changes

The open population still matches Live Tickets (New/On-Hold/closed excluded,
Ongoing included). Return distributions and lifetime history cutoffs are unchanged.
Primary cards, comparison, five month-end trend and owner leaderboard now divide
incidents by returned open tickets, using numeric averages and N/A for no returned
tickets. Each month reconstructs its open population independently. The former
10%/50% thresholds and percentage units no longer apply to this metric and are
removed from its presentation. Ticket-delivery targets/charts remain unchanged.

The existing non-Merge measure retains its original all-open denominator and
percentage units as a separately labelled **legacy measure pending Hadi review**.
It is not plotted on the numeric primary-metric axis. Unknown reasons still make
it unavailable. It is retained in its own card and the values table; no new
adjusted denominator is inferred. Its classification also recognizes the server's
Merge / Integration Conflict reason spelling.

## Implementation and verification

Initial navigation remains filters-only with no issue/history scans. Apply shares
Tickets' uncached 100-issue batches and loads scalar histories only for selected
owners. Return parsing is performed once per qualifying delivered ticket. Stored
report rows retain event metadata for selected delivered tickets; memory still
grows with selected ticket/event count. No time-entry or target scans are added.
Unused Tickets trend calculations are skipped for Returns.

Collapsed owner/team and distribution tables appear near the top; primary/total
KPI cards and shared donut distributions follow. Owner metric bars and toggleable
team/owner completion-cohort trends provide visual comparison. Numeric, table,
bar and SVG links open exact ticket contributors in new tabs with owner/range/
cohort context. Details support reason/journal audits, classification, completion
dates, sorting, grouping, 100-row pagination and whole-set native Issues handoff.
The existing large-ID-list URL length limitation remains.

Unit/history/helper/request regression coverage is added or updated. Local Ruby
and a configured test Redmine are unavailable; those Ruby tests are not executed.
Existing JavaScript navigation/legend tests should be run locally. Full installed-
plugin requests, permission checks, layout and latency/peak memory need deployment
verification using docs/deployment.md. Never run tests against production data.
