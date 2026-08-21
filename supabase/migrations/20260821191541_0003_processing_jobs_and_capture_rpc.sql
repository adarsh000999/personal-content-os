/*
# Phase 3 Part 1 — Processing Jobs & Atomic Capture RPC

## Purpose
Adds the processing_jobs table that tracks extraction/analysis work for the
future local Python worker, plus a SECURITY DEFINER RPC (`capture_url`) that
atomically creates a content row and its initial processing job in a single
transaction.

## New Tables

1. processing_jobs
   - id (uuid, primary key)
   - content_id (uuid, foreign key to content.id, on delete cascade)
   - user_id (uuid, foreign key to auth.users.id, on delete cascade)
   - status (text, not null, default 'PENDING', CHECK-constrained to 5 states)
   - attempt_count (integer, not null, default 0)
   - max_attempts (integer, not null, default 3)
   - locked_until (timestamptz, nullable)
   - locked_by (text, nullable)
   - last_error (text, nullable)
   - created_at (timestamptz, not null, default now())
   - updated_at (timestamptz, not null, default now())

## Indexes
- (status, locked_until) — for worker claim queries
- (user_id, content_id) — for user-scoped job lookups

## Security
- RLS enabled on processing_jobs.
- SELECT: authenticated users can only see their own jobs (auth.uid() = user_id).
- INSERT: authenticated users can only insert their own jobs, AND the job's
  content_id must refer to a content row owned by auth.uid() (verified via
  EXISTS subquery against the content table).
- UPDATE / DELETE: scoped to authenticated users where auth.uid() = user_id.
- No anonymous access.

## capture_url RPC
- SECURITY DEFINER function with a locked search_path.
- Derives user_id from auth.uid() — does NOT trust a caller-supplied user_id.
- Atomically inserts a content row (PENDING) and a processing_jobs row (PENDING).
- Returns the new content row's id.
- On duplicate (unique violation on user_id + normalized_url), re-raises the
  error so the client can detect PostgreSQL error code 23505.
- Granted EXECUTE to authenticated only (not anon).

## Notes
1. The RPC uses SECURITY DEFINER so both inserts succeed inside one
   transaction even though RLS would otherwise block the cross-table insert
   from a single caller context. The search_path is locked to `public` to
   prevent search_path injection.
2. The function does NOT accept a user_id parameter — ownership is always
   derived from auth.uid().
3. No existing migrations, tables, policies, or storage objects are modified.
*/

-- =============================================================
-- 1. PROCESSING_JOBS TABLE
-- =============================================================

CREATE TABLE IF NOT EXISTS processing_jobs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  content_id uuid NOT NULL REFERENCES content(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  status text NOT NULL DEFAULT 'PENDING' CHECK (
    status IN ('PENDING', 'CLAIMED', 'EXTRACTING', 'COMPLETED', 'FAILED')
  ),
  attempt_count integer NOT NULL DEFAULT 0,
  max_attempts integer NOT NULL DEFAULT 3,
  locked_until timestamptz,
  locked_by text,
  last_error text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- =============================================================
-- 2. INDEXES
-- =============================================================

CREATE INDEX IF NOT EXISTS idx_processing_jobs_status_locked_until
  ON processing_jobs(status, locked_until);

CREATE INDEX IF NOT EXISTS idx_processing_jobs_user_content
  ON processing_jobs(user_id, content_id);

-- =============================================================
-- 3. RLS — PROCESSING_JOBS
-- =============================================================

ALTER TABLE processing_jobs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "select_own_processing_jobs" ON processing_jobs;
CREATE POLICY "select_own_processing_jobs" ON processing_jobs FOR SELECT
  TO authenticated USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "insert_own_processing_jobs" ON processing_jobs;
CREATE POLICY "insert_own_processing_jobs" ON processing_jobs FOR INSERT
  TO authenticated
  WITH CHECK (
    auth.uid() = user_id
    AND EXISTS (
      SELECT 1 FROM content
      WHERE content.id = processing_jobs.content_id
      AND content.user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "update_own_processing_jobs" ON processing_jobs;
CREATE POLICY "update_own_processing_jobs" ON processing_jobs FOR UPDATE
  TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "delete_own_processing_jobs" ON processing_jobs;
CREATE POLICY "delete_own_processing_jobs" ON processing_jobs FOR DELETE
  TO authenticated USING (auth.uid() = user_id);

-- =============================================================
-- 4. capture_url RPC (SECURITY DEFINER)
-- =============================================================

CREATE OR REPLACE FUNCTION public.capture_url(
  p_original_url text,
  p_normalized_url text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_content_id uuid;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated' USING ERRCODE = '42501';
  END IF;

  INSERT INTO content (user_id, original_url, normalized_url, processing_status)
  VALUES (v_user_id, p_original_url, p_normalized_url, 'PENDING')
  RETURNING id INTO v_content_id;

  INSERT INTO processing_jobs (content_id, user_id, status, attempt_count, max_attempts)
  VALUES (v_content_id, v_user_id, 'PENDING', 0, 3);

  RETURN v_content_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.capture_url(text, text) TO authenticated;
REVOKE EXECUTE ON FUNCTION public.capture_url(text, text) FROM anon;