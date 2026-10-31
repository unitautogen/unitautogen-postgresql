# Command quick-reference

| Command | Purpose | Edition | Generates tests? | Main report and folder |
| --- | --- | --- | --- | --- |
| `unitautogen` *(default)* | Unit tests + coverage for functions and triggers | Community | YES | HTML + JSON. Tests in `<out>/unit/<schema>/`, CI bundle in `<out>/unit/` |
| `unitautogen integration` | Every routine run for real across its call map | Team | YES | HTML + JSON. Tests in `<out>/integration/<schema>/`, CI bundle in `<out>/integration/` |
| `unitautogen seccover` | Full security-coverage review | Enterprise | YES | Data security coverage, RLS policy and column-level reports and tests in `<out>/security/<schema>/` |
| `unitautogen pii` | PII in error and `RAISE` messages | Enterprise | YES | The seccover output, plus `<out>/pii_tests/` |
| `unitautogen hipaa` | HIPAA evidence: seccover + the audit-log check | Enterprise | Through seccover and the trigger tests | `<out>/hipaa/<schema>/hipaa_report.html` and `.json`, stamped |

`--out` defaults to `unitautogen_tests/` (`integration_tests/` for `integration`).

Global help: `unitautogen --help` lists the five commands; `unitautogen <command> --help` shows one
command's options. `unitautogen --version` prints the version.

## Common options

| Option | What it does |
| --- | --- |
| `--schema a,b` | The schemas to cover. |
| `--like pat` | A name filter (SQL `LIKE`). |
| `--out DIR` | Where tests and reports go. |
| `--html PATH` / `--json PATH` | The HTML report and the JSON summary. |
| `--no-report` | Skip the CI report bundle (on by default). |
| `--no-coverage` | Generate and run only. Faster. |
| `--no-triggers` | Functions only. |
| `--no-emit-tests` | Report only: everything runs, but no test files are left in `--out`. |
| `--include-extension` | Also test extension-owned routines. |
| `--supabase` | Run inside a Supabase project. See [Supabase mode](supabase.md). |
| `--config FILE` | The [config file](config-file.md). `./unitautogen.toml` is read automatically. |
| `--debug [LOGFILE]` | Write one log file to send to support. |
| `--license PATH` | The licence file, if it is not found automatically. |

## Security options (`seccover`, `pii`, `hipaa`)

| Option | What it does |
| --- | --- |
| `--sec-gate` | Fail the run on a security finding. See the exit codes below. |
| `--sec-html PATH` / `--sec-json PATH` | Move the Data security coverage report. Keep the default to keep its links working. |
| `--no-pii-audit` | Skip the PII audit (on by default). |
| `--storage` | Also check Supabase Storage policies and public buckets. `--supabase` turns it on. |

## Exit codes

| Code | Meaning |
| --- | --- |
| `0` | Success. |
| `1` | With `--sec-gate`: a leaking trigger binding, a column-level leak, or a failing RLS policy test. |
| `2` | An engine error or a would-be false test (report it - it should never happen), a bad config file, a `--supabase` setup failure (no `supabase/config.toml`, no `supabase` CLI, or `supabase status` failed), or the security pass itself errored. |
| `3` | A required extension (pgTAP or plpgsql_check) is missing. Nothing was generated. |
| `4` | The database could not be reached (`CANNOT CONNECT`), or with `--sec-gate` a function or view leak, or a two-tenant defect. |
| `5` | No licence for a paid command (nothing was generated), or with `--sec-gate` a confirmed PII-in-error leak. |

With `--sec-gate`, when several findings apply, the highest code is returned.

## Licence file

Paid commands find the licence on their own: `unitautogen.lic` in the folder you run from, or the file named
by the `UAG_LICENSE` environment variable. `--license PATH` overrides both.
