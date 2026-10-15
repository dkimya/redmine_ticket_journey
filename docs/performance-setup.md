# Performance setup and verification

Implemented in repository; not deployed or server-verified. Server output supplied by the user confirmed fields 57/70 and the status/tracker names. It did not validate the new dashboard.

## Setup

1. Deploy the plugin files and assets using [deployment guidance](deployment.md), then restart Redmine. This change adds no database migration and does not automatically create fields.
2. In Administration → Custom fields → Users, check for existing fields first. Create **Expected Monthly Ticket Count** and **Expected Monthly Complexity Weight** as optional Integer fields only if absent. Keep them positive for configured targets. Public visibility is required for non-admin dashboard viewers; public user fields may be visible elsewhere in Redmine too, so choose visibility deliberately.
3. In Administration → Plugins → PMO Dashboard → Configure, select these fields. Day 0 is automatic: owner account creation for ticket count, earliest eligible positive-weight ticket Start date for weight. The old manual setting is ignored. Missing, private, zero, or invalid targets display unavailable.
4. Populate the two fields on each relevant user. No target values are invented or bulk populated.
5. In Roles and permissions, **Dashboard** groups **PMO Dashboard** and **Performance Dashboard**. Grant the new permission to intended roles. Existing permission/module identifiers are retained, so PMO grants remain intact. Enable the project's existing module, now labelled Dashboard.
6. Open project → Performance. Select one Ticket Owner and an As of Date. Both delivery indicators use the shared Delivery Target (%) under plugin Configure, defaulting to 90%. No Extra Tasks adjustment applies. Change it to any number from 0 to 100; changing it also affects targets shown for historical dates. Monthly User targets remain separate.

## Verification on a configured test Redmine installation

Run `bundle exec rake redmine:plugins:test NAME=redmine_ticket_journey RAILS_ENV=test` from its test root, never against production data. Local Ruby is unavailable in this workspace, so new unit and functional tests have not been executed here.

Verify full web requests with the installed plugin set: separate role grants; denied access without the new permission; private/hidden issues and custom fields; owner/date selections; historical owner/status changes; due today/+2/+3 days; missing due dates/weights/targets; archived and reopened tickets; zero denominators; monthly partial months and completion dates. Compare ticket sets manually to journals. Check PMO, Issues, My page, saved queries, numeric filters/sorting and selected-column CSV still work.

Visually verify desktop and narrow layouts after asset deployment, tooltip keyboard focus, donut percentages, card alignment, missing-data states and monthly bars. No full Redmine browser render has been verified locally.

Business rules live in [reporting rules](reporting-rules.md). The sendable clarification list is [questions for Hadi](performance-hadi-questions.md).

## Drill-down verification

After deploying the memory fix, compare the same owner/date totals and drill-down IDs against previous known results, including reassigned and reopened tickets. Capture service memory and kernel OOM logs before/after one report and one drill-down. Peak history allocation is now limited to relevant changes for 100 tickets; pathological single-ticket histories and concurrent requests can still consume memory. No RAM, swap, service limits, indexes, or database values are changed by this patch. Unit/functional tests must run in the configured test Redmine installation; local Ruby remains unavailable.
Click each open count, donut percentage/legend, Due Soon, delivery numerator/denominator, monthly contributor link, and data-quality count. Confirm the whole-set count/weight matches the dashboard for unchanged data; inspect historical status/owner against journals. Verify return/pagination links preserve owner/date, empty sets render cleanly, and inaccessible issues/hidden weights stay inaccessible. The details route uses the existing Performance permission. Drill-down changes are local and await deployed web/visual verification.

## Project inheritance verification
Select a parent with child and grandchild tickets owned by the same person. Check all three levels contribute once, child-only owners appear in the initial selector, unrelated/private inaccessible projects do not contribute, and drill-down rows identify their projects. Confirm the employee target remains unchanged and pagination/back links preserve the selected parent. Current hierarchy is used for historical dates. This change needs plugin deployment and restart, with no migration; runtime tests and server verification remain pending.

## Open Tickets feedback verification
Compare an overdue ticket that skipped In Progress, one that reached In Progress and later stopped, and one that first starts after a historical report date. Verify the Not Touched/Already Started classification uses In Progress only. Check Stopped lists only open On-Hold/Pending tickets at the selected date, including inherited subprojects, and overlaps rather than increases the total. Verify its small-font placement below Total Open Tickets and alignment with Due Soon after deployment.

For Section 2, verify due counts/weights exclude Archived and Ongoing at the report date. Check a ticket archived after the selected date still qualifies under its earlier status, and an Ongoing ticket remains in Section 1. Compare drill-down IDs to both delivery figures. No migration required.
Verify both automatic Day 0 dates and separate contributor links, including open weighted tickets establishing weight start, missing/future Start dates, Archived/Ongoing exclusions and hidden weights. No migration is required.

Verify drill-down default ordering by metric, click each sortable heading twice, check missing values remain last and groups show whole-result totals. Test a project group spanning over 100 rows and confirm Next/Previous preserve sorting and report filters. No migration required.

Verify selecting two owners, comparison row totals matching charts, duplicate selection counted once, zero-ticket active member rows, and owner-specific versus aggregate drill-downs. Confirm collapse leaves heading/owner count visible, Total row stays last during sorting, combined drill-down pagination/back links preserve all owners, and inactive users stay out of selection. Monthly aggregates show an explanation; single-owner monthly comparisons continue to work. Deploy plugin and assets, restart and hard-refresh.

## Owner picker verification
Deploy the new performance_owner_picker.js asset together with performance.css and the updated view, restart through the normal process, and hard-refresh. Test search, ordinary checkbox clicks, select-all-filtered preserving other selections, clear, chip removal, empty-selection validation, Tab/Space/arrows/Escape, outside-click close, narrow screens and selected values after Apply. Selection changes must not run a report until Apply. Verify native multi-select fallback with JavaScript disabled.
