# Food Diary MVP Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a Flutter Android app that photographs food, gets AI-estimated nutrition via a Supabase-Edge-Function-proxied Gemini call, lets the user edit results, and saves them to a per-user food diary — shipped as a sideloaded `.apk`.

**Architecture:** Flutter client (repositories per feature: auth/analyze/diary) talks to Supabase (Auth, Postgres+RLS, Storage) directly for data, and to a single Supabase Edge Function (`analyze-food`) that holds the Gemini API key server-side and proxies the nutrition analysis call.

**Tech Stack:** Flutter (Dart), Supabase (supabase_flutter, Postgres, Storage, Edge Functions/Deno), Gemini API (REST, `generateContent` with `responseSchema`), image_picker, flutter_image_compress.

**Spec:** `docs/superpowers/specs/2026-09-02-food-nutrition-app-design.md`

## Global Constraints

- Auth is email/password + Google OAuth only — no phone/SMS OTP (cost).
- Nutrition fields are limited to calories, protein, carb, fat — no micronutrients.
- The Gemini API key must never be embedded in the Flutter app or committed to git; it lives only as a Supabase Edge Function secret.
- Every DB table storing user data must have RLS enabled and scoped to `auth.uid()`.
- Diary UI for this MVP is a per-day list with a daily total — no charts, no goals (deferred).
- Target platform is Android only, shipped as a sideloaded `.apk` (no Play Store, no iOS).

---

## Task 1: Project scaffolding & Supabase/Gemini account setup

**Files:**
- Create: `pubspec.yaml` (via `flutter create`)
- Create: `.gitignore` additions for `.env` / secrets (via `flutter create` default, verify it covers `*.env`)

**Interfaces:**
- Produces: a runnable Flutter project at repo root named `food_diary`, with `supabase_flutter`, `image_picker`, and `flutter_image_compress` available as dependencies for later tasks.

- [ ] **Step 1: Manual — create accounts and get credentials**

1. Go to https://supabase.com, create a free project. Note the **Project URL** and **anon public key** (Project Settings → API).
2. Go to https://aistudio.google.com/apikey, create a free-tier Gemini API key.
3. Keep both values handy — the Gemini key is used in Task 3 (Edge Function secret only, never in the Flutter app), the Supabase URL/anon key are used in Task 10 (`--dart-define` at build time, never hardcoded).

- [ ] **Step 2: Scaffold the Flutter project**

```bash
flutter create --org com.example --project-name food_diary .
```

- [ ] **Step 3: Add dependencies**

Edit `pubspec.yaml`, add under `dependencies:`

```yaml
  supabase_flutter: ^2.5.0
  image_picker: ^1.1.2
  flutter_image_compress: ^2.3.0
```

Run:

```bash
flutter pub get
```

- [ ] **Step 4: Verify the scaffold builds**

Run: `flutter analyze`
Expected: "No issues found!"

- [ ] **Step 5: Commit**

```bash
git add pubspec.yaml pubspec.lock lib android ios .gitignore
git commit -m "Scaffold Flutter project with Supabase/image dependencies"
```

---

## Task 2: Database schema & RLS policies

**Files:**
- Create: `supabase/migrations/0001_init.sql`

**Interfaces:**
- Produces: tables `meal_entries` and `food_items` with columns exactly as defined in the spec's Data Model, RLS-scoped to `auth.uid()`. Later Dart code (Task 8, Task 9) inserts/selects against these exact column names.

- [ ] **Step 1: Install the Supabase CLI and link the project**

```bash
brew install supabase/tap/supabase
supabase login
supabase init
supabase link --project-ref <your-project-ref>
```

(`<your-project-ref>` is in the Supabase project URL: `https://<project-ref>.supabase.co`.)

- [ ] **Step 2: Write the migration**

Create `supabase/migrations/0001_init.sql`:

```sql
create table meal_entries (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  photo_url text,
  note text,
  eaten_at timestamptz not null default now(),
  total_calories numeric not null default 0,
  total_protein numeric not null default 0,
  total_carb numeric not null default 0,
  total_fat numeric not null default 0,
  created_at timestamptz not null default now()
);

create table food_items (
  id uuid primary key default gen_random_uuid(),
  meal_entry_id uuid not null references meal_entries(id) on delete cascade,
  name text not null,
  quantity text not null,
  calories numeric not null default 0,
  protein numeric not null default 0,
  carb numeric not null default 0,
  fat numeric not null default 0,
  source text not null default 'ai' check (source in ('ai', 'user_edited'))
);

alter table meal_entries enable row level security;
alter table food_items enable row level security;

create policy "meal_entries_select_own" on meal_entries
  for select using (auth.uid() = user_id);
create policy "meal_entries_insert_own" on meal_entries
  for insert with check (auth.uid() = user_id);
create policy "meal_entries_update_own" on meal_entries
  for update using (auth.uid() = user_id);
create policy "meal_entries_delete_own" on meal_entries
  for delete using (auth.uid() = user_id);

create policy "food_items_select_own" on food_items
  for select using (
    exists (select 1 from meal_entries m where m.id = meal_entry_id and m.user_id = auth.uid())
  );
create policy "food_items_insert_own" on food_items
  for insert with check (
    exists (select 1 from meal_entries m where m.id = meal_entry_id and m.user_id = auth.uid())
  );
create policy "food_items_update_own" on food_items
  for update using (
    exists (select 1 from meal_entries m where m.id = meal_entry_id and m.user_id = auth.uid())
  );
create policy "food_items_delete_own" on food_items
  for delete using (
    exists (select 1 from meal_entries m where m.id = meal_entry_id and m.user_id = auth.uid())
  );

create index meal_entries_user_eaten_at_idx on meal_entries (user_id, eaten_at desc);
create index food_items_meal_entry_id_idx on food_items (meal_entry_id);
```

- [ ] **Step 3: Apply locally and verify (requires Docker for Supabase local dev)**

```bash
supabase start
supabase db reset
```

Verify tables exist:

```bash
supabase db execute --local "select table_name from information_schema.tables where table_schema = 'public'"
```

Expected: `meal_entries` and `food_items` listed.

Verify RLS is on:

```bash
supabase db execute --local "select relname, relrowsecurity from pg_class where relname in ('meal_entries','food_items')"
```

Expected: `relrowsecurity = t` for both.

- [ ] **Step 4: Push to the linked remote project**

```bash
supabase db push
```

- [ ] **Step 5: Commit**

```bash
git add supabase/migrations/0001_init.sql supabase/config.toml
git commit -m "Add meal_entries/food_items schema with RLS"
```

---

## Task 3: Supabase Edge Function `analyze-food` (Gemini proxy)

**Files:**
- Create: `supabase/functions/analyze-food/index.ts`
- Test: `supabase/functions/analyze-food/index.test.ts`

**Interfaces:**
- Consumes: `Authorization: Bearer <supabase-jwt>` header, JSON body `{ image: string (base64), mimeType: string, note?: string }`
- Produces: on success, `200` with body `{ items: FoodItemResult[] }` where `FoodItemResult = { name, quantity, calories, protein, carb, fat, confidence: "high"|"low" }`. On failure: `401` (`{error:"unauthorized"}`), `400` (`{error:"invalid_request"}`), `429` (`{error:"rate_limited"}`), `502` (`{error:"analysis_failed"}`). This exact shape is what `AnalyzeRepository` (Task 7) parses.

- [ ] **Step 1: Write the failing tests**

Create `supabase/functions/analyze-food/index.test.ts`:

```typescript
import { assertEquals, assertRejects } from "https://deno.land/std@0.208.0/assert/mod.ts";
import { callGemini, RateLimitError } from "./index.ts";

function mockFetch(response: Response) {
  globalThis.fetch = () => Promise.resolve(response);
}

Deno.test("callGemini parses a valid response into FoodItemResult[]", async () => {
  const mockBody = {
    candidates: [
      {
        content: {
          parts: [
            {
              text: JSON.stringify({
                items: [
                  { name: "Rice", quantity: "1 cup", calories: 200, protein: 4, carb: 45, fat: 0.5, confidence: "high" },
                ],
              }),
            },
          ],
        },
      },
    ],
  };
  mockFetch(new Response(JSON.stringify(mockBody), { status: 200 }));

  const result = await callGemini({ image: "abc", mimeType: "image/jpeg" });
  assertEquals(result.length, 1);
  assertEquals(result[0].name, "Rice");
  assertEquals(result[0].confidence, "high");
});

Deno.test("callGemini throws RateLimitError on HTTP 429", async () => {
  mockFetch(new Response("", { status: 429 }));
  await assertRejects(
    () => callGemini({ image: "abc", mimeType: "image/jpeg" }),
    RateLimitError,
  );
});

Deno.test("callGemini throws after retry on malformed JSON", async () => {
  mockFetch(
    new Response(
      JSON.stringify({ candidates: [{ content: { parts: [{ text: "not json" }] } }] }),
      { status: 200 },
    ),
  );
  await assertRejects(() => callGemini({ image: "abc", mimeType: "image/jpeg" }));
});
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `deno test --allow-net --allow-env supabase/functions/analyze-food/index.test.ts`
Expected: FAIL — `index.ts` does not exist yet.

- [ ] **Step 3: Implement `index.ts`**

```typescript
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const GEMINI_API_KEY = Deno.env.get("GEMINI_API_KEY") ?? "";
// Check https://ai.google.dev/gemini-api/docs/models for the current free-tier
// flash model name and update GEMINI_MODEL secret if this default is stale.
const GEMINI_MODEL = Deno.env.get("GEMINI_MODEL") ?? "gemini-1.5-flash";
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";

const RESPONSE_SCHEMA = {
  type: "object",
  properties: {
    items: {
      type: "array",
      items: {
        type: "object",
        properties: {
          name: { type: "string" },
          quantity: { type: "string" },
          calories: { type: "number" },
          protein: { type: "number" },
          carb: { type: "number" },
          fat: { type: "number" },
          confidence: { type: "string", enum: ["high", "low"] },
        },
        required: ["name", "quantity", "calories", "protein", "carb", "fat", "confidence"],
      },
    },
  },
  required: ["items"],
};

export interface AnalyzeRequest {
  image: string;
  mimeType: string;
  note?: string;
}

export interface FoodItemResult {
  name: string;
  quantity: string;
  calories: number;
  protein: number;
  carb: number;
  fat: number;
  confidence: "high" | "low";
}

export class RateLimitError extends Error {}

function buildPrompt(note?: string): string {
  return [
    "You are a nutrition estimation assistant. Look at the food photo and identify each distinct food item visible.",
    "For each item, estimate: name, quantity (e.g. '1 cup', '150g'), calories, protein (g), carb (g), fat (g).",
    "Set confidence to 'low' if you are not sure about the identification or portion size, otherwise 'high'.",
    note ? `The user provided this hint about the photo: "${note}"` : "",
    "Respond with JSON matching the required schema only.",
  ].filter(Boolean).join(" ");
}

function validateItems(items: unknown): FoodItemResult[] {
  if (!Array.isArray(items) || items.length === 0) {
    throw new Error("No items in response");
  }
  return items.map((item) => {
    const i = item as Record<string, unknown>;
    if (
      typeof i.name !== "string" ||
      typeof i.quantity !== "string" ||
      typeof i.calories !== "number" ||
      typeof i.protein !== "number" ||
      typeof i.carb !== "number" ||
      typeof i.fat !== "number" ||
      (i.confidence !== "high" && i.confidence !== "low")
    ) {
      throw new Error("Malformed food item in response");
    }
    return i as unknown as FoodItemResult;
  });
}

export async function callGemini(req: AnalyzeRequest, attempt = 1): Promise<FoodItemResult[]> {
  const body = {
    contents: [
      {
        parts: [
          { text: buildPrompt(req.note) },
          { inlineData: { mimeType: req.mimeType, data: req.image } },
        ],
      },
    ],
    generationConfig: {
      responseMimeType: "application/json",
      responseSchema: RESPONSE_SCHEMA,
    },
  };

  const res = await fetch(
    `https://generativelanguage.googleapis.com/v1beta/models/${GEMINI_MODEL}:generateContent?key=${GEMINI_API_KEY}`,
    { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify(body) },
  );

  if (res.status === 429) throw new RateLimitError();
  if (!res.ok) throw new Error(`Gemini request failed: ${res.status}`);

  const data = await res.json();
  const text = data.candidates?.[0]?.content?.parts?.[0]?.text;
  if (!text) {
    if (attempt < 2) return callGemini(req, attempt + 1);
    throw new Error("Gemini returned no content");
  }

  try {
    const parsed = JSON.parse(text);
    return validateItems(parsed.items);
  } catch (_e) {
    if (attempt < 2) return callGemini(req, attempt + 1);
    throw new Error("Gemini returned invalid JSON");
  }
}

async function handler(req: Request): Promise<Response> {
  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }

  const authHeader = req.headers.get("Authorization");
  if (!authHeader) {
    return new Response(JSON.stringify({ error: "unauthorized" }), { status: 401 });
  }

  const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
    global: { headers: { Authorization: authHeader } },
  });
  const { data: userData, error: userError } = await supabase.auth.getUser();
  if (userError || !userData.user) {
    return new Response(JSON.stringify({ error: "unauthorized" }), { status: 401 });
  }

  let payload: AnalyzeRequest;
  try {
    payload = await req.json();
  } catch {
    return new Response(JSON.stringify({ error: "invalid_request" }), { status: 400 });
  }
  if (!payload.image || !payload.mimeType) {
    return new Response(JSON.stringify({ error: "invalid_request" }), { status: 400 });
  }

  try {
    const items = await callGemini(payload);
    return new Response(JSON.stringify({ items }), { headers: { "Content-Type": "application/json" } });
  } catch (e) {
    if (e instanceof RateLimitError) {
      return new Response(JSON.stringify({ error: "rate_limited" }), { status: 429 });
    }
    return new Response(JSON.stringify({ error: "analysis_failed" }), { status: 502 });
  }
}

if (import.meta.main) {
  Deno.serve(handler);
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `deno test --allow-net --allow-env supabase/functions/analyze-food/index.test.ts`
Expected: 3 tests pass.

- [ ] **Step 5: Set the Gemini secret and deploy**

```bash
supabase secrets set GEMINI_API_KEY=<your-gemini-key>
supabase functions deploy analyze-food
```

- [ ] **Step 6: Commit**

```bash
git add supabase/functions/analyze-food/index.ts supabase/functions/analyze-food/index.test.ts
git commit -m "Add analyze-food Edge Function proxying Gemini nutrition analysis"
```

---

## Task 4: Data models (`FoodItem`, `MealEntry`)

**Files:**
- Create: `lib/models/food_item.dart`
- Create: `lib/models/meal_entry.dart`
- Test: `test/models/meal_entry_test.dart`

**Interfaces:**
- Produces: `FoodItem` (fields: `id`, `name`, `quantity`, `calories`, `protein`, `carb`, `fat`, `source`, `confidence`; factory `FoodItem.fromGemini(Map)`, method `toInsertRow(String mealEntryId)`) and `MealEntry` (fields: `id`, `photoUrl`, `note`, `eatenAt`, `items`; getters `totalCalories/totalProtein/totalCarb/totalFat`; factory `MealEntry.fromRow(Map row, List<FoodItem> items)`). Used by Tasks 5, 7, 8, 9.

- [ ] **Step 1: Write the failing test**

Create `test/models/meal_entry_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:food_diary/models/meal_entry.dart';
import 'package:food_diary/models/food_item.dart';

void main() {
  test('totalCalories and totalProtein sum all items', () {
    final entry = MealEntry(
      eatenAt: DateTime.now(),
      items: [
        FoodItem(name: 'Rice', quantity: '1 cup', calories: 200, protein: 4, carb: 45, fat: 0.5, source: 'ai'),
        FoodItem(name: 'Chicken', quantity: '100g', calories: 165, protein: 31, carb: 0, fat: 3.6, source: 'ai'),
      ],
    );
    expect(entry.totalCalories, 365);
    expect(entry.totalProtein, 35);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/models/meal_entry_test.dart`
Expected: FAIL — `package:food_diary/models/meal_entry.dart` not found.

- [ ] **Step 3: Implement the models**

Create `lib/models/food_item.dart`:

```dart
class FoodItem {
  FoodItem({
    this.id,
    required this.name,
    required this.quantity,
    required this.calories,
    required this.protein,
    required this.carb,
    required this.fat,
    required this.source,
    this.confidence,
  });

  final String? id;
  String name;
  String quantity;
  double calories;
  double protein;
  double carb;
  double fat;
  String source; // 'ai' | 'user_edited'
  String? confidence; // 'high' | 'low' — only meaningful for unsaved AI results

  factory FoodItem.fromGemini(Map<String, dynamic> json) {
    return FoodItem(
      name: json['name'] as String,
      quantity: json['quantity'] as String,
      calories: (json['calories'] as num).toDouble(),
      protein: (json['protein'] as num).toDouble(),
      carb: (json['carb'] as num).toDouble(),
      fat: (json['fat'] as num).toDouble(),
      source: 'ai',
      confidence: json['confidence'] as String?,
    );
  }

  Map<String, dynamic> toInsertRow(String mealEntryId) => {
        'meal_entry_id': mealEntryId,
        'name': name,
        'quantity': quantity,
        'calories': calories,
        'protein': protein,
        'carb': carb,
        'fat': fat,
        'source': source,
      };
}
```

Create `lib/models/meal_entry.dart`:

```dart
import 'food_item.dart';

class MealEntry {
  MealEntry({
    this.id,
    this.photoUrl,
    this.note,
    required this.eatenAt,
    required this.items,
  });

  final String? id;
  String? photoUrl;
  String? note;
  DateTime eatenAt;
  List<FoodItem> items;

  double get totalCalories => items.fold(0, (sum, i) => sum + i.calories);
  double get totalProtein => items.fold(0, (sum, i) => sum + i.protein);
  double get totalCarb => items.fold(0, (sum, i) => sum + i.carb);
  double get totalFat => items.fold(0, (sum, i) => sum + i.fat);

  factory MealEntry.fromRow(Map<String, dynamic> row, List<FoodItem> items) {
    return MealEntry(
      id: row['id'] as String,
      photoUrl: row['photo_url'] as String?,
      note: row['note'] as String?,
      eatenAt: DateTime.parse(row['eaten_at'] as String),
      items: items,
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/models/meal_entry_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/models/food_item.dart lib/models/meal_entry.dart test/models/meal_entry_test.dart
git commit -m "Add FoodItem/MealEntry models"
```

---

## Task 5: Image compression helper

**Files:**
- Create: `lib/core/image_compression.dart`
- Test: `test/core/image_compression_test.dart`

**Interfaces:**
- Produces: `ImageCompressor` class with `Future<ImageCompressionResult> compressFoodPhoto(File file)`, and `ImageCompressionResult { Uint8List bytes; String mimeType; }`. Constructor takes an injectable `CompressFn` for testability. Used by Task 8 (`CaptureScreen`).

- [ ] **Step 1: Write the failing tests**

Create `test/core/image_compression_test.dart`:

```dart
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_diary/core/image_compression.dart';

void main() {
  test('compressFoodPhoto returns compressed bytes with jpeg mimeType', () async {
    final compressor = ImageCompressor(
      compressFn: (path, minWidth, minHeight, quality) async => Uint8List.fromList([1, 2, 3]),
    );
    final result = await compressor.compressFoodPhoto(File('fake.jpg'));
    expect(result.bytes, Uint8List.fromList([1, 2, 3]));
    expect(result.mimeType, 'image/jpeg');
  });

  test('compressFoodPhoto throws when compression returns null', () async {
    final compressor = ImageCompressor(
      compressFn: (path, minWidth, minHeight, quality) async => null,
    );
    expect(() => compressor.compressFoodPhoto(File('fake.jpg')), throwsException);
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/core/image_compression_test.dart`
Expected: FAIL — `package:food_diary/core/image_compression.dart` not found.

- [ ] **Step 3: Implement**

Create `lib/core/image_compression.dart`:

```dart
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_image_compress/flutter_image_compress.dart';

typedef CompressFn = Future<Uint8List?> Function(
    String path, int minWidth, int minHeight, int quality);

class ImageCompressionResult {
  ImageCompressionResult(this.bytes, this.mimeType);
  final Uint8List bytes;
  final String mimeType;
}

class ImageCompressor {
  ImageCompressor({CompressFn? compressFn}) : _compressFn = compressFn ?? _defaultCompress;

  final CompressFn _compressFn;

  static Future<Uint8List?> _defaultCompress(
      String path, int minWidth, int minHeight, int quality) {
    return FlutterImageCompress.compressWithFile(
      path,
      minWidth: minWidth,
      minHeight: minHeight,
      quality: quality,
      format: CompressFormat.jpeg,
    );
  }

  Future<ImageCompressionResult> compressFoodPhoto(File file) async {
    final bytes = await _compressFn(file.absolute.path, 1024, 1024, 80);
    if (bytes == null) {
      throw Exception('Failed to compress image');
    }
    return ImageCompressionResult(bytes, 'image/jpeg');
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/core/image_compression_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/core/image_compression.dart test/core/image_compression_test.dart
git commit -m "Add injectable image compression helper"
```

---

## Task 6: Auth repository + email/password screens

**Files:**
- Create: `lib/features/auth/auth_repository.dart`
- Create: `lib/features/auth/login_screen.dart`
- Create: `lib/features/auth/signup_screen.dart`

**Interfaces:**
- Produces: `AuthRepository(SupabaseClient)` with `currentSession`, `onAuthStateChange`, `signUpWithEmail(email, password)`, `signInWithEmail(email, password)`, `signInWithGoogle()`, `signOut()`. `LoginScreen(authRepository, onSignedIn)` and `SignupScreen(authRepository, onSignedUp)`. Used by Task 10 (`main.dart`).

- [ ] **Step 1: Implement `AuthRepository`**

This is a thin wrapper over the Supabase Auth SDK with no branching logic to unit test in isolation (mocking `SupabaseClient` end-to-end requires the Supabase local stack). Verification for this task is manual (Step 4), not `flutter test`.

Create `lib/features/auth/auth_repository.dart`:

```dart
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthRepository {
  AuthRepository(this._client);
  final SupabaseClient _client;

  Session? get currentSession => _client.auth.currentSession;
  Stream<AuthState> get onAuthStateChange => _client.auth.onAuthStateChange;

  Future<void> signUpWithEmail(String email, String password) async {
    await _client.auth.signUp(email: email, password: password);
  }

  Future<void> signInWithEmail(String email, String password) async {
    await _client.auth.signInWithPassword(email: email, password: password);
  }

  Future<void> signInWithGoogle() async {
    await _client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: 'io.supabase.fooddiary://login-callback/',
    );
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }
}
```

- [ ] **Step 2: Implement `LoginScreen`**

Create `lib/features/auth/login_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'auth_repository.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.authRepository, required this.onSignedIn});
  final AuthRepository authRepository;
  final VoidCallback onSignedIn;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _error;
  bool _loading = false;

  Future<void> _signIn() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await widget.authRepository.signInWithEmail(_emailController.text, _passwordController.text);
      widget.onSignedIn();
    } catch (_) {
      setState(() => _error = 'Sign in failed. Check your email/password.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sign in')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(controller: _emailController, decoration: const InputDecoration(labelText: 'Email')),
            TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Password')),
            if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
            FilledButton(onPressed: _loading ? null : _signIn, child: const Text('Sign in')),
            OutlinedButton(
              onPressed: () => widget.authRepository.signInWithGoogle(),
              child: const Text('Continue with Google'),
            ),
            TextButton(
              onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => SignupScreen(
                          authRepository: widget.authRepository, onSignedUp: widget.onSignedIn))),
              child: const Text('Create account'),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 3: Implement `SignupScreen`**

Create `lib/features/auth/signup_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'auth_repository.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key, required this.authRepository, required this.onSignedUp});
  final AuthRepository authRepository;
  final VoidCallback onSignedUp;

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _error;
  bool _loading = false;

  Future<void> _signUp() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await widget.authRepository.signUpWithEmail(_emailController.text, _passwordController.text);
      widget.onSignedUp();
    } catch (e) {
      setState(() => _error = 'Sign up failed: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create account')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(controller: _emailController, decoration: const InputDecoration(labelText: 'Email')),
            TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Password')),
            if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
            FilledButton(onPressed: _loading ? null : _signUp, child: const Text('Sign up')),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Manual config for Google OAuth + deep link**

1. In Supabase Dashboard → Authentication → Providers → Google: enable it, following Supabase's guide to create a Google Cloud OAuth client (Web application type) and paste its Client ID/Secret.
2. Add the Android deep link intent filter so `io.supabase.fooddiary://login-callback/` returns to the app. In `android/app/src/main/AndroidManifest.xml`, inside the main `<activity>` tag, add:

```xml
<intent-filter>
    <action android:name="android.intent.action.VIEW" />
    <category android:name="android.intent.category.DEFAULT" />
    <category android:name="android.intent.category.BROWSABLE" />
    <data android:scheme="io.supabase.fooddiary" android:host="login-callback" />
</intent-filter>
```

- [ ] **Step 5: Verify manually**

Run: `flutter analyze` (expect clean). Deferred to Task 10 for a live sign-in run, once `main.dart` wires this screen in.

- [ ] **Step 6: Commit**

```bash
git add lib/features/auth android/app/src/main/AndroidManifest.xml
git commit -m "Add email/password + Google auth repository and screens"
```

---

## Task 7: Analyze repository (calls `analyze-food`)

**Files:**
- Create: `lib/features/analyze/analyze_repository.dart`
- Test: `test/features/analyze/analyze_repository_test.dart`

**Interfaces:**
- Consumes: `FoodItem.fromGemini` (Task 4)
- Produces: `parseAnalyzeResponse(Map<String, dynamic> data) -> List<FoodItem>` (pure, tested directly), `AnalyzeRepository(SupabaseClient)` with `Future<List<FoodItem>> analyzePhoto({required Uint8List imageBytes, required String mimeType, String? note})`, and `AnalyzeException` with `.userMessage`. Used by Task 8 (`CaptureScreen`).

- [ ] **Step 1: Write the failing test**

Create `test/features/analyze/analyze_repository_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:food_diary/features/analyze/analyze_repository.dart';

void main() {
  test('parseAnalyzeResponse maps items to FoodItem list', () {
    final data = {
      'items': [
        {
          'name': 'Rice',
          'quantity': '1 cup',
          'calories': 200,
          'protein': 4,
          'carb': 45,
          'fat': 0.5,
          'confidence': 'high',
        }
      ]
    };
    final items = parseAnalyzeResponse(data);
    expect(items.length, 1);
    expect(items.first.name, 'Rice');
    expect(items.first.confidence, 'high');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/analyze/analyze_repository_test.dart`
Expected: FAIL — file not found.

- [ ] **Step 3: Implement**

Create `lib/features/analyze/analyze_repository.dart`:

```dart
import 'dart:convert';
import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/food_item.dart';

List<FoodItem> parseAnalyzeResponse(Map<String, dynamic> data) {
  final items = (data['items'] as List)
      .map((json) => FoodItem.fromGemini(json as Map<String, dynamic>))
      .toList();
  return items;
}

class AnalyzeRepository {
  AnalyzeRepository(this._client);
  final SupabaseClient _client;

  Future<List<FoodItem>> analyzePhoto({
    required Uint8List imageBytes,
    required String mimeType,
    String? note,
  }) async {
    final response = await _client.functions.invoke(
      'analyze-food',
      body: {
        'image': base64Encode(imageBytes),
        'mimeType': mimeType,
        if (note != null && note.isNotEmpty) 'note': note,
      },
    );

    if (response.status != 200) {
      final error = (response.data is Map) ? response.data['error'] : 'unknown';
      throw AnalyzeException(error?.toString() ?? 'unknown');
    }

    return parseAnalyzeResponse(response.data as Map<String, dynamic>);
  }
}

class AnalyzeException implements Exception {
  AnalyzeException(this.code);
  final String code;

  String get userMessage {
    switch (code) {
      case 'rate_limited':
        return 'High demand right now, try again shortly.';
      case 'unauthorized':
        return 'Please sign in again.';
      default:
        return 'Analysis failed, try again.';
    }
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/analyze/analyze_repository_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/analyze/analyze_repository.dart test/features/analyze/analyze_repository_test.dart
git commit -m "Add AnalyzeRepository calling the analyze-food Edge Function"
```

---

## Task 8: Capture screen + editable analysis result screen

**Files:**
- Create: `lib/features/analyze/capture_screen.dart`
- Create: `lib/features/analyze/analysis_result_screen.dart`
- Test: `test/features/analyze/analysis_result_screen_test.dart`

**Interfaces:**
- Consumes: `AnalyzeRepository`/`AnalyzeException` (Task 7), `ImageCompressor` (Task 5), `FoodItem` (Task 4)
- Produces: `AnalysisResultScreen({initialItems, onSave})` and `CaptureScreen({analyzeRepository, onSave})` where `onSave: Future<void> Function(List<FoodItem> items, File? photoFile, String? note)`. Used by Task 10 (`main.dart`).

- [ ] **Step 1: Write the failing widget tests**

Create `test/features/analyze/analysis_result_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_diary/features/analyze/analysis_result_screen.dart';
import 'package:food_diary/models/food_item.dart';

void main() {
  testWidgets('editing calories updates the total', (tester) async {
    List<FoodItem>? saved;
    await tester.pumpWidget(MaterialApp(
      home: AnalysisResultScreen(
        initialItems: [
          FoodItem(name: 'Rice', quantity: '1 cup', calories: 200, protein: 4, carb: 45, fat: 0.5, source: 'ai'),
        ],
        onSave: (items) async => saved = items,
      ),
    ));

    expect(find.text('Total: 200 kcal'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('calories_field')), '300');
    await tester.pump();

    expect(find.text('Total: 300 kcal'), findsOneWidget);

    await tester.tap(find.text('Save to diary'));
    await tester.pumpAndSettle();

    expect(saved, isNotNull);
    expect(saved!.first.calories, 300);
  });

  testWidgets('removing an item deletes its card', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: AnalysisResultScreen(
        initialItems: [
          FoodItem(name: 'Rice', quantity: '1 cup', calories: 200, protein: 4, carb: 45, fat: 0.5, source: 'ai'),
        ],
        onSave: (items) async {},
      ),
    ));

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pump();

    expect(find.byKey(const Key('name_field')), findsNothing);
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/analyze/analysis_result_screen_test.dart`
Expected: FAIL — file not found.

- [ ] **Step 3: Implement `AnalysisResultScreen`**

Create `lib/features/analyze/analysis_result_screen.dart`:

```dart
import 'package:flutter/material.dart';
import '../../models/food_item.dart';

class AnalysisResultScreen extends StatefulWidget {
  const AnalysisResultScreen({super.key, required this.initialItems, required this.onSave});

  final List<FoodItem> initialItems;
  final Future<void> Function(List<FoodItem> items) onSave;

  @override
  State<AnalysisResultScreen> createState() => _AnalysisResultScreenState();
}

class _AnalysisResultScreenState extends State<AnalysisResultScreen> {
  late List<FoodItem> _items;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _items = List.of(widget.initialItems);
  }

  double get _totalCalories => _items.fold(0, (sum, i) => sum + i.calories);

  void _updateItem(int index, FoodItem updated) => setState(() => _items[index] = updated);
  void _removeItem(int index) => setState(() => _items.removeAt(index));
  void _addItem() => setState(() => _items.add(FoodItem(
        name: '',
        quantity: '',
        calories: 0,
        protein: 0,
        carb: 0,
        fat: 0,
        source: 'user_edited',
      )));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Review Analysis')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (var i = 0; i < _items.length; i++)
            _FoodItemCard(
              key: ValueKey('item_$i'),
              item: _items[i],
              onChanged: (updated) => _updateItem(i, updated),
              onRemove: () => _removeItem(i),
            ),
          TextButton.icon(onPressed: _addItem, icon: const Icon(Icons.add), label: const Text('Add item')),
          const Divider(),
          Text('Total: ${_totalCalories.toStringAsFixed(0)} kcal',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _saving || _items.isEmpty
                ? null
                : () async {
                    setState(() => _saving = true);
                    await widget.onSave(_items);
                    if (mounted) setState(() => _saving = false);
                  },
            child: Text(_saving ? 'Saving...' : 'Save to diary'),
          ),
        ],
      ),
    );
  }
}

class _FoodItemCard extends StatelessWidget {
  const _FoodItemCard({super.key, required this.item, required this.onChanged, required this.onRemove});

  final FoodItem item;
  final ValueChanged<FoodItem> onChanged;
  final VoidCallback onRemove;

  FoodItem _copyWith(FoodItem item, {String? name, String? quantity, double? calories}) {
    return FoodItem(
      id: item.id,
      name: name ?? item.name,
      quantity: quantity ?? item.quantity,
      calories: calories ?? item.calories,
      protein: item.protein,
      carb: item.carb,
      fat: item.fat,
      source: 'user_edited',
      confidence: item.confidence,
    );
  }

  @override
  Widget build(BuildContext context) {
    final lowConfidence = item.confidence == 'low';
    return Card(
      color: lowConfidence ? Colors.amber.shade50 : null,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            if (lowConfidence)
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('Low confidence - please check', style: TextStyle(color: Colors.orange)),
              ),
            TextFormField(
              key: const Key('name_field'),
              initialValue: item.name,
              decoration: const InputDecoration(labelText: 'Name'),
              onChanged: (v) => onChanged(_copyWith(item, name: v)),
            ),
            TextFormField(
              key: const Key('quantity_field'),
              initialValue: item.quantity,
              decoration: const InputDecoration(labelText: 'Quantity'),
              onChanged: (v) => onChanged(_copyWith(item, quantity: v)),
            ),
            TextFormField(
              key: const Key('calories_field'),
              initialValue: item.calories.toString(),
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Calories'),
              onChanged: (v) => onChanged(_copyWith(item, calories: double.tryParse(v) ?? 0)),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(icon: const Icon(Icons.delete_outline), onPressed: onRemove),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/analyze/analysis_result_screen_test.dart`
Expected: PASS.

- [ ] **Step 5: Implement `CaptureScreen`**

Create `lib/features/analyze/capture_screen.dart`:

```dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/image_compression.dart';
import '../../models/food_item.dart';
import 'analyze_repository.dart';
import 'analysis_result_screen.dart';

class CaptureScreen extends StatefulWidget {
  const CaptureScreen({super.key, required this.analyzeRepository, required this.onSave});

  final AnalyzeRepository analyzeRepository;
  final Future<void> Function(List<FoodItem> items, File? photoFile, String? note) onSave;

  @override
  State<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends State<CaptureScreen> {
  final _picker = ImagePicker();
  final _noteController = TextEditingController();
  File? _photo;
  bool _analyzing = false;
  String? _error;

  Future<void> _pickPhoto(ImageSource source) async {
    final picked = await _picker.pickImage(source: source);
    if (picked != null) setState(() => _photo = File(picked.path));
  }

  Future<void> _analyze() async {
    if (_photo == null) return;
    setState(() {
      _analyzing = true;
      _error = null;
    });
    try {
      final compressed = await ImageCompressor().compressFoodPhoto(_photo!);
      final items = await widget.analyzeRepository.analyzePhoto(
        imageBytes: compressed.bytes,
        mimeType: compressed.mimeType,
        note: _noteController.text,
      );
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AnalysisResultScreen(
            initialItems: items,
            onSave: (savedItems) => widget.onSave(savedItems, _photo, _noteController.text),
          ),
        ),
      );
    } on AnalyzeException catch (e) {
      setState(() => _error = e.userMessage);
    } catch (_) {
      setState(() => _error = 'Network error. Check your connection and try again.');
    } finally {
      if (mounted) setState(() => _analyzing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add meal')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (_photo != null) Image.file(_photo!, height: 200),
            Row(
              children: [
                TextButton(onPressed: () => _pickPhoto(ImageSource.camera), child: const Text('Camera')),
                TextButton(onPressed: () => _pickPhoto(ImageSource.gallery), child: const Text('Gallery')),
              ],
            ),
            TextField(
              controller: _noteController,
              decoration: const InputDecoration(labelText: 'Note (optional) - e.g. "Thai green curry"'),
            ),
            if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
            FilledButton(
              onPressed: _photo == null || _analyzing ? null : _analyze,
              child: Text(_analyzing ? 'Analyzing...' : 'Analyze'),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 6: Verify with analyzer**

Run: `flutter analyze`
Expected: "No issues found!"

- [ ] **Step 7: Commit**

```bash
git add lib/features/analyze test/features/analyze/analysis_result_screen_test.dart
git commit -m "Add capture screen and editable analysis result screen"
```

---

## Task 9: Diary repository + diary screen

**Files:**
- Create: `lib/features/diary/diary_repository.dart`
- Create: `lib/features/diary/diary_screen.dart`
- Test: `test/features/diary/diary_repository_test.dart`

**Interfaces:**
- Consumes: `FoodItem`/`MealEntry` (Task 4)
- Produces: `computeTotals(List<FoodItem>) -> Totals` (pure, tested directly), `DiaryRepository(SupabaseClient)` with `Future<String> saveMealEntry({items, eatenAt, note, photoBytes})` and `Future<List<MealEntry>> entriesForDay(DateTime day)`, and `DiaryScreen({repository})`. Used by Task 10 (`main.dart`).

- [ ] **Step 1: Write the failing test**

Create `test/features/diary/diary_repository_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:food_diary/features/diary/diary_repository.dart';
import 'package:food_diary/models/food_item.dart';

void main() {
  test('computeTotals sums all macro fields across items', () {
    final items = [
      FoodItem(name: 'Rice', quantity: '1 cup', calories: 200, protein: 4, carb: 45, fat: 0.5, source: 'ai'),
      FoodItem(name: 'Chicken', quantity: '100g', calories: 165, protein: 31, carb: 0, fat: 3.6, source: 'ai'),
    ];
    final totals = computeTotals(items);
    expect(totals.calories, 365);
    expect(totals.protein, 35);
    expect(totals.carb, 45);
    expect(totals.fat, closeTo(4.1, 0.001));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/diary/diary_repository_test.dart`
Expected: FAIL — file not found.

- [ ] **Step 3: Implement `DiaryRepository`**

Create `lib/features/diary/diary_repository.dart`:

```dart
import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/food_item.dart';
import '../../models/meal_entry.dart';

class Totals {
  Totals(this.calories, this.protein, this.carb, this.fat);
  final double calories;
  final double protein;
  final double carb;
  final double fat;
}

Totals computeTotals(List<FoodItem> items) {
  return Totals(
    items.fold(0, (s, i) => s + i.calories),
    items.fold(0, (s, i) => s + i.protein),
    items.fold(0, (s, i) => s + i.carb),
    items.fold(0, (s, i) => s + i.fat),
  );
}

class DiaryRepository {
  DiaryRepository(this._client);
  final SupabaseClient _client;

  Future<String> saveMealEntry({
    required List<FoodItem> items,
    required DateTime eatenAt,
    String? note,
    Uint8List? photoBytes,
  }) async {
    final userId = _client.auth.currentUser!.id;
    String? photoUrl;

    if (photoBytes != null) {
      final path = '$userId/${DateTime.now().millisecondsSinceEpoch}.jpg';
      await _client.storage.from('meal-photos').uploadBinary(
            path,
            photoBytes,
            fileOptions: const FileOptions(contentType: 'image/jpeg'),
          );
      photoUrl = path;
    }

    final totals = computeTotals(items);
    final entryRow = await _client
        .from('meal_entries')
        .insert({
          'user_id': userId,
          'photo_url': photoUrl,
          'note': note,
          'eaten_at': eatenAt.toIso8601String(),
          'total_calories': totals.calories,
          'total_protein': totals.protein,
          'total_carb': totals.carb,
          'total_fat': totals.fat,
        })
        .select()
        .single();

    final mealEntryId = entryRow['id'] as String;
    await _client.from('food_items').insert(items.map((i) => i.toInsertRow(mealEntryId)).toList());

    return mealEntryId;
  }

  Future<List<MealEntry>> entriesForDay(DateTime day) async {
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));

    final rows = await _client
        .from('meal_entries')
        .select('*, food_items(*)')
        .gte('eaten_at', start.toIso8601String())
        .lt('eaten_at', end.toIso8601String())
        .order('eaten_at');

    return (rows as List).map((row) {
      final itemsJson = row['food_items'] as List;
      final items = itemsJson
          .map((j) => FoodItem(
                id: j['id'] as String,
                name: j['name'] as String,
                quantity: j['quantity'] as String,
                calories: (j['calories'] as num).toDouble(),
                protein: (j['protein'] as num).toDouble(),
                carb: (j['carb'] as num).toDouble(),
                fat: (j['fat'] as num).toDouble(),
                source: j['source'] as String,
              ))
          .toList();
      return MealEntry.fromRow(row as Map<String, dynamic>, items);
    }).toList();
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/diary/diary_repository_test.dart`
Expected: PASS.

- [ ] **Step 5: Implement `DiaryScreen`**

Create `lib/features/diary/diary_screen.dart`:

```dart
import 'package:flutter/material.dart';
import '../../models/meal_entry.dart';
import 'diary_repository.dart';

class DiaryScreen extends StatefulWidget {
  const DiaryScreen({super.key, required this.repository});
  final DiaryRepository repository;

  @override
  State<DiaryScreen> createState() => _DiaryScreenState();
}

class _DiaryScreenState extends State<DiaryScreen> {
  DateTime _day = DateTime.now();
  late Future<List<MealEntry>> _entriesFuture;

  @override
  void initState() {
    super.initState();
    _entriesFuture = widget.repository.entriesForDay(_day);
  }

  void _changeDay(int deltaDays) {
    setState(() {
      _day = _day.add(Duration(days: deltaDays));
      _entriesFuture = widget.repository.entriesForDay(_day);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
            '${_day.year}-${_day.month.toString().padLeft(2, '0')}-${_day.day.toString().padLeft(2, '0')}'),
        leading: IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => _changeDay(-1)),
        actions: [IconButton(icon: const Icon(Icons.chevron_right), onPressed: () => _changeDay(1))],
      ),
      body: FutureBuilder<List<MealEntry>>(
        future: _entriesFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final entries = snapshot.data!;
          final totalCalories = entries.fold<double>(0, (s, e) => s + e.totalCalories);
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Total today: ${totalCalories.toStringAsFixed(0)} kcal',
                    style: Theme.of(context).textTheme.titleLarge),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: entries.length,
                  itemBuilder: (context, i) {
                    final e = entries[i];
                    return ListTile(
                      title: Text(e.items.map((it) => it.name).join(', ')),
                      subtitle: Text('${e.totalCalories.toStringAsFixed(0)} kcal'),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
```

- [ ] **Step 6: Commit**

```bash
git add lib/features/diary test/features/diary/diary_repository_test.dart
git commit -m "Add DiaryRepository and daily diary screen"
```

---

## Task 10: App wiring, storage bucket, and `.apk` build

**Files:**
- Create: `lib/main.dart`
- Modify: `android/app/src/main/AndroidManifest.xml` (camera/internet permissions)

**Interfaces:**
- Consumes: `AuthRepository`/`LoginScreen` (Task 6), `AnalyzeRepository`/`CaptureScreen` (Task 7/8), `DiaryRepository`/`DiaryScreen` (Task 9)
- Produces: the runnable app entry point; the final `.apk` artifact.

- [ ] **Step 1: Create the Storage bucket**

In Supabase Dashboard → Storage, create a bucket named `meal-photos` (private). Add a storage policy so users can only read/write objects under their own `user_id/` prefix:

```sql
create policy "meal_photos_owner_rw" on storage.objects
  for all using (bucket_id = 'meal-photos' and (storage.foldername(name))[1] = auth.uid()::text)
  with check (bucket_id = 'meal-photos' and (storage.foldername(name))[1] = auth.uid()::text);
```

Run this via `supabase db execute` against the linked remote project, or paste into the SQL editor in the dashboard.

- [ ] **Step 2: Add required Android permissions**

In `android/app/src/main/AndroidManifest.xml`, above `<application>`, ensure:

```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.CAMERA" />
```

- [ ] **Step 3: Implement `main.dart`**

Create `lib/main.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'features/auth/auth_repository.dart';
import 'features/auth/login_screen.dart';
import 'features/analyze/analyze_repository.dart';
import 'features/analyze/capture_screen.dart';
import 'features/diary/diary_repository.dart';
import 'features/diary/diary_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: const String.fromEnvironment('SUPABASE_URL'),
    anonKey: const String.fromEnvironment('SUPABASE_ANON_KEY'),
  );
  runApp(const FoodDiaryApp());
}

class FoodDiaryApp extends StatefulWidget {
  const FoodDiaryApp({super.key});

  @override
  State<FoodDiaryApp> createState() => _FoodDiaryAppState();
}

class _FoodDiaryAppState extends State<FoodDiaryApp> {
  final _client = Supabase.instance.client;
  late final _authRepository = AuthRepository(_client);
  late final _analyzeRepository = AnalyzeRepository(_client);
  late final _diaryRepository = DiaryRepository(_client);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Food Diary',
      home: StreamBuilder<AuthState>(
        stream: _authRepository.onAuthStateChange,
        builder: (context, snapshot) {
          final signedIn = _authRepository.currentSession != null;
          if (!signedIn) {
            return LoginScreen(authRepository: _authRepository, onSignedIn: () => setState(() {}));
          }
          return _HomeShell(analyzeRepository: _analyzeRepository, diaryRepository: _diaryRepository);
        },
      ),
    );
  }
}

class _HomeShell extends StatefulWidget {
  const _HomeShell({required this.analyzeRepository, required this.diaryRepository});
  final AnalyzeRepository analyzeRepository;
  final DiaryRepository diaryRepository;

  @override
  State<_HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<_HomeShell> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final screens = [
      DiaryScreen(repository: widget.diaryRepository),
      CaptureScreen(
        analyzeRepository: widget.analyzeRepository,
        onSave: (items, photoFile, note) async {
          await widget.diaryRepository.saveMealEntry(
            items: items,
            eatenAt: DateTime.now(),
            note: note,
            photoBytes: photoFile != null ? await photoFile.readAsBytes() : null,
          );
          if (mounted) setState(() => _tab = 0);
        },
      ),
    ];
    return Scaffold(
      body: screens[_tab],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.book), label: 'Diary'),
          NavigationDestination(icon: Icon(Icons.camera_alt), label: 'Add meal'),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Run the full test suite**

Run: `flutter test`
Expected: all tests from Tasks 4, 5, 7, 8, 9 pass.

- [ ] **Step 5: Run on a device/emulator and manually verify the golden path**

```bash
flutter run --dart-define=SUPABASE_URL=<your-url> --dart-define=SUPABASE_ANON_KEY=<your-anon-key>
```

Manually verify: sign up with email → sign in → capture/pick a multi-item food photo → optionally type a note → Analyze → edit a result → Save → see it appear in today's diary list with the correct total.

- [ ] **Step 6: Build the release `.apk`**

```bash
flutter build apk --release --dart-define=SUPABASE_URL=<your-url> --dart-define=SUPABASE_ANON_KEY=<your-anon-key>
```

Output: `build/app/outputs/flutter-apk/app-release.apk` — sideload this onto a phone (`adb install build/app/outputs/flutter-apk/app-release.apk` or transfer the file directly).

- [ ] **Step 7: Commit**

```bash
git add lib/main.dart android/app/src/main/AndroidManifest.xml
git commit -m "Wire app entry point, auth gate, and navigation; document .apk build"
```
