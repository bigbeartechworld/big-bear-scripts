#!/usr/bin/env bash

# Function to print headers
print_header() {
    echo "========================================="
    echo "  $1"
    echo "========================================="
}

# Function to print status messages
print_status() {
    echo "✅ $1"
}

# Function to print error messages
print_error() {
    echo "❌ $1"
}

# Function to print warning messages
print_warning() {
    echo "⚠️  $1"
}

# Display Welcome
print_header "Big Bear Favicon Generator V1.0.0"
echo "Generate favicons from any image (PNG, SVG, JPG, etc.)"
echo ""
echo "Here are some links:"
echo "https://community.bigbeartechworld.com"
echo "https://github.com/BigBearTechWorld"
echo ""
echo "If you would like to support me, please consider buying me a tea:"
echo "https://ko-fi.com/bigbeartechworld"
echo ""

# Check if ImageMagick is installed
if ! command -v magick &> /dev/null && ! command -v convert &> /dev/null; then
    print_error "ImageMagick is not installed!"
    echo ""
    echo "Please install ImageMagick:"
    echo "  • macOS: brew install imagemagick"
    echo "  • Ubuntu/Debian: sudo apt-get install imagemagick"
    echo "  • CentOS/RHEL: sudo yum install ImageMagick"
    echo "  • Arch: sudo pacman -S imagemagick"
    exit 1
fi

# Determine which ImageMagick command to use
if command -v magick &> /dev/null; then
    MAGICK_CMD="magick"
    print_status "Found ImageMagick 7+ (magick command)"
else
    MAGICK_CMD="convert"
    print_status "Found ImageMagick 6 (convert command)"
fi

# Check for input file
if [ $# -eq 0 ]; then
    echo "Usage: $0 <input-image> [output-directory]"
    echo ""
    echo "Supported formats: PNG, JPG, JPEG, SVG, BMP, GIF, TIFF, WEBP"
    echo ""
    echo "Examples:"
    echo "  $0 logo.png"
    echo "  $0 logo.svg ./output"
    echo "  $0 ~/Desktop/icon.jpg /var/www/html"
    exit 1
fi

INPUT_FILE="$1"
OUTPUT_DIR="${2:-.}"

# Check if input file exists
if [ ! -f "$INPUT_FILE" ]; then
    print_error "Input file not found: $INPUT_FILE"
    exit 1
fi

# Get the file extension
FILE_EXT="${INPUT_FILE##*.}"
FILE_EXT_LOWER=$(echo "$FILE_EXT" | tr '[:upper:]' '[:lower:]')

# Validate file format
SUPPORTED_FORMATS="png jpg jpeg svg bmp gif tiff tif webp"
if [[ ! " $SUPPORTED_FORMATS " =~ " $FILE_EXT_LOWER " ]]; then
    print_error "Unsupported file format: .$FILE_EXT"
    echo "Supported formats: PNG, JPG, JPEG, SVG, BMP, GIF, TIFF, WEBP"
    exit 1
fi

print_status "Input file: $INPUT_FILE"
print_status "Output directory: $OUTPUT_DIR"

# Create output directory if it doesn't exist
mkdir -p "$OUTPUT_DIR"

# Temporary working directory
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

print_header "Processing Image"

# For SVG files, we need special handling
if [ "$FILE_EXT_LOWER" = "svg" ]; then
    print_status "Converting SVG to PNG at high resolution..."
    # Convert SVG to high-res PNG first (1024x1024)
    if [ "$MAGICK_CMD" = "magick" ]; then
        magick -density 300 -background none "$INPUT_FILE" -resize 1024x1024 "$TEMP_DIR/source.png"
    else
        convert -density 300 -background none "$INPUT_FILE" -resize 1024x1024 "$TEMP_DIR/source.png"
    fi
    SOURCE_FILE="$TEMP_DIR/source.png"
else
    SOURCE_FILE="$INPUT_FILE"
fi

# Get image dimensions
if [ "$MAGICK_CMD" = "magick" ]; then
    IMAGE_WIDTH=$(magick identify -format "%w" "$SOURCE_FILE" 2>/dev/null)
    IMAGE_HEIGHT=$(magick identify -format "%h" "$SOURCE_FILE" 2>/dev/null)
else
    IMAGE_WIDTH=$(identify -format "%w" "$SOURCE_FILE" 2>/dev/null)
    IMAGE_HEIGHT=$(identify -format "%h" "$SOURCE_FILE" 2>/dev/null)
fi

print_status "Source image dimensions: ${IMAGE_WIDTH}x${IMAGE_HEIGHT}"

# Check if image is square
if [ "$IMAGE_WIDTH" != "$IMAGE_HEIGHT" ]; then
    print_warning "Input image is not square (${IMAGE_WIDTH}x${IMAGE_HEIGHT})"
    echo "For best results, use a square image. The image will be centered on a square canvas."
    echo ""
    read -r -p "Continue anyway? (y/N): " continue_non_square
    if [[ ! $continue_non_square =~ ^[Yy]$ ]]; then
        print_status "Cancelled by user"
        exit 0
    fi
    
    # Create square canvas with transparent/white background
    MAX_DIM=$((IMAGE_WIDTH > IMAGE_HEIGHT ? IMAGE_WIDTH : IMAGE_HEIGHT))
    print_status "Creating square canvas (${MAX_DIM}x${MAX_DIM})..."
    
    if [ "$MAGICK_CMD" = "magick" ]; then
        magick "$SOURCE_FILE" -background none -gravity center -extent ${MAX_DIM}x${MAX_DIM} "$TEMP_DIR/square.png"
    else
        convert "$SOURCE_FILE" -background none -gravity center -extent ${MAX_DIM}x${MAX_DIM} "$TEMP_DIR/square.png"
    fi
    SOURCE_FILE="$TEMP_DIR/square.png"
fi

print_header "Generating Favicon Files"

# Generate favicon sizes
# Standard sizes: 16x16, 32x32, 48x48, 180x180 (Apple), 192x192, 512x512 (Android)

print_status "Creating favicon-16x16.png..."
if [ "$MAGICK_CMD" = "magick" ]; then
    magick "$SOURCE_FILE" -resize 16x16 "$OUTPUT_DIR/favicon-16x16.png"
else
    convert "$SOURCE_FILE" -resize 16x16 "$OUTPUT_DIR/favicon-16x16.png"
fi

print_status "Creating favicon-32x32.png..."
if [ "$MAGICK_CMD" = "magick" ]; then
    magick "$SOURCE_FILE" -resize 32x32 "$OUTPUT_DIR/favicon-32x32.png"
else
    convert "$SOURCE_FILE" -resize 32x32 "$OUTPUT_DIR/favicon-32x32.png"
fi

print_status "Creating apple-touch-icon.png (180x180)..."
if [ "$MAGICK_CMD" = "magick" ]; then
    magick "$SOURCE_FILE" -resize 180x180 "$OUTPUT_DIR/apple-touch-icon.png"
else
    convert "$SOURCE_FILE" -resize 180x180 "$OUTPUT_DIR/apple-touch-icon.png"
fi

print_status "Creating android-chrome-192x192.png..."
if [ "$MAGICK_CMD" = "magick" ]; then
    magick "$SOURCE_FILE" -resize 192x192 "$OUTPUT_DIR/android-chrome-192x192.png"
else
    convert "$SOURCE_FILE" -resize 192x192 "$OUTPUT_DIR/android-chrome-192x192.png"
fi

print_status "Creating android-chrome-512x512.png..."
if [ "$MAGICK_CMD" = "magick" ]; then
    magick "$SOURCE_FILE" -resize 512x512 "$OUTPUT_DIR/android-chrome-512x512.png"
else
    convert "$SOURCE_FILE" -resize 512x512 "$OUTPUT_DIR/android-chrome-512x512.png"
fi

print_status "Creating multi-resolution favicon.ico (16x16, 32x32, 48x48)..."
# Create temporary files for ICO generation
if [ "$MAGICK_CMD" = "magick" ]; then
    magick "$SOURCE_FILE" -resize 16x16 "$TEMP_DIR/icon-16.png"
    magick "$SOURCE_FILE" -resize 32x32 "$TEMP_DIR/icon-32.png"
    magick "$SOURCE_FILE" -resize 48x48 "$TEMP_DIR/icon-48.png"
    
    # Combine into ICO file
    magick "$TEMP_DIR/icon-16.png" "$TEMP_DIR/icon-32.png" "$TEMP_DIR/icon-48.png" "$OUTPUT_DIR/favicon.ico"
else
    convert "$SOURCE_FILE" -resize 16x16 "$TEMP_DIR/icon-16.png"
    convert "$SOURCE_FILE" -resize 32x32 "$TEMP_DIR/icon-32.png"
    convert "$SOURCE_FILE" -resize 48x48 "$TEMP_DIR/icon-48.png"
    
    # Combine into ICO file
    convert "$TEMP_DIR/icon-16.png" "$TEMP_DIR/icon-32.png" "$TEMP_DIR/icon-48.png" "$OUTPUT_DIR/favicon.ico"
fi

print_header "Generating Web Manifest"

# Create site.webmanifest
cat > "$OUTPUT_DIR/site.webmanifest" << 'EOF'
{
    "name": "",
    "short_name": "",
    "icons": [
        {
            "src": "/android-chrome-192x192.png",
            "sizes": "192x192",
            "type": "image/png"
        },
        {
            "src": "/android-chrome-512x512.png",
            "sizes": "512x512",
            "type": "image/png"
        }
    ],
    "theme_color": "#ffffff",
    "background_color": "#ffffff",
    "display": "standalone"
}
EOF

print_status "Created site.webmanifest"

print_header "Installation Instructions"

echo "Files generated successfully in: $OUTPUT_DIR"
echo ""
echo "Generated files:"
echo "  • favicon.ico (16x16, 32x32, 48x48)"
echo "  • favicon-16x16.png"
echo "  • favicon-32x32.png"
echo "  • apple-touch-icon.png (180x180)"
echo "  • android-chrome-192x192.png"
echo "  • android-chrome-512x512.png"
echo "  • site.webmanifest"
echo ""
echo "To use these favicons on your website:"
echo ""
echo "1. Upload all files to your website's root directory"
echo ""
echo "2. Add these tags to your HTML <head> section:"
echo ""
cat << 'EOF'
<link rel="apple-touch-icon" sizes="180x180" href="/apple-touch-icon.png">
<link rel="icon" type="image/png" sizes="32x32" href="/favicon-32x32.png">
<link rel="icon" type="image/png" sizes="16x16" href="/favicon-16x16.png">
<link rel="manifest" href="/site.webmanifest">
EOF
echo ""
echo "3. (Optional) Edit site.webmanifest to add your app name and colors"
echo ""

print_header "Generation Complete!"
print_status "All favicons generated successfully!"
