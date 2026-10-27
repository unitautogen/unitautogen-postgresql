# The config file (`unitautogen.toml`)

UnitAutogen finds PHI, personal data and audit tables on its own. When it misses one, or picks one
wrongly, you correct it in one file, `unitautogen.toml`. Every compliance check reads it, and every
report marks what came from it.

## Where it lives

- `unitautogen.toml` in the folder you run from. It is picked up automatically.
- Or any path: `--config path/to/file.toml`. Every command accepts it.
- No file, no change to the run.
- The format is TOML, the same format as Supabase's `supabase/config.toml`. Lines starting with `#` are comments.

## Example

```toml
[phi]                       # HIPAA: protected health information
tables  = ["clinic.patients", "clinic.visits"]
columns = ["clinic.staff.home_phone"]
not     = ["public.countries", "clinic.users.email"]

[pii]                       # personal data (PII-in-error check)
columns = ["crm.contacts.mobile_no"]

[audit]                     # audit tables
tables  = ["audit.change_log"]
not     = ["clinic.event_types"]

[audit.map]                 # optional: where a table's changes must be logged
"clinic.patients" = "audit.patient_log"
"clinic.visits"   = ["audit.change_log", "audit.visit_history"]
```

## Sections

| Section | What it declares | Used by |
| --- | --- | --- |
| `[phi]` | Tables and columns that hold PHI | HIPAA report, PII-in-error check |
| `[pii]` | Tables and columns that hold personal data | PII-in-error check |
| `[audit]` | Audit tables | HIPAA audit controls and integrity |
| `[audit.map]` | Which audit table(s) a table must log to | HIPAA audit controls |

Every section uses the same keys:

- `tables` adds tables the tool missed.
- `columns` adds columns the tool missed (`[phi]` and `[pii]`).
- `not` removes a wrong guess. In `[phi]` and `[pii]` it can name a table or a column.

PHI counts as personal data, so a `[phi]` entry is also used by the PII-in-error check.

## Names

- A table is `schema.table`. A column is `schema.table.column`.
- Leave the schema out (`"patients"`, `"visits.notes"`) to match the name in every schema of the run.
- Names match without regard to case, as unquoted names do in PostgreSQL. A mixed-case name, or one
  with a dot in it, goes in double quotes, as in SQL: `'clinic."CustomerPII".email'`.

## Rules

- The final set is what the tool detects, plus what the file adds, minus what `not` removes. The file always wins.
- A column entry beats a table entry. A column of a declared table belongs to that table's class.
- The same name added and removed in one section is an error.

## What each entry changes

- `[audit] tables` - the table is an audit table, whatever its name or columns.
- `[audit] not` - a log-like table is judged as a data table.
- `[audit.map]` - checked on every run. A change recorded into a different audit table than the one
  declared is a gap, listed in What to fix with both tables named. A table without an entry is linked
  to its audit table automatically.
- `[phi] tables` - the table holds PHI, even when its name looks like a log.
- `[phi] not` - the table stays in the HIPAA report; its findings are marked *not PHI - from config file*.
- `columns` entries - a value of that column reaching an error message is classified PHI or personal
  data, whatever the column's name. A `not` column is never classified; a leak through it is still listed.

## What came from the file

Reports always show which tables and columns came from the config file, not from detection:

- a *Taken from the config file* table (object, declared as, used for, line in the file) in the HIPAA
  and Data security coverage reports, with the file's SHA-256 and any warnings;
- *from config file* next to every declared table, audit table and finding;
- the file's path and SHA-256 in the HIPAA evidence stamp.

## Checks

- A bad file stops the run with exit code 2 and names the line.
- A name not found in the database is a warning on the console and in the report, never silently ignored.
- The run prints the file it used: `config: <path> (sha256 ...)`.
