#!/bin/bash
set -e

echo "=== Erstelle Projektstruktur ==="

mkdir -p app/src/main/java/com/quiz/scanner
mkdir -p app/src/main/res/layout
mkdir -p app/src/main/res/values
mkdir -p app/src/main/res/drawable
mkdir -p app/src/main/res/mipmap-hdpi
mkdir -p app/src/main/res/mipmap-mdpi
mkdir -p app/src/main/res/mipmap-xhdpi
mkdir -p app/src/main/res/mipmap-xxhdpi
mkdir -p gradle/wrapper

# ===== build.gradle (root) =====
cat > build.gradle << 'EOF'
buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        classpath 'com.android.tools.build:gradle:7.4.2'
    }
}
allprojects {
    repositories {
        google()
        mavenCentral()
    }
}
task clean(type: Delete) {
    delete rootProject.buildDir
}
EOF

# ===== settings.gradle =====
cat > settings.gradle << 'EOF'
rootProject.name = "QuizScanner"
include ':app'
EOF

# ===== gradle.properties =====
cat > gradle.properties << 'EOF'
org.gradle.jvmargs=-Xmx2048m -Dfile.encoding=UTF-8
android.useAndroidX=true
android.enableJetifier=true
EOF

# ===== gradle/wrapper/gradle-wrapper.properties =====
cat > gradle/wrapper/gradle-wrapper.properties << 'EOF'
distributionBase=GRADLE_USER_HOME
distributionPath=wrapper/dists
distributionUrl=https\://services.gradle.org/distributions/gradle-7.5-bin.zip
zipStoreBase=GRADLE_USER_HOME
zipStorePath=wrapper/dists
EOF

# ===== app/build.gradle =====
cat > app/build.gradle << 'EOF'
plugins {
    id 'com.android.application'
}
android {
    compileSdk 33
    defaultConfig {
        applicationId "com.quiz.scanner"
        minSdk 21
        targetSdk 33
        versionCode 1
        versionName "1.0"
    }
    buildTypes {
        release {
            minifyEnabled false
            proguardFiles getDefaultProguardFile('proguard-android-optimize.txt'), 'proguard-rules.pro'
        }
    }
    compileOptions {
        sourceCompatibility JavaVersion.VERSION_1_8
        targetCompatibility JavaVersion.VERSION_1_8
    }
}
dependencies {
    implementation 'androidx.appcompat:appcompat:1.6.1'
    implementation 'com.google.android.material:material:1.9.0'
    implementation 'androidx.constraintlayout:constraintlayout:2.1.4'
    implementation 'com.journeyapps:zxing-android-embedded:4.3.0'
    implementation 'com.google.zxing:core:3.5.1'
}
EOF

# ===== app/proguard-rules.pro =====
cat > app/proguard-rules.pro << 'EOF'
-keep class com.journeyapps.barcodescanner.** { *; }
-keep class com.google.zxing.** { *; }
EOF

# ===== AndroidManifest.xml =====
cat > app/src/main/AndroidManifest.xml << 'EOF'
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="com.quiz.scanner">
    <uses-permission android:name="android.permission.CAMERA" />
    <uses-feature android:name="android.hardware.camera" android:required="false" />
    <uses-feature android:name="android.hardware.camera.autofocus" android:required="false" />
    <application
        android:allowBackup="true"
        android:icon="@mipmap/ic_launcher"
        android:label="@string/app_name"
        android:roundIcon="@mipmap/ic_launcher_round"
        android:supportsRtl="true"
        android:theme="@style/Theme.QuizScanner">
        <activity
            android:name=".MainActivity"
            android:exported="true"
            android:screenOrientation="portrait">
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LAUNCHER" />
            </intent-filter>
        </activity>
    </application>
</manifest>
EOF

# ===== MainActivity.java =====
cat > app/src/main/java/com/quiz/scanner/MainActivity.java << 'EOF'
package com.quiz.scanner;

import android.content.ActivityNotFoundException;
import android.content.Intent;
import android.net.Uri;
import android.os.Bundle;
import android.widget.Button;
import android.widget.TextView;
import android.widget.Toast;
import androidx.appcompat.app.AppCompatActivity;
import com.journeyapps.barcodescanner.ScanContract;
import com.journeyapps.barcodescanner.ScanIntentResult;
import com.journeyapps.barcodescanner.ScanOptions;
import androidx.activity.result.ActivityResultLauncher;

public class MainActivity extends AppCompatActivity {

    private TextView statusText;

    private final ActivityResultLauncher<ScanOptions> scanLauncher =
            registerForActivityResult(new ScanContract(), this::handleScanResult);

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);
        statusText = findViewById(R.id.statusText);
        Button scanButton = findViewById(R.id.scanButton);
        scanButton.setOnClickListener(v -> startScan());
        startScan();
    }

    private void startScan() {
        statusText.setText(R.string.status_scanning);
        ScanOptions options = new ScanOptions();
        options.setDesiredBarcodeFormats(ScanOptions.QR_CODE);
        options.setPrompt(getString(R.string.scan_prompt));
        options.setCameraId(0);
        options.setBeepEnabled(true);
        options.setBarcodeImageEnabled(false);
        options.setOrientationLocked(false);
        scanLauncher.launch(options);
    }

    private void handleScanResult(ScanIntentResult result) {
        if (result.getContents() == null) {
            statusText.setText(R.string.status_cancelled);
            return;
        }
        String scannedUrl = result.getContents().trim();
        statusText.setText(getString(R.string.status_found, scannedUrl));
        openInChrome(scannedUrl);
    }

    private void openInChrome(String url) {
        Uri uri;
        try {
            uri = Uri.parse(url);
        } catch (Exception e) {
            showError(getString(R.string.error_invalid_url, url));
            return;
        }
        Intent chromeIntent = new Intent(Intent.ACTION_VIEW, uri);
        chromeIntent.setPackage("com.android.chrome");
        chromeIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
        try {
            startActivity(chromeIntent);
        } catch (ActivityNotFoundException e) {
            Intent fallbackIntent = new Intent(Intent.ACTION_VIEW, uri);
            fallbackIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            try {
                startActivity(fallbackIntent);
            } catch (ActivityNotFoundException ex) {
                showError(getString(R.string.error_no_browser));
            }
        }
    }

    private void showError(String message) {
        statusText.setText(message);
        Toast.makeText(this, message, Toast.LENGTH_LONG).show();
    }
}
EOF

# ===== activity_main.xml =====
cat > app/src/main/res/layout/activity_main.xml << 'EOF'
<?xml version="1.0" encoding="utf-8"?>
<LinearLayout xmlns:android="http://schemas.android.com/apk/res/android"
    android:layout_width="match_parent"
    android:layout_height="match_parent"
    android:orientation="vertical"
    android:gravity="center"
    android:padding="32dp"
    android:background="#1a1a2e">
    <TextView
        android:id="@+id/statusText"
        android:layout_width="wrap_content"
        android:layout_height="wrap_content"
        android:text="@string/status_ready"
        android:textColor="#ffffff"
        android:textSize="20sp"
        android:gravity="center"
        android:layout_marginBottom="40dp" />
    <Button
        android:id="@+id/scanButton"
        android:layout_width="wrap_content"
        android:layout_height="56dp"
        android:paddingStart="40dp"
        android:paddingEnd="40dp"
        android:text="@string/button_scan"
        android:textSize="18sp"
        android:textColor="#1a1a2e"
        android:backgroundTint="#f5a623" />
</LinearLayout>
EOF

# ===== strings.xml =====
cat > app/src/main/res/values/strings.xml << 'EOF'
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <string name="app_name">Quiz Scanner</string>
    <string name="button_scan">QR-Code scannen</string>
    <string name="scan_prompt">QR-Code in den Rahmen halten</string>
    <string name="status_ready">Bereit zum Scannen</string>
    <string name="status_scanning">Scanner wird geöffnet…</string>
    <string name="status_cancelled">Scan abgebrochen. Bitte erneut versuchen.</string>
    <string name="status_found">Öffne: %1$s</string>
    <string name="error_invalid_url">Ungültige URL: %1$s</string>
    <string name="error_no_browser">Kein Browser gefunden!</string>
</resources>
EOF

# ===== themes.xml =====
cat > app/src/main/res/values/themes.xml << 'EOF'
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <style name="Theme.QuizScanner" parent="Theme.MaterialComponents.DayNight.NoActionBar">
        <item name="colorPrimary">#f5a623</item>
        <item name="colorPrimaryVariant">#c47d00</item>
        <item name="colorOnPrimary">#1a1a2e</item>
        <item name="android:statusBarColor">#1a1a2e</item>
    </style>
</resources>
EOF

# ===== colors.xml =====
cat > app/src/main/res/values/colors.xml << 'EOF'
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="ic_launcher_background">#1a1a2e</color>
</resources>
EOF

# ===== ic_qr.xml =====
cat > app/src/main/res/drawable/ic_qr.xml << 'EOF'
<?xml version="1.0" encoding="utf-8"?>
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="120dp"
    android:height="120dp"
    android:viewportWidth="24"
    android:viewportHeight="24">
    <path android:fillColor="#f5a623"
        android:pathData="M3,3h7v7H3V3zM4.5,4.5v4h4v-4H4.5zM14,3h7v7h-7V3zM15.5,4.5v4h4v-4H15.5zM3,14h7v7H3V14zM4.5,15.5v4h4v-4H4.5zM14,14h2v2h-2v-2zM18,14h3v3h-3v-3zM16,18h2v3h-2v-3zM19,18h2v2h-2v-2zM6,6h2v2H6V6zM17,6h2v2h-2V6zM6,17h2v2H6V17z"/>
</vector>
EOF

# ===== Launcher Icons (alle Auflösungen) =====
LAUNCHER_XML='<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ic_launcher_background"/>
    <foreground android:drawable="@drawable/ic_qr"/>
</adaptive-icon>'

for dir in mipmap-hdpi mipmap-mdpi mipmap-xhdpi mipmap-xxhdpi; do
    echo "$LAUNCHER_XML" > "app/src/main/res/$dir/ic_launcher.xml"
    echo "$LAUNCHER_XML" > "app/src/main/res/$dir/ic_launcher_round.xml"
done

# ===== gradlew =====
cat > gradlew << 'EOF'
#!/usr/bin/env sh
APP_HOME="$(cd "$(dirname "$0")"; pwd)"
exec java -classpath "$APP_HOME/gradle/wrapper/gradle-wrapper.jar" \
  org.gradle.wrapper.GradleWrapperMain "$@"
EOF
chmod +x gradlew

echo "=== Projektstruktur vollständig erstellt ==="
