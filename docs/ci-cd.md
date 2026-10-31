# CI/CD integration

## Run the committed tests, not a fresh generation

A fresh `unitautogen` run is not a regression check. It writes the expected values from the code as it is
now, so its own tests always pass. Commit the generated tests from the `--out` folder, then run those in CI.

- The tests live under `<out>/<lane>/<schema>/`, in `functions/`, `triggers/` and `views/`.
- At run time they need only `psql`, pgTAP, and the `testgen` helper schema in the database. A `unitautogen`
  run installs the helper and leaves it in place. No UnitAutogen binary is needed in CI.
- Unit, integration and trigger tests (`test_<name>.sql`) install a `test_<name>` schema of test functions.
  Install the file with `psql`, then run the schema with `runtests()`. The first line of each file shows the
  call.
- Security, column-level and RLS policy tests (`sec_*.sql`, `cls/`, `rls/`) are pgTAP scripts that run
  themselves. Run them one at a time; they say "RUN SERIALIZED".
- A test that hits a database error is reported as `not ok` with "Test died", and the run goes on with the
  next test. The run stops early only if the connection or the install of a test file fails.

## If a failing test should break the build

Run the tests with `pg_prove` (or `supabase test db`, which uses it). It exits non-zero when any test fails,
so the CI step fails. Below, `tests/` is the committed `--out` folder.

```bash
# install the unit and trigger suites, stop on an install error
for f in tests/unit/*/functions/test_*.sql tests/unit/*/triggers/test_*.sql; do
  psql -v ON_ERROR_STOP=1 -d "$DB" -f "$f"
done
# run them - exits non-zero if any test fails
for s in $(psql -At -d "$DB" -c "SELECT nspname FROM pg_namespace WHERE nspname LIKE 'test\_%'"); do
  pg_prove -d "$DB" --runtests --schema "$s"
done
# the script-style security, CLS and RLS tests, one at a time (no pg_prove -j)
pg_prove -d "$DB" tests/security/*/{functions,triggers,views,cls,rls}/*.sql
```

```
ok 1 - test_classify_amount.test_01_executes_with_valid_inputs
ok 2 - test_classify_amount.test_02_low_boundary
 ...
1..11
# All tests successful.
```

## If a failing test should not break the build

To report pass and fail and let CI decide from a threshold, keep the test step green and decide in a later
step:

```bash
pg_prove -d "$DB" ... > tap.txt || true          # failures do not fail this step
fails=$(grep -c '^not ok' tap.txt)
echo "failed tests: $fails"
[ "$fails" -le 5 ] || exit 1                     # your threshold
```

Or let your CI's test report decide: `pg_prove --formatter TAP::Formatter::JUnit ... > results.xml || true`
writes a JUnit file (it needs the `TAP::Formatter::JUnit` Perl module), and your CI's JUnit thresholds apply
the rule.

Two things to know:

- Plain `psql -c "SELECT * FROM runtests(...)"` always exits 0, even when tests fail. Use it only with a
  counting step like the one above.
- A skipped test (`ok ... # SKIP`) counts as passed in TAP.

The same steps work in GitHub Actions, GitLab CI, Azure Pipelines, Jenkins, or anything that can run `psql`
and `pg_prove`.

## Wiring the reports into CI

The generating run also writes coverage reports. They feed dashboards; they are not a pass/fail gate. The
default command and `integration` write every format into `<out>/<lane>/` by default (`--no-report` skips it):

```
unitautogen --schema public --out ci_out
# -> ci_out/unit/  report.html, report.json, junit.xml, cobertura.xml, coverage.lcov
```

- **Test results** come from your `pg_prove` run of the committed tests. The bundle's `junit.xml` records the
  generating run, which always passes.
- **Coverage dashboards** read `cobertura.xml` or `coverage.lcov` (Codecov, Coveralls, genhtml).
- **Human review** uses `report.html` as a build artifact.

## Security gate

To fail a release pipeline when the security pass finds a problem, add `--sec-gate`:

```
unitautogen seccover --schema public --sec-gate
```

| Exit code | Meaning |
| --- | --- |
| `4` | A function or view leak, or a two-tenant defect. |
| `5` | A confirmed PII-in-error leak. |
| `1` | A leaking trigger binding, a column-level leak, or a failing RLS policy test. |
| `2` | The security pass itself errored. |

When several apply, the highest code is returned. Note that exit 5 also means a paid command ran without its
licence, and exit 4 also means the database could not be reached; both stop before anything is judged. The full
list is in the [command reference](command-reference.md#exit-codes).
