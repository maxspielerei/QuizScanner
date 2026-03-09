#!/bin/bash
set -e

echo "=== Erstelle Projektstruktur ==="

mkdir -p app/src/main/java/com/quiz/scanner
mkdir -p app/src/main/res/layout
mkdir -p app/src/main/res/values
mkdir -p app/src/main/res/drawable
mkdir -p app/src/main/res/mipmap-anydpi-v26
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
        maven { url 'https://jitpack.io' }
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

# ===== gradlew =====
cat > gradlew << 'EOF'
#!/usr/bin/env sh
APP_HOME="$(cd "$(dirname "$0")"; pwd)"
exec java -classpath "$APP_HOME/gradle/wrapper/gradle-wrapper.jar" \
  org.gradle.wrapper.GradleWrapperMain "$@"
EOF
chmod +x gradlew

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
    implementation 'com.github.markusfisch:BarcodeScannerView:1.6.5'
    constraints {
        implementation('org.jetbrains.kotlin:kotlin-stdlib-jdk7:1.8.22') { because 'fix duplicate kotlin classes' }
        implementation('org.jetbrains.kotlin:kotlin-stdlib-jdk8:1.8.22') { because 'fix duplicate kotlin classes' }
    }
}
EOF

# ===== app/proguard-rules.pro =====
cat > app/proguard-rules.pro << 'EOF'
-keep class de.markusfisch.android.barcodescannerview.** { *; }
-keep class com.google.zxing.** { *; }
EOF

# ===== AndroidManifest.xml =====
cat > app/src/main/AndroidManifest.xml << 'EOF'
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="com.quiz.scanner">

    <uses-permission android:name="android.permission.CAMERA" />
    <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
    <uses-feature android:name="android.hardware.camera" android:required="true" />

    <application
        android:allowBackup="true"
        android:icon="@mipmap/ic_launcher"
        android:label="@string/app_name"
        android:roundIcon="@mipmap/ic_launcher"
        android:supportsRtl="true"
        android:theme="@style/Theme.QuizScanner">

        <activity
            android:name=".MainActivity"
            android:exported="true"
            android:screenOrientation="fullSensor">
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LAUNCHER" />
            </intent-filter>
        </activity>

        <activity
            android:name=".WebViewActivity"
            android:exported="false"
            android:screenOrientation="fullSensor" />

    </application>
</manifest>
EOF

# ===== MainActivity.java =====
cat > app/src/main/java/com/quiz/scanner/MainActivity.java << 'EOF'
package com.quiz.scanner;

import android.Manifest;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.os.Bundle;
import android.widget.Toast;

import androidx.annotation.NonNull;
import androidx.appcompat.app.AppCompatActivity;
import androidx.core.app.ActivityCompat;
import androidx.core.content.ContextCompat;

import de.markusfisch.android.barcodescannerview.widget.BarcodeScannerView;

public class MainActivity extends AppCompatActivity {

    private static final int CAMERA_PERMISSION_REQUEST = 100;
    private BarcodeScannerView scannerView;
    private boolean resultHandled = false;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);

        scannerView = findViewById(R.id.barcode_scanner_view);

        scannerView.setOnScanListener(barcode -> {
            if (resultHandled) return;
            resultHandled = true;

            String url = barcode.toString().trim();
            Intent intent = new Intent(MainActivity.this, WebViewActivity.class);
            intent.putExtra(WebViewActivity.EXTRA_URL, url);
            startActivity(intent);
        });

        if (ContextCompat.checkSelfPermission(this, Manifest.permission.CAMERA)
                != PackageManager.PERMISSION_GRANTED) {
            ActivityCompat.requestPermissions(this,
                    new String[]{Manifest.permission.CAMERA},
                    CAMERA_PERMISSION_REQUEST);
        }
    }

    @Override
    protected void onResume() {
        super.onResume();
        resultHandled = false;
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.CAMERA)
                == PackageManager.PERMISSION_GRANTED) {
            scannerView.openAsync(this);
        }
    }

    @Override
    protected void onPause() {
        super.onPause();
        scannerView.close();
    }

    @Override
    public void onRequestPermissionsResult(int requestCode,
            @NonNull String[] permissions, @NonNull int[] grantResults) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults);
        if (requestCode == CAMERA_PERMISSION_REQUEST) {
            if (grantResults.length > 0 && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
                scannerView.openAsync(this);
            } else {
                Toast.makeText(this, "Kamera-Berechtigung erforderlich!", Toast.LENGTH_LONG).show();
            }
        }
    }
}
EOF

# ===== WebViewActivity.java =====
cat > app/src/main/java/com/quiz/scanner/WebViewActivity.java << 'EOF'
package com.quiz.scanner;

import android.annotation.SuppressLint;
import android.os.Bundle;
import android.webkit.WebResourceRequest;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebViewClient;

import androidx.appcompat.app.AppCompatActivity;

public class WebViewActivity extends AppCompatActivity {

    public static final String EXTRA_URL = "url";

    private WebView webView;

    @SuppressLint("SetJavaScriptEnabled")
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_webview);

        webView = findViewById(R.id.web_view);

        WebSettings settings = webView.getSettings();
        settings.setJavaScriptEnabled(true);
        settings.setAllowFileAccess(true);
        settings.setAllowFileAccessFromFileURLs(true);
        settings.setAllowUniversalAccessFromFileURLs(true);
        settings.setDomStorageEnabled(true);

        webView.setWebViewClient(new WebViewClient() {
            @Override
            public boolean shouldOverrideUrlLoading(WebView view, WebResourceRequest request) {
                return false;
            }
        });

        String url = getIntent().getStringExtra(EXTRA_URL);
        if (url != null && !url.isEmpty()) {
            webView.loadUrl(url);
        }
    }

    @Override
    public void onBackPressed() {
        if (webView.canGoBack()) {
            webView.goBack();
        } else {
            super.onBackPressed();
        }
    }
}
EOF

# ===== activity_main.xml =====
cat > app/src/main/res/layout/activity_main.xml << 'EOF'
<?xml version="1.0" encoding="utf-8"?>
<FrameLayout xmlns:android="http://schemas.android.com/apk/res/android"
    android:layout_width="match_parent"
    android:layout_height="match_parent"
    android:background="#000000">

    <de.markusfisch.android.barcodescannerview.widget.BarcodeScannerView
        android:id="@+id/barcode_scanner_view"
        android:layout_width="match_parent"
        android:layout_height="match_parent" />

    <TextView
        android:layout_width="wrap_content"
        android:layout_height="wrap_content"
        android:layout_gravity="bottom|center_horizontal"
        android:layout_marginBottom="40dp"
        android:text="@string/scan_hint"
        android:textColor="#ffffff"
        android:textSize="16sp"
        android:background="#88000000"
        android:padding="12dp" />

</FrameLayout>
EOF

# ===== activity_webview.xml =====
cat > app/src/main/res/layout/activity_webview.xml << 'EOF'
<?xml version="1.0" encoding="utf-8"?>
<FrameLayout xmlns:android="http://schemas.android.com/apk/res/android"
    android:layout_width="match_parent"
    android:layout_height="match_parent">

    <WebView
        android:id="@+id/web_view"
        android:layout_width="match_parent"
        android:layout_height="match_parent" />

</FrameLayout>
EOF

# ===== strings.xml =====
cat > app/src/main/res/values/strings.xml << 'EOF'
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <string name="app_name">Quiz Scanner</string>
    <string name="scan_hint">QR-Code in den Rahmen halten</string>
</resources>
EOF

# ===== themes.xml =====
cat > app/src/main/res/values/themes.xml << 'EOF'
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <style name="Theme.QuizScanner" parent="Theme.AppCompat.Light.NoActionBar">
        <item name="colorPrimary">#f5a623</item>
        <item name="android:statusBarColor">#000000</item>
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

# ===== ic_launcher Drawable =====
cat > app/src/main/res/drawable/ic_launcher_foreground.xml << 'EOF'
<?xml version="1.0" encoding="utf-8"?>
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="108dp"
    android:height="108dp"
    android:viewportWidth="24"
    android:viewportHeight="24">
    <path android:fillColor="#f5a623"
        android:pathData="M3,3h7v7H3V3zM4.5,4.5v4h4v-4H4.5zM14,3h7v7h-7V3zM15.5,4.5v4h4v-4H15.5zM3,14h7v7H3V14zM4.5,15.5v4h4v-4H4.5zM14,14h2v2h-2v-2zM18,14h3v3h-3v-3zM16,18h2v3h-2v-3zM19,18h2v2h-2v-2zM6,6h2v2H6V6zM17,6h2v2h-2V6zM6,17h2v2H6V17z"/>
</vector>
EOF

# ===== Adaptive Icon =====
LAUNCHER_XML='<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ic_launcher_background"/>
    <foreground android:drawable="@drawable/ic_launcher_foreground"/>
</adaptive-icon>'
echo "$LAUNCHER_XML" > app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml
echo "$LAUNCHER_XML" > app/src/main/res/mipmap-anydpi-v26/ic_launcher_round.xml

echo "=== Fertig ==="
