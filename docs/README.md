# Red Taxi Docs Guide

Use this file to distinguish current operational docs from historical planning material.

## Current Source-Of-Truth Docs

These are the docs that should be treated as the live state of the `dev` branch:

- `CLAUDE.md`
- `docs/dev-setup.md`
- `docs/admin-v2-progress.md`
- `docs/saas/implementation-status.md`
- `docs/frontend-auth-status.md`
- `docs/prd-v2a-auth-consolidation.md`
- `docs/prd-v2b-admin-rebuild.md`
- `docs/prd-v2c-api-completion.md`
- `docs/prd-local-sms-v2.md`

## App READMEs

Current app-specific entrypoints live alongside each app:

- `src/frontend/apps/admin-v2/README.md`
- `src/frontend/apps/dispatch-v2/README.md`
- `src/frontend/apps/saas-admin/README.md`
- `src/frontend/apps/account-booker/README.md`

## Historical Or Archival Docs

These documents are useful context, but they are point-in-time records and may contain the counts or assumptions that were true when they were written:

- `docs/prd-v2-draft.md`
- `docs/documentation-drift-audit-2026-04-07.md`
- `docs/refactor/*`
- `docs/superpowers/specs/*`
- `docs/superpowers/plans/*`

When a historical doc disagrees with a current operational doc, trust the current operational doc and verify against the codebase if the detail matters.
