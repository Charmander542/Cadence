# Teller setup for Cadence Spend

Spend imports bank purchases through [Teller](https://teller.io/). Follow this checklist before enabling live enrollments.

## 1. Create a Teller application

1. Sign up at [https://teller.io/](https://teller.io/).
2. Create an application in the Teller dashboard.
3. Copy the **Application ID** (`app_…`).
4. Paste it in Cadence: **Settings → Spend & Teller → Application ID**  
   (or set `TellerApplicationID` in `Info.plist` for release builds).

## 2. Pick an environment

| Environment | Data | Cert (mTLS) | Limit | Use |
|-------------|------|-------------|-------|-----|
| **Sandbox** | Simulated | Optional | Unlimited | UI + Connect flow |
| **Development** | Real banks | **Required** | 100 enrollments | Team testing |
| **Production** | Real banks | **Required** | Paid / KYB | Live users |

Docs: [Environments](https://teller.io/docs/guides/environments) · [Authentication](https://teller.io/docs/api/authentication)

Cadence defaults to **sandbox**. Change under **Settings → Spend & Teller**.

### Sandbox test logins

Use Teller’s sandbox credentials (e.g. `username` / `password`, or `otp` / `password` for MFA). See the [Sandbox guide](https://teller.io/docs/guides/sandbox) in Teller docs for the full list.

## 3. Certificates (development & production)

Teller authenticates your **server** (or signed client) with **mTLS client certificates**.

**Do not** embed the certificate private key in the iOS app or commit it to git.

Recommended shape:

```
iOS (Cadence)  --HTTPS session-->  Your backend  --mTLS-->  api.teller.io
                     access token from Connect
```

1. Download / create the application certificate in the Teller dashboard.
2. Store cert + key in your secrets manager (or server keychain).
3. Implement a thin backend that:
   - Accepts the user’s Teller **access token** from Connect (store encrypted server-side or device Keychain).
   - Calls `GET /accounts` and `GET /accounts/{id}/transactions` with mTLS + Basic `accessToken:`.
   - Returns normalized JSON to Cadence (`TellerClient.fetchViaBackend`).

Sandbox-only: Cadence can call `https://api.teller.io` directly with Basic auth (`Settings → SYNC SANDBOX ACCOUNTS`). That path is for prototyping only.

## 4. Teller Connect (in-app link bank)

Native UI: [TellerKit](https://github.com/tellerhq/tellerkit) (`tellerConnect` SwiftUI modifier).

Checklist:

- [ ] Add TellerKit xcframework / SPM package to the MealPlannerApp target.
- [ ] Present Connect with `appId`, `environment`, products `[.transactions]` (and `.balance` if needed).
- [ ] On `.enrollment(auth)`, save `accessToken` via `KeychainStore.saveTellerAccessToken`.
- [ ] Persist a `SpendEnrollmentEntity` (institution name, enrollment id, sandbox flag).
- [ ] Trigger sync into `SpendTransactionEntity` through `SpendStore.upsertTransactions`.

Until Connect is wired, use a sandbox access token in Settings to exercise the transaction pipeline.

## 5. Products & scopes

For Spend you need at least:

- **Transactions** — purchase history + characterization
- Optional: **Balance** — account overview later

Do **not** request payment / move-money products unless you intentionally build that (requires signed requests + stronger UX).

## 6. Webhooks (optional but recommended)

In development/production, register webhook endpoints for enrollment lifecycle and transaction updates so Spend stays fresh without manual pull.

## 7. Production / KYB

Before flipping `environment: production`:

- [ ] Complete Teller KYB (company URL, product demo, beneficial owners, docs).
- [ ] Production webhook URLs live and authenticated.
- [ ] Certificate rotated/valid; private key only on servers.
- [ ] Privacy policy + in-app bank-data consent copy reviewed.
- [ ] Development enrollments are **not** portable — users reconnect in production.

## 8. Cadence wiring map

| Piece | Location |
|-------|----------|
| Preferences / App ID | `SpendPreferences.swift` |
| HTTP client | `TellerClient.swift` |
| Models | `SpendModels.swift` |
| Sync / cost-per-use | `SpendStore.swift` |
| UI | `Views/Spend/*` |
| Enable on wheel | `CadenceSubAppRegistry` + Settings toggle |
| Architecture | `docs/SUBAPPS.md` |

## 9. Security reminders

- Access tokens are useless without **your** application certificate — still treat tokens as secrets (Keychain).
- Never log tokens or cert material.
- Prefer backend proxy for anything beyond sandbox.
- If a key is leaked, revoke the certificate in the Teller dashboard immediately.
