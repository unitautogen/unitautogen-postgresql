# Using UnitAutogen as an AI guardrail

AI coding assistants now write a lot of database logic, functions, triggers, and row-level security policies, and they write it fast. UnitAutogen turns that into a safety net: it generates a pgTAP test suite that pins how your database behaves today, so any later change, from an AI or a person, that alters that behaviour fails a committed test before it ships.

The best part is that you do not have to run any of it yourself. You can hand the whole loop to the assistant. You tell it once to use UnitAutogen as its guardrail, then you just keep asking for features in plain language. From then on, every time it touches database code the assistant generates or runs the tests itself, and it will not hand you code that breaks them.

This page shows that workflow with Supabase and an AI editor. It is editor-agnostic: the guardrail runs against your database and your migrations, so it guards whatever wrote them.

## Where the code comes from

Supabase provides an [MCP server](https://supabase.com/docs/guides/ai-tools/mcp) so AI editors can work directly against your Supabase project, and documents it for the editors it supports: Cursor, VS Code with GitHub Copilot, Windsurf, Claude, and Cline. In any of them you describe what you want, the assistant proposes SQL, applies it as a migration under `supabase/migrations/`, and can run commands in your terminal. Those two abilities, writing the migration and running commands, are all it needs to run UnitAutogen as a guardrail without you lifting a finger.

## Ask once: give the assistant the guardrail rule

Editors read a project rules file and follow it on every request. Put the rule below in yours, once:

- **Cursor:** `.cursor/rules/unitautogen.mdc`
- **Claude / Claude Code:** `CLAUDE.md`
- **Most other editors:** `AGENTS.md` in the project root

```
Use UnitAutogen as the guardrail for all database work.

Whenever you add or change a PostgreSQL function, procedure, trigger, or
RLS policy, before you tell me you are done:

1. Apply the migration to the local database:  supabase db reset
2. Run the committed guardrail tests first:
     pg_prove -d "$DATABASE_URL" supabase/tests/pg/*.sql
3. If a test fails and I did NOT ask for that behaviour to change, the
   code is wrong. Fix the code and re-run until every test passes.
   Never edit a test file to make it pass.
4. If this is new logic that has no tests yet, or I confirmed the
   behaviour change was intended, (re)generate the tests:
     unitautogen --schema public --out supabase/tests/pg --html report.html
   then run them once to confirm they pass, and commit the test files
   together with the migration.
5. In your reply, tell me which tests you ran, the pass/fail count, and
   any tests you regenerated and why.
```

That is the whole setup on your side. The rest happens on its own.

## Then just build (an example session)

Here is what a real session looks like. You type plain feature requests. The assistant does the guardrail loop each time and reports back. You never run a command.

**You:**

> Add a function `membership_tier(p_points int)` that returns the tier: bronze under 500, silver from 500 to 999, gold 1000 and up.

The assistant writes the function, applies the migration, and because there are no tests for it yet, generates and runs them:

```
unitautogen --schema public --out supabase/tests/pg
pg_prove -d "$DATABASE_URL" supabase/tests/pg/test_membership_tier.sql
```

**Assistant:**

> Added `membership_tier` and generated 6 guardrail tests covering the bronze, silver and gold boundaries. All 6 pass. I committed the tests next to the migration.

You did not run anything. The behaviour you just approved is now pinned.

---

**You (a week later):**

> Add a platinum tier for 5000 points and up.

The assistant edits the function and, following the rule, runs the committed tests *first*, before it reports back. One fails:

```
pg_prove -d "$DATABASE_URL" supabase/tests/pg/*.sql
not ok 4 - membership_tier :: p_points = 1000
    #   have: silver
    #   want: gold
```

It catches its own mistake. While adding the platinum branch it had rewritten the gold check as `p_points > 1000` instead of `>= 1000`, so a customer with exactly 1000 points slipped a tier. It corrects the line, re-runs the committed tests until they pass, then regenerates so the new platinum branch is covered too, runs those, and commits.

**Assistant:**

> While adding platinum I had shifted the gold boundary, and the committed test for exactly 1000 points caught it (have: silver, want: gold). I corrected the gold check to `>= 1000`, confirmed all existing tests pass again, then regenerated to add coverage for the platinum tier. 8 tests, all green, committed.

The regression never left your machine, and you never ran a test. That is the guardrail working *inside* the coding loop, not after it.

---

**You (this time you mean it):**

> Rename the bronze tier to "starter".

Now a failing test is the correct outcome. The assistant runs the committed tests, sees them fail with `have: starter, want: bronze`, recognises this is the rename you just asked for, so it regenerates to re-pin the new behaviour instead of "fixing" the code, runs the fresh suite green, and commits.

**Assistant:**

> This was the rename you asked for, so I treated the change as intended: I regenerated the tests to pin "starter" as the new baseline, confirmed all pass, and committed. 8 tests, all green.

That is the one judgement call in the loop, and the assistant makes it from your instruction: a failure you did not ask for means fix the code; a failure that matches what you asked for means re-pin the baseline.

## One-time setup

UnitAutogen needs a PostgreSQL that has your schema and both the pgTAP and plpgsql_check extensions. Point it at whichever database you can enable both on: your local Supabase database, a standard Postgres container in CI, or any dev database that mirrors your schema. The tests it produces are ordinary pgTAP, so they run anywhere pgTAP is installed.

1. Install UnitAutogen. See [installation](installation.md).
2. Bring up a database with your schema. For local Supabase:
   ```
   supabase start
   supabase db reset      # applies your migrations to the local database
   ```
3. Enable the extensions in that database (once):
   ```
   CREATE EXTENSION IF NOT EXISTS pgtap;
   CREATE EXTENSION IF NOT EXISTS plpgsql_check;
   ```
   If a hosted provider does not offer one of them, generate and check against your local database or a CI Postgres instead, where both are available. See [prerequisites](prerequisites.md).
4. Make the connection string available to the assistant's terminal as `DATABASE_URL`. For local Supabase, `supabase status` prints it (typically `postgresql://postgres:postgres@127.0.0.1:54322/postgres`). The rule uses `pg_prove`, which ships with pgTAP; if it is not installed, the tests also run with `psql -d "$DATABASE_URL" -c "SELECT * FROM runtests('test_<routine>'::name);"`.

Once this is in place and the rule is in your rules file, the assistant handles the rest on every request.

## Make it automatic in CI too

The in-editor loop catches a break before you even see the code. A CI check is the backstop for anything that reaches a pull request, for example a change made outside the editor. Add a step that stands up a Postgres with pgTAP and plpgsql_check, applies your migrations, and runs the committed tests, failing the build on any failure. [CI/CD integration](ci-cd.md) has ready-to-use pipeline steps.

## Why the assistant regenerates only when the change was intended

Generating the tests records the current behaviour as the expected value, so a fresh suite is always green. A failure shows up later, when code changes in a way that moves behaviour a test had pinned. If the assistant regenerated after *every* edit, it would re-pin whatever the code now does and lose the guardrail. That is why the rule is explicit: run the committed tests to catch changes, fix the code when a failure was not asked for, and regenerate only when the change was deliberate. A full walk-through of a passing run and a failing run, up close, is in the [worked example](worked-example.md).
