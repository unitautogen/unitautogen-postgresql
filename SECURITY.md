# Security policy

We take the security of UnitAutogen, and of the databases you point it at, seriously.

## Reporting a vulnerability

Please report security issues privately. Do not open a public GitHub issue for a vulnerability.

Email **security@unitautogen.com** with:

- a description of the issue and its impact,
- steps to reproduce it, and
- the UnitAutogen version and your platform.

We will acknowledge your report, keep you updated as we assess it, and coordinate a fix and a disclosure timeline with you. We appreciate responsible disclosure.

## Supported versions

UnitAutogen is in beta. Security fixes are made against the latest released version, so please upgrade to the latest release before reporting.

## Scope

UnitAutogen runs on your own systems and does not transmit your schema, your data, or your usage to us. In scope: the tool's own behaviour, for example unsafe handling of a connection string, or generated SQL that could damage a target database. Out of scope: general hardening of PostgreSQL itself.
