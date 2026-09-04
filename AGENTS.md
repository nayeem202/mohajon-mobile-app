# Working Agreement

## Build & Install Workflow
- Do NOT build the APK or install it on the device automatically after code changes.
- Only build/install when the user explicitly asks (e.g. "build koro", "install koro", "deploy koro").
- After making/fixing code, run `flutter analyze` to verify it compiles, then stop and wait.
- When build/install IS requested, always use the standard flags:
  `flutter build apk --debug --dart-define=USE_CUSTOM_AUTH=true --dart-define=AUTH_BASE_URL=http://127.0.0.1:8080 --dart-define=HAALKHATA_BASE_URL=http://127.0.0.1:8081`
- Before install: `adb reverse tcp:8080 tcp:8080` and `adb reverse tcp:8081 tcp:8081` (ports are frequently lost; re-assert each time).
- Install via: `adb install -r "C:\Users\PC\IdeaProjects\inventory_1\build\app\outputs\flutter-apk\app-debug.apk"` then `adb shell am start -n com.example.inventory_1/.MainActivity`.
- Env for builds: `export JAVA_HOME=/home/pc/devtools/jdk-21.0.12+8 && export PATH=$JAVA_HOME/bin:$PATH && export ANDROID_HOME=/home/pc/Android/sdk`.