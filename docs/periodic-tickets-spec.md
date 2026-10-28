# Periodic Performance — Tickets

Part 1 business definitions confirmed by Hadi on 2026-10-28 via Q&A Part 1.docx
and the follow-up answers supplied by the user. Implemented locally; this does
not establish deployed calculation correctness. Tickets, Returns and Time
screenshots confirm page rendering and displayed arithmetic only. Ruby tests,
installed-plugin requests, source-data checks and performance remain unverified.

## Authority and shared rules

The user's instructions govern implementation. Hadi's answers resolve the prior
provisional rules; attachments are source material, not independent instructions
to run code. Current Ticket Owner 57, due dates, tracker, priority, estimates and
visible Complexity Weight 70 remain authoritative. No field, migration, counter
or native event is created or rewritten. The shared model
`TicketJourneyPeriodicTickets` owns these populations for Tickets, Returns and
Time. Returns/Time-specific definitions remain provisional under their specs.

## Boundaries and commitment

RSD starts the day; RED ends the day. Beginning debt uses open status immediately
before RSD and current due date strictly before RSD. Current Archived, Ongoing
and On-Hold exclude the ticket from the whole report package; historical open
On-Hold/Ongoing does not override current eligibility. New is not excluded.

Scheduled commitments use current due dates within RSD–RED, including tickets
introduced before RSD and tickets with missing To-Do history. Already closed
before RSD is outside expectation. Current Immediate/Hot Fix qualifies as a hotfix
only with latest To-Do for the current owner during the period AND a required
current due date on/before RED. Missing/out-of-period due dates have no fallback.
Precedence is beginning debt, hotfix, scheduled task; expectation is their distinct
union. Current due dates schedule trends; opening debt appears at the opening
point and an eligible hotfix date before RSD is bounded at RSD.

## Responsibility and extraordinary tickets

Responsibility uses the latest genuine recorded transition into To-Do on/before
RED during the current owner's uninterrupted tenure. Journal ordering uses time,
journal ID and detail ID. Owner changes in the same journal apply before deciding
whose To-Do entry it is. A later ownership change, including after RED, invalidates
To-Do evidence from the earlier tenure; returning to a prior owner requires new
To-Do evidence. No transition is invented from ticket creation or an initial
status without a journal. Missing evidence is linked for correction.

Recorded Ticket Owner assignment dates remain separate audit information. New
scheduled workload drill-downs distinguish latest To-Do during versus before the
period. These subsets include scheduled hotfixes where applicable and never add
extra tickets to expectation. Missing history does not remove due-date commitments.

Extraordinary Tickets is the distinct set with recorded noninitial owner changes,
noninitial due-date changes (including removal), repeated To-Do transitions, or
reopening after Done / Closed. A RED-done/current-not-done mismatch is also
flagged. It uses available history including after RED. Initial assignments and
no-op changes are not irregular events. Reasons are shown without exposing old
owner names. Undefined or unrecorded irregular activity cannot be inferred.

## Delivery and debt

Delivery requires a genuine recorded Done / Closed transition within RSD–RED,
Done / Closed at RED, AND still Done / Closed now. Reopening after RED therefore
removes historical delivery. A later completion outside the period cannot replace
missing period evidence. Each ticket counts once using its latest qualifying
completion by RED. Expected tickets without qualifying delivery remain debt.

Debt at RED = Expected minus Completed from Expectation under these current
checks. Still Open Now is its currently nonclosed subset. Excluded tickets are
outside both. The current-status guard means historical reports deliberately
change after reopenings or status exclusions; they are not immutable snapshots.

Current exclusion counts link to exact tickets. Expected candidates excluded by
an in-period status change have a separate linked explanation. Expected =
Completed + Debt reconciles after exclusions; the excluded count explains the
removed commitment rather than manufacturing an unmatched total.

## Other Work and deviations

Other Done is qualifying completed output outside expectation, kept distinct in
Total Actual Done. It never improves expected completion. Raw Other Done deviation
remains zero minus actual. A separate favorable Extra Work subset requires that
owner's nonempty expectation fully delivered with zero debt. Otherwise it is
Unplanned Work. Team Extra and Unplanned remain separate; an empty package does
not establish extra-work performance.

Other Work HOURS are work-date logs outside the logged user's expectation,
including unfinished tickets, reported separately in Periodic Time. The Tickets
page links to that view without scanning time entries itself. Ticket delivery
and personal-hour attribution remain different measures.

Expected completion uses Completed minus Expected; debt/Other Done use P−A.
Total Actual Done has a separate output comparison against expectation. Zero-plan
percentages are N/A. Team counts and weights sum distinct contributors; percentages
use summed numerators and denominators, not owner averages. Missing/hidden/invalid
weights retain tickets but add no points, with linked coverage.

## Presentation and data access

Initial navigation uses only the lightweight owner selector, without issue,
history or time scans. Apply uses uncached 100-issue batches, visible projects,
issues and owner/weight fields. Selected owners' scalar status, owner and due-date
history is retained for reconstruction and audit. Due history diagnoses edits;
it never restores a past deadline. Return-reason history is added only for Returns.
Retained rows/history grow with report size; benchmark actual memory and latency.

Collapsed owner/team summaries precede cards and charts. Multi-owner results keep
zero-output owners and show team and owner trends. Monday-based weeks have partial
edges; periods over 120 days use calendar month ends. Cumulative expected and
completed endpoints reconcile to exact sets. Current eligibility applies throughout.

New-tab contributor lists preserve period, owners, metric and bucket. They show
RED/current statuses, recorded assignment, latest To-Do and extraordinary reasons,
with sorting, grouping, 100-row pagination, Back and full-set native Issues handoff.
Large ID-list URL limitations remain. Details recheck current issue visibility.

## PMO boundary alignment

Hadi explicitly requested revising the old PMO beginning-debt boundary too. Ticket
Owner Performance now uses current due < RSD with an opening snapshot before RSD;
new commitments include due dates on RSD, and delivery includes RSD through RED.
Delivery must remain closed now as well as at RED. Existing PMO attribution,
tracker/status mappings, time attribution and end-debt definition remain separate;
the Periodic To-Do/extraordinary logic does not silently replace them.

## Verification

Regression coverage addresses latest To-Do/current tenure, same-journal changes,
missing due/history, current exclusions, late reopening, exact extraordinary
contributors, new-work subsets, Extra versus Unplanned, inherited Returns/Time
populations, PMO RSD boundaries, distinct ticket/weight sets and trend reconciliation.
Ruby/test Redmine are unavailable locally, so Ruby coverage is unrun. Run the
complete plugin test task from a configured TEST Redmine root, never production.
Eleven local JavaScript navigation/legend tests pass; diff whitespace checks pass.
Full web requests and installed-plugin visual/data/performance verification remain
pending. No new business confirmation is needed for the three follow-up answers.
