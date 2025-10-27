FROM ubuntu:22.04
WORKDIR /app

# --- System setup ---
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

# --- Android SDK Path ---
RUN mkdir -p android && echo "sdk.dir=/usr/lib/android-sdk" > android/local.properties

# --- Flutter clean & dependencies ---
RUN flutter clean
RUN flutter pub get

# --- Create non-root user ---
RUN useradd -m builder && chown -R builder:builder /app /usr/local/flutter
USER builder
WORKDIR /app
RUN git config --global --add safe.directory /usr/local/flutter

# ✅ Overwrite build.gradle with clean valid config
RUN echo '\
def localProperties = new Properties()\n\
def localPropertiesFile = rootProject.file("local.properties")\n\
if (localPropertiesFile.exists()) {\n\
    localPropertiesFile.withReader("UTF-8") { reader -> localProperties.load(reader) }\n\
}\n\
\n\
def flutterRoot = localProperties.getProperty("flutter.sdk")\n\
if (flutterRoot == null) {\n\
    throw new GradleException("Flutter SDK not found. Define location with flutter.sdk in the local.properties file.")\n\
}\n\
\n\
apply plugin: "com.android.application"\n\
apply plugin: "kotlin-android"\n\
apply from: "$flutterRoot/packages/flutter_tools/gradle/flutter.gradle"\n\
\n\
android {\n\
    compileSdkVersion 34\n\
\n\
    defaultConfig {\n\
        applicationId "com.visora.ai"\n\
        minSdkVersion 21\n\
        targetSdkVersion 34\n\
        versionCode 1\n\
        versionName "1.0"\n\
        multiDexEnabled true\n\
    }\n\
\n\
    buildTypes {\n\
        debug {\n\
            debuggable true\n\
        }\n\
    }\n\
}\n\
\n\
flutter {\n\
    source "../.."\n\
}\n\
' > android/app/build.gradle

# --- Build APK ---
RUN flutter build apk --debug --no-shrink

# --- Switch back to root and copy APK ---
USER root
RUN cp /app/build/app/outputs/flutter-apk/app-debug.apk /app/app-debug.apk || true

CMD ["bash"]
