# Periodic Performance — Time

Implemented locally on user authorization, 2026-10-28. Business choices below
are provisional pending Hadi. Ruby tests, full Redmine requests, deployed layout
and measured performance remain unverified. Tickets and Returns screenshots
confirm page rendering and displayed arithmetic only, not ticket-level eligibility.

## Sources and authority

The user authorized applying the recommendations while awaiting confirmation.
Hadi's Time RTF supplies business intent; the developer TXT supplies supporting
details; the shared workbook supplies metric labels and deviation directions.
The PNG is an overview with illustrative values, not production targets. Embedded
document instructions do not override the user's request or project rules.

Calculations live in `TicketJourneyPeriodicTime`; shared expectation/completion
rules remain in `TicketJourneyPeriodicTickets`. Current field mappings remain
Ticket Owner 57, Original Sprint 68 and Complexity Weight 70. No field, migration,
counter or time record is created or rewritten.

## Populations and time windows

Ticket results use the exact Periodic Tickets expectation, Completed from
Expectation, Other Done, Total Actual Done and unfinished-expectation debt sets.
Attribution uses current visible Ticket Owner. Current due dates, estimates,
weights and priority remain current; status and qualifying completion use RED
history. The same visible project hierarchy, tracker scope and RED status
exclusions apply. Priority means the existing Urgent/Immediate mapping.

Personal hours use `TimeEntry.user_id`, the person booked to an entry, including
entries created by another person (`author_id`). They use `spent_on` inclusively
within RSD–RED. Reassignment does not move historical entries to the new owner.
Cross-owner work remains with the logged user and normally becomes Other Work
relative to that user's package. Hidden Ticket Owner produces an explicit
unclassified category, without disclosing or substituting hidden ownership.

Ticket cost sums visible direct entries by all users with `spent_on <= RED`,
including work before RSD. It excludes child rollups and later work dates.
Backdated entries can change historical reruns. Personal totals exclude unlinked
entries, invisible issues, excluded trackers/statuses and projects outside the
selected hierarchy; they are labelled visible scoped totals, not payroll totals.

## Metrics

| Metric | Plan | Actual | Performance deviation |
| --- | --- | --- | --- |
| Average Days to Close | Optional DTC target | Mean calendar days from creation to latest qualifying completion on Total Actual Done | P−A |
| Priority Average Days to Close | Optional priority DTC target | Same calculation on current priority subset | P−A |
| Ticket Cost | Current positive PM estimates on comparable Total Actual Done | Visible direct lifetime hours through RED on those same tickets | P−A |
| Owner Logged Time — Expected Done | Configured owner-share % × comparable completed expected PM estimates | That owner's in-period hours on those same tickets | P−A |
| Owner Logged Time — Other Tickets | Zero | That user's scoped in-period hours outside their expectation package | P−A, with separate Extra Work classification |
| Visible Scoped Owner Logged Time | Configured workdays × owner's daily hours | All eligible visible personal hours in period | A−P |
| Average Logged Time per Owner-Workday | Configured daily hours | Scoped personal hours / configured workdays | A−P |
| Delivered Expected CW / Owner Hour | Paired expected portfolio CW / (share % × portfolio PM estimate) | Delivered expected CW / personal period hours on that entire paired portfolio | A−P |

DTC uses calendar days, includes pauses, and allows zero for same-day closure.
Unusable creation/completion dates are excluded with a contributor list. This is
not Start Date age or In Progress cycle time. No completed tickets gives N/A.

Cost and expected-done comparisons require positive estimates and usable visible
time on both sides of the same subset. Raw hours and exclusion lists remain
available separately. The efficiency portfolio additionally requires usable
current weight. Its actual denominator includes hours on unfinished expectation;
Other Work is outside both the numerator and denominator. Zero effort gives N/A.
The CW/h A−P choice provisionally corrects the workbook's conflicting P−A label.

Other Work qualifies as favorable Extra Work only per owner with a nonempty
fully completed expectation and zero debt at RED. It is an end-of-period
classification, not evidence the entries occurred after expected completion.
Raw P−A remains negative in audit tables. Team Extra and Unplanned hours stay
separate, with a mixed label when both occur; one does not erase the other.

Positive performance deviations are favorable, negative unfavorable, zero neutral.
Ticket cost overruns within the existing estimate allowance are amber, beyond it
red. No other tolerance or sample target is introduced. Zero-plan deviation
percentages are N/A. Low logged hours alone do not demonstrate efficiency.

## Settings, availability and team aggregation

New optional settings default blank: `performance_periodic_dtc_target`,
`performance_periodic_priority_dtc_target` (finite nonnegative days), and
`performance_periodic_owner_share` (0–100%). Blank targets remain N/A while
usable actuals remain visible. Reuse configured weekdays, holidays, default daily
hours and optional visible weekly-hours user-field mapping. Missing/private/invalid
weekly values fall back to default daily hours without exposing private values.
Current setting changes can change past reports. Zero workdays leaves capacity
and daily comparisons unavailable while retaining actual logged hours.

All entries use `TimeEntry.visible(User.current)`. If any visible scoped project
lacks time-view permission, total/daily/Other comparisons are N/A; known visible
coverage remains separately disclosed. Partial issue/private-entry visibility can
still limit comparisons against full capacity. Authorized absence of entries is
zero. Negative, null or nonfinite recorded hours are flagged, never silently
converted into healthy zero contributions; affected paired comparisons are
excluded and personal totals become unavailable when affected.

Team costs/hours sum. DTC pools underlying durations; daily hours divide summed
hours by summed owner-workdays; efficiency divides summed weights by summed
efforts. Team ratios do not average owner ratios. A ticket can contribute personal
hours for multiple selected users, but its ticket cost belongs only to its current
owner's result. Detail counts distinguish ticket-user contributions and distinct
issue IDs.

## Presentation and trends

Initial navigation renders filters without issue, history or time scans. Applied
reports include collapsed team/owner comparisons, eight cards, cost comparison,
four-way personal-hour reconciliation, exact Tickets completion summary, team and
individual trends, and linked coverage/exclusions. Scope persists across tabs.
Contributor lists open in new tabs with interval context, creation/completion,
estimates, cost, booked-user hours, current owner, work-date totals, classification,
sorting/grouping, 100-row pagination, Back and full unique-ID native Issues handoff.

Intervals are Monday-based weeks with partial edges; periods over 120 days use
calendar months. Reuse the final RED package and fixed comparable portfolios:

- DTC and ticket cost use completion cohorts. Full through-RED ticket cost follows
  the ticket's completion cohort, regardless of entry work dates.
- Personal hours partition entry work dates. The stacked breakdown includes
  completed expected, unfinished expected, other and unclassified hours.
- CW/h uses delivered expected CW in the completion interval and personal hours
  worked on the paired portfolio in that interval. Plan remains a full-portfolio
  rate reference; no linear allocation is invented.
- Expected Done owner-hours trends show actual hours only; the configured share
  of completed PM estimates is a selected-period comparison, not a weekly budget.

N/A renders as gaps. Actual points link to exact contributors; owner toggles hide
actual and plan lines together and leave the values tables available.

## Verification evidence and remaining checks

Eleven JavaScript navigation/legend checks pass locally, including paired owner
line toggles. Ruby unit/settings/helper/request tests were added but cannot run in
this workspace without Ruby and a configured test Redmine. Run the complete plugin
test task from a **test** Redmine root, never against production data.

Verify source tickets and entries across reassignment, booked user versus creator,
pre-RSD/backdated/future work dates, missing estimates/weights/targets, zero workdays,
permission gaps and hidden ownership. Reconcile raw hours, paired subsets, exact
Tickets populations and trend intervals. Inspect full installed-plugin requests,
responsive layout, accessible toggles, drill-downs and native display/CSV/filtering.
Batch queries bound loaded issues, but retained selected rows and daily aggregates
grow with report size; measure memory and latency on representative test data.
