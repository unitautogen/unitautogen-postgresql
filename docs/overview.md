# Overview

**UnitAutogen** is a single executable, `unitautogen`. You point it at a PostgreSQL database and it reads
your functions and triggers, **writes the tests**, **runs them**, and **reports honest coverage** - with no
test written by hand. The tests it produces are standard [pgTAP](https://pgtap.org/), so they run with
`SELECT runtests(...)` or `pg_prove` just like tests you would write yourself.

It works with any PostgreSQL 14 to 18, self-hosted or managed: Supabase, Neon, Amazon RDS and Aurora, Azure
Database for PostgreSQL, and others, wherever you can enable the pgTAP and plpgsql_check extensions.

Everything is organised as **five commands**:

| Command | What it does | Edition |
| --- | --- | --- |
| **unit tests** *(default)*<br>`unitautogen --schema public` | Unit tests and branch/statement coverage for your functions *and* triggers. No command word needed. | Community (free) |
| **integration**<br>`unitautogen integration --schema public` | Every routine run for real, together with the functions it calls and the triggers its writes fire. | Team |
| **seccover**<br>`unitautogen seccover --schema public` | The full security review: functions, views, triggers, RLS policies and column-level security. | Enterprise |
| **pii**<br>`unitautogen pii --schema public` | Personal data leaked through error and `RAISE` messages. On by default inside seccover. | Enterprise |
| **hipaa**<br>`unitautogen hipaa --schema public` | Runs seccover, adds the audit-log check, and writes a stamped HIPAA evidence report. | Enterprise |

Every command shares the same basic options - `--schema` to choose the schema(s), `--out` for the output
folder, `--html` and `--json` for reports - and prints one line per routine plus a summary. Inside a Supabase
project, add `--supabase` to any of them ([Supabase mode](supabase.md)). To add or correct the PHI,
personal-data and audit tables the tool detects, keep a `unitautogen.toml` next to your code
([the config file](config-file.md)).

**The one guarantee.** UnitAutogen never gives you a fabricated, false-passing, or flaky test. Every generated
test is re-run on a clean pass before it is kept. If a branch cannot be tested reliably, the report says so, in
plain language, as `NOT_TESTABLE` with a reason, rather than showing a green that would mislead you. Every
report comes back with no failing and no false tests, and a visible, explained gap always beats a false pass.

## A guardrail for AI-written code

AI coding assistants now write database logic fast, and that is where a silent mistake costs the most: a wrong
`WHERE`, a dropped `INSERT`, a policy loosened in one edit and forgotten. UnitAutogen captures how your
functions and triggers behave today and emits it as standard pgTAP tests you commit alongside your code, so
the next change, human or AI, that alters that behaviour fails one of them before it reaches production.
Integration testing extends the same guardrail across the whole flow, functions calling functions and the
triggers their writes fire. Wired into CI, it checks AI-authored changes as fast as they are produced. See
[AI guardrail](ai-guardrail.md).

## Generated, not guessed

The tests are derived from your code and run against your database. The same schema gives the same tests.
Nothing is guessed by a language model, so a result is reproducible and can be checked.
