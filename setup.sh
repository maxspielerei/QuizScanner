#!/bin/bash
set -e

echo "=== Erstelle Projektstruktur ==="

mkdir -p app/src/main/java/com/quiz/scanner
mkdir -p app/src/main/res/layout
mkdir -p app/src/main/res/values
mkdir -p app/src/main/res/drawable
mkdir -p app/src/main/res/mipmap-anydpi-v26
mkdir -p gradle/wrapper

cat > build.gradle << 'EOF'
buildscript {
    repositories { google(); mavenCentral() }
    dependencies { classpath 'com.android.tools.build:gradle:7.4.2' }
}
allprojects {
    repositories {
        google()
        mavenCentral()
        maven { url 'https://jitpack.io' }
    }
}
task clean(type: Delete) { delete rootProject.buildDir }
EOF

cat > settings.gradle << 'EOF'
rootProject.name = "QuizScanner"
include ':app'
EOF

cat > gradle.properties << 'EOF'
org.gradle.jvmargs=-Xmx2048m -Dfile.encoding=UTF-8
android.useAndroidX=true
android.enableJetifier=true
EOF

cat > gradle/wrapper/gradle-wrapper.properties << 'EOF'
distributionBase=GRADLE_USER_HOME
distributionPath=wrapper/dists
distributionUrl=https\://services.gradle.org/distributions/gradle-7.5-bin.zip
zipStoreBase=GRADLE_USER_HOME
zipStorePath=wrapper/dists
EOF

cat > gradlew << 'EOF'
#!/usr/bin/env sh
APP_HOME="$(cd "$(dirname "$0")"; pwd)"
exec java -classpath "$APP_HOME/gradle/wrapper/gradle-wrapper.jar" \
  org.gradle.wrapper.GradleWrapperMain "$@"
EOF
chmod +x gradlew

cat > app/build.gradle << 'EOF'
plugins { id 'com.android.application' }
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
        release { minifyEnabled false }
    }
    compileOptions {
        sourceCompatibility JavaVersion.VERSION_1_8
        targetCompatibility JavaVersion.VERSION_1_8
    }
}
dependencies {
    implementation 'androidx.appcompat:appcompat:1.6.1'
    implementation 'com.github.markusfisch:BarcodeScannerView:1.6.5'
    constraints {
        implementation('org.jetbrains.kotlin:kotlin-stdlib-jdk7:1.8.22') { because 'fix duplicates' }
        implementation('org.jetbrains.kotlin:kotlin-stdlib-jdk8:1.8.22') { because 'fix duplicates' }
    }
}
EOF

cat > app/proguard-rules.pro << 'EOF'
-keep class de.markusfisch.android.barcodescannerview.** { *; }
EOF

cat > app/src/main/AndroidManifest.xml << 'EOF'
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="com.quiz.scanner">

    <uses-permission android:name="android.permission.CAMERA" />
    <uses-feature android:name="android.hardware.camera" android:required="false" />

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

# ===== MainActivity.java - basierend auf Markus Fischs Originalcode =====
cat > app/src/main/java/com/quiz/scanner/MainActivity.java << 'EOF'
package com.quiz.scanner;

import android.app.Activity;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.os.Build;
import android.os.Bundle;
import android.view.Window;
import android.view.WindowManager;
import android.widget.Toast;

import de.markusfisch.android.barcodescannerview.widget.BarcodeScannerView;

public class MainActivity extends Activity {

    private static final int REQUEST_CAMERA = 1;
    private BarcodeScannerView scannerView;
    private boolean launched = false;

    @Override
    public void onRequestPermissionsResult(
            int requestCode,
            String[] permissions,
            int[] grantResults) {
        if (requestCode == REQUEST_CAMERA &&
                grantResults.length > 0 &&
                grantResults[0] != PackageManager.PERMISSION_GRANTED) {
            Toast.makeText(this, "Kamera-Berechtigung erforderlich!",
                    Toast.LENGTH_SHORT).show();
            finish();
        }
    }

    @Override
    protected void onCreate(Bundle state) {
        super.onCreate(state);
        requestWindowFeature(Window.FEATURE_NO_TITLE);
        getWindow().addFlags(WindowManager.LayoutParams.FLAG_FULLSCREEN);
        checkPermissions();
        setContentView(R.layout.activity_main);

        scannerView = findViewById(R.id.scanner);
        scannerView.setCropRatio(.75f);

        scannerView.setOnBarcodeListener(result -> {
            // Wird im Camera-Thread aufgerufen
            if (!launched) {
                launched = true;
                String url = result.getText().trim();
                runOnUiThread(() -> {
                    Intent intent = new Intent(MainActivity.this, WebViewActivity.class);
                    intent.putExtra(WebViewActivity.EXTRA_URL, url);
                    startActivity(intent);
                });
            }
            return false; // Scannen stoppen bis Resume
        });
    }

    @Override
    public void onResume() {
        super.onResume();
        launched = false;
        scannerView.openAsync();
    }

    @Override
    public void onPause() {
        super.onPause();
        scannerView.close();
    }

    private void checkPermissions() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            String permission = android.Manifest.permission.CAMERA;
            if (checkSelfPermission(permission) != PackageManager.PERMISSION_GRANTED) {
                requestPermissions(new String[]{permission}, REQUEST_CAMERA);
            }
        }
    }
}
EOF

# ===== WebViewActivity.java =====
cat > app/src/main/java/com/quiz/scanner/WebViewActivity.java << 'EOF'
package com.quiz.scanner;

import android.annotation.SuppressLint;
import android.app.Activity;
import android.os.Bundle;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebViewClient;

public class WebViewActivity extends Activity {

    public static final String EXTRA_URL = "url";
    private WebView webView;

    @SuppressLint("SetJavaScriptEnabled")
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_webview);

        webView = findViewById(R.id.web_view);

        WebSettings s = webView.getSettings();
        s.setJavaScriptEnabled(true);
        s.setAllowFileAccess(true);
        s.setAllowFileAccessFromFileURLs(true);
        s.setAllowUniversalAccessFromFileURLs(true);
        s.setDomStorageEnabled(true);

        webView.setWebViewClient(new WebViewClient());

        String url = getIntent().getStringExtra(EXTRA_URL);
        if (url != null && !url.isEmpty()) {
            webView.loadUrl(url);
        }
    }

    @Override
    public void onBackPressed() {
        if (webView != null && webView.canGoBack()) {
            webView.goBack();
        } else {
            super.onBackPressed();
        }
    }
}
EOF

# ===== Layouts =====
cat > app/src/main/res/layout/activity_main.xml << 'EOF'
<?xml version="1.0" encoding="utf-8"?>
<FrameLayout xmlns:android="http://schemas.android.com/apk/res/android"
    android:layout_width="match_parent"
    android:layout_height="match_parent"
    android:background="#000000">

    <de.markusfisch.android.barcodescannerview.widget.BarcodeScannerView
        android:id="@+id/scanner"
        android:layout_width="match_parent"
        android:layout_height="match_parent" />

    <TextView
        android:layout_width="wrap_content"
        android:layout_height="wrap_content"
        android:layout_gravity="bottom|center_horizontal"
        android:layout_marginBottom="40dp"
        android:text="QR-Code in den Rahmen halten"
        android:textColor="#ffffff"
        android:textSize="16sp"
        android:background="#88000000"
        android:padding="12dp" />

</FrameLayout>
EOF

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

# ===== Resources =====
cat > app/src/main/res/values/strings.xml << 'EOF'
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <string name="app_name">Quiz Scanner</string>
</resources>
EOF

cat > app/src/main/res/values/themes.xml << 'EOF'
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <style name="Theme.QuizScanner" parent="Theme.AppCompat.Light.NoActionBar" />
</resources>
EOF

cat > app/src/main/res/values/colors.xml << 'EOF'
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="ic_launcher_background">#1a1a2e</color>
</resources>
EOF

cat > app/src/main/res/drawable/ic_launcher_foreground.xml << 'EOF'
<?xml version="1.0" encoding="utf-8"?>
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="108dp" android:height="108dp"
    android:viewportWidth="24" android:viewportHeight="24">
    <path android:fillColor="#f5a623"
        android:pathData="M3,3h7v7H3V3zM4.5,4.5v4h4v-4H4.5zM14,3h7v7h-7V3zM15.5,4.5v4h4v-4H15.5zM3,14h7v7H3V14zM4.5,15.5v4h4v-4H4.5zM14,14h2v2h-2v-2zM18,14h3v3h-3v-3zM16,18h2v3h-2v-3zM19,18h2v2h-2v-2zM6,6h2v2H6V6zM17,6h2v2h-2V6zM6,17h2v2H6V17z"/>
</vector>
EOF

LAUNCHER_XML='<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ic_launcher_background"/>
    <foreground android:drawable="@drawable/ic_launcher_foreground"/>
</adaptive-icon>'
echo "$LAUNCHER_XML" > app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml
echo "$LAUNCHER_XML" > app/src/main/res/mipmap-anydpi-v26/ic_launcher_round.xml

echo "=== Fertig ==="
