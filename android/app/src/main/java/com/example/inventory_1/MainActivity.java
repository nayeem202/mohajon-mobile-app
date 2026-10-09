package com.example.inventory_1;

import android.content.ContentValues;
import android.content.Context;
import android.content.pm.PackageManager;
import android.database.Cursor;
import android.content.Intent;
import android.location.Location;
import android.location.LocationManager;
import android.media.MediaScannerConnection;
import android.net.Uri;
import android.os.Build;
import android.util.Log;
import android.os.Bundle;
import android.os.Environment;
import android.provider.MediaStore;
import android.provider.ContactsContract;
import android.provider.Settings;

import com.facebook.FacebookSdk;

import java.io.File;
import java.io.FileOutputStream;
import java.io.OutputStream;
import java.util.HashMap;
import java.util.ArrayList;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.io.InputStream;

import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.Result;

public class MainActivity extends FlutterActivity {
    private static final String DOWNLOAD_CHANNEL = "com.example.inventory_1/downloads";
    private static final String DEVICE_SESSION_CHANNEL = "com.example.inventory_1/device_session";
    private static final String CONTACTS_CHANNEL = "com.example.inventory_1/phone_contacts";
    private static final int LOCATION_PERMISSION_REQUEST = 4201;
    private static final int CONTACTS_PERMISSION_REQUEST = 6201;
    private Result pendingDeviceSessionResult;
    private Result pendingFileResult;
    private Result pendingContactsResult;
    private static final int PICK_BACKUP_REQUEST = 5201;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        // The Facebook SDK has to be initialised before super.onCreate(), which
        // is what triggers configureFlutterEngine -> GeneratedPluginRegistrant.
        //
        // flutter_facebook_auth builds its FacebookAuth instance inside the
        // plugin constructor, and that reaches LoginManager.getInstance(),
        // which throws "The SDK has not been initialized" if the SDK is not up
        // yet. The exception escapes into GeneratedPluginRegistrant, which then
        // skips every plugin after it -- including JniFlutterPlugin -- so Dart
        // ends up with no JNI environment and main() dies inside
        // Hive.initFlutter() before runApp. The visible symptom is the app
        // sitting on the splash screen forever.
        //
        // FacebookInitProvider normally does this, but it does not run when the
        // App ID is unset or rejected, so it is started explicitly here.
        initialiseFacebookSdk();
        super.onCreate(savedInstanceState);
    }

    /**
     * Starts the Facebook SDK if it is not already running.
     *
     * <p>Failures are swallowed on purpose. An unusable Facebook configuration
     * must not be able to abort startup: the exception would escape plugin
     * registration and take the whole app's plugin chain with it. Facebook
     * sign-in simply reports itself unavailable instead, which the Dart side
     * already handles.
     */
    private void initialiseFacebookSdk() {
        try {
            if (!FacebookSdk.isInitialized()) {
                FacebookSdk.sdkInitialize(getApplicationContext());
            }
        } catch (Throwable error) {
            Log.w("Mohajon", "Facebook SDK not initialised: " + error.getMessage());
        }
    }

    @Override
    public void configureFlutterEngine(FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);

        new MethodChannel(
                flutterEngine.getDartExecutor().getBinaryMessenger(),
                DOWNLOAD_CHANNEL
        ).setMethodCallHandler((call, result) -> {
            if (!"saveFileToDownloads".equals(call.method)) {
                if ("pickBackupFile".equals(call.method)) {
                    pendingFileResult = result;
                    Intent intent = new Intent(Intent.ACTION_OPEN_DOCUMENT);
                    intent.addCategory(Intent.CATEGORY_OPENABLE);
                    intent.setType("application/json");
                    startActivityForResult(intent, PICK_BACKUP_REQUEST);
                    return;
                }
                result.notImplemented();
                return;
            }

            final String fileName = call.argument("fileName");
            final String mimeType = call.argument("mimeType");
            final byte[] bytes = call.argument("bytes");

            if (fileName == null || mimeType == null || bytes == null) {
                result.error("invalid_args", "Missing required save arguments.", null);
                return;
            }

            try {
                final String savedPath = saveFileToDownloads(fileName, mimeType, bytes);
                result.success(savedPath);
            } catch (Exception exception) {
                result.error("save_failed", exception.getMessage(), null);
            }
        });

        new MethodChannel(
                flutterEngine.getDartExecutor().getBinaryMessenger(),
                DEVICE_SESSION_CHANNEL
        ).setMethodCallHandler((call, result) -> {
            if (!"getCurrentSession".equals(call.method)) {
                result.notImplemented();
                return;
            }
            // Authentication only needs a stable device/session id. Do not
            // block login on the optional location permission; location is
            // best-effort metadata and is handled as unavailable below.
            result.success(currentDeviceSession());
        });

        // Contact import uses our Activity channel on Android instead of a
        // plugin channel. This keeps the feature available after a Flutter
        // engine restart and gives the app one controlled permission path.
        new MethodChannel(
                flutterEngine.getDartExecutor().getBinaryMessenger(),
                CONTACTS_CHANNEL
        ).setMethodCallHandler((call, result) -> {
            if (!"readPhoneContacts".equals(call.method)) {
                result.notImplemented();
                return;
            }
            if (!hasContactsPermission()) {
                pendingContactsResult = result;
                requestPermissions(
                        new String[]{android.Manifest.permission.READ_CONTACTS},
                        CONTACTS_PERMISSION_REQUEST
                );
                return;
            }
            try {
                result.success(readPhoneContacts());
            } catch (Exception exception) {
                result.error("contacts_read_failed", "Could not read phone contacts.", null);
            }
        });
    }

    @Override
    protected void onActivityResult(int requestCode, int resultCode, Intent data) {
        super.onActivityResult(requestCode, resultCode, data);
        if (requestCode != PICK_BACKUP_REQUEST || pendingFileResult == null) return;
        Result result = pendingFileResult;
        pendingFileResult = null;
        if (resultCode != RESULT_OK || data == null || data.getData() == null) { result.success(null); return; }
        try (InputStream stream = getContentResolver().openInputStream(data.getData())) {
            if (stream == null) throw new IllegalStateException("Could not read backup file.");
            java.io.ByteArrayOutputStream output = new java.io.ByteArrayOutputStream();
            byte[] buffer = new byte[8192]; int read;
            while ((read = stream.read(buffer)) != -1) output.write(buffer, 0, read);
            Map<String, Object> payload = new HashMap<>();
            payload.put("fileName", data.getData().getLastPathSegment());
            payload.put("bytes", output.toByteArray());
            result.success(payload);
        } catch (Exception exception) { result.error("read_failed", exception.getMessage(), null); }
    }

    @Override
    public void onRequestPermissionsResult(
            int requestCode,
            String[] permissions,
            int[] grantResults
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults);
        if (requestCode == LOCATION_PERMISSION_REQUEST && pendingDeviceSessionResult != null) {
            pendingDeviceSessionResult.success(currentDeviceSession());
            pendingDeviceSessionResult = null;
        }
        if (requestCode == CONTACTS_PERMISSION_REQUEST && pendingContactsResult != null) {
            Result result = pendingContactsResult;
            pendingContactsResult = null;
            if (grantResults.length > 0 && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
                try {
                    result.success(readPhoneContacts());
                } catch (Exception exception) {
                    result.error("contacts_read_failed", "Could not read phone contacts.", null);
                }
            } else {
                result.error("contacts_permission_denied", "Contacts permission was not granted.", null);
            }
        }
    }

    private String saveFileToDownloads(String fileName, String mimeType, byte[] bytes)
            throws Exception {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            ContentValues values = new ContentValues();
            values.put(MediaStore.Downloads.DISPLAY_NAME, fileName);
            values.put(MediaStore.Downloads.MIME_TYPE, mimeType);
            values.put(MediaStore.Downloads.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS);
            values.put(MediaStore.Downloads.IS_PENDING, 1);

            Uri uri = getContentResolver().insert(
                    MediaStore.Downloads.EXTERNAL_CONTENT_URI,
                    values
            );
            if (uri == null) {
                throw new IllegalStateException("Could not create download entry.");
            }

            try (OutputStream stream = getContentResolver().openOutputStream(uri)) {
                if (stream == null) {
                    throw new IllegalStateException("Could not open download output stream.");
                }
                stream.write(bytes);
                stream.flush();
            }

            ContentValues completed = new ContentValues();
            completed.put(MediaStore.Downloads.IS_PENDING, 0);
            getContentResolver().update(uri, completed, null, null);
            return Environment.DIRECTORY_DOWNLOADS + "/" + fileName;
        }

        File downloadsDir = Environment.getExternalStoragePublicDirectory(
                Environment.DIRECTORY_DOWNLOADS
        );
        if (!downloadsDir.exists() && !downloadsDir.mkdirs()) {
            throw new IllegalStateException("Could not access downloads directory.");
        }

        File file = new File(downloadsDir, fileName);
        try (FileOutputStream stream = new FileOutputStream(file)) {
            stream.write(bytes);
            stream.flush();
        }
        MediaScannerConnection.scanFile(
                this,
                new String[]{file.getAbsolutePath()},
                new String[]{mimeType},
                null
        );
        return file.getAbsolutePath();
    }

    private Map<String, Object> currentDeviceSession() {
        Map<String, Object> payload = new HashMap<>();
        String androidId = Settings.Secure.getString(
                getContentResolver(),
                Settings.Secure.ANDROID_ID
        );
        String manufacturer = Build.MANUFACTURER == null ? "" : Build.MANUFACTURER;
        String model = Build.MODEL == null ? "" : Build.MODEL;
        payload.put("sessionId", androidId == null ? "android-device" : androidId);
        payload.put("platform", "Android");
        payload.put("deviceName", displayName(manufacturer, model));
        payload.put("manufacturer", manufacturer);
        payload.put("model", model);
        payload.put("osVersion", "Android " + Build.VERSION.RELEASE + " (SDK " + Build.VERSION.SDK_INT + ")");

        Location location = lastKnownLocation();
        if (location == null) {
            payload.put("locationLabel", "Location permission not allowed");
        } else {
            payload.put("latitude", location.getLatitude());
            payload.put("longitude", location.getLongitude());
            payload.put(
                    "locationLabel",
                    String.format(
                            Locale.US,
                            "%.5f, %.5f",
                            location.getLatitude(),
                            location.getLongitude()
                    )
            );
        }
        return payload;
    }

    private String displayName(String manufacturer, String model) {
        if (manufacturer.isEmpty()) return model.isEmpty() ? "Android device" : model;
        if (model.toLowerCase(Locale.US).startsWith(manufacturer.toLowerCase(Locale.US))) {
            return model;
        }
        return manufacturer + " " + model;
    }

    private Location lastKnownLocation() {
        if (!hasLocationPermission()) {
            return null;
        }

        LocationManager manager = (LocationManager) getSystemService(Context.LOCATION_SERVICE);
        if (manager == null) return null;
        Location best = null;
        for (String provider : manager.getProviders(true)) {
            Location candidate;
            try {
                candidate = manager.getLastKnownLocation(provider);
            } catch (SecurityException exception) {
                return null;
            }
            if (candidate != null
                    && (best == null || candidate.getTime() > best.getTime())) {
                best = candidate;
            }
        }
        return best;
    }

    private boolean hasLocationPermission() {
        return Build.VERSION.SDK_INT < Build.VERSION_CODES.M
                || checkSelfPermission(android.Manifest.permission.ACCESS_FINE_LOCATION)
                == PackageManager.PERMISSION_GRANTED
                || checkSelfPermission(android.Manifest.permission.ACCESS_COARSE_LOCATION)
                == PackageManager.PERMISSION_GRANTED;
    }

    private boolean hasContactsPermission() {
        return Build.VERSION.SDK_INT < Build.VERSION_CODES.M
                || checkSelfPermission(android.Manifest.permission.READ_CONTACTS)
                == PackageManager.PERMISSION_GRANTED;
    }

    private List<Map<String, String>> readPhoneContacts() {
        List<Map<String, String>> contacts = new ArrayList<>();
        java.util.HashSet<String> seen = new java.util.HashSet<>();
        String[] projection = {
                ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME,
                ContactsContract.CommonDataKinds.Phone.NUMBER
        };
        try (Cursor cursor = getContentResolver().query(
                ContactsContract.CommonDataKinds.Phone.CONTENT_URI,
                projection,
                null,
                null,
                ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME + " COLLATE NOCASE ASC"
        )) {
            if (cursor == null) return contacts;
            int nameColumn = cursor.getColumnIndex(ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME);
            int phoneColumn = cursor.getColumnIndex(ContactsContract.CommonDataKinds.Phone.NUMBER);
            while (cursor.moveToNext()) {
                String name = nameColumn < 0 ? "" : cursor.getString(nameColumn);
                String phone = phoneColumn < 0 ? "" : cursor.getString(phoneColumn);
                name = name == null ? "" : name.trim();
                phone = phone == null ? "" : phone.trim();
                if (name.isEmpty() || phone.isEmpty()) continue;
                String key = name.toLowerCase(Locale.US) + "|" + phone.replaceAll("[^0-9+]", "");
                if (!seen.add(key)) continue;
                Map<String, String> item = new HashMap<>();
                item.put("name", name);
                item.put("phone", phone);
                contacts.add(item);
            }
        }
        return contacts;
    }
}
