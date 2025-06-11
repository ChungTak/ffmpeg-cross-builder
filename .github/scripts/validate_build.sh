#!/bin/bash

# Rockchip MPP Build Validation Script
# This script validates the build output to ensure all required files are present

set -e

TARGET="$1"
OUTPUT_DIR="$2"

if [ -z "$TARGET" ] || [ -z "$OUTPUT_DIR" ]; then
    echo "Usage: $0 <target> <output_dir>"
    exit 1
fi

echo "Validating build for target: $TARGET"
echo "Output directory: $OUTPUT_DIR"

# Check if output directory exists
if [ ! -d "$OUTPUT_DIR" ]; then
    echo "ERROR: Output directory does not exist: $OUTPUT_DIR"
    exit 1
fi

# Required directories
REQUIRED_DIRS=("include" "lib")
OPTIONAL_DIRS=("pkgconfig" "bin")

echo "Checking required directories..."
for dir in "${REQUIRED_DIRS[@]}"; do
    if [ ! -d "$OUTPUT_DIR/$dir" ]; then
        echo "ERROR: Required directory missing: $dir"
        exit 1
    fi
    echo "✓ Found: $dir"
done

echo "Checking optional directories..."
for dir in "${OPTIONAL_DIRS[@]}"; do
    if [ -d "$OUTPUT_DIR/$dir" ]; then
        echo "✓ Found: $dir"
    else
        echo "- Missing (optional): $dir"
    fi
done

# Check for header files
echo "Checking for header files..."
HEADER_COUNT=$(find "$OUTPUT_DIR/include" -name "*.h" | wc -l)
if [ "$HEADER_COUNT" -eq 0 ]; then
    echo "ERROR: No header files found in include directory"
    exit 1
fi
echo "✓ Found $HEADER_COUNT header files"

# Check for library files
echo "Checking for library files..."
LIB_COUNT=0

# Check for different library types based on target
case "$TARGET" in
    *-windows-*)
        LIB_COUNT=$(find "$OUTPUT_DIR/lib" -name "*.lib" -o -name "*.dll" -o -name "*.a" | wc -l)
        ;;
    *-macos*)
        LIB_COUNT=$(find "$OUTPUT_DIR/lib" -name "*.a" -o -name "*.dylib" | wc -l)
        ;;
    *)
        LIB_COUNT=$(find "$OUTPUT_DIR/lib" -name "*.a" -o -name "*.so*" | wc -l)
        ;;
esac

if [ "$LIB_COUNT" -eq 0 ]; then
    echo "ERROR: No library files found in lib directory"
    exit 1
fi
echo "✓ Found $LIB_COUNT library files"

# List all files for debugging
echo "Build output contents:"
find "$OUTPUT_DIR" -type f | head -20
if [ $(find "$OUTPUT_DIR" -type f | wc -l) -gt 20 ]; then
    echo "... and $(( $(find "$OUTPUT_DIR" -type f | wc -l) - 20 )) more files"
fi

# Calculate total size
TOTAL_SIZE=$(du -sh "$OUTPUT_DIR" | cut -f1)
echo "Total build size: $TOTAL_SIZE"

echo "✓ Build validation successful for $TARGET"
