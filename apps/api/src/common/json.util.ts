export function extractJsonObject(text: string): string {
  const cleaned = text.replace(/```json/gi, "").replace(/```/g, "").trim();
  const firstBrace = cleaned.indexOf("{");
  const lastBrace = cleaned.lastIndexOf("}");

  if (firstBrace === -1 || lastBrace === -1 || lastBrace <= firstBrace) {
    throw new Error("Model output did not include a JSON object");
  }

  return cleaned.slice(firstBrace, lastBrace + 1);
}
