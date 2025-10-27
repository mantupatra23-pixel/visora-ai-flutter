# Use a Flutter-ready base image
FROM cirrusci/flutter:stable

# Set working directory
WORKDIR /app

# Copy your Flutter project into the container
COPY . .

# Get dependencies
RUN flutter pub get

# Build APK in release mode
RUN flutter build apk --release

# Default command
CMD ["bash"]
