# Draft message to Hadi

Hi Hadi,

We have implemented provisional Periodic Tickets and Returns based on your
explanations, Excel and designs. The Tickets page has rendered on the server;
ticket-level calculations still require verification. Returns and the revised
Live Return Ticket Metric are implemented locally and await server verification.

The Returns primary metric is incidents / tickets with at least one return,
displayed as a number such as 1.6. Periodic uses Completed from Expectation, with
a separate metric for Total Done including Other Done. Team ratios use combined
counts, not averages of owner ratios. Merge Conflict is included.

Please confirm these provisional choices or send corrections:

1. **Tickets period boundaries:** include all of RSD through RED. Beginning debt
   is measured immediately before RSD, with due dates before RSD.
2. **Planned tasks:** include eligible tasks due during the period, including
   tasks assigned before RSD. Current Ticket Owner, due date and complexity
   weight follow our previously confirmed current-field policy.
3. **Assignment/hotfix:** use recorded Ticket Owner assignment history, never
   silently substitute ticket creation. Hotfix means current Immediate/Hot Fix
   priority, assigned to the current owner during the period. It qualifies even
   without a due date or with a date outside the period; its expected date is an
   in-period due date, otherwise its assignment date.
4. **Category precedence:** beginning debt, then hotfix, then planned task.
   Each ticket contributes once to expected work.
5. **Completion/exclusions:** delivery needs recorded completion during RSD–RED
   and Done / Closed at RED. Archived/Ongoing/On-Hold at RED remove tickets from
   the whole package. Reopening before RED removes delivery; reopening after
   RED does not. Expected work lacking completion evidence remains unresolved
   in debt and is flagged for review. Debt at RED remains unfinished expectation;
   Still Open Now is its currently open subset.
6. **Deviation:** debt and Other Done have zero plan and P−A deviation. Expected
   completion uses completed expected work minus expected workload; Other Done
   cannot improve it. Total Actual Done has a separate output comparison. A
   zero plan gives N/A for deviation percentage.
7. **Return-event window:** count the full recorded return history through RED
   for the selected completed tickets, including returns before RSD. Is this
   correct, or should only incidents occurring during RSD–RED count?
8. **No returned tickets:** show N/A with “No returned tickets” and zero incidents,
   while distinguishing this from no completed tickets. Your TXT also suggests
   zero on approval; which display do you prefer?
9. **Return trends:** group the selected expectation's completed tickets by
   completion week (calendar month for long periods). Each point uses that
   cohort's return history through RED. Counts reconcile to the selected-period
   totals. Should we keep these within-period cohorts, or do you want each point
   to rebuild a separate reporting period's expectation package instead?
10. **Consecutive returns:** retain accumulated same-stage repeats. The donut
    denominator is tickets with at least one consecutive repeat, rather than
    every returned ticket. Labels “3+ returns” and “2+ consecutive” mean >=4 and
    >=3 respectively, with tooltips explaining the boundaries.
11. **Live adjusted metric:** the main Live metric and trends now use returned
    open tickets and numeric incident averages, so the old percentage thresholds
    are removed. The separate existing non-Merge percentage still divides by all
    open tickets and is labelled legacy. Should it stay, be removed, or use a new
    adjusted formula? If changed, please specify both numerator and denominator.
12. **Presentation:** collapsible summary/comparison tables near the beginning,
    followed by KPIs/charts. Multi-owner views include team values and individual
    trends; there is no ranking based only on raw output.

We can revise these rules consistently across cards, tables, trends and ticket
drill-downs after your confirmation.
