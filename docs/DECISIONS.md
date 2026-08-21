# ARCHITECTURAL DECISION RECORDS

## ADR-001: Supabase for V1

Status: LOCKED

Decision:
Use Supabase PostgreSQL, Auth, Storage, and Edge Functions for V1.

Reason:
Supabase integrates well with Bolt and provides the required backend capabilities without introducing unnecessary infrastructure.

## ADR-002: Heavy Worker Deferred

Status: LOCKED

Decision:
Do not implement the Python/yt-dlp worker in V1.

Reason:
The heavy worker architecture may be introduced in a future version if lightweight serverless extraction becomes insufficient.

The database and API boundaries should remain extensible enough that a future worker can replace the extraction implementation without redesigning the entire application.

## ADR-003: Client-Orchestrated Processing

Status: LOCKED

Decision:
The browser orchestrates separate processing stages.

Conceptually:

Browser
→ Extract Edge Function
→ Analyze Edge Function
→ Save/update Supabase

The browser must never contain the Gemini API key.

## ADR-004: Duplicate Detection

Status: LOCKED

Decision:

UNIQUE(user_id, normalized_url)

must prevent duplicate content saves for the same user.

Saving a duplicate must NOT automatically increment watch_count.

The UI should allow the user to open the existing item.


