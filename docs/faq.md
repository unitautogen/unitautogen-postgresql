# FAQ & troubleshooting

### Coverage is 100% statement but less than 100% branch. Why?

A result-set query has a condition that no committed test exercised on both sides (e.g. a date-range
filter). The report names the exact untested condition so you can add data that trips it - or confirm the
other side is unreachable.

### A routine shows "tests generated, coverage skipped".

`plpgsql_check` is not installed in that database. Tests are still generated and
run; install the extension to get branch/statement numbers.

### A test was "pruned". Is that a failure?

No, the opposite. A pruned test is one the tool set aside rather than ship, because it would not have been
reliable; the branch is then reported honestly instead. Pruned tests are listed in the JSON so you can see
exactly what was set aside and why.

### Coverage looks low for a routine whose conditions look simple.

Usually a specific precondition is not being met - a required row, an upsert target, a date gate. The
report's per-line explanations ([§6](#reading)) name the blocker. If it turns out to be a limit
of the tool (an **E** tag), reporting the routine is the most useful thing you can do.

### Do I commit the generated tests?

Yes. The `test_<routine>.sql` files are ordinary pgTAP - commit them next to
your code and run them in CI. When a routine's intended behaviour changes, re-generate (or accept the new
recorded output) and commit the update.

### Which command should I use day to day?

`unitautogen --schema public --html report.html --out unit_tests` is the one to
start with (unit tests are the default). Reach for `integration` when routines call
each other, and `seccover` / `--pii` for security review.

UnitAutogen for PostgreSQL - user documentation. Generated tests are standard pgTAP; coverage is measured
with plpgsql\_check. All command output shown in this document was produced by running the actual
`unitautogen` commands against live databases.
