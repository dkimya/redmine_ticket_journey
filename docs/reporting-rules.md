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

## Future

Automated return alarms, notifications, and alarm KPI cards are deferred; no implementation is claimed.
