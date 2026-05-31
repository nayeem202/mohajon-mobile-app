package com.example.inventory_1;

import android.content.ContentValues;
import android.media.MediaScannerConnection;
import android.net.Uri;
import android.os.Build;
import android.os.Environment;
import android.provider.MediaStore;

import java.io.File;
import java.io.FileOutputStream;
import java.io.OutputStream;

import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;

public class MainActivity extends FlutterActivity {
    private static final String DOWNLOAD_CHANNEL = "com.example.inventory_1/downloads";

    @Override
    public void configureFlutterEngine(FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);

        new MethodChannel(
                flutterEngine.getDartExecutor().getBinaryMessenger(),
                DOWNLOAD_CHANNEL
        ).setMethodCallHandler((call, result) -> {
            if (!"saveFileToDownloads".equals(call.method)) {
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
}
