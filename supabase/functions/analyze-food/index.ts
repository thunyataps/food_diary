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
