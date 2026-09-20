# Using UnitAutogen as an AI guardrail

AI coding assistants now write a lot of database logic, functions, triggers, and row-level security policies, and they write it fast. UnitAutogen turns that into a safety net: it generates a pgTAP test suite that pins how your database behaves today, so any later change, from an AI or a person, that alters that behaviour fails a committed test before it ships.

This page shows the workflow with Supabase and an AI editor. It is editor-agnostic: the guardrail runs against your database and your migrations, so it guards whatever wrote them.

## Where the code comes from

Supabase provides an [MCP server](https://supabase.com/docs/guides/ai-tools/mcp) so AI editors can work directly against your Supabase project, and documents it for the editors it supports: Cursor, VS Code with GitHub Copilot, Windsurf, Claude, and Cline. In any of them you describe what you want, the assistant proposes SQL, you approve it, and the change lands as a migration under `supabase/migrations/`. That migration, the function, trigger, or policy it defines, is exactly what UnitAutogen guards, and it is the automated check that the change you approved did not quietly alter behaviour elsewhere.

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

## Step by step

1. **Let the AI write the change.** In Cursor (or your editor), have the assistant add or edit a function, trigger, or policy, and apply the migration to your local database (`supabase db reset`).
2. **Generate the guardrail tests, once, for the reviewed behaviour:**
   ```
   unitautogen --schema public --out supabase/tests/pg --html report.html
   ```
3. **Review and commit.** Read `report.html`, confirm each routine does what you intend, then commit the generated `test_*.sql` files next to the migration. This pins today's behaviour as the baseline.
4. **On the next AI edit, run the committed tests, do not regenerate.** Running the committed pgTAP tests against the changed code is what catches the change, for example with `pg_prove` over the committed files, or `SELECT runtests('test_<routine>'::name)` per routine (see [CI/CD integration](ci-cd.md) for the exact commands). If a change moved behaviour a test pinned, that test fails and names the routine and the old-versus-new value. That is the guardrail firing.
5. **Decide.** If the change was intended, regenerate to re-pin the new behaviour and commit the update. If it was not, you just caught a regression before it shipped.

## Make it automatic in CI

The guardrail is strongest when nobody has to remember it. Add a CI step that stands up a Postgres with pgTAP and plpgsql_check, applies your migrations, and runs the committed tests, failing the build on any failure. Then every AI-authored pull request is checked the moment it opens, at the speed the code was produced. [CI/CD integration](ci-cd.md) has ready-to-use pipeline steps.

## Why you regenerate only when the change was intended

Generating the tests records the current behaviour as the expected value, so a fresh suite is always green. A failure shows up later, when code changes in a way that moves behaviour a test had pinned. If you regenerate after every edit, you re-pin whatever the code now does and lose the guardrail. So: generate to set a baseline, run the committed tests to catch changes, and regenerate only when the change was deliberate. A full walk-through, including a real failing test, is in the [worked example](worked-example.md).
