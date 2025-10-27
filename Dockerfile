# Base image
FROM ubuntu:22.04

# Set working directory
WORKDIR /app

# Install dependencies
RUN apt-get update && apt-get install -y \
  git curl unzip xz-utils zip libglu1-mesa openjdk-17-jdk

# Install Android SDK
RUN mkdir -p /usr/lib/android-sdk/cmdline-tools && \
    cd /usr/lib/android-sdk/cmdline-tools && \
    curl -o sdk-tools.zip https://dl.google.com/android/repository/commandlinetools-linux-9477386_latest.zip && \
    unzip sdk-tools.zip && rm sdk-tools.zip && \
    mv cmdline-tools latest

# Set environment variables
ENV ANDROID_HOME=/usr/lib/android-sdk
ENV PATH=$PATH:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:/usr/local/flutter/bin

# Accept licenses & install build tools
RUN yes | sdkmanager --licenses || true
RUN sdkmanager --install "platform-tools" "platforms;android-34" "build-tools;34.0.0"

# Install Flutter
RUN git clone https://github.com/flutter/flutter.git -b stable /usr/local/flutter
ENV PATH="/usr/local/flutter/bin:/usr/local/flutter/bin/cache/dart-sdk/bin:${PATH}"

# Pre-download dependencies
RUN flutter doctor -v

# Copy project files
COPY . .

# Get dependencies
RUN flutter pub get

# Build release APK
RUN flutter build apk --release --no-sound-null-safety

# Default command
CMD ["bash"]
