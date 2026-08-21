# Phase 3 Handoff Document

## Project Purpose

Personal Content OS is a private/internal V1 knowledge system. It captures URLs from articles, videos, social content, etc., preserves source evidence, extracts representations such as metadata/transcripts, and eventually creates AI knowledge.

Core loop: CAPTURE → UNDERSTAND → ORGANIZE → CONSUME

Priorities: Correctness, Reliability, Evidence/Provenance, Security, Simplicity, Practical Usability.

## Current Architecture

```
React/Vite
    ↓
Supabase Auth + PostgreSQL + Storage
    ↓
Local Python Worker (future)
```

The browser accepts URLs, performs basic validation, creates content, creates processing jobs, and displays state.

The browser does NOT scrape URLs, download external content, perform extraction, or call external websites for ingestion.

There is NO Edge Function for ingestion, NO Cloudflare Worker, NO Cloudflare D1, NO Cloudflare R2, NO traditional ingestion API.

The local Python worker is the future processing engine.

## Supabase Responsibilities

- Authentication (email/password via Supabase Auth)
- PostgreSQL database with Row Level Security on all application tables
- Private Storage bucket ("evidence") for extracted evidence files
- Hosting the `capture_url` RPC function

## Browser Responsibilities

- Accept URLs from the user
- Basic client-side URL validation (http/https only)
- URL normalization (lowercase scheme + hostname, strip fragment, normalize trailing slash)
- Call the `capture_url` RPC to atomically create content + processing job
- Display captured content feed and processing status
- Display AI knowledge and personal notes (future phases)

## Future Python Worker Responsibilities

- Claim jobs atomically using PostgreSQL `FOR UPDATE SKIP LOCKED`
- SSRF-safe fetching of source URLs
- Metadata and transcript extraction
- Evidence generation and upload to Supabase Storage
- PostgreSQL updates (content metadata, processing_status, job status)
- Future AI processing (Gemini analysis via server-side call)

## Database Structure

### Existing Tables (from migrations 0001 and 0002)

- **content** — stores captured URLs and extracted metadata. Unique on (user_id, normalized_url).
- **categories** — user-owned category tree with composite self-referencing FK.
- **tags** — user-owned tags, unique on (user_id, name).
- **content_tags** — join table between content and tags.
- **ai_knowledge** — AI-generated summaries and key points (future).
- **personal_notes** — user notes attached to content (future).

### processing_jobs (migration 0003 — Phase 3 Part 1)

| Column | Type | Description |
|---|---|---|
| id | uuid PK | Job identifier |
| content_id | uuid FK → content(id) ON DELETE CASCADE | Content this job processes |
| user_id | uuid FK → auth.users(id) ON DELETE CASCADE | Owning user |
| status | text NOT NULL DEFAULT 'PENDING' | PENDING, CLAIMED, EXTRACTING, COMPLETED, FAILED |
| attempt_count | integer NOT NULL DEFAULT 0 | Current attempt number |
| max_attempts | integer NOT NULL DEFAULT 3 | Maximum retries before FAILED |
| locked_until | timestamptz NULL | Lease expiry timestamp |
| locked_by | text NULL | Worker identifier holding the lease |
| last_error | text NULL | Last error message if FAILED |
| created_at | timestamptz NOT NULL DEFAULT now() | Creation timestamp |
| updated_at | timestamptz NOT NULL DEFAULT now() | Last update timestamp |

Indexes:
- `(status, locked_until)` — for worker claim queries
- `(user_id, content_id)` — for user-scoped job lookups

RLS:
- SELECT: `auth.uid() = user_id`
- INSERT: `auth.uid() = user_id` AND content ownership verified via EXISTS subquery
- UPDATE/DELETE: `auth.uid() = user_id`
- No anonymous access

## capture_url RPC

```sql
capture_url(p_original_url text, p_normalized_url text) RETURNS uuid
```

- SECURITY DEFINER, search_path locked to `public`
- Derives `user_id` from `auth.uid()` — does NOT accept a caller-supplied user_id
- Atomically inserts a content row (PENDING) and a processing_jobs row (PENDING)
- Returns the new content row's id
- On duplicate URL (unique violation, error code 23505), re-raises so the client can detect it
- Granted EXECUTE to `authenticated` only; revoked from `anon`

## Job Lifecycle

```
PENDING → CLAIMED → EXTRACTING → COMPLETED
                                    ↘ FAILED
```

- **PENDING**: Job created, waiting for a worker to claim it.
- **CLAIMED**: Worker has atomically claimed the job (FOR UPDATE SKIP LOCKED), set locked_by and locked_until.
- **EXTRACTING**: Worker is actively fetching and extracting content.
- **COMPLETED**: Extraction and any AI processing finished successfully.
- **FAILED**: All attempts exhausted or unrecoverable error.

Non-terminal states: PENDING, CLAIMED, EXTRACTING
Terminal states: COMPLETED, FAILED

## Lease / Heartbeat Model

A job is reclaimable when:
```sql
status NOT IN ('COMPLETED', 'FAILED')
AND locked_until < NOW()
AND attempt_count < max_attempts
```

The future worker should:
1. Claim a job: `SELECT ... FOR UPDATE SKIP LOCKED WHERE status = 'PENDING' AND locked_until < NOW()`
2. Increment `attempt_count`, set `locked_by`, set `locked_until` to now + lease duration
3. Periodically renew `locked_until` (heartbeat) while working
4. On completion: set status to COMPLETED, update content with extracted metadata
5. On failure: set status to FAILED (if attempts exhausted) or back to PENDING (if retries remain), set last_error

## Evidence Hierarchy

1. Original URL (always preserved, never lost)
2. Normalized URL (for deduplication)
3. Extracted metadata (title, author, description, thumbnail, published date)
4. Extracted text/transcript (stored as .txt or .json in Storage)
5. AI knowledge (summary, key points, notes — derived from evidence)

## Future Evidence Storage Path

```
evidence bucket: {user_id}/{content_id}/evidence.txt
                 {user_id}/{content_id}/evidence.json
```

The evidence bucket is private. Storage policies ensure users can only access objects inside their own user folder (`storage.foldername(name)[1] = auth.uid()::text`).

## Future SSRF Requirements

The Python worker must implement SSRF protection before fetching any URL:
- Reject private/internal IP ranges (10.x, 172.16-31.x, 192.168.x, 127.x, ::1, fc00::/7)
- Reject link-local addresses
- Follow redirects but re-validate each redirect target
- Enforce timeouts
- Never expose internal network topology

## Phase 3 Part 1 Implementation Status

PHASE 3 PART 1: IMPLEMENTED AND BUILD VERIFIED

Completed:
- `processing_jobs` table created with all required columns, indexes, and RLS policies
- `capture_url` SECURITY DEFINER RPC created and granted to authenticated only
- URL normalization utility (`src/lib/url.ts`) using native browser URL API
- Dashboard updated with URL capture form and content feed
- Duplicate URL handling via PostgreSQL error code 23505 detection
- Build and typecheck pass

## Phase 3 Part 2 Remaining Work

PHASE 3 PART 2: LOCAL PYTHON WORKER — INCOMPLETE

The following work remains:

1. **Python worker scaffolding** — project structure, dependencies, configuration
2. **Job claiming** — `FOR UPDATE SKIP LOCKED` claim logic with lease management
3. **SSRF-safe fetcher** — URL validation, private IP rejection, redirect re-validation, timeouts
4. **Metadata extraction** — title, author, description, thumbnail, published date from HTML/OG tags
5. **Transcript extraction** — video transcript fetching where available
6. **Evidence generation** — normalize extracted text, write .txt/.json files
7. **Storage upload** — upload evidence to `evidence` bucket at `{user_id}/{content_id}/` path
8. **Database updates** — update content metadata, processing_status, job status
9. **Heartbeat renewal** — periodic locked_until renewal during long-running extraction
10. **Retry/error handling** — attempt_count increment, last_error, FAILED state on exhaustion
11. **Gemini AI analysis** — server-side call to Gemini API for summary/key_points/ai_notes (future Phase 4)

## Architectural Prohibitions

Do not introduce Edge Functions, Cloudflare Workers, Cloudflare D1, Cloudflare R2, a traditional ingestion API, or browser-side scraping unless the architecture is explicitly re-approved.

The local Python worker is the future processing engine.

Do not:
- Scrape URLs from the browser
- Download external content from the browser
- Perform extraction in the browser
- Expose the Supabase service-role key in frontend code
- Disable or bypass RLS
- Modify existing migrations (database history is append-only)
- Introduce mock data after Supabase integration

## Setup / Run Instructions

### Frontend (React/Vite)
```bash
npm install
npm run dev
```

### Environment
The `.env` file contains `VITE_SUPABASE_URL` and `VITE_SUPABASE_ANON_KEY`. These are pre-populated. Never add `SUPABASE_SERVICE_ROLE_KEY` to a `VITE_` variable.

### Future Python Worker
The worker will use `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`, and `SUPABASE_DB_URL` from the environment (not VITE_ prefixed). These are already provisioned.

## Verification Commands

```bash
npm run build      # Production build
npm run typecheck  # TypeScript type checking
npm run lint       # ESLint (if available)
```

## Known Limitations

1. The Python worker does not exist yet — captured URLs will remain in PENDING status until the worker is built.
2. No content extraction, metadata enrichment, or AI analysis is performed.
3. The content feed shows only the original URL and PENDING status.
4. No category management, tagging UI, or notes UI yet (future phases).
5. URL normalization is conservative — it does not strip query parameters or alter meaningful URL semantics.
6. Client-side validation is basic (http/https only) and is NOT SSRF protection. The future worker handles SSRF.
