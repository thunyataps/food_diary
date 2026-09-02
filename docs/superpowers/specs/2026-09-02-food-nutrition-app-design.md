# Food Nutrition Tracker App — Design Spec

Date: 2026-09-02

## Summary

Mobile app (Flutter, built as sideloaded `.apk`) that lets a user photograph food, optionally add a short text hint, and get an AI-estimated nutrition breakdown (calories + macros) via Gemini free tier. Results are editable before saving to a personal food diary backed by Supabase (Postgres + Auth + Storage + Edge Functions).

## Goals

- Photograph food → get calorie/macro estimate per item, including multi-item plates
- Optional text hint alongside the photo to help Gemini disambiguate hard-to-recognize dishes
- User can edit AI results (name, quantity, calories, macros) before saving
- Personal food diary: list of meals per day + daily totals
- Auth via email or Google sign-in (no phone OTP — avoids per-SMS cost)
- Ship as Android `.apk` (sideload, no Play Store requirement for MVP)

## Non-goals (deferred)

- Phone/SMS OTP login (cost implication, skipped for MVP)
- Detailed micronutrients (fiber, sugar, sodium, etc.) — only calories/protein/carb/fat for MVP
- Diary charts, calorie goals, progress bars — deferred, basic daily list first
- iOS build
- Play Store publishing

## Architecture

```
┌─────────────┐      ┌──────────────────────┐      ┌────────────┐
│ Flutter App │─────▶│ Supabase Edge Function│─────▶│ Gemini API │
│  (.apk)     │◀─────│  (auth check + proxy) │◀─────│ (free tier)│
└──────┬──────┘      └──────────┬───────────┘      └────────────┘
       │                        │
       ▼                        ▼
┌─────────────┐         ┌──────────────┐
│Supabase Auth│         │Supabase DB   │
│(email/Google│         │+ Storage     │
└─────────────┘         └──────────────┘
```

Gemini API key lives only in the Supabase Edge Function (server-side secret). The Flutter app never holds the key directly — avoids key extraction from the `.apk` via reverse engineering and protects the free-tier quota from abuse.

## Components

- **Flutter app**: camera/gallery capture, auth screens, editable analysis-result form, diary list screens
- **Supabase Auth**: email/password + Google sign-in
- **Supabase Edge Function** (`analyze-food`): verifies caller's Supabase auth token, forwards image (base64) + optional text hint to Gemini with a fixed JSON-output prompt, validates/parses the response, returns structured result to the client. Does not write to the DB itself — the client saves after user review/edit.
- **Supabase Postgres**: `meal_entries` + `food_items` tables (see Data Model), RLS scoped to `auth.uid()`
- **Supabase Storage**: stores compressed meal photos, referenced by `meal_entries.photo_url`

## Data Model

```sql
-- meal_entries: one photo = one entry
meal_entries (
  id uuid pk,
  user_id uuid → auth.users,
  photo_url text,
  note text,               -- optional text hint the user typed
  eaten_at timestamptz,
  total_calories numeric,
  total_protein numeric,
  total_carb numeric,
  total_fat numeric,
  created_at timestamptz
)

-- food_items: per-item breakdown within one photo
food_items (
  id uuid pk,
  meal_entry_id uuid → meal_entries,
  name text,                -- user-editable
  quantity text,             -- e.g. "1 cup", "150g" — AI estimate, user-editable
  calories numeric,
  protein numeric,
  carb numeric,
  fat numeric,
  source text                -- 'ai' | 'user_edited'
)
```

- RLS: a user can only read/write their own `meal_entries`/`food_items` (via `user_id = auth.uid()` and a join for `food_items`)
- `meal_entries.total_*` = sum of its `food_items`, computed client-side at save time

## Data Flow

1. User captures/selects a photo, optionally types a note, taps "Analyze"
2. Flutter compresses the image (resize ~1024px, JPEG) and base64-encodes it
3. Flutter calls the `analyze-food` Edge Function with the Supabase auth token, image, and note
4. Edge Function verifies the token, builds a multimodal Gemini prompt (image + note + fixed JSON schema instruction covering per-item name, quantity, calories, macros, and a `confidence` flag), calls Gemini
5. Edge Function parses/validates the JSON response, returns it to Flutter (not yet persisted)
6. Flutter shows the result as an editable form: per-item name/quantity/calories/macros, add/remove item, low-confidence items highlighted
7. User taps "Save": Flutter uploads the photo to Supabase Storage, then inserts `meal_entries` + `food_items` (totals computed client-side)
8. The diary screen queries `meal_entries` by `eaten_at`, grouped by date, showing a per-day list and daily totals

## Error Handling

| Case | Handling |
|---|---|
| Gemini returns malformed/unparseable JSON | Edge Function retries once with a stricter prompt; on repeated failure, returns an error the client surfaces as "Analysis failed, try again" |
| Gemini free-tier rate limit hit (429) | Edge Function returns a distinct error code; Flutter shows "High demand, try again shortly" |
| No network | Flutter checks connectivity before allowing the analyze action |
| AI misidentifies or is unsure about an item | User edits the item in the editable form; Gemini is asked to include a per-item `confidence` flag so the UI can highlight low-confidence items for review |
| Auth token expires mid-request | Supabase client SDK auto-refreshes; on refresh failure, redirect to login |
| Photo upload to Storage fails after user taps Save | Entry is saved with `photo_url = null` rather than blocking the save; upload can be retried later |

## Testing

- **Edge Function**: unit tests for prompt construction and JSON parsing/validation (mocked Gemini responses), run with Deno's test runner
- **Flutter**: widget tests for the editable result form (add/remove/edit item, total recalculation), unit tests for the image-compression helper
- **Manual/integration**: end-to-end runs against the real Gemini API (consuming free-tier quota) across single-item and multi-item Thai food photos, plus error-path checks (no network, blurry photo)
- No CI pipeline for MVP — `flutter test` and `deno test` run locally before commits

## Open Items for Later (explicitly deferred, not blocking MVP)

- Daily calorie goals + trend charts (diary v2)
- Phone OTP login, if there's a reason to add it later
- Detailed micronutrients
- iOS build / Play Store release
