# Google Cloud setup (required before sign-in works)

The app authenticates with **your own Google account** and stores spreadsheets
in **your Drive**. You must create OAuth credentials once. ~15 minutes.

## 1. Create a project & enable APIs
1. Go to <https://console.cloud.google.com/> and create a project (e.g. "School Inventory").
2. **APIs & Services → Library** → enable:
   - **Google Sheets API**
   - **Google Drive API**

## 2. Configure the OAuth consent screen
1. **APIs & Services → OAuth consent screen** → User type **External** → Create.
2. Fill app name, your support email, developer email. Save.
3. **Scopes**: add
   - `.../auth/drive.file`
   - `.../auth/spreadsheets`
   - `openid`, `email`
4. **Test users**: add your own Google account.
   - In *Testing* mode, desktop refresh tokens expire after **7 days** (you just
     sign in again). For a long-lived single-user setup, click **Publish app**
     (Production) and accept the "unverified app" warning at sign-in.

## 3. Create OAuth client IDs

### Desktop (Windows / Linux / macOS) — uses a loopback browser flow
This package's desktop flow redirects to `http://localhost:8000`, which requires
a **Web application** client (not the "Desktop app" type):
1. **Credentials → Create credentials → OAuth client ID → Web application**.
2. Under **Authorized redirect URIs** add: `http://localhost:8000`
3. Save. Copy the **Client ID** and **Client secret**.

> The desktop "client secret" for an installed app is not truly secret
> (RFC 8252) — it's fine to use locally.

### Android
1. **Create credentials → OAuth client ID → Android**.
2. Package name: `com.manage.inventory`
3. SHA-1 fingerprint — get it with:
   ```
   cd android && ./gradlew signingReport
   ```
   Register the SHA-1 of **both** the debug key and (later) your release key.

### iOS
1. **Create credentials → OAuth client ID → iOS**.
2. Bundle ID: `com.manage.inventory`
3. Add the reversed client ID as a URL scheme in `ios/Runner/Info.plist`.

## 4. Run the app with the desktop credentials

The desktop client ID/secret are read from `--dart-define` (never hard-coded):

```powershell
flutter run -d windows `
  --dart-define=GOOGLE_DESKTOP_CLIENT_ID=YOUR_WEB_CLIENT_ID `
  --dart-define=GOOGLE_DESKTOP_CLIENT_SECRET=YOUR_WEB_CLIENT_SECRET
```

For convenience there is a `run_windows.ps1` template — copy it, paste your
values, and run it. Do **not** commit real credentials.

## 5. Sign-in behavior
- **Desktop**: a browser window opens for Google consent, then redirects to the
  local app. Windows may show a firewall prompt for the loopback port — allow it.
- **Mobile**: the native Google account picker appears.

Once signed in, create a room → it becomes a new spreadsheet in a Drive folder
named **"School Inventory"**, visible at <https://sheets.google.com>.
