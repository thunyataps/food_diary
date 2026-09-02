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
