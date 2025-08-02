#!/bin/bash

# Batocera AI Build and Run Script
# This script builds the Batocera image with LLM integration and runs it in QEMU

set -e  # Exit on any error

echo "🚀 Batocera AI Build and Run Script"
echo "=================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if we're in the right directory
if [ ! -f "Makefile" ]; then
    print_error "Please run this script from the batocera.AI.linux directory"
    exit 1
fi

# Step 1: Build the image
print_status "Step 1: Building Batocera x86_64 image..."
print_warning "This will take 10-15 minutes on first run, faster on subsequent runs"
echo

make x86_64-build

if [ $? -ne 0 ]; then
    print_error "Build failed!"
    exit 1
fi

print_success "Build completed successfully!"

# Step 2: Navigate to image directory
print_status "Step 2: Locating and extracting image..."
cd output/x86_64/images/batocera/images/x86_64

# Find the compressed image file dynamically
COMPRESSED_IMAGE=$(ls batocera-x86_64-42-*.img.gz 2>/dev/null | head -1)

if [ -z "$COMPRESSED_IMAGE" ]; then
    print_error "No compressed image file found!"
    print_error "Expected pattern: batocera-x86_64-42-*.img.gz"
    ls -la *.img.gz 2>/dev/null || echo "No .img.gz files found"
    exit 1
fi

print_status "Found image: $COMPRESSED_IMAGE"

# Step 3: Extract the image
print_status "Step 3: Extracting compressed image..."
gunzip -f "$COMPRESSED_IMAGE"

if [ $? -ne 0 ]; then
    print_error "Failed to extract image!"
    exit 1
fi

# Get the uncompressed image name
IMAGE_FILE="${COMPRESSED_IMAGE%.gz}"

print_success "Image extracted successfully!"

# Step 4: Resize the image
print_status "Step 4: Resizing image to 64GB for more storage..."
qemu-img resize "$IMAGE_FILE" 64G

if [ $? -ne 0 ]; then
    print_error "Failed to resize image!"
    exit 1
fi

print_success "Image resized to 64GB!"

# Step 5: Check image size
print_status "Step 5: Verifying image..."
ls -lh "$IMAGE_FILE"