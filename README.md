# Gate Entry — Visitor / Client Register

A small Flutter + Supabase app for a factory gate. It replaces the paper visitor
book so **client phone numbers can no longer be leaked** by whoever mans the gate.

- **Guard** (gate tablet): records visitor **name, entry time, exit time**. The
  visitor types their **own phone number**, which is **hidden as it is typed** and
  can **never be read back** from the tablet.
- **Owner** (personal phone): sees the **full register**, can **reveal** any phone
  number, and has an **audit log** of every reveal.

## Why it is actually private (not just hidden on screen)

Masking a field in the UI is not enough — a determined person can read the API
response. So the protection is enforced in the **database**:

1. Real phone numbers live in a separate table (`visitor_contacts`) that has
   **Row Level Security on and zero read policies** → no app client (guard *or*
   owner) can query it directly.
2. All sensitive actions go through **`SECURITY DEFINER` functions (RPCs)** that
   enforce the rules server-side:
   - `add_visitor()` — anyone logged in can add; stores the real number in the
     locked table and only a **masked** copy (`98••••••10`) where the guard sees it.
   - `mark_exit()` — anyone logged in can set the exit time.
   - `reveal_phone()` — **owner only**, and it writes an **audit row** every call.
3. The guard app literally never receives a full number. Even inspecting network
   traffic on the tablet shows only masked values.

See [`supabase/schema.sql`](supabase/schema.sql) for the full commented model.

## Setup

### 1. Create a Supabase project
Grab your **Project URL** and **anon / publishable key** from
`Project Settings → API`.

### 2. Apply the schema
Open the Supabase **SQL Editor**, paste the contents of
[`supabase/schema.sql`](supabase/schema.sql), and run it.

### 3. Create accounts and set roles
- In the Dashboard: `Authentication → Users → Add user` for the owner and each guard.
- Then run [`supabase/seed_roles.sql`](supabase/seed_roles.sql) (edit the email
  first) to promote your account to **owner**. New users default to **guard**.

### 4. Run / build the app
Credentials are passed at build time (never hard-coded):

```bash
flutter pub get

# Run on a connected device / emulator
flutter run \
  --dart-define=SUPABASE_URL=https://YOUR-PROJECT.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=YOUR-ANON-KEY

# Build a release APK to install on the gate tablet / owner phone
flutter build apk --release \
  --dart-define=SUPABASE_URL=https://YOUR-PROJECT.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=YOUR-ANON-KEY
```

The APK lands at `build/app/outputs/flutter-apk/app-release.apk`.

> Tip: put the two `--dart-define` values in a `--dart-define-from-file=env.json`
> to keep commands short. Do not commit that file.

## How it is used day to day

**At the gate (guard):**
1. Tap **New entry**, type the visitor's name (and optionally company/purpose).
2. Hand the tablet to the visitor to type their phone number — it shows as dots.
3. Tap **Record entry**. When they leave, tap **Mark exit**.

**Owner (phone):**
1. Open the **Register** tab to see everyone, search by name/company.
2. Tap **Reveal** on a visitor to see the real number (this is logged).
3. Open the **Audit** tab to see who/when numbers were viewed.

## Roles

| Capability                    | Guard | Owner |
|-------------------------------|:-----:|:-----:|
| Add visitor / record times    |  ✅   |  ✅   |
| See masked phone (`98••••••10`)|  ✅   |  ✅   |
| Reveal full phone number      |  ❌   |  ✅   |
| View audit log                |  ❌   |  ✅   |

## Tech
- Flutter (Android), `supabase_flutter`
- Supabase (Postgres + Auth + RLS + RPC)

Credentials are provided via `--dart-define`; see [`lib/config.dart`](lib/config.dart).
