# FAQ & troubleshooting

### Coverage is 100% statement but less than 100% branch. Why?

A result-set query has a condition that no committed test exercised on both sides (e.g. a date-range filter).
The report names the exact untested condition so you can add data that trips it, or confirm the other side is
unreachable.

### It stopped with exit code 3.

pgTAP or plpgsql_check is missing in that database. Both are required. The message names the exact
`CREATE EXTENSION` to run. Nothing was generated. See [Prerequisites](prerequisites.md).

### It says "CANNOT CONNECT" (exit code 4).

The database could not be reached with the settings in your environment. The first line names where the
settings came from: a connection-string variable, or the host, port, database and user from the `PG*`
variables. A leftover `DATABASE_URL` is a common cause, since it wins over the `PG*` variables. Unset it, or
set `UNITAUTOGEN_DSN` to the database you mean. See [Connecting](connecting.md).

### A paid command stopped with exit code 5 and generated nothing.

It found no licence that covers that command. Put `unitautogen.lic` in the folder you run from, or pass
`--license PATH`. `integration` needs Team; `seccover`, `pii` and `hipaa` need Enterprise.

### A test was "pruned". Is that a failure?

No, the opposite. A generated test did not pass a clean re-run, so it would have been flaky. It was dropped and
the branch reported honestly instead. Pruned tests are listed in the JSON so you can see exactly what was set
aside and why.

### Coverage looks low for a routine whose conditions look simple.

Usually a specific precondition is not being met - a required row, an upsert target, a date gate. The report's
per-line explanations name the blocker (see [Reading the report](reading-the-report.md)). If it turns out to be
a limit of the tool (an **E** tag), reporting the routine is the most useful thing you can do.

### Do I commit the generated tests?

Yes. The generated `.sql` files are ordinary pgTAP. Commit them next to your code and run them in CI (see
[CI/CD](ci-cd.md)). When a routine's intended behaviour changes, re-generate and commit the update.

### What does a run leave in my database?

- Your rows are untouched: every probe runs in a transaction that is rolled back.
- The pgTAP test schemas a run installs are dropped at the end.
- The `testgen` helper schema stays. The committed tests need it.
- When a routine calls `now()`, `random()` or similar, a `testgen_det` schema of frozen stand-ins may stay.

### Do I have to tag which tables hold PHI for the HIPAA report?

No. Which tables and columns hold PHI is decided automatically. When the tool misses a PHI table or an audit
table, or picks a wrong one, declare it in the [config file](config-file.md). Reports mark everything taken
from the file, so your declarations never read as findings of the tool.

### How do I send a debug log?

Add `--debug` to the command and send the file it writes, `unitautogen-debug-<time>.log` in the folder you ran
from (`<time>` is the start of the run, `YYYYMMDD-HHMMSS`), or name it yourself: `--debug mylog.log`. It holds
the tool version, the command, OS, the database server and extension versions, the settings (passwords
masked), the full console output, and whether the run finished or crashed. `--debug` never changes what is
generated.

### Which command should I use day to day?

`unitautogen --schema public --out unit_tests --html report.html` is the one to start with (unit tests are the
default). Reach for `integration` when routines call each other, `seccover` for security review (it includes
the PII audit), and `hipaa` for HIPAA evidence.

---

Generated tests are standard pgTAP; coverage is measured with plpgsql\_check. All command output shown in
these docs was produced by running the actual `unitautogen` commands against live databases.
