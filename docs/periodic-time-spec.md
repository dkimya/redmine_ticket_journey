# Periodic Performance — Time

Part 3 answers supplied on 2026-10-28 confirm calendar Days to Close, ticket cost
versus personal hours, booked-user attribution, paired efficiency with A−P,
Extra/Unplanned separation, project hierarchy and missing-data treatment. More
evidence is requested before adopting an owner/development-share target. The
trend explanation was not understood; the existing windows are retained with
plain labels/examples on this same page, rather than assuming approval of new
independent monthly dashboards. Implemented locally; runtime, deployed layout,
source-data reconciliation and measured performance remain unverified.

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
| Days to Close | Optional target | Mean creation-to-latest-qualifying-completion calendar days on Total Actual Done | P−A |
| Priority Days to Close | Optional separate target | Same mean on current Urgent/Immediate subset | P−A |
| Ticket Cost | Positive PM estimates on comparable Total Actual Done | Matching tickets' all-contributor visible direct hours through RED | P−A |
| Expected Done personal hours | Configured owner-share % × matching completed expected PM estimates | Booked owner's in-period hours on those same tickets | P−A |
| Other Work hours | Zero | Booked user's period hours outside their expectation, excluding separately classified archived/On-Hold/Ongoing | P−A plus separate Extra classification |
| Scoped personal logged hours | Workdays × owner's configured daily hours | All scoped period hours, including separately disclosed archived/On-Hold/Ongoing effort | A−P |
| Average hours per owner-workday | Configured daily hours | Scoped personal hours / configured workdays | A−P |
| Delivered expected CW per personal hour | Paired expected portfolio CW / (share % × estimates) | Delivered expected CW / personal period effort on that entire paired portfolio, including unfinished work | A−P |

Same-day DTC is 0 and pauses are included. It is not To-Do cycle time or Start Date
age. DTC targets remain blank unless configured. A missing target does not suppress
valid actuals. Zero workdays leave capacity/daily comparison N/A, retaining actual
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

Personal reconciliation has six disjoint categories: completed expected,
unfinished expected, other, archived, On-Hold/Ongoing, and unavailable-owner review.
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
   activity, user and the six work categories, including cross-owner work.
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

Development activities are explicitly selected from existing TimeEntryActivity IDs
in optional `performance_periodic_development_activity_ids` (default empty). The
selector shows IDs so applicable project-specific activities can be selected.
No name guessing, duplicate enumeration, custom field, counter or migration is
introduced. Blank mapping leaves development ratios N/A while all activity shares
remain visible. The activity names requested from the user remain a configuration
input if not supplied. The 90% working estimate is visible context, not a new
stored default or a silently inferred target. Existing owner-share settings remain
configurable and unchanged; measured shares never automatically overwrite them.

## Targets and data coverage

Optional DTC/priority DTC settings accept finite nonnegative days; owner share
accepts 0–100%. Reuse configured weekdays, holidays, default daily hours and the
optional existing visible weekly-hours user field. Invalid/private/missing weekly
values use the default without exposing private values. Current settings can
change past reruns.

All queries use TimeEntry.visible with project/issue scope. Incomplete project
time permission makes full totals/comparisons/percentages unavailable, while known
visible coverage is separately labelled. Partial issue/entry visibility still
limits comparison with full capacity. Authorized absence of entries is 0. Missing
mapping/targets, zero denominators, invalid hours and permission gaps are N/A,
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
