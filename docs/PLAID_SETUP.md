# Plaid setup for Cadence Spend

Spend imports bank/card purchases through [Plaid](https://plaid.com/). Teller is discontinued — use Plaid Trial (free, **10 Items**) for you + one other person.

## 1. Dashboard keys

1. Open [dashboard.plaid.com](https://dashboard.plaid.com/).
2. **Team Settings → Keys**: copy **client_id** and the **sandbox** (or production) **secret**.
3. In Cadence: **Settings → Spend**
   - Paste **Client ID**
   - Paste **Secret** → **Save secret to Keychain**
   - Environment must match the secret: **Production** secret → Production, **Sandbox** secret → Sandbox

> The keys you generate under Dashboard → Keys are per-environment. A production secret will fail against `sandbox.plaid.com`.

### Local developer file (optional)

Copy the example and fill secrets (gitignored):

```bash
cp MealPlannerApp/MealPlannerApp/PlaidLocal.plist.example \
   MealPlannerApp/MealPlannerApp/PlaidLocal.plist
```

On launch, Cadence loads `PlaidLocal.plist` into Keychain if no secret is stored yet.

**Never commit `PlaidLocal.plist` or paste secrets into source.**

## 2. Environments

| Environment | Data | Item limit (Trial) | Use |
|-------------|------|--------------------|-----|
| **Sandbox** | Simulated | Unlimited sandbox Items | UI + sync pipeline |
| **Production** | Real banks/cards | **10 Items** on Trial | You + partner |

Sandbox and Production use **different secrets** in the Plaid Dashboard.

## 3. Connect banks

### Sandbox smoke test

Only works with a **sandbox** secret. **Settings → Spend → Add sandbox test bank** creates First Platypus Bank without Link UI.

With a **production** secret (typical Trial keys), use **Connect bank or card** instead.

### Real Link (banks + cards)

1. Tap **Connect bank or card** (Plaid LinkKit).
2. Pick institution → authenticate → select accounts.
3. Cadence exchanges the public token, stores the access token in Keychain, and runs `/transactions/sync`.

Each successful Link session consumes **one Trial Item**. Removing a connection does **not** free the slot — don’t burn Items while testing.

## 4. OAuth banks (Chase, etc.)

Many production institutions require a **redirect URI** + Universal Links:

1. Plaid Dashboard → **API** → Allowed redirect URIs (e.g. `https://your.domain/plaid/`).
2. Host `apple-app-site-association` and enable Associated Domains on the app.
3. Paste the same URI into **Settings → Spend → Redirect URI**.

Sandbox non-OAuth institutions work without this.

## 5. Sync

- Spend home → **SYNC**, or Settings → **Sync transactions**.
- New Items may take a few seconds before transactions appear; sync again if the first pull is empty.

## 6. Security & persistence

- Secret and Item access tokens live in the **Keychain**.
- Cadence also keeps a Keychain **Item registry** (item id + bank name). If SwiftData is wiped on rebuild, enrollments are **restored from Keychain** on launch.
- **iCloud Keychain sync** (Settings → Spend → Backup, on by default): marks those Keychain items as synchronizable so delete/reinstall on the **same Apple ID** (with Passwords & Keychain enabled) can bring connections back without re-Linking / burning Trial Items.
- Turn sync off if you want tokens device-only.
- Fine for a personal app; for App Store shipping, move `link/token/create` + token exchange to a tiny backend.
- If a secret was pasted into chat or committed, **rotate it** in the Plaid Dashboard immediately.

## 7. Code map

| Piece | Location |
|-------|----------|
| Prefs / client id | `SpendPreferences.swift` |
| HTTP client | `PlaidClient.swift` |
| Link UI | `PlaidLinkCoordinator.swift` + LinkKit SPM |
| Sync / enroll | `SpendStore.swift` |
| UI | `Views/Spend/*` |
| Docs | this file |
