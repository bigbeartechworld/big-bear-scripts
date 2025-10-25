#!/usr/bin/env bash

# Test script for favicon generator
# This script tests the various features and edge cases

echo "========================================="
echo "  Favicon Generator - Test Suite"
echo "========================================="
echo ""

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
FAVICON_SCRIPT="$SCRIPT_DIR/run.sh"

# Check if script exists
if [ ! -f "$FAVICON_SCRIPT" ]; then
    echo "❌ Error: run.sh not found in $SCRIPT_DIR"
    exit 1
fi

echo "Testing script: $FAVICON_SCRIPT"
echo ""

# Test 1: No arguments (should show help)
echo "Test 1: Running without arguments (expect help message)..."
echo "-----------------------------------------------------------"
bash "$FAVICON_SCRIPT"
EXIT_CODE=$?
if [ $EXIT_CODE -eq 1 ]; then
    echo "✅ Test 1 passed: Script correctly shows error when no arguments provided"
else
    echo "❌ Test 1 failed: Unexpected exit code $EXIT_CODE"
fi
echo ""

# Test 2: Non-existent file
echo "Test 2: Running with non-existent file (expect error)..."
echo "-----------------------------------------------------------"
bash "$FAVICON_SCRIPT" "nonexistent.png" 2>&1 | head -20
EXIT_CODE=$?
if [ $EXIT_CODE -eq 1 ]; then
    echo "✅ Test 2 passed: Script correctly handles non-existent file"
else
    echo "❌ Test 2 failed: Unexpected exit code $EXIT_CODE"
fi
echo ""

# Test 3: Check if ImageMagick is installed
echo "Test 3: Checking ImageMagick installation..."
echo "-----------------------------------------------------------"
if command -v magick &> /dev/null; then
    echo "✅ ImageMagick 7+ found (magick command)"
    IMAGEMAGICK_INSTALLED=true
    MAGICK_VERSION=$(magick --version | head -1)
    echo "   Version: $MAGICK_VERSION"
elif command -v convert &> /dev/null; then
    echo "✅ ImageMagick 6 found (convert command)"
    IMAGEMAGICK_INSTALLED=true
    CONVERT_VERSION=$(convert --version | head -1)
    echo "   Version: $CONVERT_VERSION"
else
    echo "❌ ImageMagick is not installed"
    echo "   Install with: brew install imagemagick (macOS)"
    echo "                sudo apt-get install imagemagick (Ubuntu/Debian)"
    IMAGEMAGICK_INSTALLED=false
fi
echo ""

# If ImageMagick is installed, run full test
if [ "$IMAGEMAGICK_INSTALLED" = true ]; then
    echo "========================================="
    echo "  Running Full Functionality Tests"
    echo "========================================="
    echo ""
    
    # Test 4: Generate favicons with test image
    if [ -f "$SCRIPT_DIR/images/logo.png" ]; then
        echo "Test 4: Generating favicons from test image..."
        echo "-----------------------------------------------------------"
        
        # Create temp directory for output
        TEST_OUTPUT=$(mktemp -d)
        echo "Output directory: $TEST_OUTPUT"
        echo ""
        
        # Run the script
        bash "$FAVICON_SCRIPT" "$SCRIPT_DIR/images/logo.png" "$TEST_OUTPUT"
        EXIT_CODE=$?
        
        if [ $EXIT_CODE -eq 0 ]; then
            echo ""
            echo "Checking generated files..."
            
            EXPECTED_FILES=(
                "favicon.ico"
                "favicon-16x16.png"
                "favicon-32x32.png"
                "apple-touch-icon.png"
                "android-chrome-192x192.png"
                "android-chrome-512x512.png"
                "site.webmanifest"
            )
            
            ALL_FILES_PRESENT=true
            for file in "${EXPECTED_FILES[@]}"; do
                if [ -f "$TEST_OUTPUT/$file" ]; then
                    FILE_SIZE=$(ls -lh "$TEST_OUTPUT/$file" | awk '{print $5}')
                    echo "  ✅ $file ($FILE_SIZE)"
                else
                    echo "  ❌ $file (missing)"
                    ALL_FILES_PRESENT=false
                fi
            done
            
            if [ "$ALL_FILES_PRESENT" = true ]; then
                echo ""
                echo "✅ Test 4 passed: All favicon files generated successfully"
                echo ""
                echo "Generated files are in: $TEST_OUTPUT"
                echo "You can inspect them manually if needed"
                echo ""
                
                # Verify ICO file structure
                if command -v magick &> /dev/null; then
                    echo "Verifying ICO file structure..."
                    magick identify "$TEST_OUTPUT/favicon.ico" 2>&1 | grep -E "\.ico\[" || true
                fi
            else
                echo ""
                echo "❌ Test 4 failed: Some files missing"
            fi
        else
            echo "❌ Test 4 failed: Script exited with code $EXIT_CODE"
        fi
        
        # Clean up option
        echo ""
        read -r -p "Delete test output directory? (y/N): " cleanup
        if [[ $cleanup =~ ^[Yy]$ ]]; then
            rm -rf "$TEST_OUTPUT"
            echo "✅ Test output cleaned up"
        else
            echo "ℹ️  Test output kept at: $TEST_OUTPUT"
        fi
        
    else
        echo "⚠️  Test image not found: $SCRIPT_DIR/images/logo.png"
        echo "   Skipping full functionality test"
    fi
else
    echo "========================================="
    echo "  Skipping Full Tests"
    echo "========================================="
    echo ""
    echo "To run full tests, install ImageMagick:"
    echo ""
    echo "macOS:              brew install imagemagick"
    echo "Ubuntu/Debian:      sudo apt-get install imagemagick"
    echo "CentOS/RHEL:        sudo yum install ImageMagick"
    echo "Arch Linux:         sudo pacman -S imagemagick"
fi

echo ""
echo "========================================="
echo "  Test Suite Complete"
echo "========================================="
