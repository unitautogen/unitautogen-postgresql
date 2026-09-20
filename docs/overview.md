# Overview

**UnitAutogen** is a single executable, `unitautogen`. You point it at a
PostgreSQL database and it reads your functions and triggers, **writes the tests**, **runs
them**, and **reports honest coverage** - with no test written by hand. The tests it
produces are standard [pgTAP](https://pgtap.org/), so they run with
`SELECT runtests(...)` or `pg_prove` just like tests you would
author yourself.

It works with any PostgreSQL 14 to 18, self-hosted or managed. That includes the popular cloud offerings, Supabase, Neon, Amazon RDS and Aurora, and Azure Database for PostgreSQL, wherever you can enable the pgTAP and plpgsql_check extensions.

Everything is organised as **four commands**:

### 1 · unit tests *(default)*

Generate unit tests + branch/statement coverage for your functions *and* triggers. No command word needed.

unitautogen --schema public

### 2 · integration

Integration testing across the functions you call - they run for real together.

unitautogen integration --schema public

### 3 · seccover

The entire security-coverage pass: functions, views, triggers and data classification, unfiltered.

unitautogen seccover --schema public

### 4 · --pii

Audit for personal data (PII) leaked through error / `RAISE` messages.

unitautogen seccover --pii --schema public

Every command shares the same basic options - `--schema` to choose the schema(s),
`--out` for a folder of generated `.sql` tests,
`--html` and `--json` for reports - and prints one line per
routine plus a summary.

**The one guarantee.** UnitAutogen never gives you a fabricated, false-passing, or flaky test. If a branch cannot be tested reliably, the report tells you so, in plain language, rather than showing a green that would mislead you. Every report comes back with no failing and no false tests, and a visible, explained gap always beats a false pass.

## A guardrail for AI-written code

AI coding assistants now write database logic fast, and that is where a silent mistake costs the most: a wrong `WHERE`, a dropped `INSERT`, a policy loosened in one edit and forgotten. UnitAutogen captures how your functions and triggers behave today and emits it as standard pgTAP tests you commit alongside your code, so the next change, human or AI, that alters that behaviour fails one of them before it reaches production. Integration testing extends the same guardrail across the whole flow, functions calling functions and the triggers their writes fire. Wired into CI, it checks AI-authored changes as fast as they are produced, so you keep the speed without shipping broken database logic.
