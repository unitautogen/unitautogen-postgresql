# CI/CD integration

### Running the generated tests

The `--out` folder holds one `test_<routine>.sql` file
per function and trigger. Each file is a **standalone pgTAP suite**: it creates a
`test_<routine>` schema of test functions, and its header line shows how to run
it. The tests need only `psql` and pgTAP in the database - no Python and no UnitAutogen
at run time - so they slot into whatever runs your SQL in CI. There are two ways to run them.

**Option A - let UnitAutogen run them (simplest).** The command that generates the tests also
runs them and writes the result and coverage reports in one step, so a CI job is a single line:

```
unitautogen --schema public --report --out ci_out
```

The pass/fail results land in `ci_out/junit.xml` and the coverage in
`coverage.lcov` / `cobertura.xml` (wired up below).

**Option B - run the committed `.sql` tests yourself.** Keep the
generated `test_*.sql` in your repo and run them like any other pgTAP suite. Install a
suite, then run it with pgTAP's `runtests()`:

```
psql -d mydb -f ci_out/test_classify_amount.sql
psql -d mydb -c "SELECT * FROM runtests('test_classify_amount'::name);"
```

```
ok 1 - test_classify_amount.test_01_executes_with_valid_inputs
ok 2 - test_classify_amount.test_02_low_boundary
 ...
1..11
# All tests successful.
```

Repeat per file to run more suites (on Linux / macOS,
`for f in ci_out/test_*.sql; do psql -d mydb -f "$f"; done` installs them all), then run
each `test_<routine>` schema with `runtests()`. Trigger
suites live under `ci_out/trigger_tests/` and run the same way. The output is standard
**TAP** (`ok` / `not ok`), which
`pg_prove` and most CI test panels read directly.

### Wiring the reports into CI

Add `--report` to the default command (or `integration`)
to emit every report format CI systems expect, into the `--out` folder:

```
unitautogen --schema public --report --out ci_out
```

```
--report -> ci_out/  (report.html, report.json, junit.xml, cobertura.xml, coverage.lcov)
```

Wire them up as follows:

- **Test results** → `junit.xml` (most CI test panels read JUnit).
- **Coverage dashboards** → `cobertura.xml` or
  `coverage.lcov` (Codecov, Coveralls, genhtml).
- **Human review** → `report.html` as a build artifact.

### Security gate

To fail a release pipeline when the security pass finds a data leak, add
`--sec-gate`:

```
unitautogen seccover --schema public --sec-gate
```

The run exits with code **4** if a leak is found, which you can wire to block the release.
A run with a self-check failure or a would-be false test exits non-zero as well - treat that as a bug
report, since it should never happen.
