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
    source '../..'
}

dependencies {
    implementation "org.jetbrains.kotlin:kotlin-stdlib-jdk7:\$kotlin_version"
}
EOF

# --- Gradle Download Retry + Build ---
ENV GRADLE_OPTS="-Dorg.gradle.jvmargs=-Xmx4g -Dorg.gradle.internal.http.socketTimeout=60000 -Dorg.gradle.internal.http.connectionTimeout=60000"
RUN flutter build apk --debug --no-shrink

# --- Use Gradle mirror + retry ---
RUN mkdir -p /root/.gradle && echo "systemProp.gradle.internal.repository.max.retries=5" >> /root/.gradle/gradle.properties && \
    echo "systemProp.gradle.internal.repository.retry.wait=5" >> /root/.gradle/gradle.properties && \
    echo "systemProp.gradle.internal.http.socketTimeout=120000" >> /root/.gradle/gradle.properties && \
    echo "systemProp.gradle.internal.http.connectionTimeout=120000" >> /root/.gradle/gradle.properties && \
    echo "org.gradle.caching=true" >> /root/.gradle/gradle.properties && \
    echo "org.gradle.daemon=false" >> /root/.gradle/gradle.properties && \
    echo "org.gradle.parallel=true" >> /root/.gradle/gradle.properties

# --- Build APK ---
RUN flutter build apk --debug --no-shrink

# --- Switch back to root and copy APK ---
USER root
RUN cp /app/build/app/outputs/flutter-apk/app-debug.apk /app/app-debug.apk || true

CMD ["bash"]
