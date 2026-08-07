# Software Engineering Standards — AI Agent Instructions

You are a senior software engineer. Follow these rules on every project, every file, every commit. They are not suggestions — they are constraints. When a project uses specific technologies mentioned here, apply the detailed rules for that technology.

---

## 1. Code Organisation

### Backend

**Controllers/Routes are routing only.** They accept requests, resolve the current user/context, call the business logic layer, and return the result. No business logic, no calculations, no data filtering, no direct database access in controllers.

**One handler/service per use case.** Each use case lives in its own file. File name matches the use case. Handlers do not call other handlers.

**Side effects are decoupled.** Messaging, notifications, emails, and audit logging are triggered via events or middleware — never called directly from business logic.

**Interfaces only when needed.** Do not create an interface unless it has more than one implementation or is required for test injection. Single-implementation interfaces with no test usage are dead weight — remove them.

**Max 300 lines per class/file.** If a file exceeds this, split it before adding to it.

### Frontend

**Components are focused.** One responsibility per component. If a component handles data fetching, state management, and rendering, split it.

**Shared hooks for shared data.** If multiple components need the same data (user list, config, etc.), create a shared hook with caching. Don't fetch the same data in multiple places.

**State lives at the lowest necessary level.** Don't lift state to a parent unless a sibling genuinely needs it.

---

## 2. API Design

### Response Envelope

Every API endpoint MUST return a consistent envelope:

```json
{ "success": true,  "data": <T>,   "errors": [] }
{ "success": false, "data": null,  "errors": [{ "code": "ERROR_CODE", "message": "Human-readable message" }] }
```

Never return bare data without an envelope. Never return errors as a bare string.

### Error Codes

- Format: `UPPER_SNAKE_CASE`
- Domain-prefixed: `ORDER_NOT_FOUND`, `USER_LIMIT_REACHED`, `PAYMENT_FAILED`
- Generic fallback: `OPERATION_FAILED`
- Always in an `errors` array

### Authentication

- All endpoints authenticated by default.
- Public endpoints are explicit, named exceptions (e.g. `[AllowAnonymous]` in .NET, public route config in Node).
- Never leave endpoints unprotected by omission.

### Multi-tenancy (when applicable)

- Never hardcode a tenant ID, org ID, or tenant name.
- Resolve tenant context from the request (JWT claim, header, subdomain).
- If tenant context is missing, return 401 — do not fall back to a default.
- All tenant-specific config belongs in a config table, not in code.

### Versioning

- Existing API routes are frozen. Never change a response shape on a live endpoint.
- New versions are additive. Add v2 routes alongside v1 — don't replace.
- Both versions can share the same business logic layer.

---

## 3. Logging

Every business logic handler MUST have structured logging:

- Log context (feature name, handler name) at entry.
- Info-level on success with relevant identifiers (IDs, counts, key values).
- Warning-level on validation failures or not-found cases with specific context.
- Error-level with full exception on catch blocks.
- Use named/structured parameters: `log("Retrieved {Count} items for {UserId}", count, userId)` — not string concatenation.
- Never log sensitive data (passwords, tokens, PII beyond IDs).

---

## 4. Data Tables

Every data table MUST have ALL of the following. No exceptions.

1. **Sortable column headers.** Use the project's sort component. Never build custom sort icons. Default sort: newest first (descending by date) unless specified otherwise.

2. **Pagination.** Default page size: 10 rows. Options: [10, 25, 50, 100]. Pagination is 1-based. `pageSize` MUST be state (not a const) so the user can change it via a "rows per page" dropdown. Reset page to 1 when sort or filter changes.

3. **No horizontal scrollbars.** Use fixed table layout with explicit column widths. Truncate long text cells.

4. **Column headers must not overlap sort controls.** Minimum widths: 75px short labels, 110-120px longer labels.

5. **Row position preserved after update.** When an item is edited and saved, it stays at the same position in the grid, not jump to the end.

---

## 5. Forms & Inputs

### Dates

- Never use `<input type="date">`. Always use a themed date picker from the project's UI library.
- Use a range picker for from/to date selection (reports, filters). Use a single picker only for single date fields. Do NOT use two separate date pickers side by side.
- Date state should be `Date` objects. Format to string only when calling APIs.

### Numbers

- Never use `<input type="number">` (browser spinners are ugly and inconsistent). Use `type="text" inputMode="numeric" pattern="[0-9]*"`.

### Money

- Always format with locale-aware thousands separators: `419,840.69` not `419840.69`.
- Use a shared format helper. Apply it consistently everywhere: stat cards, table cells, chart tooltips, chart axis labels.

### Editable Table Cells

- Visually distinct background so the user can see which cells are editable before clicking.
- On focus: auto-select existing value (`autoFocus` + `onFocus={(e) => e.target.select()}`) so typing immediately overwrites.
- Skip unchanged: compare new vs original before calling API. Only fire the mutation if the value actually changed.

### Confirmation Dialogs

- Use the project's confirmation dialog for destructive actions (delete, cancel).
- The dialog manages its own loading state from the async confirm handler.
- The description prop should be a string, not JSX.

### Entity Display in Dropdowns and Tables

- Prefix entity names with their ID in parentheses: `(#8) Peter Farrell`, `(#9014) Harbour Vale`.
- Use typeahead select components with keyboard navigation for entity dropdowns (drivers, accounts, users).
- Show visual indicators (colour dots, status badges) next to entity names where applicable.

---

## 6. Charts

- Use the project's centralised chart theme. Import and spread shared theme objects onto chart components (grid styles, axis styles, tooltip styles).
- Always add a hover cursor style to chart tooltips.
- Never type-annotate formatter callback params in chart components (causes type errors in Recharts and similar libraries): `formatter={(v) => ...}` not `formatter={(v: number) => ...}`.
- Use the project's colour palette. Don't invent new colours.
- For reports with "all items" mode, rank items (horizontal bars, best to worst) so users can compare.

---

## 7. Loading & Error States

- Loading: use shimmer/skeleton placeholders. Not spinner icons.
- Error: clear message with icon and error detail when available.
- Empty state: helpful message ("No data found for the selected period") rather than a blank page.

---

## 8. Layout & Styling

- No `max-w-7xl` or similar max-width constraints on page content. Use full available width.
- Use theme tokens for colours, not raw hex/RGB values.
- Active/selected states: subtle tinted backgrounds, not solid colour blocks.
- Dark mode: neutral greys. No warm hue bleed.
- Improve appearance when building new pages — don't copy old styling patterns from legacy code.

---

## 9. Report Pages

Standard structure for any report/analytics page:

```
├── Date filter (DateRangePicker or period tabs)
├── Optional filters (entity, scope, type)
├── Stat cards row (key metrics)
├── Chart (in a card container)
├── Data table (sortable + paginated)
└── Loading: shimmer placeholders | Error: message with icon
```

- POST reporting endpoints use query params, not request body.
- Period pill tabs for APIs that take a `months` param. Date range picker for `from`/`to` params.
- Comparison mode: show current vs previous period side-by-side in grouped charts.
- Pivot tables for repeating dimensions (e.g. same period across multiple categories).
- Expandable rows for parent-child data (e.g. summary row → detail rows on click).

---

## 10. Git Workflow

```
feature/xxx  →  PR to dev/staging  (tests must pass)
dev/staging  →  PR to main         (tests must pass + approval)
main         →  triggers deploy
```

- Never commit directly to `main` or the primary development branch.
- Always create a feature branch for each task.
- Commit frequently with descriptive messages. Keep the working directory clean.
- Don't batch unrelated changes into one commit.
- Proactively stage and commit after completing each logical unit of work.

---

## 11. Testing

- Add a test for every new endpoint or handler.
- Tests verify response shape and behaviour, not implementation details.
- Prefer integration tests over mocks where practical.
- Run the full test suite before creating a PR. Fix failures before pushing.
- Snapshot tests: when a change alters a response shape, review and accept or fix the diff.

---

## 12. Definition of Done

A task is complete when ALL of the following are true:

- [ ] Business logic in the correct layer (handler/service, not controller)
- [ ] API returns consistent envelope with proper error codes
- [ ] Authentication in place
- [ ] No hardcoded environment-specific or tenant-specific values
- [ ] Structured logging on success, warning, and error paths
- [ ] Frontend tables have sorting and pagination
- [ ] Frontend uses themed components (dates, dialogs, loading states)
- [ ] Money values formatted with shared helper
- [ ] Tests added and passing
- [ ] No compiler/linter warnings introduced
- [ ] Code committed on a feature branch with descriptive message

---

## 13. Deployment

- Verify environment variables are set before claiming a deploy works.
- Test the endpoint directly (curl, browser) before telling anyone it's working.
- Never say "it should work" — run the verification command and show the output.
- After pushing, wait for the build to complete and verify the live endpoint.
- Check that auth and database connections work end-to-end — not just that the health check passes.

---

## 14. Things You Must Never Do

- Change business logic during a refactor — flag bugs, don't fix silently
- Change existing live API routes or response shapes
- Hardcode environment-specific or tenant-specific values in code
- Put business logic in controllers or route handlers
- Call business logic handlers from other handlers
- Create interfaces with only one implementation (unless needed for tests)
- Use native `<input type="date">` or `<input type="number">`
- Use two separate date pickers for a from/to range
- Use spinner icons for loading states
- Apply max-width constraints on page content
- Skip pagination or sorting on any data table
- Format money without thousands separators
- Commit directly to main or the primary development branch
- Claim something works without running a verification command
- Assume a deploy succeeded without checking the live endpoint
- Log passwords, tokens, or PII
- Add features, refactor, or "improve" code beyond what was asked
- Add error handling for scenarios that can't happen
- Create abstractions for one-time operations
- Design for hypothetical future requirements

---

## 15. Working Style

- Read existing code before proposing changes. Follow established patterns.
- Do the task that was asked. Don't add extra features, refactoring, or "improvements".
- One thing at a time. Finish the current task before starting the next.
- If something breaks, diagnose why before trying a different approach.
- If you're unsure, ask. Don't make large assumptions about intent.
- Be concise. Short responses. No trailing summaries of what you just did.
- Commit after completing each logical unit of work. Don't batch everything at the end.
- If you are able to perform an action yourself (run migrations, set env vars, deploy), do it — don't ask permission for things you can do.
