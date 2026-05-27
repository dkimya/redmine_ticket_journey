# PMO Dashboard V14HA - Current Implementation Gap Report

Generated from:
- `PMO_Dashboard_Metrics_V14HA.xlsx`
- `PMO_Dashboard_Implementation_V14HA_Names Checked.xlsx`
- Current Redmine plugin code in `app/controllers/ticket_journey_controller.rb`, `app/views/ticket_journey`, `app/helpers/ticket_journey_helper.rb`, and `config/routes.rb`

## Executive Summary

The current implementation already covers most of the visible Phase 1 dashboard structure:

- Main tabs exist for PMO Control, Sprint Delivery, Planning & Estimation, Ticket Owner Performance, QA & Returns, Bug Analysis, and Ticket Quality/Data Discipline.
- Supporting tabs exist for Duration Report, Issue Detail, Owner Workload, Aging/SLA Risk, Priority/SLA Risk, Cycle Distribution, Flow Report, Project Health, and Release Readiness.
- The biggest missing target section is **Time Utilization & Scope Control Dashboard**.
- The biggest functional gaps are around **time-log analytics**, **retrospective sprint snapshots**, **owner/PM estimation comparison**, **carry-over reason analysis**, **complexity-based metrics**, **testing coverage**, and **release readiness scoring**.

## Target Section Coverage

| Target Dashboard Section | Current Coverage | Status |
|---|---|---|
| PMO Control Dashboard | `pmo_control` tab exists with KPIs, health rule, open work mix, open technical snapshot, cross-project risk summary, data discipline, workload, priority, release, and bug health. | Partial |
| Sprint Delivery Dashboard | `sprint_delivery` tab exists with sprint KPIs, status/owner matrix, execution summary, time efficiency, high-priority view, owner summary, committed ticket detail, status trend, and tracker trend. | Mostly covered |
| Team / Ticket Owner Performance Dashboard | Current tab is named `Ticket Owner Performance`; includes owner delivery/return metrics, average time in status, and idle/no-update detail. | Partial |
| QA & Returns Dashboard | `qa_returns` tab covers done tickets, return rate, first-pass rate, return counts, rework duration, work/rework ratio, return reason, owner return view, and returned ticket detail. | Mostly covered |
| Bug Control Dashboard | Current tab is named `Bugs Analysis`; includes bug source movement, bug impact summary, related page/module histogram, and critical open bugs. | Mostly covered |
| Planning & Estimation Dashboard | `planning_estimation` tab covers planned vs actual, estimation accuracy, original sprint composition, field health, not-started work, and commitment reliability. | Partial |
| Ticket Quality & Data Discipline Dashboard | Current tab title is target-aligned; covers missing required fields, stale tickets, open planned tickets health, and reliability by project. | Mostly covered |
| Time Utilization & Scope Control Dashboard | No direct tab. Only small pieces are indirectly present through planning spent hours and duration/owner workload views. | Missing |

## Table-Level Gaps

| Target Table | Current Status | Gap / Difference |
|---|---|---|
| T01 Open Technical Tickets Snapshot | Partial | Implemented by project/status group, but target requires Project, Tracker, Status, Ticket Owner, and Priority. Current table does not break down by owner or priority. |
| T02 Cross-Project Risk Summary | Partial | Table exists, but current code leaves sprint completion and carry-over at placeholder `0.0` values and does not include return history or bug severity in the row logic. |
| T03 Open Tasks / Business Jobs | Partial | PMO has open work mix count and Project Health has task block, but no dedicated task/business-job table with owner/status distribution. |
| T04 Open Milestones | Partial | PMO has milestone count via open work mix and Project Health has milestone block, but no detailed milestone progress table in PMO Control. |
| T05 Committed Tickets for Sprint #X | Partial | Current sprint scope is based on issue relations to the Sprint issue. Target requires a retrospective committed baseline using Original Sprint and sprint-start/end snapshot behavior. |
| T06 Sprint Tasks Distribution in Statuses | Covered | Implemented as owner-by-status matrix with WIP/Stopped/Done totals. |
| T07 Original Sprint Composition | Covered | Implemented through current-scope vs carry-over composition. |
| T08 Sprint Completion Summary | Partial | Implemented, but current status is used; target expects sprint-end snapshot semantics for accurate retrospective completion. |
| T09 Done Tickets Time Efficiency | Covered | Average cycle time and lead time are present. |
| T10 Ticket Status Change Trend | Covered | Implemented through Flow Report and Sprint Delivery trend tables. |
| T11 Tracker Change Trend | Covered | Implemented through Flow Report and Sprint Delivery trend tables. |
| T12 High-Priority Delivery View | Covered | Urgent/Immediate delivery rate and cycle time are present. |
| T13 Ticket Delivery Analysis by Owner | Partial | Owner-level completion, throughput-like done count, debt, idle, returns, and cycle time exist. Commitment reliability is not clearly sprint-baseline based. |
| T14 Done Committed Tickets Analysis by Owner | Partial | Done cycle time, priority cycle time, and returns exist, but complexity weight is not implemented. |
| T15 Average Time for Each Status | Partial | Average time by status exists, but not grouped by owner in the visible table. |
| T16 Owner Ticket Idle / No Update Detail | Covered | Implemented. |
| T17 Owner Time Allocation | Missing | Requires time logs, sprint/non-sprint split, user/activity allocation. Not implemented. |
| T18 Done Tickets Analysis | Covered | Implemented. |
| T19 Returned Tickets Analysis - Count | Covered | Implemented with R1-R4 return counters. |
| T20 Returned Tickets Analysis - Duration | Partial | Rework duration exists using journey duration fields, not actual time logs by return type. |
| T21 Work & Rework Ratio | Partial | Ratio exists using duration fields, not logged work/rework time. |
| T22 Return Reason Analysis | Covered | Implemented using Return Reason custom field. |
| T23 Bugs Analysis by Category | Covered | Implemented by Bug Source. |
| T24 Bug Impact Summary | Covered | Implemented using Bug Impact Rating. |
| T25 Related Page Histogram | Covered | Implemented using Related Page / Module custom field names. |
| T26 Critical Bugs Open Detail | Covered | Implemented. |
| T27 Planning vs Actual Time Analysis | Covered | Uses estimated hours vs TimeEntry spent hours in sprint period. |
| T28 PM Estimation vs Owner Estimation vs Time Spent | Missing | No owner estimation field or calculation is implemented. |
| T29 Original Sprint Composition | Covered | Implemented. |
| T30 Open Planned Tickets Health | Covered | Implemented as planning field health. |
| T31 Not Started Tickets | Covered | Implemented. |
| T32 Commitment Reliability Summary | Partial | Implemented as completion, carry-over, not-started, technical debt; still depends on current sprint relation rather than a preserved sprint baseline. |
| T33 Carry-over Reason Analysis | Missing | No carry-over reason custom field or distribution is implemented. |
| T34 Open Planned Tickets Health | Covered | Implemented in Data Quality. |
| T35 Tickets Without Updates | Covered | Implemented. |
| T36 Missing Required Fields Detail | Covered | Implemented. |
| T37 Data Reliability by Project | Partial | Project reliability exists, but Time Logging Completeness is not included. |
| T38 Spent Time: General vs Sprint Tickets | Missing | No Time Utilization tab or report. |
| T39 Out-of-Sprint Scope Works | Missing | No sprint vs non-sprint time-log analysis. |
| T40 Spent Time on Group of Tickets in Specific Date Period | Missing | No grouped TimeEntry report by date/user/activity/ticket group. |
| T41 Average Spent Time vs Calendar Duration | Missing | No spent-time vs calendar-duration metric. |
| T42 Owner Time Allocation | Missing | Same gap as T17; no owner time allocation from TimeEntry activity logs. |
| T43 Activity Distribution in Spent Time Report | Missing | No TimeEntry activity distribution report. |
| T44 Feature / Improvement Visibility by Version or Date | Missing | No dedicated feature/improvement visibility table by target version/date. Some release readiness data exists, but not this target table. |
| T45 Daily Agile Board Snapshot | Missing / Partial | Sprint Delivery has weekly/periodic status and tracker trends, but no daily board snapshot table by sprint/date/owner/tracker. |

## Metric Gaps

### Missing or Not Evident

- Time-log utilization metrics:
  - Sprint Logged Time
  - Non-Sprint Logged Time
  - Out-of-Sprint Work Ratio
  - Work Intensity Ratio
  - Owner Time Allocation
  - Activity Distribution
  - Time Logging Completeness
- Estimation/comparison metrics:
  - PM vs Owner Estimation Variance
  - Owner Estimation Accuracy
  - Carry-over Reason Distribution
  - Underestimation Frequency
  - Scope Change Rate / Scope Volatility Trend
  - Re-prioritized Tickets
  - Repeated Carry-over
- Complexity metrics:
  - Complexity-Normalized Cycle Time
  - High Complexity Failure Rate
  - Complexity vs Quality cross-metric
- Release/testing metrics:
  - Testing Coverage
  - Release Readiness Score
  - Release Risk Score
- Bug intelligence metrics:
  - Bug Reopen Rate
  - Severity Distribution as a true severity breakdown
  - Resolution Time by Severity
  - QA Escape Rate
  - Test Coverage Gap Rate
  - Regression Rate
- Advanced returns metrics:
  - Return Loop Depth
  - Return Cycle Duration
  - Return Trend
  - Return-based Fail Rate
  - Critical Return Reason Rate as a distinct threshold/risk metric

### Implemented but With Different Semantics

- Carry-over and completion are calculated from current sprint-related issues and current status; target design asks for a preserved Original Sprint baseline and retrospective sprint-end interpretation.
- Rework and work/rework ratio use journey duration fields, while target tables mention time logs and work type.
- PMO Cross-Project Risk Summary exists, but sprint completion and carry-over are not populated with real per-project values.
- Release Readiness exists as target-version readiness, but not as a formal score using critical bugs, return rate, testing coverage, and sprint completion rate.

## Highest Priority Implementation Work

1. Add **Time Utilization & Scope Control** as a direct tab or explicitly host T38-T43 under existing tabs.
2. Implement a **retrospective sprint baseline** based on Original Sprint and sprint-end snapshot logic for T05/T08/T32.
3. Add or wire custom fields for:
   - Owner Estimation
   - Carry-over Reason
   - Complexity Weight
   - Testing Coverage / QA coverage signal if available
4. Fix PMO Cross-Project Risk Summary so sprint completion and carry-over are real per-project values, not placeholders.
5. Add T44 Feature / Improvement Visibility by Version or Date.
6. Add T45 Daily Agile Board Snapshot if daily board reconstruction is required.
7. Decide whether Release Readiness should remain a supporting tab or become a scored dashboard with target metric 59.

## Code Evidence

- Routes expose all current tabs except Time Utilization & Scope Control: `config/routes.rb`.
- Current tab labels are defined in `app/views/ticket_journey/_report_tabs.html.erb`.
- PMO Control report composition starts in `compute_pmo_control_report`.
- Sprint Delivery report composition starts in `compute_sprint_delivery_report`.
- Planning & Estimation report composition starts in `compute_planning_estimation_report`.
- Data Quality report composition starts in `compute_data_quality_report`.
- Bug Analysis report composition starts in `compute_bug_analysis_report`.
- QA & Returns report composition starts in `compute_qa_returns_report`.
- Owner performance report composition starts in `compute_owner_returns_summary`.
