import { assertEquals, assertRejects } from "https://deno.land/std@0.208.0/assert/mod.ts";
import { callGemini, RateLimitError } from "./index.ts";

function mockFetch(response: Response) {
  globalThis.fetch = () => Promise.resolve(response);
}

/** Like {@link mockFetch}, but also captures the request body Gemini receives. */
function mockFetchCapturing(response: Response): { body: () => unknown } {
  let captured: unknown;
  globalThis.fetch = (_url, init) => {
    captured = JSON.parse((init as RequestInit).body as string);
    return Promise.resolve(response);
  };
  return { body: () => captured };
}

const oneItemResponse = () =>
  new Response(
    JSON.stringify({
      candidates: [
        {
          content: {
            parts: [
              {
                text: JSON.stringify({
                  items: [
                    { name: "Toast", quantity: "1 slice", calories: 80, protein: 3, carb: 15, fat: 1, confidence: "low" },
                  ],
                }),
              },
            ],
          },
        },
      ],
    }),
    { status: 200 },
  );

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

Deno.test("callGemini sends the text part plus an inlineData image part when a photo is present", async () => {
  const { body } = mockFetchCapturing(oneItemResponse());
  await callGemini({ image: "abc", mimeType: "image/jpeg" });
  const parts = (body() as { contents: { parts: unknown[] }[] }).contents[0].parts;
  assertEquals(parts.length, 2);
  assertEquals((parts[1] as { inlineData: { mimeType: string; data: string } }).inlineData, {
    mimeType: "image/jpeg",
    data: "abc",
  });
});

Deno.test("callGemini sends only the text part when there is no photo", async () => {
  const { body } = mockFetchCapturing(oneItemResponse());
  await callGemini({ note: "2 fried eggs and toast" });
  const parts = (body() as { contents: { parts: unknown[] }[] }).contents[0].parts;
  assertEquals(parts.length, 1);
  assertEquals("inlineData" in (parts[0] as object), false);
});
