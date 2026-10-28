# Deployment and verification

## Hadi-confirmed Part 1 changes — 2026-10-28

Deploy the shared Periodic Tickets model, Time eligibility change, Performance
controller/views/tabs, and PMO Ticket Owner Performance controller/view together.
Restart Redmine and hard-refresh. No schema, settings or stored-event migration.
The tab is labelled Tickets without a confirmation badge; confirmation is noted
in the page text and calculation notes. User-facing notices use passive wording
without personal names. Returns/Time-specific rules remain provisional.
See [the current Tickets specification](periodic-tickets-spec.md).

1. Run the complete plugin tests from a configured TEST Redmine root. Added Ruby
   unit/history/request and PMO boundary tests are unrun locally without Ruby.
   Eleven JavaScript navigation/legend checks pass; `git diff --check` passes.
2. Inspect latest To-Do for current owner after multiple entries/reassignments,
   including same-journal changes and reassignment after RED. No initial-status,
   creation-date or missing-date fallback. Due-in-period commitments still count
   without To-Do, but hotfix classification requires valid To-Do and due <= RED.
3. Reopen a test ticket after RED: prior delivery/Returns/time cost/DTC/efficiency
   output must disappear while current status is not Done; logged effort must
   remain in unfinished expected effort unless the current status is excluded.
4. Check current On-Hold/Ongoing/Archived exclusions, historical open status versus
   current eligibility, and exact excluded-during-period explanations. Inspect
   Expected = Completed + Debt after exclusions across all three sections.
5. Verify Extraordinary links, reasons, latest To-Do, RED/current status, new-work
   subsets, per-owner Other Done Extra/Unplanned, sorting/grouping/pagination/Back
   and full-set native Issues handoff under restricted issue/field visibility.
   Recorded due edits diagnose irregularity without restoring historical values.
6. PMO: due on RSD belongs to new commitment, due before RSD to opening debt;
   closures on RSD qualify. Current reopened tickets cannot count as delivered.
   Check single-day periods and historical reruns with current-field edits.
7. Verify all installed-plugin requests, native issue/My page/Issues/query/CSV
   integration, deployed layout and measured memory/latency on test data. These
   changes are not verified by earlier screenshots or partial renders.

## Periodic Time — 2026-10-28

Deploy the new Periodic Time model/views with controller/helper, shared tabs,
settings validation/view/defaults and performance.css. Reuse existing calendar,
owner picker, navigation and leaderboard scripts. Restart Redmine and publish
assets through the normal host process; hard-refresh. No migration or field is
required. All Periodic sections are provisional; older Time Planned checks below
are superseded. Keep the provisional notice and [Time rules](periodic-time-spec.md).

1. Configure optional DTC/priority DTC targets and owner-share % under plugin
   settings. Blank stays N/A; do not copy illustrative design values as defaults.
   Verify weekday/holiday/default hours and optional weekly-hours field mapping.
2. Run `bundle exec rake redmine:plugins:test NAME=redmine_ticket_journey RAILS_ENV=test`
   from a configured **test Redmine root**, never on production data. Ruby is not
   installed locally; the added Ruby unit/settings/helper/request tests are unrun.
   Eleven local JavaScript navigation/legend checks pass.
3. Initial Time navigation must avoid issue/history/time scans. Apply retains
   dates/owners across sections. Reconcile expected/done/other/debt with Tickets.
   Compare all eight metrics and exact contributor lists against source data.
4. Check booked user `user_id` versus entry creator `author_id`, reassignment and
   cross-owner work. Lifetime direct ticket cost includes pre-RSD work through
   RED from all users; personal time uses selected users' in-period `spent_on`.
   Verify backdated/future entries, unlinked/out-of-scope exclusions and raw versus
   paired totals. Unfinished expected hours must reconcile and affect efficiency.
5. Check missing estimates/weights/targets, authorized zero entries, invalid hours,
   hidden Ticket Owner, mixed project time permissions, zero workdays and weekly
   hour fallback. Unknown values must not look like healthy zeros. Team rates
   must recompute from underlying totals, not owner averages.
6. Verify per-owner Extra Work with nonempty completed package and no RED debt;
   empty packages do not qualify. Mixed team Extra/Unplanned must stay separate.
   Cost allowance boundaries are amber/red; CW/h deviation is provisionally A−P.
7. Verify partial Monday-based weeks and >120-day calendar-month intervals,
   fixed RED portfolios, completion-cohort costs versus work-date personal hours,
   exact values, N/A gaps, contributor links and paired actual/plan legend toggles.
   No weekly owner-share budget should be invented.
8. Inspect new-tab detail sorting/grouping/pagination, logged versus current owner,
   work-date totals, range/Back and unique-ID native Issues handoff. Check wide and
   narrow screens, keyboard access and actual request exceptions. Measure memory
   and latency on representative test data, including large ranges/owner counts.
9. Recheck Live and Periodic Tickets/Returns, ticket page, My page, Issues, saved
   queries, numeric Return Count sorting/filtering and selected-column CSV with
   the installed plugins. Successful partial rendering alone is insufficient.

## Periodic Returns and Live metric change — 2026-10-28

Deploy the new TicketJourneyPeriodicReturns model and Periodic Returns views with
the changed Tickets/history and Live Returns models, controller/helper, shared
tabs/distribution/audit/leaderboard/trend partials and performance.css together.
Reuse the existing performance_leaderboard.js for owner toggles. Restart Redmine,
publish assets through the host's existing process, and hard-refresh. No migrations,
new fields, settings or permissions are required. Keep the provisional notice
visible; [the specification](periodic-returns-spec.md) documents Hadi-pending choices.

1. Initial Periodic Returns must render filters without issue/history scans. Apply
   must retain RSD/RED/owners across tabs and show expected/total-done populations
   matching Tickets' exact Completed from Expectation/Total Actual Done sets.
   Periodic Time must remain Planned and scan-free.
2. Verify the 12-done/5-returned/8-incident example gives 1.6, not 66.7% or 160%.
   Check zero completed tickets separately from completed tickets with zero returns:
   both metric values are N/A, with different population explanations and explicit
   zero incidents. Verify 3+ means >=4 and 2+ repeats means >=3. Consecutive donut
   denominator must be repeat tickets only, not all returned tickets.
3. Inspect a completion with returns before RSD, on RED, and after RED. Full history
   through RED counts; later events do not. Confirm existing stage-family rules,
   duplicate journal-detail protection, accumulated repeats, Merge Conflict
   inclusion and hidden/missing reason behavior. Inspect the actual Merge /
   Integration Conflict option in audits and legacy non-Merge calculations.
4. Verify weekly completion cohorts partition the final expected-done set, including
   partial Monday-based weeks, equal RSD/RED, month/year/leap-day boundaries and
   >120-day calendar-month intervals. Population, returned counts and incident sums
   must reconcile to headline totals. No future or opening-debt cohort. Each
   point's full through-RED return history is disclosed; gaps mean N/A.
5. Multi-owner: include a zero-output owner and different returned-ticket counts.
   Team ratio must use combined counts. Confirm owner-only links do not retain a
   competing team owner_ids parameter. Hide/show owner trend lines by keyboard;
   the team line and values table must remain available. Check top tables default
   collapsed, narrow screens, contrast, labels, hover/focus values and no percent
   suffix on primary metrics. Distribution percentages remain percentages.
6. Verify every card/bucket/bar/table/point contributor list, including Other Done,
   completion date, classification, reason flags, journal links, selected range,
   cohort, sorting/grouping/pagination/Back and full-set native Issues handoff.
   Large ID-list URL limits remain. Recheck restricted/inactive/blank/hidden-owner,
   issue and reason visibility with the installed plugin set.
7. Live: unchanged open population/distributions; primary metric = incidents /
   returned open tickets at the chosen date and each of five month ends. Compare
   cards, owner comparison and leaderboard. No old threshold lines or percentage
   suffix. Legacy non-Merge percentage remains separate with its original all-open
   denominator and unknown-reason guard; do not plot mixed units on one axis.
8. Recheck Live Tickets/Time, Periodic Tickets, native ticket/My page/Issues/saved
   queries/Return Count numeric filtering/sorting and selected-column CSV. Run
   `bundle exec rake redmine:plugins:test NAME=redmine_ticket_journey RAILS_ENV=test`
   only from a configured test Redmine root, never against production data.
   Measure full-request latency and peak memory; selected ticket/event retention
   still grows and history batching alone does not establish safe performance.

Local result: ten JavaScript tests and git diff --check pass. Ruby/request,
deployed visual/installed-plugin and service performance verification are pending.

## Periodic Tickets — provisional implementation, 2026-10-27

Deploy the new TicketJourneyPeriodicTickets model, controller/helper changes,
Periodic views/partials, shared tabs and performance.css together. Restart Redmine,
publish assets through the existing host process and hard-refresh. No settings,
fields, migrations or new permission are required. The provisional badge and
calculation notes must remain visible pending Hadi's review. See
[the specification](periodic-tickets-spec.md) for the authorized defaults.

1. Verify RSD/RED and owner controls on all Periodic sections. Apply/section links
   preserve ranges; Live retains its separate As of Date. Check malformed dates,
   RSD after RED, future RED, equal dates, leap/month/year boundaries and permission
   failures. Invalid dates return 422. Initial Tickets and all Returns/Time pages
   must not scan histories; Returns/Time stay Planned.
2. Compare an opening-debt ticket, a scheduled task assigned before RSD, and an
   in-period assigned Immediate/Hot Fix with no due date. Check category precedence,
   a future-due hotfix, a missing assignment record and a ticket already closed at
   opening. No duplicate expectation contributions or creation-date fallback.
3. Check Done on RSD and RED, reopened before/after RED, no recorded completion,
   and Archived/Ongoing/On-Hold at RED versus different current statuses. Verify
   Expected = Completed from Expectation + Debt and Actual = Completed + Other Done
   for counts and weights. Unverified completion stays unresolved with a review
   link; Still Open Now remains a current subset of RED debt. PMO rules stay intact.
4. Reassign current owner and change current due/weight/priority: past reruns may
   change as documented. Test blank/hidden owner, hidden/nonpositive/missing weights,
   restricted projects/issues and inactive saved-owner reports. No hidden values
   should be exposed through totals, selector discovery or detail lists.
5. Multi-owner view: include an owner with zero output, sum each category against
   the team values, and calculate team deviations from combined totals rather than
   average percentages. Each owner link must select only that owner, without a
   competing team owner_ids parameter. Check missing weights and zero-plan N/A.
6. Verify collapsed top summary tables, seven KPI cards, comparisons, completion
   donut, debt follow-up, stacked actual-owner bars, centered deviation bars, team
   and individual ticket/CW trends on desktop/narrow screens and keyboard use.
   Opening debt is present at the opening point; final points equal cards. Check
   partial Monday-based weeks and month-end buckets for periods over 120 days.
7. Open numeric/bar/SVG point/detail-table links in new tabs. Check full period,
   owners and trend bucket in the URL, exact contributor IDs, sorting, grouping,
   100-row pagination, Back and whole-set native Issues links. Large ID-list URL
   limitations remain. Current issue/field visibility must still apply.
8. Run plugin tests only in a configured test Redmine root, never production.
   Measure full-request time and peak memory on the installed plugin set. Recheck
   Live Tickets/Returns/Time, ticket page, My page, Issues, saved queries, numeric
   Return Count filtering/sorting and selected-column CSV. Local Ruby/request and
   deployed visual/performance verification have not been performed.

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


## Performance Live Time verification

Deploy the Time model, working_calendar library, controller/helper/settings changes, Time views/partials and CSS together with init.rb. Restart Redmine, publish plugin assets using the host's existing process and hard-refresh. No migration or automatic custom-field creation is required. Periodic Time must remain Planned.

1. Configure working weekdays, daily hours, dated holidays, optional existing numeric User weekly-hours field and separate estimate/SV thresholds in Administration → Plugins → PMO Dashboard → Configure. Test invalid/empty weekdays, impossible dates, nonfinite/out-of-range hours and invalid field mappings. Existing installations use Monday–Friday/eight-hour defaults. Private/missing User values must fall back without disclosure.
2. Live Time initial navigation must show filters without scanning issues/history/entries. Apply preserves owner/date across tabs and audit/drill-down links, including inactive-owner saved reports and descendant project scope. Verify issue/owner-field visibility with the actual installed plugin set.
3. Compare Time Total Open with Tickets/Returns for identical filters. Check New/On-Hold/closed exclusions and Ongoing inclusion. Confirm working-day ages at 0/15/16/30/31/60/61, weekends, holidays, missing/future starts and no pause/reopening reset. Age-eligible buckets must sum to their displayed denominator; excluded starts remain in full open totals. Urgent/Immediate priority subset and Immediate list use Ticket Owner.
4. Check Start 5 October 2026, Due 16 October, report 13 October under Monday–Friday/no holidays: 10 total working days, 7 elapsed, 70% planned; age is 6 working days (Start Date zero). Same-day start is eligible. Due day gives 100%. Due <= Start and zero-working-day windows are excluded. Check missing dates/estimates, restricted time permissions, early entries and linked fix reasons.
5. Compare direct entries across authors, parent/child issues, backdated records, future work dates and invalid negative hours. Main cards show visible totals; paired balance/SV comparisons must use identical contributor sets. 380 planned / 475 actual gives -25% SV. Test neutral zero, SV at -10% (red), estimate balance at -10% (within allowance/warning) and just beyond -10% (red), plus changed thresholds.
6. Productivity for an October report must show May–September individual monthly ratios, not averages. Compare completed/reopened/Archived tickets at each month-end, current owner reassignment, current/hidden/missing weights, zero hours, missing completion and private entries. Include work logged before the delivery month; exclude entries with work dates after that month-end. Check contributor/exclusion links, monthly context, sorting/grouping/pagination/back and full-set native Issues handoff.
7. Verify desktop/narrow-screen cards, donuts, table coverage, tooltips, comparison bars, trend gaps and focus labels. Measure request time/peak memory before and after; bounded batches do not establish acceptable server performance by themselves. Recheck Tickets, Returns, ticket page, My page, Issues, saved queries, numeric Return Count sorting/filtering and selected-column CSV on the installed plugins.
8. Run the full plugin suite only from a configured test Redmine root: bundle exec rake redmine:plugins:test NAME=redmine_ticket_journey RAILS_ENV=test. Local Ruby and a host test Redmine are unavailable; new Ruby tests are not locally executed. Existing JavaScript navigation/leaderboard tests pass.

- Performance drill-down new tabs: deploy the shared helper plus updated header/owner-change/productivity partials. Check numeric/card/distribution/comparison/exclusion links on Tickets, Returns and Time open a new browser tab with the same date/owners, including explicit productivity month context. Owner-change audit links behave the same. Tooltips announce the new tab. Dashboard selection/scroll remains intact; sorting, pagination, filters and section navigation stay in their current tab. In the new drill-down tab, Back to Performance must use its normal dashboard URL without jumping browser history. Ctrl/Cmd-click and middle-click remain native browser behavior. Nine local JavaScript tests pass; full Redmine rendering/browser verification is pending.
