#!/usr/bin/env bash
# ==============================================================================
# Build Android APK locally using configured tools
# ==============================================================================

set -e
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
cd "$DIR"

export JAVA_HOME="$HOME/.tools/jdk-17"
export ANDROID_HOME="$HOME/.tools/android-sdk"
export PATH="$JAVA_HOME/bin:$PATH"

echo "⚙️ Đang biên dịch Android APK bằng Gradle..."
cd "$DIR/android"
./gradlew assembleDebug

APK_PATH="$DIR/android/app/build/outputs/apk/debug/app-debug.apk"
if [ -f "$APK_PATH" ]; then
    cp "$APK_PATH" "$DIR/DeskPulse.apk"
    cp "$APK_PATH" "$DIR/static/DeskPulse.apk"
    echo "=============================================================="
    echo "🎉 BIÊN DỊCH APK THÀNH CÔNG!"
    echo "📍 File APK: $DIR/DeskPulse.apk"
    echo "📦 Dung lượng: $(ls -lh "$DIR/DeskPulse.apk" | awk '{print $5}')"
    echo "📲 Có thể tải trực tiếp trên điện thoại qua địa chỉ:"
    echo "   http://<IP_MÁY_TÍNH>:8765/DeskPulse.apk"
    echo "=============================================================="
fi
