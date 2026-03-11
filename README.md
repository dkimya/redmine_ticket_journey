# redmine_ticket_journey

**Ticket Journey Duration Report** — Redmine Plugin  
Calculates D1–D7-aug durations and return counters for every issue,  
based on the **Ticket Journey Map V03HA** by Manage Petro.

---

## Features

- Calculates all 13 duration fields (D1, D2, D2-aug, D3, D3-aug, D4, D4-aug, D5, D5-aug, D6, D6-aug, D7-aug, D7) per issue
- Tracks 4 return counters (C1–C4) for each error type
- Project-level menu item under every project
- Filters by date range, tracker, and assignee
- Single-issue detail view with bar chart + status timeline
- CSV export of full report
- Client-side search/filter

---

## Requirements

- Redmine 4.0.0 or higher
- Ruby 2.6+
- MySQL or MariaDB (uses `CAST(... AS UNSIGNED)` for journal_details values)
  - For PostgreSQL: change `CAST(jd.old_value AS UNSIGNED)` → `jd.old_value::integer`

---

## Installation

1. **Copy** the plugin folder into your Redmine plugins directory:

```bash
cp -r redmine_ticket_journey /path/to/redmine/plugins/
```

2. **Restart** Redmine:

```bash
cd /path/to/redmine
bundle exec rake redmine:plugins:migrate RAILS_ENV=production
touch tmp/restart.txt
# or: systemctl restart redmine / passenger-config restart-app .
```

3. **Verify** the plugin appears at:
   `Administration → Plugins`

---

## Status Name Configuration

By default the plugin maps these Redmine status names:

| Role         | Default names accepted                        |
|--------------|-----------------------------------------------|
| New          | `New`                                         |
| To-Do        | `To-Do`, `To Do`, `ToDo`                      |
| In Progress  | `In Progress`                                 |
| Feedback     | `Feedback`                                    |
| Review       | `Review`                                      |
| Ready to Merge | `Ready to Merge`, `Ready to merge`          |
| Final Check  | `Final Check`                                 |
| Done         | `Done`, `Closed`                              |

To use different names, edit the `STATUS_NAMES` constant at the top of:
```
app/controllers/ticket_journey_controller.rb
```

---

## Duration Field Reference

| Field   | Measures                                      | By           |
|---------|-----------------------------------------------|--------------|
| D1      | Time in **New** status (Planning)             | Team Lead    |
| D2      | Time in **To-Do** — 1st visit                 | Ticket Owner |
| D2-aug  | Time in **To-Do** — subsequent visits (sum)   | Ticket Owner |
| D3      | Time in **In Progress** — 1st visit           | Ticket Owner |
| D3-aug  | Time in **In Progress** — 2nd+ visits (sum)   | Ticket Owner |
| D4      | Time in **Feedback** — 1st visit              | Assigned QA  |
| D4-aug  | Time in **Feedback** — 2nd+ visits (sum)      | Assigned QA  |
| D5      | Gap: last Feedback exit → first Review enter  | Assigned QA  |
| D5-aug  | Time in **Review** — 1st visit (Code Review)  | Team Lead    |
| D6      | Gap: last Review exit → Ready to Merge enter  | Team Lead    |
| D6-aug  | Time in **Ready to Merge** (Integration)      | Team Lead    |
| D7-aug  | Time in **Final Check** (Post-Int QA)         | Team Lead    |
| D7      | Gap: last Final Check exit → Done enter       | Team Lead    |

### Return Counters

| Counter | Trigger                                    | Error Type              |
|---------|--------------------------------------------|-------------------------|
| C1      | Feedback → In Progress (loop back)         | Function-Fail / Granular |
| C2      | Review → In Progress (loop back)           | Code-Quality-Fail        |
| C3      | Ready to Merge → In Progress (loop back)   | Merge-Conflict Error     |
| C4      | Final Check → In Progress (loop back)      | E2E-Fail / Side Effect   |

---

## Usage

1. Navigate to any project
2. Click **Journey Report** in the project menu
3. Use date / tracker / assignee filters and click **Apply**
4. Click any **#issue-id** link to see the detail view with bar chart and timeline
5. Click **Export CSV** to download the full report

---

## PostgreSQL Notes

In `app/controllers/ticket_journey_controller.rb`, replace:
```sql
CAST(jd.old_value AS UNSIGNED)
CAST(jd.value AS UNSIGNED)
```
with:
```sql
CAST(jd.old_value AS INTEGER)
CAST(jd.value AS INTEGER)
```

---

## License

MIT — Free to use and modify.  
Prepared by: Hadi (Harvey) Afshari — Manage Petro Project Manager
