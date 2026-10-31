# The five commands

Run `unitautogen --help` to list the commands and `unitautogen <command> --help` for one command's full
option list. Each section below says what the command does, its command line, the report it writes, where
its files go, and whether it generates tests.

| Command | What it does | Edition |
| --- | --- | --- |
| `unitautogen` *(default)* | Unit tests and coverage for functions and triggers | Community (free) |
| `unitautogen integration` | Every routine run for real with what it calls and fires | Team |
| `unitautogen seccover` | The full security-coverage review | Enterprise |
| `unitautogen pii` | Personal data leaked through error and `RAISE` messages | Enterprise |
| `unitautogen hipaa` | seccover plus the audit-log check, as a stamped HIPAA report | Enterprise |

Every command writes into one `--out` folder, one sub-folder per command, so runs of different commands into
the same folder never overwrite each other:

```
<out>/
  unit/<schema>/{functions,triggers,views}/      unit and trigger tests
  unit/                                          the CI report bundle
  integration/<schema>/{functions,triggers,views}/
  integration/                                   the CI report bundle
  security/<schema>/                             seccover reports and tests
  pii_tests/                                     the PII-in-error findings
  hipaa/<schema>/                                the HIPAA report
  run_summary.json                               per-function summary of the unit run
```

In a Supabase project, add `--supabase` to any command and the tests go where `supabase test db` runs
them. See [Supabase mode](supabase.md).

## 1. Unit tests for functions and triggers (the default command)

The everyday command, and the default, so `unitautogen --schema public` runs it with no command word
(`unitautogen unit` also works). For each function and procedure it generates a full set of pgTAP tests,
runs them, and measures how much of the routine they exercised. Then it does the same for your triggers.
Every routine gets: *executes with valid inputs*, *low and high boundary values*, one test per branch (the
true side and the false side), *returns a stable result-set shape*, *returns rows matching its recorded
output*, *touches only the expected tables*, and a *hand-built expectation* scaffold for you to fill in.
Triggers are tested by behaviour: the test fires the `INSERT`, `UPDATE` or `DELETE` and asserts what the
trigger did.

|  |  |
| --- | --- |
| What it does | Generates unit tests for functions **and** triggers, runs them, and measures branch and statement coverage. |
| Generates tests? | YES. One `test_<routine>.sql` per function, and one `test_trg_<schema>__<table>__<trigger>.sql` per trigger. |
| Command | `unitautogen --schema public --out unit_tests --html report.html --json report.json` |
| Key options | `--schema a,b` schemas · `--like pat` name filter · `--out DIR` where the files go · `--html PATH` the HTML report · `--json PATH` the JSON summary · `--no-report` skip the CI bundle · `--no-coverage` generate and run only (faster) · `--no-triggers` functions only · `--no-emit-tests` report only, leave no test files · `--include-extension` also test extension-owned routines. |
| Report(s) | The **HTML** report (per-routine test counts, branch % and statement %, click-through annotated source), the **JSON** summary (one entry per routine), and the CI bundle: `report.html`, `report.json`, `junit.xml`, `cobertura.xml`, `coverage.lcov`. |
| Folder | `--out` (default `unitautogen_tests/`). Function tests in `<out>/unit/<schema>/functions/`, trigger tests in `<out>/unit/<schema>/triggers/`, the CI bundle in `<out>/unit/`. |

The JSON summary is a list with one object per routine. A representative entry:

```
{
  "proc": "public.salesbycategory",
  "tests": 7,
  "status": "ok",
  "branch_coverage": 1.0,
  "statement_coverage": 1.0,
  "tests_passed": 6,
  "tests_failed": 0,
  "tests_skipped": 1,
  "pruned": [],
  "uncovered_classes": {}
}
```

Read this as: 7 tests generated, 6 pass, 1 skipped (the hand-built-expectation scaffold, which waits for
you to fill it in), 0 failed, 0 pruned, nothing left uncovered. `tests_failed` is **0** for every routine,
always - a test that cannot pass cleanly is never kept.

### The HTML report

The `--html` file is the **Database Coverage Report**. It opens to four summary cards and a per-routine
table (click any routine name for its annotated source):

![The unit coverage report](img/img01.png)

The unit report for a sample schema with 6 functions *and* 2 triggers - 72 function tests (top table) plus
5 behaviour assertions for the triggers (the **Trigger bindings** section below it).

| Report element | What the data represents |
| --- | --- |
| Line coverage | The share of executable lines the generated tests actually ran (e.g. 16/16 lines = 100%). |
| Branch coverage | The mean, across all routines, of the true/false decision outcomes your tests covered. |
| Tests | Total generated, split into pass / fail / error / skip. *fail is always 0*. *skip* counts the hand-built-expectation scaffolds left for you to fill in. |
| Autonomy | How many tests are generated as they are, and how many you have edited. |
| Per-routine row | *Testable* and *Gen*, the *Pass / Fail / Err / Skip* counts, *Lines* and *Covered*, *Line %*, *Branch %*, and the *Uncovered* tags. |
| Uncovered tags | **D** suspected dead code · **H** error recovery · **E** a tool limit · **BUG** a function bug · **DDL** a statement that emits DDL · **Q** a query condition your test data did not exercise on both sides. See [Reading the report](reading-the-report.md). |
| Trigger bindings | One row per trigger: its *Timing* (BEFORE/AFTER), *Level* (ROW/STATEMENT) and *Events*, the tests and their results, the trigger's own *Cov %*, the tables it *Writes*, behaviour *Tags* (e.g. `update:wrote`, `insert:threw`), and *Status*. A trigger with no provable behaviour is skipped, never asserted vacuously. |
| Click a routine | The *write footprint* per test (rows inserted, updated or deleted, and what the routine returned), the *query arms* measured on the test data, and the *annotated source*, each line coloured by whether it ran, with hit counts. |

A generated trigger test drives the change and asserts what the trigger did. For the `AFTER UPDATE` audit
trigger above, the test fires an update and checks the exact audit row it wrote:

```
-- generated: test_trg_account__audit_balance
UPDATE public.account SET balance = 1;                       -- Act: fire the trigger
RETURN NEXT is(
    (SELECT ... "action" FROM public.audit_log),
    '[{"action": "balance_change"}]'::jsonb,                 -- Assert: the row the trigger wrote
    'audit_balance :: update write-effect on public.audit_log');
```

### Trigger kinds covered

Triggers fire for real; a trigger's behaviour is its cascade, so it is never mocked.

| Kind | What the tests prove |
| --- | --- |
| BEFORE ROW | The resulting row, a raise on bad data, row suppression. |
| AFTER ROW, including nested cascades | The writes across every table the cascade reaches. |
| BEFORE / AFTER STATEMENT | One summary row for an N-row change; branches over transition tables. |
| UPDATE OF `<column>` | Fires on that column's change, not on others. |
| WHEN (...) | Fires on the real condition, not otherwise. |
| INSTEAD OF | DML on the view writes the base table. |
| TRUNCATE | TRUNCATE is rejected (append-only guard). |
| CONSTRAINT / DEFERRED | The deferred check fires; a balanced change passes, an unbalanced one raises. |
| One function on several tables / TG_ARGV | Coverage per binding, then the union. |
| EVENT TRIGGER | Reported `NOT_TESTABLE: EVENT_TRIGGER`. Listed, never silently skipped. |

An arm that cannot run under a binding's events (for example a DELETE arm on an INSERT-only trigger) is
tagged **U** with the reason. It stays uncovered for that binding; a sibling binding that can reach it
covers it.

### The coverage drill-down - one function and one trigger

Clicking a routine or trigger name opens its coverage detail. This is where you see *how* a routine is
covered and what to do about a gap. A **function** drill-down:

![A function drill-down](img/img02.png)

`account_health` - the per-test **Footprint** (each test's writes, and its returned value:
`low` / `over_limit` / `overdrawn` / `ok`) above the **annotated source**, every line carrying its hit count.

**How to use it:** read the annotated source top-down. A green line ran, and its hit count (e.g. `8x`) is
how many tests ran it. A *red* line never ran, and its tag says whether it is a suspected bug, error-recovery
code, or a tool limit. The Footprint shows which input produced which result, so you can confirm each branch
returns what it should. If you change the code, the tests that pinned those values fail (see the
[worked example](worked-example.md)).

A **trigger** drill-down shows the per-firing effect and the trigger function's source:

![A trigger drill-down](img/img03.png)

`audit_balance` - the **Write footprint** per firing (test\_10 wrote an `audit_log` row asserting
`action=balance_change`; test\_20 asserted *no* row was written), the **Call tree** of the trigger function
and its helpers, and the **Stitched source** with per-line hit counts.

**Use unit testing to:** catch regressions (a changed behaviour fails the pinned test), find untested
branches (red lines and skips), and spot suspected bugs (a **D** line is a contradiction in your logic).
Commit the generated test files so CI re-runs them on every change.

## 2. `integration` - integration testing for functions (Team licence)

Unit testing checks a routine on its own and stands in for what it calls. `integration` runs the whole call
map for real - a function together with the functions it calls and the triggers its writes fire - and
measures coverage across that map. **Every routine in the schema becomes an integration test**, including
ones that call nothing (those are simply a map with no callees), so one run is a complete suite for the
schema.

|  |  |
| --- | --- |
| What it does | Exercises the real cross-function and trigger call map end to end, and measures coverage across it. |
| Generates tests? | YES - integration-level pgTAP tests for every routine. |
| Command | `unitautogen integration --schema public --out integration_tests --html integration.html --json integration.json` |
| Key options | `--schema a,b` · `--like pat` · `--out DIR` · `--html PATH` · `--json PATH` · `--no-report` · `--no-coverage` · `--include-extension` · `--license PATH`. |
| Report(s) | The **HTML** and **JSON** reports, and the CI bundle in `<out>/integration/`. |
| Folder | `--out` (default `integration_tests/`). Tests in `<out>/integration/<schema>/{functions,triggers,views}/`. |

**Requires a Team licence (or above).** Without one the command reports `NOT LICENSED`, runs nothing and
exits with code **5**. See [Prerequisites](prerequisites.md#licensing) for where the licence file goes.

### The HTML report

The integration `--html` file is the **Integration Testing Report**. It has the same four summary cards,
measured across the whole call map, and one row per routine:

![The integration report](img/img04.png)

A sample schema of connected routines - 28 routines, 186 tests, 100% map coverage. The **EXT:1** tag marks
an external boundary the map does not run (for example a remote dblink call).

| Report element | What the data represents |
| --- | --- |
| Summary cards | Line and branch coverage, test counts and autonomy, line-weighted over the whole call map the tests drove. |
| One row per routine | For a caller, its tests call it directly, and every function it calls and every trigger its writes fire runs for real underneath it. A routine that calls nothing is covered as its own node. |
| Lines / Line % / Branch % | Line-weighted over the call map the routine's tests drove. A line counts only if the call actually reached it. |
| Confirm intent | Tests whose input sits exactly on a numeric boundary (e.g. `amount > 1000` tested at `1000`). They pass against the code as written; confirm each is the result you intend. Nothing here is a failure. |
| Click a routine | The call map in real call order, the per-test write footprint across the whole map, and the stitched annotated source of every function in it. |

Click a routine to open its **call map** drill-down:

![An integration call-map drill-down](img/img05.png)

`iz18_root` - the per-test **Write footprint** across the whole map, the **Call map** (root, then its helper,
then the trigger the INSERT fired, all REAL), and the **Stitched source** of every function in the map with
per-line hit counts.

**Use integration testing to:** verify a whole flow end to end, and find lines that are only reachable
through the real call map, not the isolated unit test.

## 3. `seccover` - security coverage (Enterprise licence)

The entire security-coverage pass, unfiltered. It builds a database-wide ownership map and checks whether
data can cross a trust boundary through any kind of object: `SECURITY DEFINER` functions, views, triggers,
RLS policies and column grants. Each is classified as leaking, safely contained, or not judgeable. It writes
pgTAP tests for the security cases and three reports. The PII audit runs as part of it. How the verdicts are
proven is explained in [How seccover proves its verdicts](how-seccover-works.md).

|  |  |
| --- | --- |
| What it does | The full security review across functions, views, triggers, RLS policies and column-level security, database-wide. |
| Generates tests? | YES - pgTAP tests for the security cases. |
| Command | `unitautogen seccover --schema public --out sec_out` |
| Key options | `--schema a,b` · `--out DIR` · `--sec-gate` fail the run on a finding (see [CI/CD](ci-cd.md#security-gate)) · `--no-emit-tests` a report-only run · `--no-pii-audit` skip the PII audit · `--storage` also check Supabase Storage (see [HIPAA](hipaa.md#supabase-storage---storage)) · `--sec-html PATH` / `--sec-json PATH` move the report · `--license PATH`. |
| Report(s) | The **Data security coverage** report (`sec_report.html` / `.json`), the **RLS policy** report (`rls_report.html` / `.json`), and the **column-level security** report (`cls-report.html` / `cls_report.json`). |
| Folder | Everything in `<out>/security/<schema>/`: the three reports, `seed_gate.json`, and the security tests under `functions/`, `triggers/`, `views/`, `rls/` and `cls/`. |

Keep the reports at their default paths: their links to the tests and to each other are relative to that
folder, so moving one with `--sec-html` breaks them. A leak is reported into any schema it reaches, whatever
`--schema` names.

**Requires an Enterprise licence.** Without one the command reports `NOT LICENSED`, generates nothing, and
exits with code **5**.

```
== security: DB-WIDE ownership map (20 RLS table(s) across all schemas, 3 identities) -- a leak is reported into ANY schema regardless of --schema ==
  trigger bindings: 31 judged contained 3, leaking 13, no-tenant-axis 1, not-reached 14
    [CONTAINED] sz.doc_safe :: trg_audit_safe -- role sz_user -- INSERT: the caller's cross-tenant INSERT is rejected (WITH CHECK or a trigger guard contains it) ...
    [LEAKING] sz.docs2 :: trg_docs2 -- role sz_user -- INSERT: the caller's INSERT stamped with the rival's tenant reached the rival's scope in audit2, docs2 ...
  CLS security report -> out\security\sz\cls-report.html  (9 leaking, 0 enforced/contained, 0 unreliable)
  24 (function, role) pair(s) judged over 13 function(s): 24 leaking, 0 too strict, 0 enforced, 0 unproven, 0 unproven cell(s); 0 not covered
  security report -> out\security\sz\sec_report.html
```

### The Data security coverage report

A contents index, then numbered chapters. Every table has a row-number column and every chapter heading is a
link anchor.

![The Data security coverage report](img/img06.png)

A run on a leak / no-leak test corpus - 17 SECURITY DEFINER functions judged, 8 leaking and 9 enforced. The
tiles read 8 leaking and 13 enforced: the 9 functions plus 4 RLS tables whose policy tests pass.

| Chapter | What it shows |
| --- | --- |
| 1. Summary | Four totals - leaking, too strict, enforced, unproven - across functions, views, trigger bindings and RLS tables. Then one card per check (RLS policy tests, RLS leaks, trigger bindings, views, PII in errors) saying whether it ran and what it found. |
| 2. What to fix | Every finding ranked, with the object, the finding, the smallest database change that closes it, and a link to the evidence. **fix now** = another tenant's data is reachable or writable. **review** = no leak, but a wrong result for an entitled caller, a policy error, an open policy, or a hardening gap. **not evidenced** = the path could not be exercised, so the fix is a test fixture, not a schema change. |
| 3. Reports | The other reports of the run, each with the question it answers and a link. Only files that exist are listed. |
| 4. How to read this report | A glossary of every verdict, flag, caller, cell mark, channel and column. |
| 5. Function verdicts | Every client-reachable `SECURITY DEFINER` function: its verdict, links to its unit test and its security tests, its coverage, and one row per table and role with a mark per command. |
| View verdicts | Only when there are views. A view runs as its owner unless it is `security_invoker`, so the base table's RLS may never be checked for the caller. |
| Trigger bindings | Each trigger on a row-secured table, per role and command, with a *Leaks into* column naming the exact tables a leak reaches. |
| RLS policies (last) | One matrix per table - identities by command, for row level and column level - with holes, too-strict and unreliable cells, policy errors, and a pgTAP test link per table. Then the bypass surfaces. |

Chapters 1 to 5 keep these numbers whenever the run judged functions. After that the numbers depend on what
the run found: View verdicts only when there are views, then *Not covered - and by whom*, *What each caller
got back* and *Member of 2 tenants* when there is something to show, then Trigger bindings, *Who else can
read these tables*, and the RLS policies last.

The marks: **✗** a hole - the role can act but shouldn't · **!** too strict - an authorised caller is denied
· **✓** enforced as declared · **?** unproven - the check could not have fired.

### The column-level security report

`cls-report.html` catches a value reaching a **column** a role has no grant on: on `SELECT` that is read
escalation; on `INSERT` / `UPDATE` it is a caller's value written into a column the role cannot write. It has
up to three sections - Functions, Triggers and Views - each with a *Source* column (where the value comes
from) and a *Leakage* column (the `table.column` where it improperly becomes visible).

```
Function                                  Verdict   Role     Channel  Source              Leakage
cf_read_enforced()                        CLEAN     tl_user  SELECT   accounts.secret_ssn  ✓ withheld from caller
cf_read_leak()                            LEAKING   tl_user  SELECT   accounts.secret_ssn  ✗ cf_accounts.secret_ssn
cf_insert_leak(p_id, p_secret)            LEAKING   tl_user  INSERT   arg p_secret         ✗ cf_accounts.secret_ssn
```

Verdicts: `CLEAN` (the restricted column was withheld), `LEAKING`, `PINNED (no grant today)` (the path exists
but no client role holds the grant today), `NOT APPLICABLE`, and `UNRELIABLE` (could not be judged soundly -
reported, never a false green).

**Use seccover to:** block a release when a leak is found (`--sec-gate`), work through *What to fix* from the
top, and read the *Leaks into* column to see exactly which table and command exposes one tenant's data to
another.

## 4. `pii` - PII in error and RAISE messages (Enterprise licence)

The PII audit is part of every security pass: `unitautogen seccover` and `unitautogen hipaa` run it by
default, and `unitautogen pii` is the same pass under its own name. It drives each routine so that its error
and `RAISE` paths run, then checks the messages for personal data - names, emails, phone numbers, card-like
numbers, and similar. A function that echoes a row into an exception message is exactly what it catches.

|  |  |
| --- | --- |
| What it does | Audits every routine's error and `RAISE` output for leaked personal data, as part of the security pass. |
| Generates tests? | YES - the seccover security tests, plus the PII findings. |
| Command | `unitautogen pii --schema public --out sec_out` |
| Key options | The same as `seccover`. `--config FILE` declares personal-data columns the tool does not recognise (see [the config file](config-file.md)). Inside `seccover` and `hipaa`, `--no-pii-audit` turns it off. |
| Report(s) | The full seccover output, plus `<out>/pii_tests/pii_findings.json` (always) and the PII-in-error report `<out>/pii_tests/pii_report.html` (only when something leaks). |
| Folder | `<out>/security/<schema>/` and `<out>/pii_tests/`. |

A clean run writes no `pii_report.html`; the PII card of the Data security coverage report reads "ran clean".

Besides the usual personal data it recognises **PHI by column name**: medical record numbers, health plan and
insurance IDs, diagnosis and ICD codes, medication and prescriptions, lab results and other clinical data,
and provider IDs.

### The PII-in-error report

![The PII-in-error report](img/img07.png)

A run against a fixture that leaks - **5 routines / 7 findings, 7 confirmed, 1 not audited**. Each row names
the leaking function or trigger, where it leaks (*Leak site*), the *Pattern*, and the exact *Source of
leakage* - here `patient.email` and `patient.full_name` echoed straight into handler output.

| Report element | What the data represents |
| --- | --- |
| Counters | Routines leaking PII, total findings, confirmed vs possible, and not audited. |
| Pattern | *column-emit* - a column's value written into the message; *raise-exposure* - a `RAISE` puts a column or argument into the error; *error-passthrough* - the handler re-emits the caught error's MESSAGE/DETAIL/HINT; *context-exposure* - the error context is re-emitted. |
| Severity | *confirmed* - a value classified as PII reached the output; *echo* - a handler re-emitting diagnostics; *not-audited* - the handler could not be driven, so it is neither cleared nor blamed. |

Every leak is proven by real output, never inferred from the source: the value must actually appear in the
handler's output before it is listed.

**Use pii to:** catch routines that echo personal data into error messages before those messages reach
production logs or clients.

## 5. `hipaa` - HIPAA evidence (Enterprise licence)

`hipaa` runs seccover and adds the **audit-log check**: for each table, whether every `INSERT`, `UPDATE` and
`DELETE` is recorded, where, with which values, and whether that record can be altered. It writes one
stamped HIPAA report covering access control, audit controls, integrity and authentication, mapped to the
Security Rule.

|  |  |
| --- | --- |
| What it does | seccover, plus the audit-log check, as one stamped HIPAA evidence report. |
| Generates tests? | Through seccover and the trigger tests. `hipaa` writes no tests of its own. |
| Command | `unitautogen hipaa --schema public --out unitautogen_tests` |
| Key options | The seccover options · `--config FILE` audit or PHI tables the tool missed · `--storage` also check Supabase Storage. |
| Report(s) | `<out>/hipaa/<schema>/hipaa_report.html` and `hipaa_report.json`. |

The full description - the report's chapters, the audit-table rules, Supabase Storage, and what the report
does and does not cover - is on its own page: [HIPAA evidence](hipaa.md).
