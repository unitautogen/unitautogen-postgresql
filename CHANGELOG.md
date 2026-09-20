# Changelog

All notable changes to UnitAutogen for PostgreSQL are recorded here. Versions follow the product's release tags.

## 0.3.2-beta

First public beta of the PostgreSQL edition.

- Unit and trigger test generation with branch and statement coverage (Community Edition).
- Integration testing across the function call map (Team).
- seccover security-coverage pass, and PII audit via `--pii` (Enterprise).
- Standard pgTAP output; HTML and JSON reports; Cobertura and JUnit for CI.
- The one guarantee: no fabricated, false-passing, or flaky tests. Branches that cannot be driven soundly are reported as NOT_TESTABLE with a reason, never faked.
- Windows and Linux builds.

See the [README](README.md) for prerequisites and the quick start.
