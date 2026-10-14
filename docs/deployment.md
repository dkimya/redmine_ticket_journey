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

- Ticket page, My page, and Issues work with Kanban Block and Return Count.
- Select Return Count under Options → Columns; check numeric filtering, sorting, saved queries, and CSV. Compare a sample against journal history/lifetime report.
- Check current due dates, carry-over boundaries, points/missing-weight links, and completion/debt totals in affected reports.
- Visually check placement below Invoiced? (right-column fallback if absent), summary Points, and split end-status tables. These later layout changes lack explicit server confirmation in the conversation.
- Runner checks supplement web checks: count/partial rendering previously passed while full issue requests failed.

## Logs and rollback

On this host, failed web requests did not update `production.log`; Puma logs contained the traces. Capture a new request:

```bash
cd /opt/redmine
tail -n 0 -F log/puma.stdout.log log/puma.stderr.log
```

Refresh once, then Ctrl+C. Share the exception, request ID, and relevant stack frames; omit credentials/cookies/private content. Startup deprecation warnings alone do not explain a 500.

Service/startup diagnostics: `sudo journalctl -u redmine -n 100 --no-pager`. `log/production.log` still contains startup messages. Puma stdout was about 1.2 GB when inspected; confirm log rotation separately without deleting logs during diagnosis.

Rollback: restore the previous compatible plugin files together, restart `redmine.service`, and repeat affected-page verification.
