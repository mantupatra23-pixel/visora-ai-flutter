# Use Ubuntu as base
FROM ubuntu:22.04

# Set working directory
WORKDIR /app

# Install dependencies
RUN apt-get update && apt-get install -y \
  git curl unzip xz-utils zip libglu1-mesa

# Install Flutter (latest stable)
RUN git clone https://github.com/flutter/flutter.git -b stable /usr/local/flutter

# Add flutter to PATH
ENV PATH="/usr/local/flutter/bin:/usr/local/flutter/bin/cache/dart-sdk/bin:${PATH}"

# Pre-download Dart dependencies
RUN flutter doctor -v

# Copy project files
COPY . .

# Get dependencies
RUN flutter pub get

# Build APK
RUN flutter build apk --release

# Default command
CMD ["bash"]
