# redmine_ticket_journey

**PMO Dashboard / Ticket Journey Report** — Redmine plugin for ticket journeys, team performance, sprint delivery, debt, returns, and related reports.

## Documentation

- [Project guidance and checks](AGENTS.md)
- [Reporting rules](docs/reporting-rules.md)
- [Deployment, verification, and logs](docs/deployment.md)
- [Known issues, evidence, and open decisions](docs/known-issues.md)

These documents distinguish implemented code, server-confirmed behavior, and deferred plans. They replace the outdated requirements and mappings in the earlier README.

## Requirements and use

`init.rb` requires **Redmine 6.0+**. Use a Ruby version compatible with the host Redmine. Full database portability is not established: controller journal SQL still uses MySQL/MariaDB-style casts.

Install under the host's `plugins/redmine_ticket_journey` directory, enable the Ticket Journey project module, and grant `view_ticket_journey` as appropriate. Open **PMO Dashboard** from a project. Follow the deployment document when applying changes.

## License

MIT — Free to use and modify.
Prepared by: Hadi (Harvey) Afshari — Manage Petro Project Manager
