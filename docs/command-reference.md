# Command quick-reference

| Command | Purpose | Generates tests? | Main report / folder |
| --- | --- | --- | --- |
| `unitautogen` *(default)* | Unit tests + coverage for functions & triggers | YES | HTML + JSON; `--out` folder (`test_*.sql` + `trigger_tests/`) |
| `unitautogen integration` | End-to-end call-map tests Team | YES | HTML + JSON; `--out` folder |
| `unitautogen seccover` | Full security-coverage review Enterprise | YES | Security HTML + JSON + classification report |
| `unitautogen seccover --pii` | PII in error / RAISE messages Enterprise | YES | Security report with a PII-in-error section |

Options every command takes: `--config FILE` (the [config file](config-file.md); `./unitautogen.toml` is read automatically) and `--debug [LOGFILE]` (a log file to send to support).

Global help: `unitautogen --help` lists the four commands;
`unitautogen <command> --help` shows one command's options.

**Supabase projects:** add `--supabase` to any command (run it from inside your Supabase project) to auto-detect the project via `supabase/config.toml`, use the local Supabase database, default `--schema` to `public`, and write the generated tests into `supabase/tests/seccover/` ready for `supabase test db`.
