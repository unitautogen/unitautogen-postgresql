# Prerequisites

- **The `unitautogen` executable.** A single self-contained binary - no Python installation, no dependencies
  to manage. Put it on your `PATH` (or call it by full path).
  - **Linux:** x86-64 with glibc 2.31 or newer - Debian 11+, Ubuntu 20.04+, RHEL / Rocky / AlmaLinux 8+.
    Not arm64. Copying the binary from a zip or a Windows drive drops the exec bit, so run
    `chmod +x unitautogen`.
  - Check it runs: `unitautogen --version`.
- **PostgreSQL 14-18**, with two **required** extensions installed *in the database you are testing*:
  - [pgTAP](https://pgtap.org/) 1.3.4 or newer - the framework the generated tests are written in.
  - [plpgsql\_check](https://github.com/okbob/plpgsql_check) 2.8 or newer - the coverage meter.

  UnitAutogen checks for both before it generates anything and stops with a clear message (exit code **3**)
  if either is missing, naming the exact command to run - so you never get a half-finished run.
- **A disposable copy of your database, never production.** The tool seeds rows and runs real statements.
  Each is rolled back, but the statements do run.

### Installing pgTAP and plpgsql\_check

Both are standard PostgreSQL extensions, added in two steps: install the extension on the database *server*
once (a one-time DBA action), then enable it in each database you test.

**1. Install on the server.**

- **Linux, Debian / Ubuntu** (PostgreSQL PGDG apt repo), e.g. for PostgreSQL 16:
  `sudo apt install postgresql-16-pgtap postgresql-16-plpgsql-check` (swap `16` for your major version).
- **Linux, RHEL / Rocky / Alma** (PGDG yum repo): `sudo dnf install pgtap_16 plpgsql_check_16`.
- **Windows or from source.** Neither extension ships with the EDB installer or StackBuilder. pgTAP is pure
  SQL on PG14+ (no compiler needed) - install it from the [pgTAP](https://pgtap.org/) distribution.
  plpgsql\_check is compiled - use a prebuilt build that matches your PostgreSQL major version (from the
  [plpgsql\_check](https://github.com/okbob/plpgsql_check) releases) and place its files in PostgreSQL's
  `lib` and `share/extension` directories.
- **Managed / cloud PostgreSQL** (Supabase, Neon, Amazon RDS and Aurora, Cloud SQL, Azure Database for
  PostgreSQL, and similar): both are often available already - just run the `CREATE EXTENSION` step below. If
  a provider does not offer one, check its supported-extensions list or ask its support to enable it.

**2. Enable in each database you test** (once per database; needs a role allowed to create extensions):

```
CREATE EXTENSION IF NOT EXISTS pgtap;
CREATE EXTENSION IF NOT EXISTS plpgsql_check;
```

This is exactly the command UnitAutogen prints when it detects a missing extension. Extensions are
per-database, so repeat step 2 for every database you point the tool at.

**Optional extensions.**

- `uuid-ossp` - only if a routine calls `uuid_generate_v4()`. (`gen_random_uuid()` is built in.)
- `pgaudit` - only for the HIPAA report's statement-logging evidence. See [HIPAA](hipaa.md).

**The tables your routine reads must exist.** They must be present in the database, along with any custom
types they use, even if empty. UnitAutogen does not need them populated, but it reads their real columns and
constraints.

### Privileges

The connecting role needs to create schemas in the database: each run installs its pgTAP test schemas and
drops them at the end.

Plain functions need no other rights. A few advanced setups - around triggers, circular foreign keys, and
role-dependent branches - need a superuser or replication-capable role. Without it, those specific branches
are skipped honestly (reported `NOT_TESTABLE`) rather than faked.

### Licensing

- **Community Edition** - the default unit-test command. Free, no licence needed.
- **Team** - needed for `integration`.
- **Enterprise** - needed for `seccover`, `pii` and `hipaa`.

Paid commands pick up the licence on their own: put `unitautogen.lic` in the folder you run from, or pass
`--license PATH`. A paid command run without its licence reports
`NOT LICENSED`, generates nothing, and exits with code **5**. Editions and prices:
[unitautogen.com/postgresql/pricing](https://unitautogen.com/postgresql/pricing/).
