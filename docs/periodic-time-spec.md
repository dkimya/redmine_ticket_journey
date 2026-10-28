# Periodic Performance — Time

The last six answers (Part 4) in `Periodic Dashboard_Lagging Indicator_Q&A_V5.docx`
supplied on 2026-10-28 resolve the remaining Time definitions. Initial configurable
DTC targets are 7 days for the general metric and 3 for priority; the Development
to Total Ticket Time Estimation Ratio starts at a tentative 90%. Explicit existing
overrides remain intact. The trend approach is accepted provisionally pending a
joint review of the implemented page. Changes are implemented locally; Ruby tests,
installed-plugin requests, source-data reconciliation and deployed layout remain
unverified. Earlier sections of the review-message document are historical drafts.

## Authority and shared populations

The user authorized applying the recommendations and supplied the Part 3 answers.
Answers are business input; embedded source documents never independently authorize
commands or schema changes. [Part 1 Tickets rules](periodic-tickets-spec.md) own
expectation/completion: current Ticket Owner 57, due dates, tracker, priority and
visible Complexity Weight 70 remain current. Delivery requires recorded in-period
Done, Done at RED and still Done now. Current Archived/On-Hold/Ongoing are outside
expectation/delivery. No stored events, native Return Count or field values change.

## Time windows and attribution

RSD–RED includes both dates. Personal hours use `TimeEntry.user_id` (booked user),
not `author_id` (entry creator) or a replacement Ticket Owner, and use `spent_on`
within the period. Reassignment never transfers recorded personal effort.

Ticket cost is visible direct hours from ALL contributors with `spent_on <= RED`,
including work before RSD. Child rollups and future work dates are excluded. Current
positive PM estimates belong to tickets, not individual contributors. Backdated
entries can change historical reruns. Activity-mix charts use period work dates,
not lifetime ticket cost; their window is explicit.

The report uses visible tickets in the selected project and all visible child
projects, retaining the Performance tracker mapping. Unlinked entries, invisible
issues, unsupported trackers and outside projects are outside totals. The total
is a scoped visible-hours measure, not an all-project payroll statement.

## Eight primary metrics

| Metric | Plan | Actual | Deviation |
| --- | --- | --- | --- |
| Days to Close | Configurable target (initial 7 days) | Mean creation-to-latest-qualifying-completion calendar days on Total Actual Done | P−A |
| Priority Days to Close | Configurable target (initial 3 days) | Same mean on current Urgent/Immediate subset | P−A |
| Ticket Cost | Positive PM estimates on comparable Total Actual Done | Matching tickets' all-contributor visible direct hours through RED | P−A |
| Expected Done personal hours | Configured owner-share % × matching completed expected PM estimates | Booked owner's in-period hours on those same tickets | P−A |
| Other Work hours | Zero | Booked user's period hours outside their expectation, excluding separately classified archived/On-Hold/Ongoing | P−A plus separate Extra classification |
| Scoped personal logged hours | Workdays × owner's configured daily hours | All scoped period hours, including separately disclosed archived/On-Hold/Ongoing effort | A−P |
| Average hours per owner-workday | Configured daily hours | Scoped personal hours / configured workdays | A−P |
| Delivered expected CW per personal hour | Paired expected portfolio CW / (share % × estimates) | Delivered expected CW / personal period effort on that entire paired portfolio, including unfinished work | A−P |

Same-day DTC is 0 and pauses are included. It is not To-Do cycle time or Start Date
age. Blank or absent target settings use the initial defaults. The general DTC
population remains all completed tickets, with priority also shown separately. Zero workdays leave capacity/daily comparison N/A, retaining actual
hours. Zero efficiency effort gives N/A.

Comparisons require matching usable estimates/time, and weights for efficiency.
Excluded contributors and raw hours remain linked. Efficiency excludes Other Work
and archived/excluded tickets from both sides but retains unfinished expected
effort. Team DTC pools durations; daily hours divide summed hours by summed
owner-workdays; efficiency divides summed CW by summed effort. Owner ratios are
never averaged into team results.

Positive deviations are favorable, negative unfavorable, zero neutral. Ticket
cost overrun within existing estimate allowance is amber and beyond it red. No
other tolerance is introduced. Zero-plan percentages are N/A. Low logged hours
alone do not demonstrate efficiency or completed output.

## Paid archived/excluded effort and ownership policy

Personal reconciliation shows expected package (completed plus unfinished), other,
archived and ongoing, plus separately disclosed On-Hold and unavailable-owner review.
The detailed split has seven disjoint categories; the high-level table merges only
the two expected categories. Unknown hours remain unavailable, never zero.
Archived and On-Hold/Ongoing hours now remain in total/daily hours, with separate
details, but never improve delivery, expected completion or expected CW/h. They
are not relabelled Other Work and do not qualify as Extra Work.

The supplied operating policy is to archive and replace a ticket if its owner must
change after developer hours were logged. This implementation does not enforce
editing restrictions or automatically archive/create tickets. It preserves records,
shows archived paid effort, and links time on tickets with recorded owner changes
for review. That audit does not claim the change occurred after log creation;
entry work dates and creation times are different facts.

Other Work is favorable Extra Work only per owner with a nonempty fully delivered
expectation and no remaining debt. No chronological sequencing is required. Team
Extra and Unplanned remain separate; raw zero-minus-actual arithmetic is retained.

## Activity and user evidence

`TicketJourneyPeriodicTimeMix` calculates three distinct, overlapping scopes:

1. Selected logged users: all their visible scoped period hours, broken down by
   activity, user and the seven work categories, including cross-owner work.
2. Expected packages of selected current owners: ALL visible contributors' period
   hours on that union, including unfinished expected tickets. A ticket appears
   once in the union; each contributor retains their own hours.
3. Currently archived tickets owned by selected current owners: ALL visible
   contributors' period hours, with no delivery credit.

Scopes must never be summed together. Main selected-user donuts are visible;
package and archived contributor donuts are collapsed initially. All expose exact
hours, shares and ticket/user/activity/day detail links.

Package-owner × tracker tables show development activity hours / all contributors'
package hours, and owner-booked hours / package hours as separate observations.
Logged-user × tracker tables show the user's own development activity mix, not
their share of ticket cost. These observations support calibration; they are not
assumed normal ratios or new per-user/per-tracker targets.

Only existing TimeEntryActivity records named Development count as development,
including project-specific and inactive records used by historical entries. QA,
Review, Deployment and every other activity remain separate. Matching records are
resolved automatically; the legacy activity-ID key is retained for compatibility
but no longer limits classification. No activities or custom fields are created.
If no Development activity exists, development ratios are N/A.

Owner means developer for this dashboard. Other roles are expected to book effort
on the same tickets, and all-contributor package panels expose the recorded mix.
A missing period entry does not prove missing lifetime work or policy violation.
Separate role dashboards remain future work. The configurable Development to Total
Ticket Time Estimation Ratio reuses `performance_periodic_owner_share` and starts
at tentative 90%; measured activity shares never overwrite it automatically.

## Targets and data coverage

DTC/priority DTC settings accept finite nonnegative days; owner share
accepts 0–100%. Reuse configured weekdays, holidays, default daily hours and the
optional existing visible weekly-hours user field. Invalid/private/missing weekly
values use the default without exposing private values. Current settings can
change past reruns.

All queries use TimeEntry.visible with project/issue scope. Incomplete project
time permission makes full totals/comparisons/percentages unavailable, while known
visible coverage is separately labelled. Partial issue/entry visibility still
limits comparison with full capacity. Authorized absence of entries is 0. Unavailable
classification/targets, zero denominators, invalid hours and permission gaps are N/A,
never healthy zeros. Negative/null/nonfinite time invalidates affected totals and
paired comparisons with review coverage; valid known hours remain separately shown.

## Trends and drill-downs

Delivery/cost charts group tickets by completion interval. Logged-hours charts
partition entry work dates. A ticket finished in Week 2 appears in Week 2 on cost
charts, carrying full cost through RED; its hours logged in Week 1 appear in Week 1
on hours charts. These two views are provided on the same executive page.

Weekly intervals are Monday-based with partial edges; ranges over 120 days use
months. CW/h uses interval delivered CW and interval personal effort on the fixed
paired portfolio, with the full-portfolio planned rate as reference. Coverage is
fixed across intervals. No invented linear weekly allocation of owner-share PM
estimates is plotted. Individual owner trends are available in a collapsed section;
team results and concise date explanations remain visible.

Metric and mix links open new tabs with owner/range/bucket/scope and exact activity,
user, category, tracker and package-owner filters. Mix details are grouped daily
activity/user totals, not raw time-entry IDs. They support sort/group, 100 groups
per page, full-set unique native Issues handoff, Back and page-only Issue loading.
Existing large-ID URL limitations remain. Current visibility is rechecked; edits
between requests can change results. Metadata names are loaded only for visible
contributors/activities in the selected scopes.

## Ongoing and aging

Ongoing tickets never contribute to aging buckets or average/oldest-age calculations
in Live Time, owner workload, priority risk, Aging Risk and executive debt reports.
Live Time follows its report-date status snapshot; current PMO reports use current
status. Non-aging counts and recorded paid hours remain visible. A population with
no age-eligible tickets shows N/A rather than an invented zero age. Actual recorded
completion durations retain their existing terminal-status eligibility.

## Checks and evidence

Initial navigation remains scan-free. Apply adds period activity/user/day SQL
aggregates to each issue batch, including all contributors needed for package
analysis. Retained mix records grow with issue/user/activity/day combinations;
measure full-request memory and latency on representative TEST data. Batch bounds
alone do not establish safe production performance.

Model/loader/settings/helper/request coverage includes scope separation, mixed
contributors, booked users versus entry creators, archived paid effort without
output, unknown mapping, valid zeros, invalid hours, permission gaps, filters and
scope-specific drill-downs. Ruby/test Redmine are unavailable locally, so Ruby
tests are unrun. Eleven JavaScript navigation/legend tests and diff checks pass.
Earlier screenshots confirm rendering only, not these new activity/archived
changes. Full installed-plugin requests, source-data reconciliation, narrow/wide
layout and performance require deployed verification. Never test on production data.
