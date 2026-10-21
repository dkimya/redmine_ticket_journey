# Performance Dashboard — current tooltip review

Prepared for Hadi. Current local wording; no wording changes have been applied.

Scope: Performance Tickets, Returns, trends, audit links, drill-downs and shared navigation. PMO-specific report tooltips are a separate inventory. Repeated identical tooltips are listed once with their locations. Brackets indicate dynamic values. Screen-reader-only labels and ordinary visible calculation notes are excluded.

Total: 39 distinct entries.

Please mark each entry: Keep / Simplify / Clarify calculation / Move details to Calculation notes.

## 1. Tickets → scope line below header

Type: Information icon

> Includes Bug, Change Request / Improvement, Feature, and Task (Business Jobs). User Story and other trackers are excluded provisionally. Current Ticket Owner is used for all dates, cards and trends; reassignment updates historical attribution. Status is reconstructed at the selected date; current due dates and weights are used. Missing status history falls back to current status. Owner-change history remains available in the audit.

Review / suggested wording:

---

## 2. Tickets → Section 1: Open Tickets heading

Type: Information icon

> New and On-Hold at the selected report date are excluded from open-ticket counts, weights, breakdowns, and Due Soon. Other non-closed statuses, including Pending and Ongoing, remain included. Stopped means Pending only and is a subset of Total Open Tickets. Archived is closed and is not a delivery. Missing due dates are included in Not Overdue; due today is not overdue. Not Touched means the ticket has not been In Progress by the report date. Logged time, comments, and later workflow stages alone do not establish Started. Earlier In Progress history, including before reassignment, still counts. Section 2 retains its separate rules.

Review / suggested wording:

---

## 3. Tickets → Total Open Tickets card → Stopped

Type: Information icon

> Open tickets in Pending at the selected report date. New and On-Hold are excluded. Already included in Total Open Tickets and the three breakdown groups; do not add this count to the total.

Review / suggested wording:

---

## 4. Tickets → Not Overdue card → Due soon (<3 days)

Type: Information icon

> Due today, tomorrow, or the following day. Tickets without a due date are excluded from Due Soon.

Review / suggested wording:

---

## 5. Tickets → Section 2: Delivery Metrics heading

Type: Information icon

> Cumulative delivery uses tickets with a current due date on or before the report date. The numerator includes only those tickets in Done / Closed at that date. Archived and Ongoing tickets at the selected report date are excluded from all Section 2 counts and weights, including the due denominator. Reopened tickets are not counted as done. No due date means excluded from both delivery ratios. Each ticket counts once.

Review / suggested wording:

---

## 6. Tickets → both delivery ratio cards → Target

Type: Information icon

> Shared delivery target configured in Administration → Plugins → PMO Dashboard → Configure. Default: 90%. Applies to both delivery ratios for all employees and projects, including past report dates. No Extra Tasks adjustment. Monthly employee targets are separate.

Review / suggested wording:

---

## 7. Tickets → both Average Monthly Delivered card headings

Type: Information icon

> Uses the three complete calendar months before the selected date’s month. Qualifying completed ticket count or current usable complexity weight is divided by 3, including zero-delivery months. With multiple owners, divide actuals again by the selected owner count and compare with the arithmetic mean of their monthly targets. Every selected owner counts, including zero-delivery owners. If any owner target is missing, hidden, invalid, or nonpositive, that metric’s combined target and deviation are unavailable. Tickets must be Done / Closed at the report date, with latest completion inside the window; Archived, Ongoing, and reopened tickets are excluded. Current Ticket Owner is used even for past dates. Current weights and targets are used; account creation and ticket Start dates do not change the window.

Review / suggested wording:

---

## 8. Tickets → average delivery cards → % vs Target

Type: Information icon

> Green means at or above target; red means below target. The separate requirement allowing a shortfall below 10% awaits clarification; this color is not a final tolerance-based pass/fail result.

Review / suggested wording:

---

## 9. Tickets → both average cards → Per owner / arithmetic mean targets line

Type: Hover text; multiple owners only

> Actual = combined three-month total ÷ 3 ÷ selected owner count. Target = sum of selected owners’ monthly targets ÷ selected owner count. Owners with zero deliveries still count.

Review / suggested wording:

---

## 10. Tickets → left chart → Delivery ratio trend heading

Type: Information icon

> Each point uses the current Ticket Owner and reconstructs ticket status at that month-end. Includes all tickets with a current due date on or before that date; Done / Closed is the numerator. Archived and Ongoing are excluded. Current due dates and visible current complexity weights are used, so later edits can change historical results. Combined ratios use summed counts or weights, not averages of employee percentages. This is cumulative delivery, not output during that month. The target is the current configured delivery target.

Review / suggested wording:

---

## 11. Tickets → right panel → Monthly Delivery Trend heading

Type: Information icon

> Each point shows tickets and visible current complexity points delivered during that calendar month. Tickets must be Done / Closed at that point, with their latest recorded completion inside the window; Archived, Ongoing, reopened tickets and missing completion dates are excluded. Current Ticket Owner is used at every point; reassignment updates historical results. With multiple owners, divide by all selected owners, including zero-delivery owners. Current weights and current employee targets apply. Each target requires a usable value for every selected owner. Each point is actual output for one month, not a rolling average. The cards above retain their three-month averages; later reopening can cause differences.

Review / suggested wording:

---

## 12. Returns → scope line below header

Type: Information icon

> Uses the Tickets tracker scope and current-owner attribution and historical status reconstruction. Returns uses the same open population as Tickets: New, On-Hold, and closed statuses are excluded; Ongoing is included in all return populations and ratio denominators. Only recorded qualifying transitions into Returned through this date count. Current tracker mappings apply. All qualifying incidents belong to the current Ticket Owner, including incidents before reassignment. No time window or Day 0 applies.

Review / suggested wording:

---

## 13. Returns → comparison table → Number of Tickets with Consecutive Returns; also Returns drill-down → Consecutive Returns column

Type: Information icon

> Each return from the same stage as the previous return adds 1 consecutive return. Counts accumulate across stages. Example: Feedback → Feedback → Final Check → Final Check = 2 consecutive returns.

Review / suggested wording:

---

## 14. Returns → comparison table → 3+ returns column

Type: Column-header hover text

> 4 or more returns

Review / suggested wording:

---

## 15. Returns → comparison table → 2+ consecutive returns column

Type: Column-header hover text

> 3 or more accumulated consecutive returns

Review / suggested wording:

---

## 16. Returns → Section 1: Return Count Distribution heading

Type: Information icon

> All open tickets partition into 0, 1, 2, 3, and 4-or-more qualifying returns by report date. The approved 3+ label means more than 3.

Review / suggested wording:

---

## 17. Returns → Section 2: Consecutive Return Distribution heading

Type: Information icon

> Each return from the same stage as the previous return adds 1 consecutive return. Counts accumulate across stages. Example: Feedback → Feedback → Final Check → Final Check = 2 consecutive returns. Only open tickets with at least one repeat are included in this chart. Buckets are 1, 2, and 3-or-more repeats; 2+ means more than 2.

Review / suggested wording:

---

## 18. Returns → Section 3: Open Tickets Return Metric heading

Type: Information icon

> Return incidents divided by open tickets, displayed as a percentage. This is not the percentage of tickets returned and can exceed 100%. One ticket can contribute many incidents. Values use ordinary rounding to one decimal place.

Review / suggested wording:

---

## 19. Returns → below shared color legend

Type: Information icon

> Both cards use the same thresholds, applied to the unrounded ratio. Displayed percentages are rounded to one decimal place.

Review / suggested wording:

---

## 20. Returns → Return ratio trend heading

Type: Information icon

> Each point uses tickets open at that month-end, currently owned by the selected owners, and their qualifying return incidents recorded up to that date. This is a month-end snapshot, not returns occurring only during that month. Current project hierarchy, tracker mappings and visibility apply. Missing Return Reason makes the adjusted point unavailable; zero open tickets makes both points unavailable.

Review / suggested wording:

---

## 21. Tickets and Returns → owner-change count/link below trends

Type: Information icon; dates vary

> [period start] – [period end]. Each visible in-scope ticket counts once when an existing Ticket Owner is changed or removed and a selected owner is involved. Initial assignments from no owner are excluded. All report metrics use the current Ticket Owner; this audit retains recorded previous/new owners.

Review / suggested wording:

---

## 22. Tickets drill-down → Options checkbox and column heading → Title / Subject

Type: Column hover text

> The current ticket title is Redmine’s Subject field.

Review / suggested wording:

---

## 23. Tickets drill-down → Options checkbox and column heading → Priority

Type: Column hover text

> Current ticket priority, not a historical priority snapshot.

Review / suggested wording:

---

## 24. Tickets drill-down → Options checkbox and column heading → PM Estimate

Type: Column hover text

> Current Redmine Estimated time (PM estimate) in hours; not Ticket Owner Estimation.

Review / suggested wording:

---

## 25. Tickets drill-down → Options checkbox and column heading → Time Spent

Type: Column hover text

> Lifetime visible time entries logged directly against this ticket, in hours. No child rollups or report-date cutoff. Restricted users may see partial totals; no time-view permission shows Unavailable.

Review / suggested wording:

---

## 26. Tickets drill-down → Back to Performance link

Type: Link hover text

> Return to the previous Performance report when available. Click Apply there to refresh its results.

Review / suggested wording:

---

## 27. Tickets drill-down → Open matching tickets in Issues (current values)

Type: Link hover text

> Open all matching ticket IDs in the standard Redmine Issues list. Owner, status, and other fields show current values. You can change columns, grouping, and save the query there.

Review / suggested wording:

---

## 28. Tickets drill-down → sortable column headings

Type: Generated hover text

> Sort [column] [ascending/descending] [within each selected group / across all results]

Review / suggested wording:

---

## 29. Tickets → linked metric numbers, percentages and data-quality counts

Type: Generated link hover text

> View tickets: [metric name]

Review / suggested wording:

---

## 30. Shared header → Live Dashboard tab

Type: Navigation hover text

> View a dashboard snapshot at the selected As of Date; this page does not automatically refresh.

Review / suggested wording:

---

## 31. Shared header → Periodic Report tab

Type: Navigation hover text

> Planned category. Periodic date ranges and metrics are not implemented yet.

Review / suggested wording:

---

## 32. Tickets → Delivery Ratio Trend → plotted points

Type: Generated point hover text

> [month-end date]: [Done Tickets / All Tickets Due OR Done Weight / All Weight Due], [percentage]%; [done count or weight] / [due count or weight]

Review / suggested wording:

---

## 33. Tickets → Delivery Ratio Trend → dashed target line

Type: Generated line hover text

> Configured target: [delivery target]%

Review / suggested wording:

---

## 34. Tickets → Monthly Delivery Trend → plotted ticket and point values

Type: Generated point hover text

> [month start] – [month end]: [value] [tickets/complexity points] per month [per owner for multiple owners]; total [delivered total] ÷ [selected owner count] owner(s)

Review / suggested wording:

---

## 35. Tickets → Monthly Delivery Trend → dashed target lines

Type: Generated line hover text; absent if target unavailable

> Current monthly target: [target]

Review / suggested wording:

---

## 36. Returns → Return Ratio Trend → plotted points

Type: Generated point hover text

> [month-end date]: [All return incidents OR Excluding Merge Conflict], [percentage]%; [incident count] incidents / [open ticket count] open tickets

Review / suggested wording:

---

## 37. Tickets → delivery-ratio chart background

Type: Chart title; browser may display on hover

> Delivery ratios at the last five month ends

Review / suggested wording:

---

## 38. Tickets → monthly output chart backgrounds

Type: Chart title; browser may display on hover

> ">Monthly delivery: [Tickets or Complexity Points] delivered per month

Review / suggested wording:

---

## 39. Returns → return-ratio chart background

Type: Chart title; browser may display on hover

> Return ratios at the last five month ends

Review / suggested wording:

---
