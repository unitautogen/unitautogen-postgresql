# Changelog

All notable changes to UnitAutogen for PostgreSQL are recorded here. Versions follow the product's release tags.

## 0.5.1-beta

- Wider PL/pgSQL coverage: queries that join three or more tables, outer joins (LEFT, RIGHT, FULL, NATURAL), loops over `ORDER BY` results, `ORDER BY` on text including `COLLATE "C"`, case-insensitive (nondeterministic) collations, nested array subscripts, `concat`, `concat_ws`, `format`, `num_nulls`, `array_to_string` on text arrays, and `WHILE` loops.
- More accurate coverage: a branch that holds only `NULL;` counts as covered only when the run shows it executed. Otherwise it is reported as not covered, with the reason.
- Test data fixes for functions that read the same table more than once, and for variables declared with a case-insensitive collation.

## 0.5.0-beta

The first public release since 0.3.2. It includes everything below.

- The config file, `unitautogen.toml` (or `--config FILE`): add or correct the PHI and personal-data tables and columns, and the audit tables, the tool detects, and state which audit table a table must log to. Reports mark everything taken from the file. See [docs/config-file.md](docs/config-file.md).
- PHI recognised by column name: medical record numbers, health plan and insurance IDs, diagnosis and ICD codes, medication and prescriptions, lab results and other clinical data, provider IDs.
- `--debug`: one log file to send to support.
- `--supabase` on every command: run from inside a Supabase project. Uses the local Supabase database, defaults `--schema` to `public`, and writes the tests into `supabase/tests/seccover/` for `supabase test db`. See [docs/supabase.md](docs/supabase.md).
- Supabase Storage check (`--storage`, on with `--supabase`): the RLS policies on `storage.objects` and `storage.buckets`, and who can list the files in a public bucket. See [docs/hipaa.md](docs/hipaa.md).
- Connecting: `DATABASE_URL` is read as a connection string. An unreachable database gives a clear `CANNOT CONNECT` message and exit code 4. See [docs/connecting.md](docs/connecting.md).
- Multi-column (composite) foreign keys are seeded correctly in every command.
- More column types work as keys and values: sized `char` / `varchar`, `uuid`, domains with `CHECK`, arrays, `bit(n)`, `bytea`, `money`, `ltree`, `hstore`, `inet` / `cidr`, ranges, composite types, generated columns and quoted mixed-case names.
- More branches reached: values returned through a called function's `OUT` / `INOUT` parameters, chains of local variables, date differences, `NOT IN` with a `NULL`, divide by zero.
- More error handlers reached: foreign-key violation on `DELETE`, `NOT NULL`, `UNIQUE` on the real key, bad xml / json / base64 input. A handler test is named for the handler that actually ran, or marked not reached.
- seccover judges more schemas: self-referencing foreign keys, `CHECK (col IS NOT NULL)`, unique indexes without a primary key, generated columns, and the column types above.
- New command `hipaa`: runs seccover, adds the audit-log check (is each data change recorded, where, and can the record be altered), and writes one stamped HIPAA evidence report for 164.312(a)(1), (b), (c)(1) and (d). pgaudit settings are read as audit-control evidence. See [docs/hipaa.md](docs/hipaa.md).
- The PII audit runs by default in `seccover` and `hipaa` (`--no-pii-audit` skips it), and `unitautogen pii` runs the same pass. Findings go to `<out>/pii_tests/`.
- The Data security coverage report (`sec_report.html`) is laid out in numbered chapters: Summary, a ranked **What to fix** list, Reports, a glossary, the verdict chapters, and the RLS policy report as the last chapter.
- seccover also judges writes through views.
- New output layout: `<out>/<command>/<schema>/{functions,triggers,views}/`, so runs of different commands into one `--out` never overwrite each other. The default `--out` is `unitautogen_tests/`.
- `integration` now tests every routine, including ones that call nothing, so one run is a complete suite for the schema.

## 0.3.2-beta

First public beta of the PostgreSQL edition.

- Unit and trigger test generation with branch and statement coverage (Community Edition).
- Integration testing across the function call map (Team).
- seccover security-coverage pass, and PII audit via `--pii` (Enterprise).
- Standard pgTAP output; HTML and JSON reports; Cobertura and JUnit for CI.
- The one guarantee: no fabricated, false-passing, or flaky tests. Branches that cannot be driven soundly are reported as NOT_TESTABLE with a reason, never faked.
- Windows and Linux builds.

See the [README](README.md) for prerequisites and the quick start.
