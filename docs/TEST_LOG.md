# PROJECT VERIFICATION & TEST LOG

## Phase 0 Verification

Date:
2026-08-19

Status:
PASS

Checks:

- [x] docs/PROJECT_RULES.md exists
- [x] docs/V1_SPEC.md exists
- [x] docs/DECISIONS.md exists
- [x] docs/CURRENT_STATUS.md exists
- [x] docs/TEST_LOG.md exists
- [x] Files contain the approved architecture
- [x] No application functionality was implemented during Phase 0

## Phase 1 Verification

Date:
2026-08-19

Status:
MIGRATION APPLIED — PENDING USER VERIFICATION

Checks:

- [x] categories table created
- [x] content table created
- [x] ai_knowledge table created
- [x] personal_notes table created
- [x] tags table created
- [x] content_tags table created
- [x] UNIQUE(user_id, normalized_url) verified
- [x] UNIQUE(user_id, name) verified for tags
- [x] RLS enabled on all tables
- [ ] Relational RLS tested (requires authenticated session — Phase 2)
- [ ] Anonymous access tested and rejected (requires authenticated session — Phase 2)
- [x] evidence Storage bucket created
- [ ] Storage ownership policies tested (requires authenticated session — Phase 2)
- [x] UNIQUE(id, user_id) on categories
- [x] composite categories parent FK (parent_id, user_id) → categories(id, user_id) ON DELETE SET NULL (parent_id)
- [x] composite content category FK (category_id, user_id) → categories(id, user_id) ON DELETE SET NULL (category_id)
- [x] content.user_id remains NOT NULL
- [x] ADR-005 removed from DECISIONS.md

Notes:
- All six tables verified present via list_tables.
- RLS enabled on all six tables verified via get_security_posture.
- All 24 table policies (4 per table x 6 tables) verified present and correct.
- UNIQUE constraints verified via pg_constraint query.
- evidence bucket verified as private (public=false) via storage.buckets query.
- Four storage policies (SELECT, INSERT, UPDATE, DELETE) applied to storage.objects.
- Relational RLS, anonymous access rejection, and storage ownership tests require
  an authenticated user session, which depends on Phase 2 (Authentication).
  These checks will be completed after Phase 2 is implemented.

## Phase 1 Integrity Remediation (Migration 0002)

Date:
2026-08-20

Status:
PASS

Checks:

- [x] 0002 migration applied successfully
- [x] categories UNIQUE(id, user_id) — PASS
- [x] categories composite parent FK — PASS
- [x] content composite category FK — PASS
- [x] column-scoped ON DELETE SET NULL (parent_id) — PASS
- [x] column-scoped ON DELETE SET NULL (category_id) — PASS
- [x] content.user_id NOT NULL — PASS
- [x] Phase 1 regression checks — PASS

Regression details:
- All 6 tables exist
- content UNIQUE(user_id, normalized_url) intact
- tags UNIQUE(user_id, name) intact
- RLS enabled on all 6 tables
- All 24 RLS policies unchanged
- evidence bucket remains private
- 4 storage ownership policies intact

## Phase 2 Authentication Testing Checklist

Date:
2026-08-20

Status:
IN PROGRESS — PENDING MANUAL TESTING

Checks:

- [ ] Unauthenticated `/` redirects to `/login`
- [ ] Sign Up works
- [ ] Email-confirmation state handled correctly
- [ ] Sign In works
- [ ] Authenticated user reaches `/`
- [ ] User email displayed
- [ ] Sign Out works
- [ ] Sign Out returns user to `/login`
