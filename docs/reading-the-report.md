# Reading the report

Open the HTML report and you get a summary table (one row per routine, with branch % and statement %) and,
by clicking a routine name, its **annotated source**: covered lines in green, uncovered lines
in red. The numbers come from actually running the generated tests, so they are measured, not estimated.

### Coverage numbers

- **Branch %** - the share of true/false decision outcomes your tests covered.
- **Statement %** - the share of executable lines the tests ran.
- A routine can show *100% statement* but *less than 100% branch* when a result-set query
  has a condition (e.g. a date range) that no committed test exercised on both sides - the report names the
  exact untested condition.

### Every uncovered line is explained

Rather than leave a line simply red, the report tags each uncovered line so you know whose problem it is:

| Tag | Meaning | What to do |
| --- | --- | --- |
| **D** | **Dead code** - the line can never run, sometimes proven with the exact contradictory conditions named. | Check your logic; it usually points at a real bug. |
| **H** | **Error-recovery code** - inside an exception handler that valid data cannot reach. Untested by default, by design. | Nobody's bug. You can opt in to cover it. |
| **E** | **Tool limit** - no evidence of dead code; the tool could not produce a test for this line. | An honest gap in the tool. Reporting the routine helps close it. |

The counts appear as `D:n, H:n, E:n` in the summary table's Uncovered column and in
the JSON under `uncovered_classes`, so CI can flag when a new suspected-dead branch
appears in a commit.

### NOT\_TESTABLE

When a branch cannot be tested reliably, it is reported
`NOT_TESTABLE` with a plain reason (for example, an error handler that valid data cannot reach, or a
genuinely non-deterministic path). This is the guarantee in action: a visible, explained gap instead of a
false green.
