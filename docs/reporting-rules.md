# Reporting rules

## Live Returns — Return Types

An initially collapsed Return Types table follows the leaderboard, before Combined
Results. It reuses the exact Live open-ticket population, current-owner attribution
and qualifying return events through the selected date. Owner rows and team Total
show Open Tickets, distinct Returned Tickets, Return Rate (returned / open × 100;
N/A for no open tickets), R1–R5 incidents, Total Returns and Top Reason. R1–R5 map
to shared C1–C5 stages: Feedback, Review, Ready to Merge, Final Check and Done /
Closed transitioning into Returned, preserving tracker-family rules. Each has a
tooltip. Merge incidents remain included. Top Reason counts incidents and shows
all ties; missing/hidden reasons are labelled Reason unavailable. Rework Time is
omitted. No additional history scan or stored counters. Implemented locally;
runtime and deployed visual verification pending.

## V5 Part 4 answers — 2026-10-28

The last six answers are applied locally. The authoritative current definitions
are in [Periodic Time](periodic-time-spec.md); older dated notes below describe
previous states. Targets now default to 7/3 calendar days and tentative 90% effort
share, preserving explicit overrides. Development classification uses existing
activities named Development. Ongoing paid hours are separate and Ongoing is
excluded from aging calculations across the audited reports. No workflow editing
restriction or automatic archive/replacement is introduced.

## Periodic individual-owner legend — 2026-10-28

Tickets and Complexity Weight individual-owner charts now use a selectable owner
legend on the right, below the chart on narrow screens. Each owner toggles both
Expected and Completed from Expectation lines and point links together. All owners
start visible. The breakdown table, totals, contributor sets and calculations are
unchanged. This is a display control, not a report filter or ranking.

## Part 3 Time review — 2026-10-28

Supplied answers confirm calendar creation-to-completion DTC, all-contributor
ticket cost through RED versus personal work-date hours, booked-user attribution,
paired full-portfolio efficiency/A−P, Extra/Unplanned separation, selected project
and child-project scope, and N/A/zero treatment. See [the Time spec](periodic-time-spec.md)
for the current rule reference. Trend communication was requested rather than
explicitly approving new monthly dashboards: retained windows now have plain
date explanations/examples on this same page, with owner charts collapsed.

Time activity/user donuts and tracker/package-owner/logged-user observations are
implemented locally. Development activity IDs are optional explicit settings,
default empty; all activity shares remain visible but development ratios are N/A
until mapped. The 90% working estimate is context, not a silently set target.
Current estimates and user share settings are not rewritten from observed ratios.

Archived and On-Hold/Ongoing personal hours are now retained in total/daily logged
hours, with separate reconciliation categories and no delivery/efficiency credit.
All-contributor expected-package and archived-ticket activity/user scopes are
separate from selected-user hours and must not be added together. Archive/replace
on necessary owner change is an operating policy, not an automated editing rule.
No custom fields, counters, native events or migrations are introduced. Ruby,
deployed data/visual/request verification and measured performance remain pending.

## Part 2 confirmations — 2026-10-28

The supplied answers confirm full return history through RED (including before
RSD), within-period completion-cohort trends, and non-Merge incidents divided by
ALL tickets with at least one return. See [the Returns specification](periodic-returns-spec.md)
for the current authority; this supersedes legacy non-Merge percentage/all-open
denominator and Returns-provisional statements below. Applied to Live, Periodic
Expected Done, Total Done, owner/team comparisons and trends. Merge-only tickets
stay in the denominator; unknown reasons make only the non-Merge average unavailable.

The user approved N/A as not applicable for no returned tickets (0/0), while
counts stay 0. A known non-Merge zero numerator with returned tickets gives 0.
Live consecutive distributions use open tickets at the selected date; Periodic
uses completed expected cohorts for lagging comparison. Part 1 exclusions and
current-field rules stay in force. Archived/on-hold period-history audits include
later-reactivated tickets. Only Time-specific definitions remain provisional.
Implemented locally, with full runtime/deployed verification pending.

## Hadi Part 1 confirmations — 2026-10-28

The Q&A Part 1 document and follow-up answers supplied by the user confirm the
Tickets business definitions. See [the Tickets specification](periodic-tickets-spec.md)
for the authoritative current rules. They supersede prior provisional assignment,
hotfix fallback, RED-only exclusions and reopening statements below. Implemented
locally; deployment/source-data verification remains pending.

Use latest recorded To-Do for the current owner's tenure, required hotfix due dates
on/before RED, current status exclusions, and Done at RED AND now for delivery.
Reopening after RED invalidates delivery while currently reopened. Extraordinary
lists show recorded owner/due changes, repeated To-Do and reopenings, including
later changes. Missing dates/history are flagged, never assumed. Scheduled due-date
commitments remain independent of missing To-Do. Current due/owner/weight policies
remain unchanged. In-period exclusion explanations and new-work drill-downs reuse
exact sets. Other Done has separate per-owner Extra/Unplanned assessment; logged
Other Work remains a distinct unfinished-or-finished time measure.

Returns and Time inherit the corrected Tickets populations; their own formulas,
targets and event windows remain provisional. Their native events are not reset.
PMO Ticket Owner Performance now uses due < RSD and pre-RSD opening status, due
within RSD–RED for new commitment, inclusive RSD-day delivery and current closed
delivery checks. Its other mappings and end-debt rules are retained.

## Periodic Time — provisional implementation, 2026-10-28

The user authorized the Time recommendations pending Hadi. All three Periodic
sections are now implemented provisionally; older Time Planned statements below
are superseded. See [the Time specification](periodic-time-spec.md) for the single
business-rule reference. Time reuses exact Tickets packages; current owner/due/
estimate/weight/priority remain authoritative. Personal hours follow booked user
`TimeEntry.user_id`, not entry creator or current Ticket Owner. Ticket cost is
visible direct lifetime hours through RED; personal hours use RSD–RED work dates.

Eight metrics, optional blank targets/share, owner/team comparisons, reconciliation,
completion/work-date trends and audited contributor lists are implemented locally.
Paired comparisons disclose exclusions. Unfinished expected effort remains in
reconciliation and the paired efficiency denominator. Extra Work is per owner
with nonempty fully completed expectation and no RED debt; team Extra/Unplanned
stay separate. CW/h uses A−P provisionally. Permission/missing-data gaps are N/A.
Initial navigation remains scan-free. Ruby, deployed requests/layout and measured
performance remain unverified; Hadi has not confirmed the provisional choices.

## Periodic Returns and revised Live metric — 2026-10-28

User-authorized suggestions/corrections are implemented locally; see
[the Returns specification](periodic-returns-spec.md). Periodic Returns is now
provisional rather than Planned. Periodic Time remains Planned. Primary population
is the exact Periodic Tickets Completed from Expectation set; secondary population
is Total Actual Done. Return/repeat events reuse existing shared rules. Provisional
timing counts full recorded history through RED, including before RSD. Weekly
completion cohorts (monthly for >120-day ranges) partition the final expected-done
population; they do not independently rebuild expectations or use cumulative ratios.

Return Ticket Metric is incidents divided by tickets with >=1 return, a numeric
average (8/5 = 1.6), not a percentage. Zero returned tickets gives N/A with explicit
population/zero-incident context. Return buckets are 0/1/2/3/>=4; repeat buckets
are 1/2/>=3 and use only tickets with at least one repeat as denominator. Merge
Conflict stays included. Team counts aggregate before dividing. Shared current
owner/visibility/period eligibility and native Return Count rules are unchanged.

Live's primary cards/comparison/five monthly snapshots/owner leaderboard now use
returned open tickets as denominator. Its all-open distribution population is
unchanged, including Ongoing; the old 10%/50% thresholds and percentage units no
longer apply. Existing non-Merge incidents/all-open tickets remains separately
labelled as a legacy percentage pending Hadi's review, not plotted on the numeric
metric axis. Unknown reasons still make it unavailable. The shared classifier now
recognizes the server's `Merge / Integration Conflict` spelling too, correcting
audit flags/legacy exclusion without changing raw incident counts.

These newer rules supersede older denominator/threshold/Planned statements below.
Runtime, deployed visuals, installed-plugin requests and measured memory/latency
remain unverified. Hadi's confirmation of provisional defaults is still pending.

## Periodic Tickets — provisional implementation, 2026-10-27

The user authorized implementation of the recommendations while awaiting Hadi.
See [the calculation and layout specification](periodic-tickets-spec.md) for
the implemented provisional defaults. This supersedes older statements that
Periodic Tickets is Planned or has no date-range inputs. Periodic Returns/Time
remain Planned. Current-owner/current-due-date/current-weight policies remain
authoritative. Runtime and deployed verification are pending.

Periodic Tickets Debt at RED is user-confirmed as unfinished tickets from the
expectation package; Still Open Now is its currently open subset. Existing PMO
open-and-due-by-RED debt is unchanged. The remaining rules are provisional, not
Hadi-confirmed: full RSD–RED inclusivity, opening snapshot immediately before
RSD, beginning debt then current Immediate/Hot Fix with in-period recorded owner
assignment then scheduled tasks due within the period. Earlier-assigned tasks
due in the period are included. Missing assignment history is disclosed with no
creation-date fallback. Archived/Ongoing/On-Hold at RED remove tickets from the
entire package. Actual delivery requires recorded in-period completion and
Done / Closed at RED. Missing completion evidence remains unresolved in debt
for expected tickets and is linked for review. Other Done never improves expected
completion or its deviation; team sums and aggregate percentages are distinct
from Live monthly averages. Cards, charts and drill-downs reuse exact sets in
TicketJourneyPeriodicTickets. Initial navigation remains scan-free. No fields,
counters, settings, migrations or changes to Live calculations are added.

Reviewed against code and conversation on 2026-10-13. **Implemented** means present in code, not necessarily server-verified. See [known issues](known-issues.md) for evidence and differences requiring confirmation.

## Current Ticket Owner policy — Hadi confirmed, implemented locally

The current stored Ticket Owner (#57) is authoritative for all dates in Performance Tickets/Returns, cards, trends, drill-downs, and PMO Ticket Owner Performance commitments (A/B/C), beginning debt at RSD, delivery, end debt at RED, activity, returns and rework. PMO Status Snapshot also uses current Ticket Owner. Reassignment moves historical attribution to the new current owner; a blank current owner stays unassigned and never falls back to a prior owner. This supersedes every older historical-owner/commitment-owner/event-owner rule in this document. Status, completion dates, period boundaries, current due dates/weights and visibility rules remain unchanged. Native journals/time entries and their authors are never rewritten.

PMO ticket activity and visible logged/rework time for a ticket are attributed to its current owner regardless of who authored the journal or logged the entry; recorded users remain intact. Current role and locked-user filters still apply. Performance owner discovery now reads current visible owner values without owner-history queries. Candidate scans retain history matches only to preserve the owner-change audit's previous-owner coverage; exact report contributors are filtered by current owner.

Owner changes are always accessible: Performance Tickets and Returns show their five-month audit link/count even at zero; drill-down headers link to it. PMO Ticket Owner Performance always shows an expandable report-period ticket/change list, with an explicit zero state, and every PMO report navigation includes a link to that audit under its report-period filters. Both exclude initial assignments from no owner, include reassignments/removals, count each ticket once, and apply issue/owner-field visibility. Previous/new names in these audits describe the recorded changes, while report attribution uses current owners. Tests updated but not run without local Ruby/host Redmine; full deployed report, installed-plugin compatibility, rendering and performance checks remain pending.

## Historical reporting and due dates — implemented

Performance Open Tickets weight cards show missing-weight counts and usable-ticket coverage when incomplete. Each count links to the missing-weight tickets in that exact open/status group; hidden, missing and nonpositive weights remain excluded from sums. Ongoing status at the report date requires no complexity weight and is excluded from all Performance missing-weight counts/lists, while remaining in open totals. A clickable Ongoing count beside Stopped shows that open subset. Existing usable recorded Ongoing weights still contribute to Section 1 sums; weight percentages use only usable recorded weights across the open population. Implemented locally; deployed rendering remains to be verified.

- Team Performance reconstructs status/owner history, completion events, returns, and dated activity. It is not an immutable snapshot of every field.
- Beginning debt A: created by and open at report start (RSD), with **current due date on/before RSD**; snapshot is RSD end of day.
- New commitment B: current due date after RSD through report end (RED), excluding tickets already closed at RSD. C is the distinct union of A and B.
- End debt I: open at RED end of day, current due date on/before RED. I1 is now paid; I2 remains open at generation time. I is debt that existed at RED, not just today's remaining debt.
- H/H+ count qualifying closures from RSD+1 through RED, still closed at RED. T is their distinct total. Activity D/E/F covers RSD through RED. Preserve these different date boundaries.
- All commitment, activity, return, delivery and debt attribution uses current Ticket Owner, per the policy above; role membership is current.
- Blank current due dates remain missing. Current deadline edits can change past report results. Filters select the report population; historical reconstruction does not override that selection.

## Carry-over — implemented

Within the selected sprint's related scope: **current ticket due date < sprint start date**. Equal dates are not carry-over; missing due date or sprint start cannot qualify. Original Sprint is reference only. Completed work can count as carry-over; Technical Debt includes unfinished carry-over. Remaining Current Scope includes missing-date tickets, also flagged separately.

## Returns — implemented

- The legacy PMO report labelled “Consecutive Returns” means **cumulative lifetime returns**, across qualifying stages/reasons; the new Performance Returns dashboard has a separate same-stage-repeat metric below. Progress and completion never reset it.
- Each recorded transition into explicit `Returned` counts once: Feedback C1, Review C2, Ready to Merge C3, Final Check C4, Done / Closed C5. `Returned → In Progress` adds nothing; direct backward moves without Returned do not qualify.
- Technical trackers use C1–C5; Task / Task (Business Jobs) uses C1/C4/C5. Customer Support/container families have none; unmapped trackers fall back to technical. Current tracker/status mappings determine classification.
- Minimum is **inclusive**, default 3; use X+1 for more than X. Filters/saved queries select tickets; counts use their full recorded history regardless of date filters, with no top-N cutoff.
- The separate report table/audit reuse journals: no separate database table or backfill. Native read-only Return Count supports standard query columns, numeric filters/sorting, and selected-column CSV. Other plugins' custom lists may need integration.
- Team Performance R1–R5 counts **period events**, not lifetime totals. Its loop classifies source stages without the lifetime counter's family restriction.

## Complexity points — implemented

Use **current Complexity Weight (field 70)**, once per distinct ticket per metric. Returns never multiply points. Committed Points follows C; Completed Points follows T including Other Done. Summary rows A1–C, D–F, H–I also carry points. Totals use distinct ticket sets, not repeated row sums.

Points link to contributors; missing/nonpositive/nonfinite weights add no points and appear separately. Parsing uses decimal-comma normalization and Ruby `to_f`, not strict validation. The screenshot's 5/8/13/21 restriction is not enforced by this plugin.

Done Activities Points measures tickets worked on, not necessarily completed work. End-of-Report Status separates Completed Tickets (H/H+/T) from End-of-Period Debt (I1/I2/I), with independent totals. Current weight edits can change past report points.

## Tickets Time Report — implemented; server verification pending

Above the journey-family sections, one row per distinct filtered ticket, with Issue/Subject plus standard columns selected in Options. Dev. Estimate uses the visible current Ticket Owner Estimation (#56); PM Estimate uses current Redmine Estimated time. Estimates are positive finite hours; missing, zero, negative, or malformed estimates show unavailable.

Time Spent sums lifetime direct time entries through `TimeEntry.visible(User.current)`; issue date filters do not filter entry dates. Parent rows exclude child-ticket rollups. The activity dropdown changes only activity hours, defaults to All activities, and includes project-configured activities plus those found in visible entries. Unknown selections fall back to All activities with a warning. Selection survives report parameter links and the separate Time CSV export.

Spent / PM Estimate is a percentage. The total ratio is summed spent hours divided by summed PM estimates **only for tickets with positive PM estimates and permission to view time**, not an average of row percentages. Other hours still contribute to the displayed Time Spent total; the exclusion count explains the difference. No time-view permission shows unavailable, not zero. With permission, no visible entries means zero. Other visibility restrictions may yield partial totals; all hours are explicitly labelled visible.

Totals sum each numeric column over distinct tickets. CSV includes selected standard columns, selected activity in its header, totals, and exclusion/missing-value notes. UI tooltips explain fields, ratio examples, time scope, and permissions. Estimates are current, not historical snapshots. No schema changes.

The section starts expanded with all details. Collapse hides its body; Compact view hides selected standard fields and both estimates, retaining Issue, Subject, Time Spent, ratio, and activity hours. CSV always includes all columns. Estimates are light blue, logged time light green, activity hours light amber; ratios above 100% are amber and above 150% red (150% itself remains amber). Unavailable values are muted; totals stay shaded and bold. These display controls/colors await server visual verification.

A single Export dropdown in the page header offers Ticket Journey CSV (journey durations/returns) and Tickets Time CSV (estimates/logged hours/activity/totals). The time section has no separate export button. Time CSV was an assistant suggestion approved by the user, not an explicit requirement from Hadi. This export layout awaits server visual verification.

## Performance Results — Tickets (implemented; provisional rules, server verification pending)

- Only currently active Redmine users appear in the Performance owner selector, both initially and after running a report. Existing report/drill-down links for inactive owners remain usable under normal project, issue and field permissions. Explicit owners are resolved from visible in-scope ticket history independently of the dropdown; an inactive owner report is labelled above the metrics without adding an inactive dropdown option. This does not change ticket ownership history or other PMO reports.

- Memory optimization: report execution scans visible in-scope issues created by the report date in batches of 100, excluding issue descriptions. It loads only scalar status changes and post-report owner changes, without journal notes or unrelated details. Query caching is disabled for the scan; only selected-owner snapshot hashes and distinct owner IDs survive batches. Drill-down records load only for the selected 100-row page. Calculation/date/visibility rules remain the same; selected-owner result memory still grows with that owner's ticket count. Server memory validation is pending.

- Initial menu navigation loads member owner choices from visible projects in the selected hierarchy only, without scanning issues or journals. Apply (an explicit owner selection) runs the report; report/drill-down URLs retaining owner/date still calculate directly. Calculated results discover additional historical owners from visible tickets. This loading optimization awaits server timing verification.

- Separate project menu and permission under Dashboard. One or multiple selected owners, selected project plus every descendant subproject at any depth, visible projects/issues only. The current project hierarchy applies even for past report dates; unrelated projects are excluded. Dashboard metrics, owner choices, monthly delivery and drill-downs share this scope; each ticket counts once and employee targets are not multiplied. Drill-downs show the current Project. Included trackers: Bug, Change Request / Improvement, Feature, Task (Business Jobs). Section 1 includes non-closed statuses except New and On-Hold, based on status at the selected report date; Pending and Ongoing remain included. User Story and containers are excluded pending clarification.
- Status and owner are reconstructed at report-date end of day by reversing later journal changes. Missing history falls back to current values; recorded blank owners stay blank. Current due dates and visible current weights (#70) are preserved. Hidden Ticket Owner (#57) fields exclude issues from this report.
- Open groups partition the total: Not Overdue (including missing due dates), overdue started, overdue untouched. Due date equal to report date is not overdue. Due Soon covers today through +2 calendar days. Hadi-confirmed rule: Started means the ticket is In Progress at the report date or recorded status history establishes it was In Progress on/before that date (including a transition out of In Progress). Not Touched is the absence of that evidence. Later stages, comments and logged time do not substitute for In Progress. Future starts do not affect earlier reports; earlier starts before reassignment still count. Stopped is a secondary count of open Pending tickets only at the report date, with its own drill-down under Total Open Tickets. It overlaps the existing three groups and adds no extra tickets or weight.
- Section 2 excludes Archived and Ongoing tickets based on reconstructed status at the report date from both delivery ratios, monthly contributors and corresponding drill-downs. Section 1 still includes open Ongoing tickets. Due population has current due date on/before report date, including older backlog, after these exclusions. Done numerator is the subset in Done / Closed at report date. Archived/reopened work does not qualify. Each ticket counts once; no due date excludes tickets from both ratios. Zero denominators show N/A.
- Monthly averages now use the same three completed calendar months before the selected report date’s month: e.g. 15 October 2026 means 1 July–30 September 2026. Count distinct tickets still Done / Closed at the report date whose latest recorded completion is within that inclusive window; ownership is still at the report date. Divide ticket count and current usable complexity weight by 3, including zero-delivery months. Account creation, ticket Start dates, and former manual Day 0 settings do not affect the window. Missing completion dates exclude tickets with a note. Existing Archived/Ongoing/reopened exclusions and current field visibility remain. Combined monthly actuals are per-owner means: three-month combined totals ÷ 3 ÷ number of distinct selected owners, including owners with zero deliveries. Monthly targets are arithmetic means of all selected owners’ current usable targets. A missing/hidden/invalid/nonpositive target for any owner makes only that metric’s target/deviation unavailable; never average a subset silently. Contributor lists retain every qualifying ticket. Implemented on user approval; server verification pending.
- Targets use selected numeric User custom fields and current positive finite values. Non-admins see only public fields. No fields or target values are created automatically. Hadi confirmed a single shared Delivery Target, default 90%, with no Extra Tasks adjustment. The plugin setting Delivery Target (%) accepts finite numbers from 0 through 100 (browser and server validation) and applies to both Done Tickets / Due Tickets and Done Weight / Due Weight. Existing settings without the key use 90%; invalid legacy values fall back to 90% when read. The current setting also applies to past report dates; actual ratios are unchanged. Multiple-owner monthly targets use per-owner arithmetic means; tolerance-based pass/fail remains deferred. Below-target monthly deviation is red; at/above target is green.
- Missing/hidden/nonpositive/nonfinite weights contribute no weight and are reported in notes. Monthly target fields and web behavior require setup/verification; see [setup](performance-setup.md) and [Hadi questions](performance-hadi-questions.md).

Performance drill-downs reuse the exact calculation sets for open groups, Due Soon, data-quality counts, due/done populations and monthly contributors. They run under the existing Performance permission and current issue/field visibility. Owner/date and back/pagination links retain the report context; 100 rows per page with whole-set totals. Status/owner are historical, subject/tracker/due date/weight current. Requests recalculate data, so intervening edits or permission changes can change the set. Missing weights are displayed as unavailable, never exposed from hidden fields. Implemented locally; drill-down web verification pending.

## Future work

Performance uses two navigation levels inside the blue header, above the title and filters: Live Dashboard (default) / Periodic Report, then Tickets (default) / Returns / Time, under the existing project menu and permission. Live Dashboard means a selected As of Date snapshot, not automatic refresh. Periodic Report is a Planned category for every section; it retains owner/date context but has no period calculations or From/To inputs yet. Live Tickets, Returns and Time are implemented locally; Periodic sections remain Planned. See the Time rules below. Planned categories have with shared date/owner controls and context-preserving tab links. Planned categories do not run ticket/history/target calculations or show metrics. Their selector uses active visible-project members; retained owner IDs outside that lightweight list show a generic ID label without resolving unrelated user names. Tickets still validates report ownership normally. No new metrics, periodic date-window decisions, Trends tab, or Periodic Report calculations are included. Periodic From/To dates will be introduced with its implementation. Navigation is implemented locally; server verification pending.

Automated return alarms, notifications, and alarm KPI cards are deferred; no implementation is claimed.

## Performance drill-down ordering
Drill-downs default to one ungrouped list. Options select the report columns (Ticket is mandatory) and optional grouping by current Project/Tracker or historical Owner/Status; default columns remain the original nine fields. Optional Priority, PM Estimate (native Estimated time), and lifetime visible direct Time Spent are current values; Title / Subject is the existing Subject field. Spent hours are aggregated only for the displayed page when selected, through native time-entry visibility, without child rollups or an as-of cutoff. No time-view permission shows Unavailable; permitted users with no visible entries see 0. These three optional fields are display-only, not sortable headings. Groups, when selected, are alphabetical (project ID breaks same-name project ties); whole-group counts/weights cover all pages. Open/due/stopped lists default to due date ascending, delivered lists to completion descending, and data-quality lists to ID ascending. ID, subject, historical status, current due date/weight and completion date headings toggle direction. Missing values remain last; ties use ID ascending. Grouping/sorting precede 100-row pagination. Option/sort changes reset the page; pagination and sorting preserve chosen columns/grouping, owner, date and metric. Only compact metadata is retained; full issues remain page-only. An optional Open matching tickets in Issues link passes the full matching ID set, removes the native open-only status default, and displays current values with standard Redmine query controls. It does not turn native fields into historical snapshots. Implemented locally; server verification pending.

## Developer comparison and aggregated charts
The first report section is an expanded-by-default native collapsible table matching Hadi's Tickets/Complexity Weight column groups, with owner rows and a bold Total row, plus Stopped/Due Soon subsets. Headings sort owner rows; the total stays last. One or multiple owners can be selected; duplicates are removed. One batched history scan retains selected-owner rows; table totals and combined charts use the same sets. Row numbers drill down to that owner, while Total/chart links preserve all selected owners through sorting, pagination and return navigation. Owners with no matching tickets can show zero when they are active members of the visible project hierarchy. Inactive users remain absent from selection, but saved links to inactive owners found on visible tickets work. Single-owner monthly metrics use the last three completed calendar months. Multi-owner monthly actuals and targets both use per-owner means; missing targets are explained per metric. Implemented locally; runtime and server verification pending.

## Performance scan optimization
SQL candidates include current Ticket Owner matches or ownership history mentioning selected owners; exact as-of ownership is still reconstructed before counting. Safe drill-down due-date prefilters use current due dates, preserving existing rules; current status is never used to prefilter historical status. The full dashboard dropdown discovers owners with post-cutoff ownership changes only, without reading status history. Drill-down owner discovery is limited to selected-owner candidates, and skips comparison-row calculation and monthly target lookups. Standard Redmine field visibility uses a batch read of only fields 57/70 plus native field availability/visible_by? checks; overridden issue-level field visibility methods take the original full-value path. Batches remain 100 and uncached, with no new database/index or counter changes. Logs include owner-discovery duration and candidate scan count/duration for before/after measurement. Implemented locally; server timings and runtime tests pending.

## Open-ticket exclusions (Hadi’s latest feedback)
New and On-Hold are excluded from Section 1 at the selected As of Date. Apply this shared population to owner comparison counts/weights, combined donut/breakdowns, Due Soon, open missing-due-date totals, and their drill-downs. Stopped is Pending only, remains an overlapping subset, and stays under Total Open Tickets. The three breakdowns still partition the open total. Current status must not prefilter historical results. Section 2 cumulative delivery, monthly metrics, and all-ticket missing-weight data quality retain separate existing rules; do not remove excluded open statuses globally from calculation input. This supersedes earlier inclusion of New/On-Hold and On-Hold in Stopped. Implemented locally; Ruby tests updated but unrun; server verification pending.

## Performance Results — Returns (implemented; server verification pending)
Live Dashboard → Returns is implemented under the existing Performance permission. Date/owner picker, visibility, current project hierarchy/subprojects, tracker population and batched candidate scanning are shared with Tickets. Eligible tickets use the same open population as Tickets: open at the report date excluding New, On-Hold and closed statuses. Ongoing is included on Hadi's confirmation to keep both open totals and incident-ratio denominators consistent; it participates in buckets and return history normally. Historical owner/status are reconstructed at end of day; all incidents are attributed to the ticket's owner at that date, including earlier owners' incidents. Current tracker/stage mappings apply.

Total returns reuse TicketJourney::ReturnCount.events and existing family counter restrictions, stop at the selected date and deduplicate journal detail IDs. Native lifetime Return Count and legacy reports are unchanged. The separate accumulated consecutive count adds one whenever a qualifying event's source-stage counter matches the previous qualifying return event's source-stage counter. Intermediate workflow/progress/completion transitions do not reset it. Feedback/Feedback/Feedback plus Final Check/Final Check gives three accumulated repeats. It never resets and can accumulate across stages.

Return buckets are exactly 0, 1, 2, 3 and >=4 (approved label 3+). Repeat buckets are exactly 1, 2 and >=3 (approved label 2+); zero-repeat tickets are excluded from this distribution only. Denominators are respectively all eligible open tickets and eligible tickets with >=1 repeat. Counts partition their denominators. Ratios are total incidents/open tickets and known non-merge incidents/open tickets, expressed as percentages and allowed above 100%. Ordinary rounding to one decimal is used; the source example's 48/116 is 41.4%, not 42%.

Merge Conflict remains in both distributions and the raw ratio. It is excluded only from the adjusted ratio, with no two-week condition. Field 66 reason is reconstructed backward at each return, treating same-journal reason edits as effective for that event. Missing historical edits fall back to the available current value. Missing/hidden reasons are unknown: their incidents still count in totals/distributions, but make the adjusted ratio unavailable rather than treating them as non-merge. Known non-merge drill-down may then be a labelled partial list.

The page starts with an expanded collapsible owner-comparison table and bold Total row, then two combined donut/distribution tables and orange/red ratio cards. Comparison headings sort owners, and counts link to matching ticket sets. Audit drill-downs show historical status/owner and each dated return source, reason and repeat marker, with sorting/grouping and 100-ticket pagination. Full Issue records are loaded only for that page; status/owner/reason history is scalar and batch bounded. The initial no-selection Returns page runs no history scan. Periodic sections remain Planned; Live Time is implemented separately below. No stored counters, custom fields or migrations are added. Runtime tests and deployed layout/calculation verification remain pending.

Returns comparison table: Hadi's latest feedback replaces the last two columns with Total Return Incidents (integer) and Return Incidents / Open Tickets (percentage). Both include Merge Conflict and link to all qualifying incident contributors. The separate adjusted ratio card below retains its confirmed non-merge rule. Owner sorting and the Total row use the corresponding incident count and raw ratio.

Section 3 includes a line chart for the five completed calendar month-end snapshots preceding the selected As of Date's month (21 October means 31 May, 30 June, 31 July, 31 August, 30 September). Each point independently reconstructs eligible open status and selected-owner attribution at that month-end, including tickets since closed or reassigned. Its numerator counts all qualifying returns through that date for that snapshot's open population, not just incidents occurring within the month. Combined ratios divide combined incident counts by combined open-ticket counts, not average employee percentages. Both raw and non-merge ratios follow the existing reason-visibility/unknown rules; zero open tickets makes both unavailable. Missing points are gaps, not zeros; percentages may exceed 100%. Hover titles and an expandable table provide exact dates, percentages, numerators and denominators. The cards retain the selected date. Current visibility, project hierarchy and tracker mappings still apply; this is not immutable historical field/permission storage.

The trend reuses the dashboard's batched candidate scan, loads owner history back to the earliest month-end, parses return events at most once per candidate and retains five aggregate hashes rather than monthly ticket sets. It performs five additional snapshot reconstructions per candidate in memory; no extra full database scans or client chart library are added. Initial filters-only navigation, drill-downs, Tickets and Planned tabs skip trend work. Code and regression tests are implemented locally; runtime, deployed appearance and timing verification remain pending.

Section 3 ratio cards share color thresholds on unrounded values: green below 10%, orange from 10% through 50% inclusive, red above 50%, neutral gray for unavailable ratios. Each card uses a pale background and darker matching percentage. A shared text/color legend explains boundaries and rounding. This supersedes fixed orange/red card backgrounds; calculations and trend series colors are unchanged.

## Tickets delivery ratio trend — implemented locally
Tickets Section 2 is followed by a five-point trend over the same completed month ends as Returns. Each point independently reconstructs selected-owner attribution and status; Archived and Ongoing are excluded using shared delivery rules. All current due dates through that month-end form the denominator; Done / Closed forms the numerator. Count and visible current complexity-weight ratios use combined totals, never averages of employee percentages. Missing/nonpositive/hidden weight contributes zero weight while the ticket still counts. Zero due tickets/usable weight makes the respective point unavailable and leaves a gap. Current due-date/weight edits can change past values; existing monthly output averages are unchanged. The axis is 0%-100%, with the current configured shared delivery target shown as a horizontal line. Hover/focus descriptions and an expandable monthly table give numerators and denominators.
The trend reuses the existing batched candidate scan, requesting owner history from the earliest month-end. Five extra snapshots per candidate are computed in memory with only five aggregate hashes retained. Initial filters-only pages, drill-downs and Planned tabs skip it; no Returns event/reason scan is added to Tickets. No migrations, settings or chart libraries are required. Tests added; local Ruby/host Redmine are unavailable, and runtime, deployed visual/timing checks remain pending.

## Tickets monthly output trends — implemented locally
Below Section 2, the delivery-ratio chart is on the left and Monthly Delivery Trend on the right (stacked on narrow screens). The right panel has separate scales for tickets and complexity points. Each of five points shows actual delivery in that calendar month, not a rolling three-month average. At each month-end, a ticket must be Done / Closed with latest recorded completion within that month; Archived, Ongoing, reopened and missing-completion tickets are excluded using shared monthly eligibility. Due dates do not restrict monthly output. Current visible usable weights apply; zero/missing weight still permits ticket count. Ownership/status are reconstructed at each month-end.
Combined monthly totals divide by every distinct selected owner, including zero-delivery owners, to compare against current arithmetic-mean monthly targets. There is no division by 3 in the trend. A missing/hidden/invalid target disables only that metric's target line. Existing upper cards retain their three-month-average calculation using selected-report-date ownership/status; reopening or reassignment can make them differ from the latest three plotted points. Hover labels and the expandable table expose monthly totals, per-owner values and missing-completion counts. All output aggregates reuse the ratio trend's five snapshots; no extra snapshot or full history scan is added.

## Ownership changes during the trend period — implemented locally
Below Tickets and Returns trends, a clickable audit note always appears after running the report, including zero changes. It counts recorded Ticket Owner changes involving at least one selected owner during the five completed calendar months shown (October report: May 1 through September 30 inclusive). Each visible in-scope ticket counts once, even with multiple changes, regardless of current owner/status or whether it contributes delivery. Initial assignments from blank/no owner are excluded, including historical-ticket owner backfills. Reassignment between existing owners and removal of an existing owner remain included; no-op edits and changes entirely between unselected owners are excluded. The same project hierarchy, tracker, issue and Ticket Owner field visibility applies. Scalar owner history loads from just before the first month begins, sharing the existing batched candidate scan.
The owner_changes metric opens a dedicated audit under existing Performance authorization, sorted by latest change then ticket ID, with 100 tickets per page. It lists current subject and dated old/new owners with journal links. Page tickets are visibility-checked again, and owner names are resolved only for displayed changes. Date/selected owners and fast Back navigation are retained. The note is informational and does not alter delivery attribution or upper-card calculations. No stored tags, counters or new permissions are created. Ruby/runtime, deployed appearance, navigation and performance checks remain pending.

## Individual owner trend Leaderboards — implemented locally
When multiple distinct owners are selected, both Tickets and Returns insert Leaderboard — Individual Owner Trends immediately after the developer comparison table and before Combined Results for selected owners (team). No leaderboard is calculated or displayed for single-owner, initial filters-only, Planned or drill-down requests. Tickets plots each owner's actual delivered complexity weight in each of the same five completed calendar months, using existing completion/exclusion/current-owner/current-weight/visibility rules, with no division by owner count or by 3. Returns plots each owner's raw return incidents/open tickets at each month-end, including Merge Conflict. Zero open tickets produces a gap, not zero; percentages may exceed 100%. Team ratios remain calculated from combined counts, never means of owner percentages.
Owners receive distinct qualitative palette slots based on sorted selected IDs. Colors match across tabs and row sorting for the same owner selection; changing the selected set can reassign colors. Large selections beyond the 12-color palette use additional hues. Legend buttons hide/show lines with accessible pressed states; axes and the exact-values table stay unchanged. Hover/focus labels show owner, date, value and contributing counts. The expandable table lists all five months per owner, with return numerator/denominator or delivered tickets/points. No ranks or winner labels are assigned. Owner aggregates are added during the existing batched scan and reused snapshots/events; Returns parses events once per ticket. Retained extra state grows by five small aggregate hashes per selected owner. No extra issue/history scans, migrations, settings or chart libraries are added. JavaScript tests pass; Ruby tests and deployed visual/timing checks remain pending.

Leaderboard reference lines: Tickets draws one thin neutral-gray dashed horizontal line per unique visible current monthly complexity-point target. Labels identify the value, and hover text identifies all owners sharing it. Legend entries show each owner's target in small muted parentheses, with unavailable values explicitly marked. Hiding an owner hides their actual series; a shared target remains while any associated owner is visible, disappears when all are hidden, and reappears on show. The exact-values table retains per-owner targets. Individual targets reuse existing visibility-checked lookups; combined team target validity rules are unchanged. Returns keeps shared 10%/50% thresholds independent of owner toggles. Plot scales include targets/thresholds; no new configuration or scans are added. This supersedes the earlier same-color per-owner target-line design.

Leaderboard axes use a tighter readable ceiling based on all plotted values and targets/thresholds. Example: 211 delivered points with target 160 uses 0-300 with 100-point ticks; a return peak of 112.5% uses 0%-125% with 25% ticks. Tick count adapts to the ceiling. Future values/targets expand the axis automatically; nothing is clipped at 300 or 125%. Other trend charts keep their existing scales.


## Performance Results — Time (implemented locally; server verification pending)

Based on Hadi's three rounds of Time Q&A and the user-approved configurable calendar. The existing Performance permission, active owner picker/inactive saved links, visible project hierarchy, trackers and current Ticket Owner policy apply. Live Time is implemented; Periodic Time remains Planned. Initial navigation does not scan issues/history/time. Current owner, priority, Start Date, Due Date, PM Estimate and visible Complexity Weight apply even to past reports. Status is reconstructed at each snapshot. No User fields, tables, migrations or stored counters are created.

- Open population matches Tickets/Returns: non-closed at report date, excluding New/On-Hold, including Ongoing. Age counts configured working days after current Start Date through As of Date; age is zero on Start Date. All pauses remain included and reopening does not reset Start Date automatically. Buckets are 0–15, 16–30, 31–60 and >60 working days. Missing/future starts are excluded from age distributions, shown explicitly and linked for investigation. Percentages and donut centers use the age-eligible subset, with full open population and coverage stated separately. Priority uses existing Urgent/Immediate name matching; the dedicated Immediate / Hot Fix list means Immediate priority under current Ticket Owner, without inventing another field/tracker mapping.
- Visible spent hours are direct TimeEntry.visible entries from all recorded authors, with spent_on <= snapshot date; parent rows do not include child rollups. Backdated entries created later can change historical reports. Negative and nonfinite aggregates are excluded. No time-view permission is unavailable, not zero. Authorized users with no visible entries see zero; private-entry visibility can still make totals partial. Native users/authors are never rewritten.
- Total PM Estimate sums current positive finite native Estimated time values. Top-level estimate and visible-spent totals retain their respective available populations. Estimate Balance uses only tickets with both usable estimate and time permission on both sides: estimate minus visible spent, divided by comparable estimate for its percentage. Coverage and comparable totals are disclosed. Positive means Remaining Estimate, not realized savings. Negative means overrun, zero is neutral. Exactly the configured overrun allowance remains within allowance (warning); exceeding it is red.
- SV includes open schedules starting on/before the report date, including same-day starts and future-due tickets. Start and Due must exist, Due > Start, estimate must be positive finite and time must be viewable. Windows containing no working days are excluded. Planned effort per ticket = estimate × inclusive elapsed working hours / inclusive total scheduled working hours, capped 0–100%. The report day's full working hours are included. Due/overdue tickets use full estimate. Early logged work is retained in actual hours for valid started schedules; future-start tickets remain outside SV until their start. Overall SV = (summed planned − summed visible actual) / summed planned × 100, never averaged ticket/owner percentages. Zero planned total is N/A. Insufficient schedules are excluded from both SV sums and linked with corrective reasons. The three-bar chart uses the SV contributor subset for all three bars, so totals may differ from the overall cards.
- SV wording is Below / At / Above planned time consumption. Positive is green; exactly zero neutral; a negative shortfall smaller than the configured warning threshold is amber; reaching/exceeding it is red. The estimate allowance and SV threshold are separate settings (default 10%, each validated 0–100%). Thresholds use unrounded values. Low logged hours do not prove functional completion.
- Working weekdays (default Monday–Friday), default hours/day (8), dated organization holidays and optional numeric User weekly-hours field mapping are configurable in plugin settings. Holidays support YYYY-MM-DD plus optional descriptions; duplicates count once. At least one weekday and finite daily hours >0 and <=24 are required. Per-owner weekly hours divide by configured weekdays; unavailable/private/invalid values or >24 daily hours use the default and disclose a fallback count. Private User values remain hidden. Constant owner daily hours cancel in the elapsed/window fraction and do not rescale PM Estimate. Current settings apply to historical reruns; no calendar history is stored.
- Delivered Complexity Weight / Total Direct Ticket Logged Hours is a separate five-completed-month trend. Each point reuses Tickets' month-end completion eligibility: still Done / Closed at that month-end, latest recorded completion in that calendar month, with shared Archived/Ongoing exclusions. Current owner/weight apply. The denominator is visible direct lifetime hours through that month-end for the same contributors, including work before the delivery month. Missing/unusable weight or unavailable time excludes both numerator and denominator; missing completion dates are separately disclosed. Sum points and hours across all selected owners before dividing. No owner-count or month-count division. Zero hours gives N/A/gaps; this is not open-ticket productivity or a rolling average. Values/coverage table links to monthly contributor/data-review lists. This Live extension was explicitly requested by Hadi; container assessment remains future work.
- Time detail lists use these exact sets, current issue/field visibility, sorting/grouping, 100-ticket pagination, native Issues handoff and shared Back navigation. Monthly productivity links retain the selected report date and explicit month-end snapshot. The five-month owner-change audit is available on Time. One uncached batched issue/history scan is reused; visible time aggregates are loaded by issue/work date within each 100-issue batch. Only compact selected-owner metadata and five monthly aggregates survive; time rows/history still add work and require measured server validation.

Implementation and tests are local. Ruby/Redmine runtime, installed-plugin compatibility, deployed rendering, calendar settings saves, historical calculations and request latency/peak memory are unverified. JavaScript navigation/leaderboard tests passed; see deployment checks for full validation.

Time display clarification: the user's supplied screenshot confirms the Live Time page renders, but does not independently validate ticket-level calculations. Estimate Balance now prominently explains visible logged hours on tickets with missing/invalid PM Estimate, with a link to the exact exclusion list; these hours remain in Total Visible Spent Time. Unavailable excluded hours are not displayed as zero. When an age distribution has tickets but no usable Start Dates, its donut shows the full ticket count with “No eligible Start Date” instead of an unexplained zero. The coverage note separates missing and future starts; Priority investigations link only to excluded priority tickets. Numeric report rules are unchanged. These display clarifications await deployed visual verification.

Performance drill-down navigation: on user approval, Tickets/Returns/Time metric links (comparison counts, totals, card/chart links, exclusions, monthly productivity contributors and owner-change audits) now use standard target="_blank" links with rel="noopener" and an "Opens in a new tab" tooltip. Dashboard date/owner context stays in each URL. Filters, report tabs, sorting and pagination stay in their current browser tab. Back to Performance remains a normal dashboard link in newly opened tabs; existing history-based behavior remains for ordinary same-tab navigation. Implemented locally; 9 JavaScript navigation/leaderboard tests pass. Deployed browser and Ruby-render verification remain pending.
