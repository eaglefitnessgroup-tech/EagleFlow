# EagleFlow — Project Rules

## PHASE 6 LOCK (Permanent)

**Locked on:** 2026-08-03
**Base commit:** ``a02f62c`` (branch: ``main``)
**Tests at lock:** 137 passed · 0 failures · 0 new warnings

### What is locked

Phase 6 is **complete and permanently frozen**. The following modules MUST NOT be
modified, refactored, restructured, or deleted unless the user explicitly requests a
**bug fix** by name:

| Module | Key files |
|---|---|
| Authentication (login, persistent login, Remember Me) | lib/features/authentication/ |
| RBAC & Admin Guard | lib/core/guards/, lib/features/authentication/ |
| Dashboard | lib/features/dashboard/ |
| Products & Product Details | lib/features/products/ |
| Stock In / Stock Out | lib/features/stock/ |
| Create Quotation | lib/features/quotations/presentation/create_quotation_screen.dart |
| Previous Quotations | lib/features/quotations/presentation/previous_quotations_screen.dart |
| Quotation Preview & Document v1.0 | lib/features/quotations/presentation/preview/ |
| Quotation domain model | lib/features/quotations/domain/ |
| Pagination & Totals | (within the modules above) |

### Rules for all future development

1. Never refactor locked modules. Do not rename, reorganise, or re-architect any
   file listed above unless a specific bug is being fixed.
2. No unsolicited UI changes to locked screens, widgets, or the quotation document layout.
3. No unsolicited architecture changes — service locator wiring, repository interfaces,
   controller patterns, and the Sembast database layer are frozen.
4. Tests must stay green. Any future commit that causes a previously passing test to fail
   must be fixed before merging.
5. Analyze must not regress. Do not introduce new warnings beyond the 21 pre-existing
   ones recorded at lock time.
6. All new work starts from Phase 7. Future features must be implemented as additive
   new modules; they must not touch locked code paths.
7. Existing quotation data compatibility is required. The Quotation model on disk
   (Sembast) uses salespersonId only — do not add or rename persisted fields without
   a migration.

### Verified state at lock

- dart format .       — clean (no changes)
- flutter analyze     — 21 issues, all pre-existing, 0 new
- flutter test        — 137/137 passed
- Manual QA           — completed
- git push origin main — confirmed at commit a02f62c
