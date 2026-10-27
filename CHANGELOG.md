# Changelog

All notable changes to UnitAutogen for PostgreSQL are recorded here. Versions follow the product's release tags.

## 0.5.0

- The config file, `unitautogen.toml` (or `--config FILE`): add or correct the PHI and personal-data tables and columns, and the audit tables, the tool detects, and state which audit table a table must log to. Reports mark everything taken from the file. See [docs/config-file.md](docs/config-file.md).
- PHI recognised by column name: medical record numbers, health plan and insurance IDs, diagnosis and ICD codes, medication and prescriptions, lab results and other clinical data, provider IDs.
- `--debug`: one log file to send to support.
- `--supabase` on every command: run from inside a Supabase project. Uses the local Supabase database, defaults `--schema` to `public`, and writes the tests into `supabase/tests/seccover/` for `supabase test db`. See [docs/commands.md](docs/commands.md).

## 0.3.2-beta

First public beta of the PostgreSQL edition.

- Unit and trigger test generation with branch and statement coverage (Community Edition).
- Integration testing across the function call map (Team).
- seccover security-coverage pass, and PII audit via `--pii` (Enterprise).
- Standard pgTAP output; HTML and JSON reports; Cobertura and JUnit for CI.
- The one guarantee: no fabricated, false-passing, or flaky tests. Branches that cannot be driven soundly are reported as NOT_TESTABLE with a reason, never faked.
- Windows and Linux builds.

See the [README](README.md) for prerequisites and the quick start.
