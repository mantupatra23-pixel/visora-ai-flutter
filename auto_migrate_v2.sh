#!/bin/bash
echo "🚀 Starting Visora AI Android Auto-Migration Patch..."

# ✅ Step 1: Ensure correct Gradle and Kotlin versions
echo "🔧 Updating android/build.gradle..."
sed -i '/classpath "org.jetbrains.kotlin:kotlin-gradle-plugin/c\        classpath "org.jetbrains.kotlin:kotlin-gradle-plugin:1.9.25"' android/build.gradle
sed -i '/classpath "com.android.tools.build:gradle/c\        classpath "com.android.tools.build:gradle:8.5.2"' android/build.gradle

# ✅ Step 2: Set SDK versions
echo "📱 Updating SDK configs..."
grep -q "flutter.compileSdkVersion" android/gradle.properties || echo -e "\nflutter.minSdkVersion=23\nflutter.targetSdkVersion=35\nflutter.compileSdkVersion=35" >> android/gradle.properties

# ✅ Step 3: Create/replace MainActivity.kt with V2 embedding
echo "⚙️ Creating MainActivity.kt..."
mkdir -p android/app/src/main/kotlin/com/example/visora_ai_flutter
cat > android/app/src/main/kotlin/com/example/visora_ai_flutter/MainActivity.kt <<EOL
package com.example.visora_ai_flutter

import io.flutter.embedding.android.FlutterActivity

class MainActivity: FlutterActivity() {
}
EOL

# ✅ Step 4: Clean up V1 activity in Manifest if any
echo "🧹 Cleaning AndroidManifest.xml..."
sed -i '/<activity/,/<\/activity>/d' android/app/src/main/AndroidManifest.xml

# ✅ Step 5: Flutter clean + pub get
echo "🧽 Running flutter clean & pub get..."
flutter clean
flutter pub get

echo "✅ Migration Complete: Android V2 embedding + Gradle ready!"
