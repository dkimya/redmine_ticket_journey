# Draft message to Hadi

Part 2 status, 2026-10-28: Returns questions below have been answered. Full
through-RED history, completion cohorts and non-Merge incidents / all returned
tickets are confirmed; the user approved N/A (not applicable) for no returned
tickets, with 0 counts and genuine adjusted zeros preserved. Live uses open
report-date populations; Periodic uses completed expected work. These changes
are applied locally; source-data/runtime/deployed verification remains pending.
Do not resend old questions 7–11. Only Time-specific definitions remain open.

Part 1 status, 2026-10-28: Hadi answered the original Tickets questions and all
three follow-ups. Do not resend Tickets questions 1–6 below; the body is retained
as the earlier draft. Latest To-Do for current owner, current-status completion,
required hotfix due dates and extraordinary audits are confirmed and applied
locally. See [the confirmed Tickets spec](periodic-tickets-spec.md). Questions
specific to Returns and Time remain pending; Part 1 answers do not confirm their
other formulas or target values. No message has been sent automatically.

Hi Hadi,

We have implemented provisional Periodic Tickets, Returns and Time based on your
explanations, Excel and designs. Tickets and Returns screenshots confirm page
rendering and displayed arithmetic; ticket-level calculations still require
verification. Time and the revised Live Return Ticket Metric are implemented
locally and await server verification.

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

For Time, please also confirm these recommendations:

13. **Days to Close:** calendar days from ticket creation to latest qualifying
    completion, including pauses; same-day closure is zero. Priority uses current
    Urgent/Immediate. Should DTC instead start from Start Date or first In Progress?
    Please provide the DTC and priority DTC targets; they currently default blank.
14. **Ticket cost versus personal time:** ticket cost includes all visible direct
    ticket hours by all contributors through RED, including work before RSD, on
    Total Actual Done including Other Done. Personal hours use only RSD–RED work
    dates. Is this distinction correct? Child rollups are excluded.
15. **Personal attribution:** use the person booked to the time entry (`user_id`),
    even if someone else created it (`author_id`) or the ticket was reassigned.
    Current Ticket Owner still controls ticket delivery and expectation results.
16. **Expected Done comparison:** owner plan = owner-share % × PM estimates of
    completed expected tickets; actual uses the same estimate/time-available
    tickets. Raw hours and exclusions are separate. Please confirm the share %;
    it defaults blank rather than assuming the design's 90%.
17. **Unfinished work:** retain its personal hours in total reconciliation and
    efficiency effort. Do not classify unfinished expectation hours as Other Work.
18. **CW per hour:** actual = delivered expected CW / personal hours on the full
    paired expectation portfolio, including unfinished tickets. Plan = portfolio
    expected CW / (share % × PM estimate). Require usable estimate, weight and
    visible time on the same portfolio. Deviation is A−P because higher is better;
    this provisionally corrects the Excel's P−A label. Do you agree with this basis?
19. **Other Work / Extra Work:** favorable only per owner with a nonempty fully
    completed expectation and zero RED debt. This is an end-of-period judgement,
    not a claim that other work happened after completion. Raw P−A remains in
    audit tables; team Extra and Unplanned stay separate. Should sequencing be
    required instead?
20. **Capacity and scope:** reuse configured weekdays, holidays and per-owner daily
    hours. Logged totals cover visible eligible tickets in the selected hierarchy;
    unlinked/out-of-scope entries are excluded. Is that the intended scope, or do
    you want a separate all-project personal-hours report?
21. **Time trends:** DTC/cost use completion cohorts; personal hours use work dates.
    CW/h compares interval delivered CW to interval effort on the fixed portfolio.
    No estimated weekly allocation is invented. Keep weekly intervals (monthly
    for long ranges), or add separate independently rebuilt monthly reports?
22. **Missing data:** blank targets, unavailable permissions and zero-effort ratios
    show N/A; authorized zero entries remain zero. Missing estimates/weights are
    excluded from paired comparisons with raw totals and review links. Keep this?

We can revise these rules consistently across cards, tables, trends and ticket
drill-downs after your confirmation. These questions are a draft for review;
no message has been sent automatically.
