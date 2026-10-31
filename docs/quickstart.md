# Quick start

> **Before you run:** point the tool at a disposable copy of your database, never production, with pgTAP and
> plpgsql_check installed. See [Prerequisites](prerequisites.md) and [Connecting](connecting.md). On a
> Supabase project, use [Supabase mode](supabase.md) instead.

Generate unit tests and a coverage report for every function and trigger in the `public` schema. Generating
unit tests is the **default action**, so you don't type a command word:

```
unitautogen --schema public --out unit_tests --html report.html --json report.json
```

**Windows and Linux - same commands.** The tool ships as one self-contained executable per platform, and every
command, flag and report is identical on both. Only how you invoke the binary differs:

| Platform | Invoke it as | Example |
| --- | --- | --- |
| Windows | `unitautogen.exe` (or just `unitautogen` if it is on your `PATH`) | `unitautogen.exe --schema public` |
| Linux | `./unitautogen` (add its folder to `PATH` to drop the `./`) | `./unitautogen --schema public` |

Throughout these docs commands are written as `unitautogen …`; read that as `unitautogen.exe` on Windows and
`./unitautogen` on Linux.

You will see one line per routine, one line per trigger, and a summary. Real output from a sample database:

```
  public.account_health: 14 tests kept, branch 100% / stmt 100%  [test_account_health.sql]
  public.accrue_interest: 15 tests kept, branch 100% / stmt 100%  [test_accrue_interest.sql]
  public.apply_overdraft_fee: 12 tests kept, branch 100% / stmt 100%  [test_apply_overdraft_fee.sql]
  public.close_account: 9 tests kept, 1 pruned -> NT, branch 100% / stmt 100%  [test_close_account.sql]
  public.post_entry: 7 tests kept, 1 pruned -> NT, branch 100% / stmt 100%  [test_post_entry.sql]
  public.transfer_funds: 15 tests kept, 1 pruned -> NT, branch 100% / stmt 100%  [test_transfer_funds.sql]

== trigger battery ==
  [OK  ] public.account :: audit_balance  2/2  [update:wrote, update:absent]
  [OK  ] public.journal_line :: require_linked_account  3/3  [insert:threw, insert:rows, insert:rows]
  triggers: 2 (2 behaviour-driven, 0 skipped), 5 behavioural assertions, 0 fail, 0 skip

== done: 72 tests across 6 routines, avg branch 100.0% -> unit_tests/ ==
```

That single command produced:

- 72 runnable pgTAP tests for the functions, one `test_<routine>.sql` each in `unit_tests/unit/public/functions/`;
- behaviour tests for the 2 triggers in `unit_tests/unit/public/triggers/`;
- the HTML report and the JSON summary;
- the CI report bundle (JUnit, Cobertura, LCOV) in `unit_tests/unit/`.

A "1 pruned -> NT" note is the guarantee at work: a test that would not pass cleanly is dropped and the branch
reported honestly, never faked.

Run a generated suite yourself at any time - install the file, then run its schema:

```
psql -d mydb -f unit_tests/unit/public/functions/test_transfer_funds.sql
psql -d mydb -c "SELECT * FROM runtests('test_transfer_funds'::name);"
```

Next: [the five commands](commands.md), [reading the report](reading-the-report.md), and running the tests in
[CI](ci-cd.md).
