# V1 TECHNICAL & PRODUCT SPECIFICATION

## 1. Processing State Machine

Content processing uses these states:

- PENDING: Saved, waiting for processing.
- EXTRACTING: Edge Function is extracting metadata/body text/transcript.
- ANALYZING: Edge Function is calling Gemini.
- COMPLETED: Full extraction and AI analysis succeeded.
- PARTIALLY_COMPLETED: Metadata was obtained but full evidence was unavailable; available information may still be processed.
- EXTRACTION_FAILED: The source could not be accessed/extracted.
- AI_FAILED: Evidence was extracted but AI processing failed or timed out.

## 2. Database Schema

### categories

- id: UUID primary key
- user_id: UUID foreign key to auth.users.id
- name: TEXT NOT NULL
- parent_id: UUID self-referencing foreign key
- created_at: TIMESTAMPTZ

### content

- id: UUID primary key
- user_id: UUID foreign key to auth.users.id
- original_url: TEXT NOT NULL
- normalized_url: TEXT NOT NULL
- platform: TEXT
- content_type: TEXT
- title: TEXT
- author: TEXT
- thumbnail_url: TEXT
- description: TEXT
- duration: TEXT
- published_date: TEXT
- processing_status: TEXT NOT NULL
- watch_status: TEXT NOT NULL
- watch_count: INTEGER NOT NULL DEFAULT 0
- last_watched_at: TIMESTAMPTZ
- saved_at: TIMESTAMPTZ
- category_id: UUID
- storage_path: TEXT
- created_at: TIMESTAMPTZ
- updated_at: TIMESTAMPTZ

Required constraint:

UNIQUE(user_id, normalized_url)

watch_status must allow:

- unwatched
- watching
- watched

processing_status must allow:

- PENDING
- EXTRACTING
- ANALYZING
- COMPLETED
- PARTIALLY_COMPLETED
- EXTRACTION_FAILED
- AI_FAILED

### ai_knowledge

- id: UUID primary key
- content_id: UUID foreign key
- summary: TEXT
- key_points: JSONB
- ai_notes: TEXT
- processed_at: TIMESTAMPTZ

### personal_notes

- id: UUID primary key
- content_id: UUID foreign key
- note_text: TEXT NOT NULL
- created_at: TIMESTAMPTZ
- updated_at: TIMESTAMPTZ

### tags

- id: UUID primary key
- user_id: UUID foreign key
- name: TEXT NOT NULL

Required constraint:

UNIQUE(user_id, name)

### content_tags

- content_id: UUID foreign key
- tag_id: UUID foreign key
- composite primary key:

(content_id, tag_id)

## 3. Row Level Security

RLS MUST be enabled on every application table.

categories:
auth.uid() must equal user_id.

tags:
auth.uid() must equal user_id.

content:
auth.uid() must equal user_id.

ai_knowledge:
The associated content row must belong to auth.uid().

personal_notes:
The associated content row must belong to auth.uid().

content_tags:
The associated content row must belong to auth.uid(), and the tag must also belong to the same user.

There must be no anonymous public read/write access to personal data.

## 4. Storage

Create a PRIVATE bucket named:

evidence

Recommended path:

{user_id}/{content_id}/evidence.txt

Storage object policies must ensure users can only access objects inside their own user folder.

## 5. Edge Functions

Future V1 phases will use:

/functions/extract

and

/functions/analyze

The extract function will handle server-side content extraction.

The analyze function will securely call Gemini.

These functions are NOT to be implemented during Phase 0.
