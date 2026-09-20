# Prerequisites

- **The `unitautogen` executable.** A single self-contained binary -
  no Python installation, no dependencies to manage. Put it on your `PATH` (or call
  it by full path).
- **PostgreSQL 14-18**, with two **required** extensions installed
  *in the database you are testing*:
  - [pgTAP](https://pgtap.org/) - the framework the generated tests are written in.
  - [plpgsql\_check](https://github.com/okbob/plpgsql_check) - the coverage meter.Both are required. UnitAutogen checks for them before it generates anything and stops with a clear message
  (exit code **3**) if either is missing, naming the exact command to run - so you never get a
  half-finished run.

### Installing pgTAP and plpgsql\_check

Both are standard PostgreSQL extensions, added in two steps: install the extension on the database
*server* once (a one-time DBA action), then enable it in each database you test.

**1. Install on the server.**

- **Linux, Debian / Ubuntu** (PostgreSQL PGDG apt repo), e.g. for PostgreSQL 16:
    
  `sudo apt install postgresql-16-pgtap postgresql-16-plpgsql-check`
  (swap `16` for your major version).
- **Linux, RHEL / Rocky / Alma** (PGDG yum repo):
    
  `sudo dnf install pgtap_16 plpgsql_check_16`.
- **Windows or from source.** pgTAP is pure SQL on PG14+ (no compiler needed) - install it
  from the [pgTAP](https://pgtap.org/) distribution. plpgsql\_check is a compiled extension - use a
  prebuilt build that matches your PostgreSQL major version (from the
  [plpgsql\_check](https://github.com/okbob/plpgsql_check) releases) and place its files in
  PostgreSQL's `lib` and `share/extension` directories.
- **Managed / cloud PostgreSQL** (Supabase, Neon, Amazon RDS and Aurora, Azure Database for PostgreSQL, and similar): both
  are frequently available already - just run the `CREATE EXTENSION` step below. If a
  provider does not offer one of them, check its supported-extensions list or ask its support to enable it.

**2. Enable in each database you test** (once per database; needs a role allowed to create
extensions):

```
CREATE EXTENSION IF NOT EXISTS pgtap;
CREATE EXTENSION IF NOT EXISTS plpgsql_check;
```

This is exactly the command UnitAutogen prints when it detects a missing extension. Extensions are
per-database, so repeat step 2 for every database you point the tool at.

**The tables your routine reads must exist.** They must be present in the database, along with any custom types they use, even if empty. UnitAutogen does not need them populated, but it does need them to be there.

**Privilege note.** Plain functions need no special rights. A few advanced setups - around
triggers, circular foreign keys, and role-dependent branches - need a superuser/replication-capable role.
Without it, those specific branches are skipped honestly (reported `NOT_TESTABLE`)
rather than faked. Licensing by command: the default unit-test generation is free;
`integration` needs a **Team** license;
`seccover` and `--pii` need an **Enterprise**
license.
