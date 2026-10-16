# Deployment and verification

Observed host: `/opt/redmine`, plugin `/opt/redmine/plugins/redmine_ticket_journey`, Puma under `redmine.service`, nginx proxy. Logs showed Ruby 3.3.4 and Rails 7.2.3; observations are not a support matrix.

## Deploy

1. Review the diff; retain the previous plugin version for rollback. Copy intended changes to the plugin directory using the existing deployment process. Transfer credentials/mechanism are not documented here.
2. The documented due-date, carry-over, returns, points, and layout changes add **no migrations, fields, or backfill**. Do not run blanket plugin migrations for them; reassess if future changes add migrations.
3. Restart the application, not just nginx:
   ```bash
   sudo systemctl restart redmine
   systemctl status redmine --no-pager
   ```
4. Hard-refresh for CSS/JavaScript changes. Plugin assets must reach the served location through the host's existing asset deployment process. The exact asset/precompile procedure is unconfirmed; restart alone may not republish CSS.

## Verify

- Open Tickets: New and On-Hold at the selected date must be absent from counts, weights, donut breakdowns, Due Soon, and open drill-downs. Stopped lists Pending only. Compare a currently On-Hold ticket against an earlier In Progress snapshot. Verify group counts sum to Total Open and Section 2 retains existing totals.

- Performance header: dashboard type, report section, then title/filters, all inside blue header. Switch categories/sections and Apply: owners/date persist; Periodic and Returns/Time show Planned with no metrics. Existing Live Tickets and drill-downs still work. Check narrow-screen wrapping and keyboard navigation.

- Combined monthly view: targets 10/20 should average to 15; actuals use combined totals ÷ 3 ÷ 2 owners. Include an owner with no deliveries. Remove one owner’s point target: only point target/deviation becomes unavailable, with its name; ticket comparison remains. Verify public/private target visibility and intact combined contributor lists.

- Monthly metrics: As of 15 October 2026 must show 1 July–30 September 2026 for both metrics; totals divide by 3. Check contributor links, zero-delivery months, month/year boundaries, unchanged cumulative ratios, and per-owner actual/target means for multiple owners. No migration is required.

- Performance drill-down: default list has no group headings. Change columns/grouping, sort, and paginate; check choices persist and totals still span all results. Compare historical Owner/Status against the native Issues link's current values. Confirm its ticket IDs include all pages and native issue visibility remains enforced.

For the new Performance page, also follow [Performance setup and verification](performance-setup.md). It requires separate role grants and administrator configuration of existing/new User target fields. Monthly windows require no Day 0 setup. No migration or automatic field creation is included.

- Ticket page, My page, and Issues work with Kanban Block and Return Count.
- Select Return Count under Options → Columns; check numeric filtering, sorting, saved queries, and CSV. Compare a sample against journal history/lifetime report.
- Check current due dates, carry-over boundaries, points/missing-weight links, and completion/debt totals in affected reports.
- Visually check placement below Invoiced? (right-column fallback if absent), summary Points, and split end-status tables. These later layout changes lack explicit server confirmation in the conversation.
- Runner checks supplement web checks: count/partial rendering previously passed while full issue requests failed.
- Tickets Time Report: confirm placement before journey sections, activity changes without changing ticket population, current estimates, lifetime direct hours, total ratio exclusions, and matching Time CSV. Test a restricted time-view user and a parent/child ticket pair to check visibility and rollups.

## Logs and rollback

On this host, failed web requests did not update `production.log`; Puma logs contained the traces. Capture a new request:

```bash
cd /opt/redmine
tail -n 0 -F log/puma.stdout.log log/puma.stderr.log
```

Refresh once, then Ctrl+C. Share the exception, request ID, and relevant stack frames; omit credentials/cookies/private content. Startup deprecation warnings alone do not explain a 500.

Service/startup diagnostics: `sudo journalctl -u redmine -n 100 --no-pager`. `log/production.log` still contains startup messages. Puma stdout was about 1.2 GB when inspected; confirm log rotation separately without deleting logs during diagnosis.

Rollback: restore the previous compatible plugin files together, restart `redmine.service`, and repeat affected-page verification.
