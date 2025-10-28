FROM ubuntu:22.04
WORKDIR /app

# --- System setup ---
RUN sed -i 's|http://archive.ubuntu.com|http://mirror.leaseweb.com|g' /etc/apt/sources.list && \
    sed -i 's|http://security.ubuntu.com|http://mirror.leaseweb.com|g' /etc/apt/sources.list

RUN apt-get update && apt-get install -y \
  git curl unzip xz-utils zip libglu1-mesa openjdk-17-jdk sudo

# --- Android SDK setup ---
RUN mkdir -p /usr/lib/android-sdk/cmdline-tools && \
    cd /usr/lib/android-sdk/cmdline-tools && \
    curl -o sdk-tools.zip https://dl.google.com/android/repository/commandlinetools-linux-9477386_latest.zip && \
    unzip sdk-tools.zip && rm sdk-tools.zip && \
    mv cmdline-tools latest

ENV ANDROID_HOME=/usr/lib/android-sdk
ENV PATH=$PATH:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:/usr/local/flutter/bin

RUN yes | sdkmanager --licenses || true
RUN sdkmanager --install "platform-tools" "platforms;android-34" "build-tools;34.0.0"

# --- Flutter setup ---
RUN git clone https://github.com/flutter/flutter.git -b stable /usr/local/flutter
ENV PATH="/usr/local/flutter/bin:/usr/local/flutter/bin/cache/dart-sdk/bin:${PATH}"
RUN flutter doctor -v

# --- Copy project ---
COPY . .

# --- Android SDK path ---
RUN mkdir -p android && echo "sdk.dir=/usr/lib/android-sdk" > android/local.properties

# --- Clean and install dependencies ---
RUN flutter clean
RUN flutter pub get

# --- Add non-root user ---
RUN useradd -m builder && chown -R builder:builder /app /usr/local/flutter
USER builder
WORKDIR /app
RUN git config --global --add safe.directory /usr/local/flutter

# --- Fix missing local.properties path ---
RUN echo "sdk.dir=/usr/lib/android-sdk" > android/local.properties

# --- Fix Gradle + Flutter Build ---
RUN cat > android/app/build.gradle <<'EOF'
def localProperties = new Properties()
def localPropertiesFile = rootProject.file('local.properties')
if (localPropertiesFile.exists()) {
    localPropertiesFile.withReader('UTF-8') { reader -> localProperties.load(reader) }
}

def flutterRoot = localProperties.getProperty('flutter.sdk')
if (flutterRoot == null) {
    throw new GradleException("Flutter SDK not found. Define location with flutter.sdk in local.properties.")
}

apply plugin: 'com.android.application'
apply plugin: 'kotlin-android'
apply from: "${flutterRoot}/packages/flutter_tools/gradle/flutter.gradle"

android {
    namespace "com.visora.ai"
    compileSdkVersion 34

    defaultConfig {
        applicationId "com.visora.ai"
        minSdkVersion 21
        targetSdkVersion 34
        versionCode 1
        versionName "1.0"
        multiDexEnabled true
    }

    buildTypes {
        debug {
            debuggable true
        }
        release {
            minifyEnabled false
            shrinkResources false
            signingConfig signingConfigs.debug
        }
    }

    compileOptions {
        sourceCompatibility JavaVersion.VERSION_17
        targetCompatibility JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }
}

flutter {
    source = "/usr/local/flutter"
}

dependencies {
    implementation "org.jetbrains.kotlin:kotlin-stdlib-jdk7:\$kotlin_version"
}
EOF

# --- Clear Gradle cache and rebuild ---
RUN rm -rf /app/.gradle /app/build /root/.gradle || true
RUN flutter clean
RUN flutter pub get

# --- Network Optimization ---
ENV GRADLE_OPTS="-Dorg.gradle.jvmargs=-Xmx4g -Dorg.gradle.internal.http.socketTimeout=120000 -Dorg.gradle.internal.http.connectionTimeout=120000"
RUN flutter doctor --android-licenses || true

# --- Auto-generate Gradle Wrapper in Cloud (Stable Version) ---
USER root
WORKDIR /app/android

# ensure build.gradle exists before wrapper
RUN if [ -f "build.gradle" ]; then echo "Gradle file found ✅"; else echo "apply plugin: 'com.android.application'" > build.gradle; fi

# recheck JAVA + SDK environment
ENV JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
ENV ANDROID_SDK_ROOT=/usr/lib/android-sdk
ENV PATH="$PATH:$ANDROID_SDK_ROOT/cmdline-tools/latest/bin:$ANDROID_SDK_ROOT/platform-tools"

# now run wrapper safely
RUN gradle wrapper --gradle-version 7.5.1 --distribution-type all || true

# give execute permission
RUN chmod +x gradlew || true

USER builder
WORKDIR /app/android

# --- Build APK (cloud only) ---
RUN flutter clean && flutter pub get && ./gradlew assembleDebug || flutter build apk --debug --no-shrink

# --- Copy APK for Download ---
WORKDIR /app
RUN mkdir -p /app/build/app/outputs/flutter-apk && \
    cp /app/android/app/build/outputs/apk/debug/app-debug.apk /app/app-debug.apk || true

CMD ["bash"]
