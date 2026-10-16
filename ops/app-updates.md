# App updates after sign-in

The app checks the database-backed update policy in `AuthenticatedEntry`, after
email, Google or Facebook sign-in and after restoring an existing session. The
login and splash screens are never gated. A required update also blocks shop
setup, Home, and the Back button until the installed release meets the policy.

## Configure a release

In the admin portal, open **App updates**, choose Android or iOS, and enter:

| Field | Meaning |
| --- | --- |
| Minimum supported version | Oldest allowed version, such as `1.1.0` |
| Minimum build number | Oldest allowed build of that same version |
| Latest published version/build | Release advertised in the update screen |
| Update URL | Published Google Play listing (Android) or App Store listing (iOS) |
| English / Bangla message | Optional explanation shown in the user's app language |
| Require an update | Enables or disables the mandatory gate |

Version comparisons are numeric, so `1.10.0` is newer than `1.9.0`. With minimum
`1.1.0 (5)`, `1.0.9` and `1.1.0 (4)` must update; `1.1.0 (5)` and `1.2.0` can
continue. Increase the Android build/versionCode on every store upload, even
when the visible version changes.

Publish the required release to the affected users' Play track/countries before
enabling the requirement. A staged rollout is not necessarily available to every
user. The default migration creates disabled Android/iOS policies; deploying the
feature alone does not force anyone to update.

## Google Play behavior

The Update button first tries Google's immediate update flow. Once the user
accepts Google's prompt, Play handles downloading, installation, and restart.
Cancellation leaves the required-update screen visible. Interrupted immediate
updates resume when the authenticated app is reopened. If Play's update API is
unavailable, the button opens the installed package's Play listing (first the
Play Store application, then its HTTPS page). Opening a store page never clears
the requirement or starts a silent installation.

This flow requires a Play-distributed app owned by the testing account, matching
application ID/signature, and a higher versionCode available to that account.
ADB-installed debug APKs can verify the gate and listing fallback; use a Google
Play internal testing track or internal app sharing for the actual installation.
See [Google's update flow](https://developer.android.com/guide/playcore/in-app-updates)
and [testing instructions](https://developer.android.com/guide/playcore/in-app-updates/test).

## Database and API

Java service: `../haalkhata-service`. Migration:
`src/main/resources/db/migration/V59__app_update_policies.sql`.

- `GET /api/v1/app-updates/policy?platform=android`: authenticated app policy.
- `GET /api/v1/platform-admin/app-updates`: platform-admin policies.
- `PUT /api/v1/platform-admin/app-updates/android`: platform-admin policy update.

The table is `app_update_policies`, keyed by `platform`. The portal saves directly
through the guarded admin endpoint; normal shop administrators cannot edit it.
For an emergency cancellation directly in the database:

```sql
UPDATE app_update_policies
SET force_update_enabled = FALSE, updated_at = CURRENT_TIMESTAMP
WHERE platform = 'android';
```

The authenticated app checks after login and on resume (at most once a minute
when already supported). Blocked users can also tap **Check again** immediately.
The last valid policy is cached. A known mandatory policy remains effective
offline; without any known policy, a failed server request permits normal offline
work. Disabling a requirement takes effect on the next successful check.

First distribute a build that contains this feature. Builds shipped before the
feature existed cannot display its gate. Local source changes and migration must
be deployed to the test/production service and portal before remote configuration
can be used. No live database policy is enabled as part of development.
