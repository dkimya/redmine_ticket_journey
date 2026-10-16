# Performance Section 1 — questions for Hadi

Hi Hadi,

We are implementing Performance Results — Tickets first, using the supplied design. This includes Open Tickets, cumulative delivery ratios, and the two monthly delivery averages. Returns, Time, and Periodic Performance will follow separately.

Please confirm these calculation and scope decisions:

1. **Day 0 replacement:** Resolved by user approval: monthly metrics use the last three completed calendar months before the selected date’s month. Account creation and ticket Start dates are no longer window boundaries. Cumulative delivery still includes older backlog due by the report date.
2. **Monthly average:** Resolved by user approval: divide both qualifying ticket count and usable complexity weights by 3, including zero-delivery months. Exclude the report month; no partial-month proration.
3. **Extra Tasks:** Resolved: Hadi requested one target of 90% for now. A shared Delivery Target (%) plugin setting applies to both delivery ratios; there is no Extra Tasks adjustment.
4. **Multiple owners:** Resolved on user instruction: combined monthly targets use the arithmetic mean across selected owners, with matching per-owner monthly actuals (combined three-month totals ÷ 3 ÷ owner count). Zero-delivery owners remain included. Any missing/unusable target makes that metric’s target unavailable rather than averaging only a subset. Delivery percentage target remains shared.
5. **Ticket scope:** Proposed included trackers: Bug, Change Request / Improvement, Feature, and Task (Business Jobs). Should User Story or Customer Support also count? Sprint, EPIC, and Milestones are currently excluded. Confirmed by Hadi: include the selected project and all nested subprojects, subject to visibility. Unrelated projects are excluded; employee targets count once.
6. **Open statuses:** Updated per Hadi’s latest feedback: exclude New and On-Hold from Section 1 based on status at the report date. Pending remains open and is the only Stopped category. Ongoing remains open under the existing rule; Archived remains excluded. This supersedes the earlier On-Hold inclusion. Section 2 keeps its separate Archived/Ongoing exclusions.
7. **Done / Due:** Confirm that the numerator includes only Done / Closed tickets within the due-by-date population. Future-due completed tickets are excluded from these ratios but may count toward monthly delivery.
8. **Reopened and archived work:** Should previously completed tickets count as delivered if reopened or archived by the report date? Currently they do not. Repeated completions count a ticket once, using its latest recorded completion for the monthly window.
9. **Ownership:** Should delivery credit belong to the owner at completion or the owner at the report date? Currently all metrics use the owner at the report date. Does “Already Started” mean anyone started the ticket, or the selected developer personally started it?
10. **Started evidence:** Confirmed by Hadi: Not Touched means the ticket has not been In Progress yet. Only In Progress as of/before the report date establishes Started; logged work or later stages alone do not.
11. **Historical fields:** Confirm use of current due dates and Complexity Weight when viewing past dates, consistent with existing PMO reporting. Status and Ticket Owner are reconstructed historically. Current monthly targets also apply to past dates.
12. **Missing data:** Confirm tickets without due dates remain in Not Overdue, but are excluded from delivery ratios and Due Soon. Missing/invalid weights contribute no weight, with a data-quality note. Done tickets without recorded completion dates are excluded from monthly averages.
13. **Tolerance and colors:** Should a shortfall smaller than 10% be green, amber, or red? The specification says negative deviations are red, while also allowing a shortfall below 10%. Is exactly -10% a failure? Currently green means at/above target and red means below; tolerance-based pass/fail is deferred.
14. **Targets and access:** Who maintains Expected Monthly Ticket Count and Expected Monthly Complexity Weight? Who may view other employees' performance and targets? Currently the role permission permits reporting on visible tickets for any selectable owner; there is no separate self-only permission.

Please also provide initial monthly target values per employee, and representative tickets for checking started/not-started, reassignment, reopening, and archiving.
