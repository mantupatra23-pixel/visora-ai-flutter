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

# --- Android config ---
RUN mkdir -p android && echo "sdk.dir=/usr/lib/android-sdk" > android/local.properties

# --- Clean and get packages ---
RUN flutter clean
RUN flutter pub get

# --- Create builder user and fix permissions ---
RUN useradd -m builder && chown -R builder:builder /app /usr/local/flutter

# --- Switch to builder user ---
USER builder
WORKDIR /app

# 🧩 Fix Git ownership for builder user (the real fix)
RUN git config --global --add safe.directory /usr/local/flutter

# --- Build Debug APK ---
RUN flutter build apk --debug

# --- Switch back to root for copying APK ---
USER root
RUN cp /app/build/app/outputs/flutter-apk/app-debug.apk /app/app-debug.apk || true

CMD ["bash"]
