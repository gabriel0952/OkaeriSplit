import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Content-Type': 'application/json',
}

const MAX_IMAGE_BYTES = 5 * 1024 * 1024
const MAX_REQUESTS = 5
const RATE_LIMIT_WINDOW_MS = 60_000
// Per-model timeout. Up to 3 models may be tried sequentially.
const MODEL_TIMEOUT_MS = 25_000
const ALLOWED_MIME_TYPES = new Set(['image/jpeg', 'image/png', 'image/webp', 'image/heic'])

// Try models in order; fall back on 429 / 503 to reduce rate-limit failures.
const MODELS = ['gemini-2.5-flash', 'gemini-2.0-flash', 'gemini-1.5-flash']

const TAX_TYPES = new Set(['included', 'excluded', 'exempt'])
const SUGGESTED_CATEGORIES = new Set(['餐飲', '交通', '購物', '住宿', '娛樂', '醫藥', '其他'])

type TaxType = 'included' | 'excluded' | 'exempt'
type SuggestedCategory = '餐飲' | '交通' | '購物' | '住宿' | '娛樂' | '醫藥' | '其他'

type ScanItem = {
  name: string
  amount: number
  quantity?: number
  unit_price?: number | null
  item_tax_amount?: number | null
}

type ScanResultPayload = {
  items: ScanItem[]
  total: number
  low_confidence: boolean
  raw_text?: string
  merchant?: string | null
  date?: string | null
  currency?: string | null
  tax_amount?: number | null
  tax_type?: TaxType | null
  suggested_category?: SuggestedCategory | null
}

type RateLimitEntry = {
  windowStartedAt: number
  count: number
}

const rateLimitMap = new Map<string, RateLimitEntry>()

function jsonResponse(payload: unknown, status = 200) {
  return new Response(JSON.stringify(payload), {
    status,
    headers: corsHeaders,
  })
}

function fail(error_code: string, error: string, status = 200) {
  return jsonResponse({ success: false, error_code, error }, status)
}

function cleanJsonText(text: string) {
  return text
    .replace(/^```json\s*/i, '')
    .replace(/^```\s*/i, '')
    .replace(/\s*```$/i, '')
    .trim()
}

function checkRateLimit(userId: string) {
  const now = Date.now()
  const current = rateLimitMap.get(userId)

  if (!current || now - current.windowStartedAt >= RATE_LIMIT_WINDOW_MS) {
    // Purge all expired entries when starting a new window to prevent unbounded growth.
    for (const [key, entry] of rateLimitMap) {
      if (now - entry.windowStartedAt >= RATE_LIMIT_WINDOW_MS) {
        rateLimitMap.delete(key)
      }
    }
    rateLimitMap.set(userId, { windowStartedAt: now, count: 1 })
    return true
  }

  if (current.count >= MAX_REQUESTS) {
    return false
  }

  current.count += 1
  rateLimitMap.set(userId, current)
  return true
}

function assertMimeType(mimeType: unknown): asserts mimeType is string {
  if (typeof mimeType !== 'string' || !ALLOWED_MIME_TYPES.has(mimeType)) {
    throw new Error('payload_invalid_mime')
  }
}

function assertBase64Payload(base64: unknown): asserts base64 is string {
  if (typeof base64 !== 'string' || base64.trim().length === 0) {
    throw new Error('payload_invalid_image')
  }

  const approxBytes = Math.ceil((base64.length * 3) / 4)
  if (approxBytes > MAX_IMAGE_BYTES) {
    throw new Error('payload_too_large')
  }
}

function assertApiKey(apiKey: unknown): asserts apiKey is string {
  if (typeof apiKey !== 'string' || apiKey.trim().length === 0) {
    throw new Error('invalid_key')
  }
}

function buildPrompt(languageHint: string) {
  const targetLangMap: Record<string, string> = {
    chinese: 'Traditional Chinese (繁體中文)',
    japanese: 'Japanese (日本語)',
    english: 'English',
  }
  const targetLang = targetLangMap[languageHint] ?? null

  const languageLine = targetLang
    ? `Translate all item names and the merchant name to ${targetLang}. Keep numeric values and dates as-is.`
    : 'Detect the receipt language automatically. Keep item names and merchant name in their original language.'

  return `
You are extracting structured expense data from a receipt image for a group expense-splitting app.

${languageLine}

Return JSON only, with no markdown fences and no additional commentary.
The JSON MUST follow this schema exactly:
{
  "items": [
    {
      "name": "string",
      "amount": number,
      "quantity": number,
      "unit_price": number | null,
      "item_tax_amount": number | null
    }
  ],
  "total": number,
  "low_confidence": boolean,
  "raw_text": "string",
  "merchant": "string | null",
  "date": "YYYY-MM-DD | null",
  "currency": "string | null",
  "tax_amount": number | null,
  "tax_type": "included | excluded | exempt | null",
  "suggested_category": "餐飲 | 交通 | 購物 | 住宿 | 娛樂 | 醫藥 | 其他 | null"
}

RULES:

1. TOTAL: Use the final total printed on the receipt (after all discounts and taxes).
   - 外税 (exclusive tax, tax added at bottom): total INCLUDES the tax shown at the bottom.
   - 内税 (inclusive tax, tax in prices): total is the grand total on receipt.
   - 免税 (tax-exempt / duty-free): total is the pre-tax price shown.

2. TAX:
   - tax_type "excluded" = 外税 (tax listed separately at the bottom)
   - tax_type "included" = 内税 (tax embedded in item prices)
   - tax_type "exempt"   = 免税 / duty-free
   - Set tax_amount to the actual tax charged (0 if exempt, null if not determinable).
   - Japan receipts may have two tax rates (8% food, 10% non-food); sum both into tax_amount.

3. PER-ITEM TAX (item_tax_amount):
   - For tax_type "included" (内税): set item_tax_amount for each item to the tax portion
     embedded in that item's price. Example: price 110円 at 10% → item_tax_amount = 10.
     If only a blended rate is visible, distribute proportionally. Set null if indeterminate.
   - For tax_type "excluded" (外税): items already represent pre-tax amounts, so
     item_tax_amount should be null for each item (tax is captured in tax_amount instead).
   - For tax_type "exempt": item_tax_amount is null.

4. DISCOUNTS: Discounts (割引 / 値引 / member discount / coupon etc.) must be reflected
   in the final total. Show them as negative-amount items if they appear as line items on
   the receipt, so the user can see what was deducted.

5. SELF-VALIDATE: After filling in all items, verify that sum(items[].amount) is
   reasonably close to "total" (allow for rounding ±5 and tax differences).
   If the discrepancy is large and unexplained, re-examine the receipt image and set
   low_confidence to true.

6. ITEMS:
   - "items" may be empty only if no reliable itemization can be extracted.
   - "name" must be a human-readable item name, not noise or metadata.
   - "amount" is the total amount for the line (quantity × unit_price if applicable).
   - Translate item names according to the translation rule above.

7. MERCHANT: Store, restaurant, or shop name. Translate if translation rule applies. Null if not found.

8. DATE: Extract the purchase date as YYYY-MM-DD. Return null if not found.

9. CURRENCY: Return ISO 4217 code (e.g. "JPY", "TWD", "USD", "EUR"). Return null if unclear.

10. SUGGESTED_CATEGORY: Pick the best-fit category based on items and merchant.
    Return null if unclear or ambiguous.

11. RAW_TEXT: A concise text reconstruction of the key receipt content, not an explanation.

12. If uncertain about the overall result quality, set low_confidence to true.
`.trim()
}

function parseOptionalString(v: unknown): string | null {
  return typeof v === 'string' && v.trim().length > 0 ? v.trim() : null
}

function parseOptionalNumber(v: unknown): number | null {
  return typeof v === 'number' ? v : null
}

function parseGeminiText(responseText: string): ScanResultPayload {
  let parsed: unknown

  try {
    parsed = JSON.parse(cleanJsonText(responseText))
  } catch {
    throw new Error('schema_invalid')
  }

  if (!parsed || typeof parsed !== 'object' || Array.isArray(parsed)) {
    throw new Error('schema_invalid')
  }

  const payload = parsed as Record<string, unknown>
  if (!Array.isArray(payload.items) || typeof payload.total !== 'number') {
    throw new Error('schema_invalid')
  }

  const items = payload.items.map((item) => {
    if (!item || typeof item !== 'object' || Array.isArray(item)) {
      throw new Error('schema_invalid')
    }

    const candidate = item as Record<string, unknown>
    if (typeof candidate.name !== 'string' || typeof candidate.amount !== 'number') {
      throw new Error('schema_invalid')
    }

    return {
      name: candidate.name.trim(),
      amount: candidate.amount,
      quantity: typeof candidate.quantity === 'number' ? Math.max(1, Math.round(candidate.quantity)) : 1,
      unit_price:
        typeof candidate.unit_price === 'number'
          ? candidate.unit_price
          : candidate.unit_price === null
            ? null
            : undefined,
    } satisfies ScanItem
  })

  const rawTaxType = payload.tax_type
  const taxType: TaxType | null =
    typeof rawTaxType === 'string' && TAX_TYPES.has(rawTaxType)
      ? (rawTaxType as TaxType)
      : null

  const rawCategory = payload.suggested_category
  const suggestedCategory: SuggestedCategory | null =
    typeof rawCategory === 'string' && SUGGESTED_CATEGORIES.has(rawCategory)
      ? (rawCategory as SuggestedCategory)
      : null

  return {
    items,
    total: payload.total,
    low_confidence: typeof payload.low_confidence === 'boolean' ? payload.low_confidence : false,
    raw_text: typeof payload.raw_text === 'string' ? payload.raw_text : undefined,
    merchant: parseOptionalString(payload.merchant),
    date: parseOptionalString(payload.date),
    currency: parseOptionalString(payload.currency),
    tax_amount: parseOptionalNumber(payload.tax_amount),
    tax_type: taxType,
    suggested_category: suggestedCategory,
  }
}

function extractResponseText(responseJson: Record<string, unknown>) {
  const candidates = responseJson.candidates
  if (!Array.isArray(candidates) || candidates.length === 0) {
    throw new Error('upstream_failure')
  }

  const candidate = candidates[0]
  if (!candidate || typeof candidate !== 'object' || Array.isArray(candidate)) {
    throw new Error('upstream_failure')
  }

  const content = (candidate as Record<string, unknown>).content
  if (!content || typeof content !== 'object' || Array.isArray(content)) {
    throw new Error('upstream_failure')
  }

  const parts = (content as Record<string, unknown>).parts
  if (!Array.isArray(parts)) {
    throw new Error('upstream_failure')
  }

  const textPart = parts.find((part) => part && typeof part === 'object' && !Array.isArray(part) && typeof (part as Record<string, unknown>).text === 'string')
  if (!textPart) {
    throw new Error('upstream_failure')
  }

  return ((textPart as Record<string, unknown>).text as string).trim()
}

function buildGeminiRequestBody(languageHint: string, mimeType: string, imageBase64: string) {
  return JSON.stringify({
    generationConfig: {
      responseMimeType: 'application/json',
    },
    contents: [
      {
        parts: [
          { text: buildPrompt(languageHint) },
          {
            inlineData: {
              mimeType,
              data: imageBase64,
            },
          },
        ],
      },
    ],
  })
}

// Tries each model in order, falling back on 429/503 to reduce rate-limit failures.
async function callGeminiWithFallback(
  apiKey: string,
  languageHint: string,
  mimeType: string,
  imageBase64: string,
): Promise<Response> {
  const requestBody = buildGeminiRequestBody(languageHint, mimeType, imageBase64)

  for (let i = 0; i < MODELS.length; i++) {
    const model = MODELS[i]
    const isLast = i === MODELS.length - 1
    const ac = new AbortController()
    const tid = setTimeout(() => ac.abort(), MODEL_TIMEOUT_MS)

    try {
      const resp = await fetch(
        `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${encodeURIComponent(apiKey)}`,
        {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          signal: ac.signal,
          body: requestBody,
        },
      )
      clearTimeout(tid)

      // On 429 or 503, try the next model if available.
      if (!isLast && (resp.status === 429 || resp.status === 503)) continue

      return resp
    } catch (err) {
      clearTimeout(tid)
      if (err instanceof DOMException && err.name === 'AbortError') {
        if (!isLast) continue  // this model timed out; try next
        throw err
      }
      throw err
    }
  }

  // Unreachable, but satisfies TypeScript.
  throw new Error('upstream_failure')
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // Use service role key so getUser() properly validates the JWT signature.
    // getClaims() only decodes without signature verification and must not be used.
    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    )

    const authHeader =
      req.headers.get('Authorization') ?? req.headers.get('authorization')
    if (!authHeader) {
      return fail('unauthorized', '未授權', 401)
    }

    const [bearer, jwt] = authHeader.split(' ')
    if (bearer !== 'Bearer' || !jwt) {
      return fail('unauthorized', '未授權', 401)
    }

    const { data: { user }, error: authError } = await supabaseAdmin.auth.getUser(jwt)
    const userId = user?.id

    if (authError || typeof userId !== 'string' || userId.length === 0) {
      return fail('unauthorized', '未授權', 401)
    }

    if (!checkRateLimit(userId)) {
      return fail('rate_limited', 'Gemini 掃描過於頻繁，請稍後再試')
    }

    const body = await req.json()
    const { api_key, image_base64, mime_type, language_hint } = body ?? {}

    assertApiKey(api_key)
    assertBase64Payload(image_base64)
    assertMimeType(mime_type)

    const langHint = typeof language_hint === 'string' ? language_hint : 'auto'

    let upstreamResponse: Response
    try {
      upstreamResponse = await callGeminiWithFallback(api_key.trim(), langHint, mime_type, image_base64)
    } catch (error) {
      if (error instanceof DOMException && error.name === 'AbortError') {
        return fail('timeout', 'Gemini 掃描逾時，請重試')
      }
      return fail('upstream_failure', 'Gemini 掃描失敗，請稍後再試')
    }

    if (upstreamResponse.status === 400 || upstreamResponse.status === 401 || upstreamResponse.status === 403) {
      return fail('invalid_key', 'Gemini API key 無效，請更新後重試')
    }
    if (upstreamResponse.status === 429) {
      return fail('rate_limited', 'Gemini 請求過於頻繁或暫時受限，請稍後再試')
    }
    if (!upstreamResponse.ok) {
      return fail('upstream_failure', 'Gemini 掃描失敗，請稍後再試')
    }

    const upstreamJson = (await upstreamResponse.json()) as Record<string, unknown>
    const responseText = extractResponseText(upstreamJson)
    const result = parseGeminiText(responseText)

    return jsonResponse({ success: true, result })
  } catch (error) {
    if (error instanceof Error) {
      if (error.message === 'payload_too_large') {
        return fail('payload_too_large', '圖片大小超過 Gemini 掃描上限')
      }
      if (error.message === 'payload_invalid_image' || error.message === 'payload_invalid_mime') {
        return fail('payload_invalid', '圖片格式不支援或資料不完整')
      }
      if (error.message === 'invalid_key') {
        return fail('invalid_key', 'Gemini API key 無效，請更新後重試')
      }
      if (error.message === 'schema_invalid') {
        return fail('schema_invalid', 'Gemini 掃描結果格式異常，請重試或改用本地 OCR')
      }
    }

    return fail('upstream_failure', 'Gemini 掃描失敗，請稍後再試', 500)
  }
})
