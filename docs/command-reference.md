# Command quick-reference

| Command | Purpose | Generates tests? | Main report / folder |
| --- | --- | --- | --- |
| `unitautogen` *(default)* | Unit tests + coverage for functions & triggers | YES | HTML + JSON; `--out` folder (`test_*.sql` + `trigger_tests/`) |
| `unitautogen integration` | End-to-end call-map tests Team | YES | HTML + JSON; `--out` folder |
| `unitautogen seccover` | Full security-coverage review Enterprise | YES | Security HTML + JSON + classification report |
| `unitautogen seccover --pii` | PII in error / RAISE messages Enterprise | YES | Security report with a PII-in-error section |

Global help: `unitautogen --help` lists the four commands;
`unitautogen <command> --help` shows one command's options.
