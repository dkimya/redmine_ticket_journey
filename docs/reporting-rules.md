# Reporting rules

Reviewed against code and conversation on 2026-10-13. **Implemented** means present in code, not necessarily server-verified. See [known issues](known-issues.md) for evidence and differences requiring confirmation.

## Historical reporting and due dates — implemented

- Team Performance reconstructs status/owner history, completion events, returns, and dated activity. It is not an immutable snapshot of every field.
- Beginning debt A: created by and open at report start (RSD), with **current due date on/before RSD**; snapshot is RSD end of day.
- New commitment B: current due date after RSD through report end (RED), excluding tickets already closed at RSD. C is the distinct union of A and B.
- End debt I: open at RED end of day, current due date on/before RED. I1 is now paid; I2 remains open at generation time. I is debt that existed at RED, not just today's remaining debt.
- H/H+ count qualifying closures from RSD+1 through RED, still closed at RED. T is their distinct total. Activity D/E/F covers RSD through RED. Preserve these different date boundaries.
- Commitment outcomes stay with the commitment owner; activity uses ownership at the event; end debt uses ownership at RED. Return audit retains event ownership; delivery attribution prefers the delivery owner. Current owner is a fallback when history is unavailable; role membership is current.
- Blank current due dates remain missing. Current deadline edits can change past report results. Filters select the report population; historical reconstruction does not override that selection.

## Carry-over — implemented

Within the selected sprint's related scope: **current ticket due date < sprint start date**. Equal dates are not carry-over; missing due date or sprint start cannot qualify. Original Sprint is reference only. Completed work can count as carry-over; Technical Debt includes unfinished carry-over. Remaining Current Scope includes missing-date tickets, also flagged separately.

## Returns — implemented

- “Consecutive Returns” means **cumulative lifetime returns**, across qualifying stages/reasons. Progress and completion never reset it.
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

- Separate project menu and permission under Dashboard. One owner, one project, visible issues only. Included trackers: Bug, Change Request / Improvement, Feature, Task (Business Jobs). All non-closed statuses count as open. User Story and containers are excluded pending clarification.
- Status and owner are reconstructed at report-date end of day by reversing later journal changes. Missing history falls back to current values; recorded blank owners stay blank. Current due dates and visible current weights (#70) are preserved. Hidden Ticket Owner (#57) fields exclude issues from this report.
- Open groups partition the total: Not Overdue (including missing due dates), overdue started, overdue untouched. Due date equal to report date is not overdue. Due Soon covers today through +2 calendar days. Started means current/as-of development stage or recorded earlier In Progress, Feedback, Returned, Review, Ready to Merge, Final Check, or Done / Closed; it does not require activity by the selected owner personally.
- Due population has current due date on/before report date, including older backlog. Done numerator is the subset in Done / Closed at report date. Archived/reopened work does not qualify. Each ticket counts once; no due date excludes tickets from both ratios. Zero denominators show N/A.
- Monthly averages require configured common Day 0. Count distinct tickets still Done / Closed whose latest recorded completion is in the inclusive Day-0-to-report-date window. Ownership is at report date. Divide by calendar months with partial months prorated by their actual day count. Missing completion dates exclude tickets from monthly averages with a note.
- Targets use selected numeric User custom fields and current positive finite values. Non-admins see only public fields. No fields or target values are created automatically. Extra Tasks has no confirmed source, so the 80%/90% target remains unconfigured. Multiple owners and tolerance-based pass/fail are deferred. Below-target monthly deviation is red; at/above target is green.
- Missing/hidden/nonpositive/nonfinite weights contribute no weight and are reported in notes. Monthly fields, Day 0 and web behavior require setup/verification; see [setup](performance-setup.md) and [Hadi questions](performance-hadi-questions.md).

## Future work

Automated return alarms, notifications, and alarm KPI cards are deferred; no implementation is claimed.
