# Performance setup and verification

Implemented in repository; not deployed or server-verified. Server output supplied by the user confirmed fields 57/70 and the status/tracker names. It did not validate the new dashboard.

## Setup

1. Deploy the plugin files and assets using [deployment guidance](deployment.md), then restart Redmine. This change adds no database migration and does not automatically create fields.
2. In Administration → Custom fields → Users, check for existing fields first. Create **Expected Monthly Ticket Count** and **Expected Monthly Complexity Weight** as optional Integer fields only if absent. Keep them positive for configured targets. Public visibility is required for non-admin dashboard viewers; public user fields may be visible elsewhere in Redmine too, so choose visibility deliberately.
3. In Administration → Plugins → PMO Dashboard → Configure, select these fields and set the approved Day 0. Leave Day 0 blank until decided; monthly averages display N/A. Missing, private, zero, or invalid targets display unavailable.
4. Populate the two fields on each relevant user. No target values are invented or bulk populated.
5. In Roles and permissions, **Dashboard** groups **PMO Dashboard** and **Performance Dashboard**. Grant the new permission to intended roles. Existing permission/module identifiers are retained, so PMO grants remain intact. Enable the project's existing module, now labelled Dashboard.
6. Open project → Performance. Select one Ticket Owner and an As of Date. Extra Tasks targets remain unconfigured until the rule/source is agreed.

## Verification on a configured test Redmine installation

Run `bundle exec rake redmine:plugins:test NAME=redmine_ticket_journey RAILS_ENV=test` from its test root, never against production data. Local Ruby is unavailable in this workspace, so new unit and functional tests have not been executed here.

Verify full web requests with the installed plugin set: separate role grants; denied access without the new permission; private/hidden issues and custom fields; owner/date selections; historical owner/status changes; due today/+2/+3 days; missing due dates/weights/targets; archived and reopened tickets; zero denominators; monthly partial months and completion dates. Compare ticket sets manually to journals. Check PMO, Issues, My page, saved queries, numeric filters/sorting and selected-column CSV still work.

Visually verify desktop and narrow layouts after asset deployment, tooltip keyboard focus, donut percentages, card alignment, missing-data states and monthly bars. No full Redmine browser render has been verified locally.

Business rules live in [reporting rules](reporting-rules.md). The sendable clarification list is [questions for Hadi](performance-hadi-questions.md).

## Drill-down verification

After deploying the memory fix, compare the same owner/date totals and drill-down IDs against previous known results, including reassigned and reopened tickets. Capture service memory and kernel OOM logs before/after one report and one drill-down. Peak history allocation is now limited to relevant changes for 100 tickets; pathological single-ticket histories and concurrent requests can still consume memory. No RAM, swap, service limits, indexes, or database values are changed by this patch. Unit/functional tests must run in the configured test Redmine installation; local Ruby remains unavailable.
Click each open count, donut percentage/legend, Due Soon, delivery numerator/denominator, monthly contributor link, and data-quality count. Confirm the whole-set count/weight matches the dashboard for unchanged data; inspect historical status/owner against journals. Verify return/pagination links preserve owner/date, empty sets render cleanly, and inaccessible issues/hidden weights stay inaccessible. The details route uses the existing Performance permission. Drill-down changes are local and await deployed web/visual verification.
