/*
# Personal Content OS V1 — Database Foundation

## Purpose
Creates the complete database schema, Row Level Security policies, and Storage
bucket for Personal Content OS V1.

## New Tables

1. categories
   - id (uuid, primary key)
   - user_id (uuid, foreign key to auth.users.id, defaults to auth.uid())
   - name (text, not null)
   - parent_id (uuid, self-referencing composite foreign key with user_id, nullable)
   - created_at (timestamptz, defaults to now())
   - UNIQUE(id, user_id)

2. content
   - id (uuid, primary key)
   - user_id (uuid, foreign key to auth.users.id, defaults to auth.uid())
   - original_url (text, not null)
   - normalized_url (text, not null)
   - platform (text, nullable)
   - content_type (text, nullable)
   - title (text, nullable)
   - author (text, nullable)
   - thumbnail_url (text, nullable)
   - description (text, nullable)
   - duration (text, nullable)
   - published_date (text, nullable)
   - processing_status (text, not null, CHECK-constrained to 7 states)
   - watch_status (text, not null, CHECK-constrained to 3 states)
   - watch_count (integer, not null, defaults to 0)
   - last_watched_at (timestamptz, nullable)
   - saved_at (timestamptz, nullable)
   - category_id (uuid, composite foreign key with user_id to categories, on delete set null category_id)
   - storage_path (text, nullable)
   - created_at (timestamptz, defaults to now())
   - updated_at (timestamptz, defaults to now())
   - UNIQUE(user_id, normalized_url)

3. ai_knowledge
   - id (uuid, primary key)
   - content_id (uuid, foreign key to content, on delete cascade)
   - summary (text, nullable)
   - key_points (jsonb, nullable)
   - ai_notes (text, nullable)
   - processed_at (timestamptz, nullable)

4. personal_notes
   - id (uuid, primary key)
   - content_id (uuid, foreign key to content, on delete cascade)
   - note_text (text, not null)
   - created_at (timestamptz, defaults to now())
   - updated_at (timestamptz, defaults to now())

5. tags
   - id (uuid, primary key)
   - user_id (uuid, foreign key to auth.users.id, defaults to auth.uid())
   - name (text, not null)
   - UNIQUE(user_id, name)

6. content_tags
   - content_id (uuid, foreign key to content, on delete cascade)
   - tag_id (uuid, foreign key to tags, on delete cascade)
   - composite primary key (content_id, tag_id)

## Security

- RLS enabled on all six application tables.
- Direct ownership tables (categories, tags, content): four policies each
  (SELECT, INSERT, UPDATE, DELETE) scoped to authenticated users where
  auth.uid() = user_id.
- Child tables (ai_knowledge, personal_notes, content_tags): four policies
  each that verify ownership through the parent content row using EXISTS
  (SELECT 1 FROM content WHERE content.id = content_id AND
  content.user_id = auth.uid()).
- content_tags also verifies the tag belongs to the same user.
- No anonymous/public access to any table.

## Storage

- Private bucket "evidence" created.
- Storage policies restrict access to objects inside the user's own folder
  using (storage.foldername(name))[1] = auth.uid()::text.
- Four storage policies: SELECT, INSERT, UPDATE, DELETE.

## Category Ownership Integrity

- categories has UNIQUE(id, user_id) to support composite foreign keys.
- categories.parent_id uses a composite FK (parent_id, user_id) referencing
  categories(id, user_id) with ON DELETE SET NULL (parent_id) — only parent_id
  is nulled, user_id is never touched.
- content.category_id uses a composite FK (category_id, user_id) referencing
  categories(id, user_id) with ON DELETE SET NULL (category_id) — only
  category_id is nulled, user_id is never touched.
- content.user_id remains NOT NULL throughout.
*/

-- =============================================================
-- 1. CATEGORIES
-- =============================================================

CREATE TABLE IF NOT EXISTS categories (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL DEFAULT auth.uid() REFERENCES auth.users(id) ON DELETE CASCADE,
  name text NOT NULL,
  parent_id uuid,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (id, user_id),
  UNIQUE (id, user_id),
  FOREIGN KEY (parent_id, user_id)
    REFERENCES categories (id, user_id)
    ON DELETE SET NULL (parent_id)
);

ALTER TABLE categories ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "select_own_categories" ON categories;
CREATE POLICY "select_own_categories" ON categories FOR SELECT
  TO authenticated USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "insert_own_categories" ON categories;
CREATE POLICY "insert_own_categories" ON categories FOR INSERT
  TO authenticated WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "update_own_categories" ON categories;
CREATE POLICY "update_own_categories" ON categories FOR UPDATE
  TO authenticated USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "delete_own_categories" ON categories;
CREATE POLICY "delete_own_categories" ON categories FOR DELETE
  TO authenticated USING (auth.uid() = user_id);

-- =============================================================
-- 2. CONTENT
-- =============================================================

CREATE TABLE IF NOT EXISTS content (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL DEFAULT auth.uid() REFERENCES auth.users(id) ON DELETE CASCADE,
  original_url text NOT NULL,
  normalized_url text NOT NULL,
  platform text,
  content_type text,
  title text,
  author text,
  thumbnail_url text,
  description text,
  duration text,
  published_date text,
  processing_status text NOT NULL DEFAULT 'PENDING' CHECK (
    processing_status IN (
      'PENDING',
      'EXTRACTING',
      'ANALYZING',
      'COMPLETED',
      'PARTIALLY_COMPLETED',
      'EXTRACTION_FAILED',
      'AI_FAILED'
    )
  ),
  watch_status text NOT NULL DEFAULT 'unwatched' CHECK (
    watch_status IN ('unwatched', 'watching', 'watched')
  ),
  watch_count integer NOT NULL DEFAULT 0,
  last_watched_at timestamptz,
  saved_at timestamptz,
  category_id uuid,
  storage_path text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(user_id, normalized_url),
  FOREIGN KEY (category_id, user_id)
    REFERENCES categories (id, user_id)
    ON DELETE SET NULL (category_id)
);

ALTER TABLE content ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "select_own_content" ON content;
CREATE POLICY "select_own_content" ON content FOR SELECT
  TO authenticated USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "insert_own_content" ON content;
CREATE POLICY "insert_own_content" ON content FOR INSERT
  TO authenticated WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "update_own_content" ON content;
CREATE POLICY "update_own_content" ON content FOR UPDATE
  TO authenticated USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "delete_own_content" ON content;
CREATE POLICY "delete_own_content" ON content FOR DELETE
  TO authenticated USING (auth.uid() = user_id);

-- =============================================================
-- 3. AI_KNOWLEDGE
-- =============================================================

CREATE TABLE IF NOT EXISTS ai_knowledge (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  content_id uuid NOT NULL REFERENCES content(id) ON DELETE CASCADE,
  summary text,
  key_points jsonb,
  ai_notes text,
  processed_at timestamptz
);

ALTER TABLE ai_knowledge ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "select_own_ai_knowledge" ON ai_knowledge;
CREATE POLICY "select_own_ai_knowledge" ON ai_knowledge FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM content
      WHERE content.id = ai_knowledge.content_id
      AND content.user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "insert_own_ai_knowledge" ON ai_knowledge;
CREATE POLICY "insert_own_ai_knowledge" ON ai_knowledge FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM content
      WHERE content.id = ai_knowledge.content_id
      AND content.user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "update_own_ai_knowledge" ON ai_knowledge;
CREATE POLICY "update_own_ai_knowledge" ON ai_knowledge FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM content
      WHERE content.id = ai_knowledge.content_id
      AND content.user_id = auth.uid()
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM content
      WHERE content.id = ai_knowledge.content_id
      AND content.user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "delete_own_ai_knowledge" ON ai_knowledge;
CREATE POLICY "delete_own_ai_knowledge" ON ai_knowledge FOR DELETE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM content
      WHERE content.id = ai_knowledge.content_id
      AND content.user_id = auth.uid()
    )
  );

-- =============================================================
-- 4. PERSONAL_NOTES
-- =============================================================

CREATE TABLE IF NOT EXISTS personal_notes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  content_id uuid NOT NULL REFERENCES content(id) ON DELETE CASCADE,
  note_text text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE personal_notes ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "select_own_personal_notes" ON personal_notes;
CREATE POLICY "select_own_personal_notes" ON personal_notes FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM content
      WHERE content.id = personal_notes.content_id
      AND content.user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "insert_own_personal_notes" ON personal_notes;
CREATE POLICY "insert_own_personal_notes" ON personal_notes FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM content
      WHERE content.id = personal_notes.content_id
      AND content.user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "update_own_personal_notes" ON personal_notes;
CREATE POLICY "update_own_personal_notes" ON personal_notes FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM content
      WHERE content.id = personal_notes.content_id
      AND content.user_id = auth.uid()
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM content
      WHERE content.id = personal_notes.content_id
      AND content.user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "delete_own_personal_notes" ON personal_notes;
CREATE POLICY "delete_own_personal_notes" ON personal_notes FOR DELETE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM content
      WHERE content.id = personal_notes.content_id
      AND content.user_id = auth.uid()
    )
  );

-- =============================================================
-- 5. TAGS
-- =============================================================

CREATE TABLE IF NOT EXISTS tags (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL DEFAULT auth.uid() REFERENCES auth.users(id) ON DELETE CASCADE,
  name text NOT NULL,
  UNIQUE(user_id, name)
);

ALTER TABLE tags ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "select_own_tags" ON tags;
CREATE POLICY "select_own_tags" ON tags FOR SELECT
  TO authenticated USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "insert_own_tags" ON tags;
CREATE POLICY "insert_own_tags" ON tags FOR INSERT
  TO authenticated WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "update_own_tags" ON tags;
CREATE POLICY "update_own_tags" ON tags FOR UPDATE
  TO authenticated USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "delete_own_tags" ON tags;
CREATE POLICY "delete_own_tags" ON tags FOR DELETE
  TO authenticated USING (auth.uid() = user_id);

-- =============================================================
-- 6. CONTENT_TAGS
-- =============================================================

CREATE TABLE IF NOT EXISTS content_tags (
  content_id uuid NOT NULL REFERENCES content(id) ON DELETE CASCADE,
  tag_id uuid NOT NULL REFERENCES tags(id) ON DELETE CASCADE,
  PRIMARY KEY (content_id, tag_id)
);

ALTER TABLE content_tags ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "select_own_content_tags" ON content_tags;
CREATE POLICY "select_own_content_tags" ON content_tags FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM content
      WHERE content.id = content_tags.content_id
      AND content.user_id = auth.uid()
    )
    AND EXISTS (
      SELECT 1 FROM tags
      WHERE tags.id = content_tags.tag_id
      AND tags.user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "insert_own_content_tags" ON content_tags;
CREATE POLICY "insert_own_content_tags" ON content_tags FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM content
      WHERE content.id = content_tags.content_id
      AND content.user_id = auth.uid()
    )
    AND EXISTS (
      SELECT 1 FROM tags
      WHERE tags.id = content_tags.tag_id
      AND tags.user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "update_own_content_tags" ON content_tags;
CREATE POLICY "update_own_content_tags" ON content_tags FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM content
      WHERE content.id = content_tags.content_id
      AND content.user_id = auth.uid()
    )
    AND EXISTS (
      SELECT 1 FROM tags
      WHERE tags.id = content_tags.tag_id
      AND tags.user_id = auth.uid()
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM content
      WHERE content.id = content_tags.content_id
      AND content.user_id = auth.uid()
    )
    AND EXISTS (
      SELECT 1 FROM tags
      WHERE tags.id = content_tags.tag_id
      AND tags.user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "delete_own_content_tags" ON content_tags;
CREATE POLICY "delete_own_content_tags" ON content_tags FOR DELETE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM content
      WHERE content.id = content_tags.content_id
      AND content.user_id = auth.uid()
    )
    AND EXISTS (
      SELECT 1 FROM tags
      WHERE tags.id = content_tags.tag_id
      AND tags.user_id = auth.uid()
    )
  );

-- =============================================================
-- 7. INDEXES
-- =============================================================

CREATE INDEX IF NOT EXISTS idx_content_user_id ON content(user_id);
CREATE INDEX IF NOT EXISTS idx_content_category_id ON content(category_id);
CREATE INDEX IF NOT EXISTS idx_content_processing_status ON content(processing_status);
CREATE INDEX IF NOT EXISTS idx_content_watch_status ON content(watch_status);
CREATE INDEX IF NOT EXISTS idx_categories_user_id ON categories(user_id);
CREATE INDEX IF NOT EXISTS idx_tags_user_id ON tags(user_id);
CREATE INDEX IF NOT EXISTS idx_ai_knowledge_content_id ON ai_knowledge(content_id);
CREATE INDEX IF NOT EXISTS idx_personal_notes_content_id ON personal_notes(content_id);
CREATE INDEX IF NOT EXISTS idx_content_tags_content_id ON content_tags(content_id);
CREATE INDEX IF NOT EXISTS idx_content_tags_tag_id ON content_tags(tag_id);

-- =============================================================
-- 8. STORAGE — EVIDENCE BUCKET
-- =============================================================

INSERT INTO storage.buckets (id, name, public)
VALUES ('evidence', 'evidence', false)
ON CONFLICT (id) DO NOTHING;

DROP POLICY IF EXISTS "read_own_evidence" ON storage.objects;
CREATE POLICY "read_own_evidence" ON storage.objects FOR SELECT
  TO authenticated
  USING (
    bucket_id = 'evidence'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

DROP POLICY IF EXISTS "insert_own_evidence" ON storage.objects;
CREATE POLICY "insert_own_evidence" ON storage.objects FOR INSERT
  TO authenticated
  WITH CHECK (
    bucket_id = 'evidence'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

DROP POLICY IF EXISTS "update_own_evidence" ON storage.objects;
CREATE POLICY "update_own_evidence" ON storage.objects FOR UPDATE
  TO authenticated
  USING (
    bucket_id = 'evidence'
    AND (storage.foldername(name))[1] = auth.uid()::text
  )
  WITH CHECK (
    bucket_id = 'evidence'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

DROP POLICY IF EXISTS "delete_own_evidence" ON storage.objects;
CREATE POLICY "delete_own_evidence" ON storage.objects FOR DELETE
  TO authenticated
  USING (
    bucket_id = 'evidence'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );
