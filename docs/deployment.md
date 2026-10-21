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

## Performance Returns verification
Deploy the new calculation model, views/partials and CSS along with controller/helper/shared history changes, then restart Redmine and hard-refresh assets. No migration or additional field/permission is needed. Select Live Dashboard → Returns. Check initial page does not scan before Apply, owner/date context across tabs, inherited projects, inactive dropdown exclusion, permissions and hidden issue/owner/reason fields. Compare each bucket and owner Total against journal events, including returns after the selected date, same-stage repeats across QA/Final Check, Merge Conflict reason changes, missing reasons and empty populations. Verify 3+ means >=4 and 2+ means >=3, ratios can exceed 100%, and pagination/grouping/sorting/back/Issues links preserve scope. Check native lifetime Return Count and Tickets/My page/Issues/saved queries/CSV still work. Run the plugin suite only in the configured test Redmine root, never production. Measure service memory and one Returns request with the installed plugin set; a partial render alone is insufficient.

- Returns consistency: for unchanged owner/date/project/permissions, Tickets Total Open must equal Returns Open Tickets, including Ongoing. Compare matching ID sets and confirm zero-return Ongoing tickets enter the 0 bucket and both ratio denominators. Tickets Section 2 delivery still excludes Ongoing independently.

- Returns trend: select 21 October 2026 and verify May 31, June 30, July 31, August 31 and September 30. Compare each monthly value to the Returns cards when separately running that month-end date with identical owners/project/permissions. Check tickets closed/reassigned after each point, month/year/leap-year boundaries, zero open tickets, missing/hidden reasons and ratios above 100%. Check hover values, keyboard-accessible point labels, the expandable exact-values table, overlapping lines and narrow screens. Confirm the chart is below both Section 3 cards and absent on initial filters-only pages and drill-downs. Compare candidate-scan timing and peak service memory before/after on the installed plugin set. Deploy the new `_return_trend.html.erb` partial with model/controller/helper/CSS changes; no migrations or new settings are required.

- Tickets delivery trend: deploy the new _delivery_trend.html.erb partial with model/controller/helper/view/CSS changes, restart and publish assets normally. With As of 21 October 2026 check May 31, June 30, July 31, August 31, September 30 against separate reports at those dates. Verify reassignment, closure/reopening, Archived/Ongoing, missing due dates and hidden/missing weights. Check fixed 0%-100% axis, configured target at 0/90/100%, overlapping lines, gaps, hover/table values and narrow screens. Confirm monthly output averages and Returns remain unchanged, no trend scan on initial navigation or drill-downs, and measure candidate-scan latency/memory. Run plugin tests only in a test Redmine installation.

- Tickets output trends: deploy _monthly_delivery_trend.html.erb with the controller/model/helper/index/CSS changes. On desktop verify ratio trend left, two output charts right; narrow screens stack panels. September point must average July-September, May point March-May. Verify exact window boundaries, current weights, missing completion dates, missing weights, reopened/Archived/Ongoing exclusions, historical ownership and tickets without due dates. Two owners divide combined output by 3 then 2, keeping a zero-delivery owner. Check mean employee target lines, one missing target and separate numeric scales. Monthly cards and ratio points must retain their prior values. Measure latency/memory after deployment; no extra database scans or schema changes were added.

- Monthly output correction supersedes the rolling-average instructions above: September point counts September deliveries only; the cards above retain July-September averages. Verify month start/end inclusivity, zero-delivery months and per-owner output/targets. Deploy the new owner_changes.html.erb audit too. Test owner changes on May 1 and September 30, outside-window/no-op/unselected-owner edits, blank assignments, multiple changes on one ticket, currently reassigned tickets, hidden owner fields and issue visibility. The conditional note must count unique tickets and preserve owner/date in its paginated journal-linked audit. Check initial page/Returns stay unaffected and measure RAM/latency.

- Current-owner policy: reassign one fixture ticket from A to B after the test report's RED. Rerun Performance Tickets/Returns, monthly cards/trends/drill-downs and PMO Ticket Owner Performance. Verify all ticket counts/points, beginning debt A, commitments B/C, delivery H/T, end debt I, activity and returns move to B while historical statuses/dates and global totals remain unchanged. PMO ticket activity/rework follows current owner even when old owner authored/logged it; native time/journal users must be unchanged. Clear current owner: no fallback to A. Check current-role/locked-user filters, hidden owner fields, and both owner-change audits (initial assignments excluded). PMO Status Snapshot must show historical status with current owner. Deploy controller/model/view updates together; no migrations. Run tests only in a configured test Redmine root and perform the installed-plugin verification above.

- Owner-change audit availability: on Tickets and Returns, verify the link/count is visible with both zero and nonzero changes. Returns audit, pagination and Back must retain tab=returns, date and owner selection. Drill-down headers must provide an audit link. Every PMO report navigation must link to the Ticket Owner Performance audit, whose period and query filters remain explicit. Expand a zero-change PMO audit to see an empty-state message. Deploy the new _owner_change_note.html.erb partial with controller/shared-header/shared-tabs/view changes. Initial filters-only and Planned pages remain without scans.

- Leaderboards: deploy _leaderboard.html.erb and performance_leaderboard.js with controller/model/helper/view/CSS changes; publish assets and hard-refresh. Select multiple owners in Tickets and Returns: check comparison table, Leaderboard, then team heading/order. Verify five monthly point totals per owner on Tickets and raw Returns ratios with Merge Conflict; selected owners with no output show zero points, while no open tickets shows ratio N/A/gaps. Sum individual counts/points against team totals; compute team return ratio from combined counts. Check same owner colors across tabs, hover and table counts, legend hide/show with keyboard, all-lines-hidden state, many selected owners, narrow screens, current-owner reassignment and field/issue visibility. Single-owner/initial/Planned/drill-down pages must omit the Leaderboard. Measure runtime/memory; run Ruby tests only in test Redmine.

- Leaderboard target lines: configure two selected owners with monthly point targets 160/200. Check distinct same-color dashed owner targets, legend/table values, and scales including both targets. Hide/show one owner: actual points and their target must toggle together. Test equal targets, a private/missing/invalid target, and a valid target belonging to another owner; never expose hidden values or draw unavailable as zero. Returns must show common 10% and 50% dashed lines, including with zero ratios or all owner lines hidden; verify ratios over 100% still fit. Shared thresholds must not get owner-specific colors. Deploy updated controller/partial/JS/CSS and hard-refresh.

- Unique targets supersede same-color per-owner target lines: with targets 160/70/160 verify exactly two thin gray dashed lines, with labels and hover text listing the owners sharing each. Hide one 160 owner: 160 stays; hide both: 160 disappears; restore either: it returns. Keep the unrelated 70 line correct. Check bold Monthly Delivered Complexity Points title, small inline parenthetical legend values, wrapped long names, unavailable targets and mobile layout. Returns 10%/50% thresholds stay unchanged. Publish updated JS and CSS together with the partial and hard-refresh.

- Leaderboard axis check: approximately 211 points should use 0/100/200/300; approximately 112.5% returns should use 0/25/50/75/100/125%. Confirm actual and reference-line positions align with labels, high future data or targets expand the scale, empty Returns data still includes 10%/50% thresholds, and other trend scales remain unchanged.
