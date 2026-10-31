# Connecting to your database

> **Use a disposable copy, never production.** UnitAutogen probes each routine by seeding rows and running
> real statements. Each is rolled back, but the statements do run.

UnitAutogen connects using the standard PostgreSQL environment variables. Set them once, then run any
command:

```
set PGHOST=127.0.0.1
set PGPORT=5432
set PGUSER=postgres
set PGPASSWORD=********
set PGDATABASE=mydb
```

You can also give a full connection string in `DATABASE_URL`. Many platforms, CI systems and Supabase setups
already set it, and UnitAutogen uses it with no extra step:

```
set DATABASE_URL=postgresql://postgres:********@127.0.0.1:5432/mydb
```

To point UnitAutogen at a different database from the rest of your tools, set `UNITAUTOGEN_DSN`. It wins over
`DATABASE_URL`:

```
set UNITAUTOGEN_DSN=postgresql://postgres:********@127.0.0.1:5432/mydb_test
```

## Which setting wins

1. `UNITAUTOGEN_DSN`.
2. `DATABASE_URL`.
3. The separate `PG*` variables, used only when no connection string is set.

Check `DATABASE_URL` before you run. It often points at an application's real database. Point UnitAutogen at a
test or disposable copy, or set `UNITAUTOGEN_DSN` to override it.

## Setting variables depends on your shell

The examples above use the Windows Command Prompt (`set VAR=value`). The same variables on other shells:

| Shell | Syntax | Example |
| --- | --- | --- |
| Windows Command Prompt (cmd) | `set VAR=value` | `set UNITAUTOGEN_DSN=postgresql://user:pass@host:5432/mydb` |
| Windows PowerShell | `$env:VAR="value"` | `$env:UNITAUTOGEN_DSN="postgresql://user:pass@host:5432/mydb"` |
| Linux / macOS (bash, zsh) | `export VAR=value` | `export UNITAUTOGEN_DSN=postgresql://user:pass@host:5432/mydb` |

The variable names and values are identical across all three.

## If the connection fails

`unitautogen` stops before generating anything, with exit code **4**. The message names the variable it
used, never its value, since that holds the password:

```
CANNOT CONNECT to PostgreSQL using the connection string in DATABASE_URL: <reason>
  -> set the connection via environment variables: PGHOST, PGPORT, PGDATABASE, PGUSER, PGPASSWORD
     (or a single connection string in UNITAUTOGEN_DSN or DATABASE_URL, e.g. postgresql://user:password@host:5432/dbname)
  Nothing was generated.
```

With no connection string set, the first line names the host, port, database and user instead. A connection
attempt gives up after 10 seconds.

In a Supabase project you can skip this page: [Supabase mode](supabase.md) finds the local database for you.
