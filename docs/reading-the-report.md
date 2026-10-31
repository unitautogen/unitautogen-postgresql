# Reading the report

Open the HTML report and you get a summary table - one row per routine, with branch % and statement % - and a
section for triggers below it. Click a routine name for its **annotated source**: covered lines in green,
uncovered lines in red. The numbers come from actually running the generated tests, so they are measured, not
estimated.

### Coverage numbers

- **Branch %** - the share of true/false decision outcomes the tests covered.
- **Statement %** - the share of executable lines the tests ran.
- **Tests** - split into pass, fail, error and skip. Fail is always 0. Skip counts the hand-built expectation
  scaffolds left for you to fill in.
- **Autonomy** - how many tests are generated as they are, and how many you have edited.

A routine can show *100% statement* but *less than 100% branch* when a result-set query has a condition (e.g. a
date range) that no test exercised on both sides. The report names the exact untested condition.

### Every uncovered line is explained

Rather than leave a line simply red, the report tags each uncovered line so you know whose problem it is:

| Tag | Meaning | What to do |
| --- | --- | --- |
| **D** | **Dead code** - the line can never run, sometimes proven with the exact contradictory conditions named. | Check your logic; it usually points at a real bug. |
| **H** | **Error-recovery code** - inside an exception handler that valid data cannot reach. Untested by default, by design. | Nobody's bug. |
| **E** | **Tool limit** - no evidence of dead code; the tool could not produce a test for this line. | An honest gap in the tool. Reporting the routine helps close it. |
| **Q** | A query condition the test data did not exercise on both sides. | Add data that trips it, or confirm the other side is unreachable. |
| **BUG** | A bug in the function itself. | Fix the function. |
| **DDL** | A statement that emits DDL. | Review whether it belongs in the routine. |
| **U** | (Triggers) an arm that cannot run under this binding's events, e.g. a DELETE arm on an INSERT-only trigger. | Nothing, if a sibling binding covers it. |

The counts appear in the summary table's Uncovered column and in the JSON under `uncovered_classes`, so CI can
flag when a new suspected-dead branch appears in a commit.

### NOT\_TESTABLE

When a branch cannot be driven without a fabricated or flaky test, it is reported `NOT_TESTABLE` with a plain
reason - for example an error handler that valid data cannot reach, a genuinely non-deterministic path, or an
event trigger (`NOT_TESTABLE: EVENT_TRIGGER`). This is the guarantee in action: a visible, explained gap
instead of a false green.

### Drill-downs

- A **function** shows the write footprint per test (rows inserted, updated or deleted, and what it returned),
  the query arms measured on the test data, and the annotated source with per-line hit counts.
- A **trigger** shows what each firing changed, and what it correctly did not change, plus the call tree and
  the stitched source of the trigger function and its helpers.
- Click a test name in either drill-down to open its committed pgTAP definition.

### When a test fails after a code change

A fresh suite is always green, because the generator records the routine's current output as the expected
value. A failure appears later, when the code changes in a way that alters behaviour a test had pinned. Only the
tests whose recorded result moved fail; the rest stay green, so a failure points straight at what changed. If
the change was intended, re-generate and commit the update. The [worked example](worked-example.md) shows one
up close.
