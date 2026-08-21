# PERSONAL CONTENT OS — PROJECT CONSTITUTION & RULES

## 1. Core Purpose

Personal Content OS transforms scattered internet content (videos, articles, posts) into a persistent, organized, AI-understood personal knowledge library.

Core Loop:

CAPTURE → UNDERSTAND → ORGANIZE → CONSUME

## 2. Non-Negotiable Architectural Rules

1. Never Lose the URL:
If extraction or AI fails, the item must still be saved in the database with its original URL and whatever metadata was captured.

2. Partial Knowledge is Success:
An article with metadata but no full text, or a video with description but no transcript, is a valid capture and may use PARTIALLY_COMPLETED status.

3. Evidence, Not Junk:
Store normalized, useful text in Supabase Storage (.txt/.json), not messy multi-megabyte raw HTML dumps.

4. AI Grounding:
AI summaries and notes must be strictly derived from extracted evidence. AI must never hallucinate external links or cite made-up sources.

5. Saving ≠ Watching:
Saving an item does not increment watch_count. Only explicit user consumption updates watch metrics.

6. Zero Client Secrets:
The Gemini API key and privileged operations live ONLY inside Supabase Edge Functions. The React client only holds the public Supabase Anon Key.

7. Strict Relational RLS:
Every application table and the relevant Supabase Storage objects must enforce Row Level Security. No public read/write access to user data.

## 3. Approved Tech Stack (V1)

Frontend:
- React
- Vite
- TypeScript
- Tailwind CSS
- Lucide Icons

Backend / Database:
- Supabase PostgreSQL
- Supabase Auth
- Supabase Storage

Compute:
- Supabase Edge Functions
- Deno / TypeScript

AI:
- Google Gemini API
- Gemini API is called server-side through Supabase Edge Functions.

## 4. Explicit V1 Exclusions

DO NOT BUILD IN V1:

- Python workers
- yt-dlp
- local daemon scripts
- WhatsApp bots
- Telegram capture
- browser extensions
- vector embeddings
- semantic vector search
- RAG / Ask My Library
- flashcards
- quizzes
- spaced repetition
- automated full video/audio downloading
- Whisper-based full video transcription
- background queues
- unnecessary microservices

These may be considered in future versions.

## 5. Instructions for AI Builders

- Do not silently replace Supabase with Firebase, MongoDB, Firebase Auth, LocalStorage, or another backend.
- Do not disable or bypass RLS to make code work.
- Do not introduce mock data after Supabase integration.
- Do not invent features outside the currently approved phase.
- Do not rewrite working architecture unnecessarily.
- Do not modify unrelated files when implementing a phase.
- Do not expose privileged API keys in frontend code.
- Do not use Node-only APIs inside Supabase Edge Functions.
- Supabase Edge Functions must remain Deno-compatible.
- Before making architectural changes, stop and ask the user.
- Before starting work in a new session, read all files inside docs/ and especially PROJECT_RULES.md, V1_SPEC.md, DECISIONS.md, CURRENT_STATUS.md, and TEST_LOG.md.
