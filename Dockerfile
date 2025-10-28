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

# --- Final Android SDK + Flutter Path Setup ---
WORKDIR /app/android
RUN mkdir -p /app/android && \
    echo "sdk.dir=/usr/lib/android-sdk" > /app/android/local.properties && \
    echo "flutter.sdk=/usr/local/flutter" >> /app/android/local.properties && \
    cat /app/android/local.properties

# --- Gradle Configuration Safe Path ---
RUN mkdir -p /home/builder/.gradle && \
    echo "org.gradle.daemon=false" >> /home/builder/.gradle/gradle.properties && \
    echo "org.gradle.parallel=true" >> /home/builder/.gradle/gradle.properties && \
    echo "org.gradle.caching=true" >> /home/builder/.gradle/gradle.properties

# --- Set Gradle Environment Variables ---
ENV GRADLE_USER_HOME=/home/builder/.gradle
ENV JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64

# --- Verify ---
RUN echo "=== VERIFY android/local.properties ===" && ls -la /app/android && \
    echo "File content:" && cat /app/android/local.properties && \
    echo "Gradle Home: $GRADLE_USER_HOME" && pwd

# --- Build APK from android/app directory (correct path) ---
WORKDIR /app/android/app
RUN flutter clean && flutter pub get && flutter build apk --debug --no-shrink

# --- Copy APK for Download ---
WORKDIR /app
RUN mkdir -p /app/build/app/outputs/flutter-apk && \
    cp /app/android/app/build/outputs/flutter-apk/app-debug.apk /app/app-debug.apk || true

CMD ["bash"]
