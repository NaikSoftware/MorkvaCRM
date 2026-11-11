# Epic 8 — T0 spike findings (2026-11-10)

Measured against the real `morkvacrm` project (Spark plan) through the Firebase AI Logic proxy
(`https://firebasevertexai.googleapis.com/v1beta/projects/morkvacrm/models/<model>:<task>`),
from the built web app on `localhost:8088`, using the same headers `firebase_ai` sends.

## Setup facts

- **App Check is enforced on AI Logic.** A request without `X-Firebase-AppCheck` gets
  `401 UNAUTHENTICATED "Firebase App Check token is invalid."`. The web app is registered with
  **Fraud Defense (reCAPTCHA Enterprise)**, site key `6LfFrhguAAAAAIZj85LzZCfOYz6lJETlj8BgU-j1`
  (public; domains `localhost`, `morkvacrm.web.app`, `morkvacrm.firebaseapp.com`). The app must call
  `FirebaseAppCheck.instance.activate(providerWeb: ReCaptchaEnterpriseProvider(<key>))` **before**
  the first AI call (T13b; it is no longer optional). Android/iOS are not registered yet: on mobile
  the assistant shows the `notSetUp` state until they are (out of scope for this epic).
  reCAPTCHA Enterprise issued tokens fine in the CDP-driven test Chrome.
- Pass Firebase Auth to the SDK: `FirebaseAI.googleAI(auth: FirebaseAuth.instance, appCheck:
  FirebaseAppCheck.instance)` so the `Authorization: Firebase <idToken>` and App Check headers are
  attached (needed for "authenticated users only" mode).
- `firebase_ai` is pinned to **3.13.1** (3.14.0 forces `firebase_auth` 6.5.5, which breaks the web
  build); the API is identical.

## Model

- **`gemini-3.5-flash-lite`** works as is (no `-preview` suffix). `modelVersion` echoes it,
  `serviceTier: "standard"`.
- `thinkingConfig: {thinkingLevel: MINIMAL}` accepted.

## Tool schema (`parametersJsonSchema`)

Accepted unchanged, no lowering switches needed:
- `additionalProperties: false` on objects (nested too),
- `anyOf` of scalar types (value unions),
- `additionalProperties: {anyOf: …}` maps (`values: {field: value}`),
- `enum`, `minimum`/`maximum`, `required`.

## Streaming shape

- Two function calls arrived in **two separate SSE chunks**, then a final chunk with an empty text
  part and `finishReason: STOP` → the aggregator must collect calls across all chunks.
- Every call carries an **`id`** (`call_1300…`) → echo it in the `FunctionResponse`.
- The first part carried a **`thoughtSignature`** even with MINIMAL thinking → keep original parts.
- `usageMetadata` is on every chunk (prompt 300, candidates 67 for a 2-tool request).
- Latency: ~1.5 s for the whole 2-call response.

## Tokens

- `countTokens` for a system line + 1 user message + 2 small tool declarations = **300** tokens.
  Budget the full 21-op declaration set with `countTokens` in T9/T14.

## Quota (free tier) and 429 samples

- **Per-minute limit: 15 requests** (`limit: 15`) for `gemini-3.5-flash-lite`. 30 parallel requests →
  18 × 200, 12 × 429.
- 429 body (`status: RESOURCE_EXHAUSTED`), message excerpt:

  ```
  You exceeded your current quota, please check your plan and billing details. …
  * Quota exceeded for metric: generativelanguage.googleapis.com/generate_content_free_tier_requests,
    limit: 15, model: gemini-3.5-flash-lite, description: Generate content requests per minute limit
    exceeded on Free Tier. …
  Please retry in 58.536995658s.
  ```

- Classification rules for `gemini_errors.dart`:
  - per-minute: message contains `per minute` (RPM) or `input token count per minute` (TPM) →
    `RateLimited(scope)`; retry hint from `retry in (\d+(\.\d+)?)s`.
  - per-day: message contains `per day` → `DailyQuota`.
  - otherwise a 429 → `RateLimited(rpm)` with the default 20 s.
- Config defaults: `rpm: 12` (below the 15 hard limit, leaves headroom for retries), `maxRounds: 6`.
  The daily limit was not hit; it is not published per model (third-party reports: ~500 RPD for
  Flash-Lite).
