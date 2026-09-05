# EC8A Scanner

A Flutter app for **Nigeria Democratic Congress (NDC) party agents** to scan INEC
**Form EC 8A** (polling-unit result sheets), extract the votes for **every party
printed on the form**, and sync them to a live dashboard with an **auto-updating
overall tally** across all covered polling units.

## Key behaviour

- **Home party is NDC** but nothing is hard-coded: the party list comes from the
  scanned form itself. Abbreviations unknown to the catalog are auto-added as
  `pending` for admin confirmation (so newly registered parties just work).
- **Duplicate EC 8A protection** (agreed rule): every PU contributes its
  **latest submission** to the overall tally. Earlier entries stay as history and
  are flagged. Duplicates that **agree** → PU badge *Cross-checked ✓*;
  duplicates that **differ** → PU badge *Conflict* and excluded-side-by-side
  review in the dashboard.
- **Offline-first:** submissions and photos queue locally and sync when
  connectivity returns (retries are idempotent via a device-generated
  `client_uid`).
- **Validation before submit:** sum of party votes must equal the sheet's
  *total votes cast*; low-confidence OCR cells are highlighted for manual fix.

## Repository layout

```
ec8a-scanner/
├── supabase/migrations/     # run these in Supabase SQL editor, in order
│   ├── 0001_core_tables.sql
│   ├── 0002_submissions.sql
│   ├── 0003_views.sql       # pu_rollup (duplicate/conflict flags), overall_tally
│   ├── 0004_rls.sql         # row-level security + signup trigger
│   ├── 0005_rpc.sql         # submit_ec8a() - the single validated write path
│   ├── 0006_storage.sql     # photo bucket + realtime publication
│   ├── 0007_seed.sql        # parties (incl. NDC), election, sample PUs/teams
│   ├── 0008_profiles_email.sql
│   └── 0009_pu_latest_votes.sql  # votes of the latest entry per PU (export)
├── lib/
│   ├── features/
│   │   ├── scan/            # capture, QR scan, OCR service, parsers, review
│   │   ├── home/            # assigned polling units + status badges
│   │   ├── dashboard/       # live tally + per-PU entry detail
│   │   ├── admin/           # CSV PU import, parties, teams
│   │   └── auth/            # login
│   ├── data/                # repositories + offline sync queue
│   ├── state/               # Riverpod providers (incl. realtime)
│   └── core/                # config (dart-define) + theme
├── test/                    # parser, QR payload and sync-queue tests
├── pubspec.yaml
└── README.md
```

## Three ways to capture an EC 8A

1. **Scan QR code** (newer forms) - most reliable; the QR at the bottom of
   the sheet encodes the results digitally. Tolerant JSON/text payload parser.
2. **Photo scan** - on-device ML Kit OCR anchored on printed party
   abbreviations; low-confidence cells tinted orange for review.
3. **Manual entry** - type the votes with the photo stored as evidence.

Every path ends at the same review screen: values side-by-side with the
photo, sum-check against "total votes cast", team selector, then submit
(online or queued offline).

**CSV export** (Admin -> Export tab): generates a results matrix - one row
per polling unit (its latest entry, exactly what the tally counts), one
column per party with NDC first, plus the `entries`/`duplicate_flag`/
`cross_checked`/`conflict_flag` audit columns. Saved to the app documents
folder with one-tap clipboard copy for pasting into Sheets/WhatsApp.


## Setup — Supabase (free tier, no subscription)

1. Create a project at <https://supabase.com> (free tier is enough for a pilot).
2. Open **SQL Editor** → *New query* → paste the contents of each file in
   `supabase/migrations/` **in file-name order** and run them one by one
   (`0001` → `0007`).
3. Note **Project URL** and **anon key** (*Settings → API*) — the app needs them.
4. Create users in **Authentication → Users → Add user** (email + password).
   The `on_auth_user_created` trigger auto-creates their `profiles` row.
5. Promote your first admin:
   ```sql
   update public.profiles set role = 'admin' where id = '<auth-user-uuid>';
   ```
6. Put agents into teams (sample teams/PU assignments are seeded):
   ```sql
   insert into public.team_members (team_id, user_id)
   select id, '<auth-user-uuid>' from public.teams where name = 'Municipal Ward 1 Team';
   ```
7. Import real polling units by CSV (state, lga, ward, code, name) or INSERT
   statements — see `polling_units` table.

## Setup — Flutter app

Toolchain already installed on this machine (by Cline):
- Flutter SDK: `C:\Users\mclde\flutter` (3.47.2, on PATH)
- JDK 21: `C:\Users\mclde\jdk` (configured via `flutter config --jdk-dir`)
- Android SDK: `C:\Users\mclde\android-sdk` (platforms 35/36, build-tools 36.1.0,
  licenses accepted; configured via `flutter config --android-sdk`)

Requires the [Flutter SDK](https://docs.flutter.dev/get-started/install/windows)
and Android Studio/SDK for Android builds.

```bash
cd ec8a-scanner
flutter pub get

# run with your Supabase credentials (no secrets in code):
flutter run \
  --dart-define=SUPABASE_URL=https://YOUR-PROJECT.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=YOUR-ANON-KEY

# release APK:
flutter build apk --release \
  --dart-define=SUPABASE_URL=https://YOUR-PROJECT.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=YOUR-ANON-KEY
```

## iPhone / iOS Setup

### Option A: Build & Deploy (requires a Mac)

```bash
cd ec8a-scanner
flutter pub get
flutter build ios --release
# Open ios/Runner.xcworkspace in Xcode, connect your iPhone, and run
```

### Option B: Sideload the CI-built IPA (no Mac needed)

Every push to `main` builds an unsigned `.ipa` via GitHub Actions:

1. Go to **Actions** → **iOS Build** → select the latest run
2. Download the `ios-ipa` artifact (`ec8a-scanner-ios.ipa`)
3. Sideload onto your iPhone using one of these tools:

| Tool | Cost | Jailbreak needed |
|------|------|------------------|
| [AltStore](https://altstore.io) | Free | No |
| [Sideloadly](https://sideloadly.io) | Free | No |

**Steps with AltStore (recommended):**
1. Install AltServer on your computer (altstore.io)
2. Connect iPhone via USB, trust the computer
3. Open AltStore on iPhone → My Apps → "+" → select the `.ipa`
4. Enter your Apple ID when prompted (used for free provisioning)
5. The app appears on your home screen

> **Note:** Free provisioning profiles expire after 7 days. Re-sign weekly via AltStore (it auto-refreshes when on the same Wi-Fi as AltServer).

---

### Prebuilt APKs (built WITHOUT Supabase credentials)

Located in `build\app\outputs\flutter-apk\`:
- `app-arm64-v8a-release.apk` (34.2 MB) — modern Android phones, install this one
- `app-armeabi-v7a-release.apk` (26.1 MB) — older phones
- `app-x86_64-release.apk` (37.3 MB) — emulators
- `app-release.apk` (90.1 MB) — all-ABIs bundle

An APK built without `--dart-define` credentials starts on a setup screen
explaining how to rebuild it with your Supabase URL/key. For a shareable
production APK, rebuild with the `--dart-define` flags above, then copy
`app-arm64-v8a-release.apk` to agents' phones and install it
(allow "install from unknown sources").

### Android build notes (already applied)

- `android/app/proguard-rules.pro`: `-dontwarn` rules for the ML Kit optional
  script recognizers (we only use Latin) — required for release R8.
- `compileSdk = 36` in `android/app/build.gradle.kts`: required by
  flutter_plugin_android_lifecycle's AAR metadata.
- `file_picker` was upgraded to v12 (new static `FilePicker.pickFiles()` API)
  because v8 compiled against an older SDK.


## Duplicate / conflict rules (recap)

| Situation | Result |
|---|---|
| PU submitted once | counts toward overall tally |
| 2nd entry, numbers **agree** | still counts once, badge *Cross-checked* |
| 2nd entry, numbers **differ** | counts once (latest), badge *Conflict*, side-by-side review |
| Same user re-submits own PU | flagged *Re-entry* in dashboard |
| Older duplicate entries | kept forever with photos, never counted twice |

## Stack

Flutter · Riverpod · google_mlkit_text_recognition (on-device OCR, free) ·
mobile_scanner (QR path) · file-backed offline sync queue (atomic rename +
`client_uid` idempotency) · supabase_flutter
(auth, Postgres + RLS, Storage, Realtime).
