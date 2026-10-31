# Supabase mode (`--supabase`)

Add `--supabase` to any of the five commands and run it from inside your Supabase project - the folder that
has `supabase/config.toml`.

## What it does for you

- Finds the project from `supabase/config.toml` and connects to the local database reported by
  `supabase status`.
- Defaults `--schema` to `public`.
- Writes the generated pgTAP into `supabase/tests/seccover/`, where `supabase test db` already looks.
- Enables pgTAP once, through a first-ordered `000-setup-pgtap` hook, so the suite runs on a clean database.
- On a re-run, replaces only its own generated files and leaves your hand-written tests untouched.

So the tests you generate are the tests your Supabase test run executes, with nothing to copy, wire up, or
keep in sync.

## One command per module

Run from the project root. Paid commands pick up your licence on their own (see
[Prerequisites](prerequisites.md#licensing)).

```bash
cd my-supabase-project

unitautogen --supabase --schema public               # unit tests (free)
unitautogen --supabase integration --schema public   # integration (Team)
unitautogen --supabase seccover --schema public      # security coverage (Enterprise)
unitautogen --supabase pii --schema public           # PII in errors (Enterprise)
unitautogen --supabase hipaa --schema public         # HIPAA evidence (Enterprise)

supabase test db                                     # Supabase runs everything above
```

## Where each command writes

| Command | Writes to |
| --- | --- |
| default (unit) | `supabase/tests/seccover/unit/` |
| `integration` | `supabase/tests/seccover/integration/` |
| `seccover` | `supabase/tests/seccover/security/` |
| `pii` | The seccover tests in `security/`, plus `supabase/tests/seccover/pii_tests/pii_findings.json` - a findings report, not pgTAP tests |
| `hipaa` | `supabase/tests/seccover/hipaa/<schema>/hipaa_report.html`, with its security tests in `security/`. |

With `--supabase`, every security command (`seccover`, `pii`, `hipaa`) also runs the Supabase Storage check (`--storage`, see [HIPAA](hipaa.md#supabase-storage---storage)).

## Watch out for a leftover connection string

Any of `UNITAUTOGEN_DSN`, `TESTGEN_DSN`, `DATABASE_URL` or `PGHOST` in the environment replaces the
`supabase status` database. Unset a leftover `DATABASE_URL` before a Supabase run.

For using it as a guardrail for an AI editor working on your Supabase project, see
[AI guardrail](ai-guardrail.md).
