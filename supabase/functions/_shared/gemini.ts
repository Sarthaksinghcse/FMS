// Shared Gemini API helper — import this in every Edge Function

const GEMINI_API_URL =
  "https://generativelanguage.googleapis.com/v1beta/models/gemini-3.1-flash-lite:generateContent";

export interface GeminiResponse {
  candidates: {
    content: {
      parts: { text: string }[];
    };
  }[];
}

/**
 * Call Gemini 2.0 Flash and return the response text.
 * Pass requireJson=true to ask Gemini to return only valid JSON.
 */
export async function callGemini(
  prompt: string,
  requireJson = false
): Promise<string> {
  const apiKey = Deno.env.get("GEMINI_API_KEY");
  if (!apiKey) throw new Error("GEMINI_API_KEY secret is not set");

  const systemInstruction = requireJson
    ? "You are a helpful fleet management AI assistant. Always respond with valid JSON only. Do not include markdown code fences or any explanation outside the JSON."
    : "You are a helpful fleet management AI assistant.";

  const body = {
    system_instruction: {
      parts: [{ text: systemInstruction }],
    },
    contents: [
      {
        parts: [{ text: prompt }],
      },
    ],
    generationConfig: {
      temperature: 0.2,          // Low temp = more consistent, factual outputs
      responseMimeType: requireJson ? "application/json" : "text/plain",
    },
  };

  const res = await fetch(`${GEMINI_API_URL}?key=${apiKey}`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body),
  });

  if (!res.ok) {
    const err = await res.text();
    throw new Error(`Gemini API error ${res.status}: ${err}`);
  }

  const data: GeminiResponse = await res.json();
  return data.candidates[0].content.parts[0].text;
}
