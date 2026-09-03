# Food Diary

An Android food diary: photograph a meal, a Gemini-backed Supabase Edge Function estimates the
nutrition of each item, you correct anything that's wrong, and the meal is saved to your own
per-user diary.

- **Client:** Flutter (`lib/`), one repository per feature — `auth`, `analyze`, `diary`.
- **Backend:** Supabase — Auth (email/password + Google), Postgres with row-level security,
  Storage for meal photos, and one Edge Function (`analyze-food`) that holds the Gemini API key
  server-side.
- **Design docs:** `docs/superpowers/specs/2026-09-02-food-nutrition-app-design.md` (spec) and
  `docs/superpowers/plans/2026-09-02-food-diary-mvp.md` (implementation plan).

No credentials are committed. The Supabase URL/anon key are supplied at build time with
`--dart-define`; the Gemini key exists only as a Supabase Edge Function secret.

## Prerequisites

- Flutter SDK (Dart `^3.13.2`) and the Android toolchain.
- [Supabase CLI](https://supabase.com/docs/guides/local-development/cli/getting-started)
  (`brew install supabase/tap/supabase`).
- A Supabase project (free tier is fine) and a Gemini API key from
  <https://aistudio.google.com/apikey>.

## Setup checklist

Run these in order. Steps marked **Dashboard** cannot be scripted from this repo.

1. **Install Dart dependencies**

   ```bash
   flutter pub get
   ```

2. **Link the Supabase project**

   ```bash
   supabase login
   supabase link --project-ref <your-project-ref>
   ```

   `<your-project-ref>` is the subdomain of your project URL: `https://<project-ref>.supabase.co`.

3. **Push the database schema, RLS policies, and the storage bucket**

   ```bash
   supabase db push
   ```

   This applies `supabase/migrations/0001_init.sql` (the `meal_entries` / `food_items` tables and
   their RLS policies) and `supabase/migrations/0002_storage.sql` (the private `meal-photos`
   bucket and its owner-only policy). No manual bucket creation is needed.

4. **Set the Gemini secret and deploy the Edge Function**

   ```bash
   supabase secrets set GEMINI_API_KEY=<your-gemini-key>
   # Optional — defaults to gemini-1.5-flash. Check
   # https://ai.google.dev/gemini-api/docs/models for the current free-tier flash model.
   supabase secrets set GEMINI_MODEL=<model-name>
   supabase functions deploy analyze-food
   ```

   Smoke-test the deployment before debugging anything else — invoke `analyze-food` once from the
   app (or with `curl` plus a valid `Authorization: Bearer <user-jwt>` header) and confirm it
   answers rather than 404-ing.

5. **Dashboard — enable the Google provider**

   Authentication → Providers → Google: enable it, and paste the Client ID/Secret of a Google
   Cloud OAuth client ("Web application" type), following Supabase's Google provider guide.

6. **Dashboard — allow-list the OAuth redirect URL**

   Authentication → URL Configuration → Redirect URLs: add

   ```
   io.supabase.fooddiary://login-callback/
   ```

   This is the `redirectTo` value in `lib/features/auth/auth_repository.dart`. Google sign-in
   fails without it even once the provider is enabled. The same URL is already listed in
   `supabase/config.toml`'s `additional_redirect_urls`, which covers local `supabase start` only.

   The matching Android deep-link intent filter is already committed in
   `android/app/src/main/AndroidManifest.xml`.

7. **Email confirmations (decide one way or the other)**

   Hosted Supabase projects have email confirmations **on** by default. With them on, signing up
   creates no session until the user clicks the emailed link — the app handles this by showing
   "check your email to confirm your account" on the sign-up screen. To skip confirmation instead,
   turn it off under Authentication → Sign In / Providers → Email → "Confirm email".

8. **Run the app**

   ```bash
   flutter run \
     --dart-define=SUPABASE_URL=<your-project-url> \
     --dart-define=SUPABASE_ANON_KEY=<your-anon-key>
   ```

   Both values are under Project Settings → API.

## Building the release APK

```bash
flutter build apk --release \
  --dart-define=SUPABASE_URL=<your-project-url> \
  --dart-define=SUPABASE_ANON_KEY=<your-anon-key>
```

Output: `build/app/outputs/flutter-apk/app-release.apk`. Sideload it with
`adb install build/app/outputs/flutter-apk/app-release.apk`, or copy the file to the device.

The release build is signed with the debug keystore (the `flutter create` default) — fine for
personal sideloading, not for distribution.

## Tests

```bash
flutter test      # Dart unit + widget tests
flutter analyze   # static analysis
deno test --allow-net --allow-env supabase/functions/analyze-food/index.test.ts
```
