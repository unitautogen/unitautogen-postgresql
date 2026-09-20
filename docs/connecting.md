# Connecting to your database

UnitAutogen connects using the standard PostgreSQL environment variables. Set them once, then run any
command:

```
set PGHOST=127.0.0.1
set PGPORT=5432
set PGUSER=postgres
set PGPASSWORD=********
set PGDATABASE=mydb
```

You can also supply a full connection string in `UNITAUTOGEN_DSN` instead of the
separate variables, which is handy when switching between databases:

```
set UNITAUTOGEN_DSN=postgresql://postgres:********@127.0.0.1:5432/mydb
```

**Setting variables depends on your shell.** The examples above use the
Windows Command Prompt (`set VAR=value`). The same variables on other shells:

| Shell | Syntax | Example |
| --- | --- | --- |
| Windows Command Prompt (cmd) | `set VAR=value` | `set UNITAUTOGEN_DSN=postgresql://user:pass@host:5432/mydb` |
| Windows PowerShell | `$env:VAR="value"` | `$env:UNITAUTOGEN_DSN="postgresql://user:pass@host:5432/mydb"` |
| Linux / macOS (bash, zsh) | `export VAR=value` | `export UNITAUTOGEN_DSN=postgresql://user:pass@host:5432/mydb` |

Use whichever matches the terminal you run `unitautogen` from; the variable names and
values are identical across all three.
