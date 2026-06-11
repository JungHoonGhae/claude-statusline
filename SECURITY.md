# Security Policy

## Supported Versions

This project is distributed as a rolling release — the `main` branch is the only
supported version. Please make sure you are running the latest scripts before
reporting an issue.

## Reporting a Vulnerability

If you discover a security vulnerability, please **do not open a public issue**.
Instead, report it privately:

- Email: **lucas.ghae@gmail.com**
- Or use GitHub's [private vulnerability reporting](https://github.com/JungHoonGhae/claude-statusline/security/advisories/new).

Please include:

- A description of the vulnerability and its impact
- Steps to reproduce
- Any relevant logs or proof-of-concept

You can expect an initial response within a few days. Once the issue is
confirmed and fixed, we will publish the fix and credit you (unless you prefer
to remain anonymous).

## Scope

This statusline runs locally and reads:

- The JSON payload Claude Code pipes to it on stdin
- Your OAuth token from the OS keychain / credentials file (read-only, used only
  to query the Anthropic usage API over HTTPS)
- `ccusage` output for token-cost aggregation

It does not transmit your credentials anywhere except `api.anthropic.com`. If you
find behavior that contradicts this, it is a security issue worth reporting.
