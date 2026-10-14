# Performance Section 1 — questions for Hadi

Hi Hadi,

We are implementing Performance Results — Tickets first, using the supplied design. This includes Open Tickets, cumulative delivery ratios, and the two monthly delivery averages. Returns, Time, and Periodic Performance will follow separately.

Please confirm these calculation and scope decisions:

1. **Day 0:** What date should reporting start? Is it company-wide, project-specific, or each employee's start date? Should cumulative delivery exclude tickets due before Day 0, or include the older backlog? Current provisional ratios include all tickets due by the report date; monthly averages require a configured common Day 0.
2. **Monthly average:** Should partial months be prorated by calendar days, or should we use completed months only? The provisional implementation prorates partial months, includes the report date, and includes zero-delivery months.
3. **Extra Tasks:** Resolved: Hadi requested one target of 90% for now. A shared Delivery Target (%) plugin setting applies to both delivery ratios; there is no Extra Tasks adjustment.
4. **Multiple owners:** Can the first release use one owner at a time? Later, should monthly employee targets be summed? The delivery percentage target is now shared.
5. **Ticket scope:** Proposed included trackers: Bug, Change Request / Improvement, Feature, and Task (Business Jobs). Should User Story or Customer Support also count? Sprint, EPIC, and Milestones are currently excluded. Confirmed by Hadi: include the selected project and all nested subprojects, subject to visibility. Unrelated projects are excluded; employee targets count once.
6. **Open statuses:** Hadi confirmed On-Hold and Pending remain open and should appear as a small Stopped count under Total Open Tickets. New and Ongoing also currently count as open; please confirm those. Archived is excluded from open tickets and never treated as delivered.
7. **Done / Due:** Confirm that the numerator includes only Done / Closed tickets within the due-by-date population. Future-due completed tickets are excluded from these ratios but may count toward monthly delivery.
8. **Reopened and archived work:** Should previously completed tickets count as delivered if reopened or archived by the report date? Currently they do not. Repeated completions count a ticket once, using its latest recorded completion for the monthly window.
9. **Ownership:** Should delivery credit belong to the owner at completion or the owner at the report date? Currently all metrics use the owner at the report date. Does “Already Started” mean anyone started the ticket, or the selected developer personally started it?
10. **Started evidence:** Confirmed by Hadi: Not Touched means the ticket has not been In Progress yet. Only In Progress as of/before the report date establishes Started; logged work or later stages alone do not.
11. **Historical fields:** Confirm use of current due dates and Complexity Weight when viewing past dates, consistent with existing PMO reporting. Status and Ticket Owner are reconstructed historically. Current monthly targets also apply to past dates.
12. **Missing data:** Confirm tickets without due dates remain in Not Overdue, but are excluded from delivery ratios and Due Soon. Missing/invalid weights contribute no weight, with a data-quality note. Done tickets without recorded completion dates are excluded from monthly averages.
13. **Tolerance and colors:** Should a shortfall smaller than 10% be green, amber, or red? The specification says negative deviations are red, while also allowing a shortfall below 10%. Is exactly -10% a failure? Currently green means at/above target and red means below; tolerance-based pass/fail is deferred.
14. **Targets and access:** Who maintains Expected Monthly Ticket Count and Expected Monthly Complexity Weight? Who may view other employees' performance and targets? Currently the role permission permits reporting on visible tickets for any selectable owner; there is no separate self-only permission.

Please also provide the approved Day 0, initial monthly target values per employee, and representative tickets for checking started/not-started, reassignment, reopening, and archiving.
