# Big Bear Favicon Generator 🐻‍❄️

Generate a complete set of favicons from any source image (PNG, SVG, JPG, etc.) - just like [favicon.io](https://favicon.io) but local!

## What This Script Does

This script automatically generates all the favicon files you need for modern websites and apps:

- **favicon.ico** - Multi-resolution ICO file (16x16, 32x32, 48x48)
- **favicon-16x16.png** - Small favicon for browser tabs
- **favicon-32x32.png** - Standard favicon
- **apple-touch-icon.png** - 180x180 icon for iOS devices
- **android-chrome-192x192.png** - Android home screen icon
- **android-chrome-512x512.png** - High-res Android icon
- **site.webmanifest** - Web app manifest file

## Prerequisites

**ImageMagick** must be installed on your system:

### Installation

**macOS:**
```bash
brew install imagemagick
```

**Ubuntu/Debian:**
```bash
sudo apt-get update
sudo apt-get install imagemagick
```

**CentOS/RHEL:**
```bash
sudo yum install ImageMagick
```

**Arch Linux:**
```bash
sudo pacman -S imagemagick
```

**Windows (WSL):**
```bash
sudo apt-get install imagemagick
```

## Usage

### Run Directly from GitHub

You can run the script directly without cloning the repository:

```bash
bash -c "$(wget -qLO - https://raw.githubusercontent.com/bigbeartechworld/big-bear-scripts/master/generate-favicons/run.sh)" -s <input-image> <output-directory>
```

Or with curl:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/bigbeartechworld/big-bear-scripts/master/generate-favicons/run.sh)" -s <input-image> <output-directory>
```

### Basic Usage

After cloning or downloading the script:

```bash
bash run.sh <input-image>
```

This will generate all favicon files in the current directory.

### Specify Output Directory

```bash
bash run.sh <input-image> <output-directory>
```

### Examples

```bash
# Generate favicons from a PNG file
bash run.sh logo.png

# Generate favicons from SVG and output to a specific directory
bash run.sh logo.svg ./public

# Generate favicons and output to web server directory
bash run.sh icon.jpg /var/www/html
```

## Supported Input Formats

- PNG
- SVG (recommended for best quality)
- JPG/JPEG
- BMP
- GIF
- TIFF
- WEBP

## Best Practices

### Image Requirements

1. **Use a square image** - The script works best with square images (e.g., 512x512, 1024x1024)
2. **Simple designs work best** - Complex images lose detail when scaled down to 16x16
3. **High resolution source** - Start with at least 512x512 pixels for best results
4. **Transparent background** - Use PNG or SVG with transparent background for best results

### Recommended Source Image Specs

- **Format:** PNG or SVG
- **Size:** 512x512 or larger
- **Background:** Transparent
- **Content:** Simple, recognizable icon or logo

## Installation on Your Website

After generating the favicons, follow these steps:

### 1. Upload Files

Upload all generated files to your website's root directory:
- favicon.ico
- favicon-16x16.png
- favicon-32x32.png
- apple-touch-icon.png
- android-chrome-192x192.png
- android-chrome-512x512.png
- site.webmanifest

### 2. Add HTML Tags

Add these tags to the `<head>` section of your HTML:

```html
<link rel="apple-touch-icon" sizes="180x180" href="/apple-touch-icon.png">
<link rel="icon" type="image/png" sizes="32x32" href="/favicon-32x32.png">
<link rel="icon" type="image/png" sizes="16x16" href="/favicon-16x16.png">
<link rel="manifest" href="/site.webmanifest">
```

### 3. Customize site.webmanifest (Optional)

Edit the `site.webmanifest` file to add your app's name and customize colors:

```json
{
    "name": "My Awesome App",
    "short_name": "MyApp",
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
    "theme_color": "#2196F3",
    "background_color": "#ffffff",
    "display": "standalone"
}
```

## Features

✅ Supports multiple input formats (PNG, SVG, JPG, etc.)  
✅ Generates all standard favicon sizes  
✅ Creates multi-resolution ICO file  
✅ Handles non-square images (with warning)  
✅ SVG support with high-quality conversion  
✅ Generates web app manifest  
✅ Works with both ImageMagick 6 and 7  
✅ Automatic transparent background handling  
✅ No internet connection required  

## Troubleshooting

### "ImageMagick is not installed" Error

Install ImageMagick using the commands in the Prerequisites section above.

### "Input file not found" Error

Make sure the path to your image file is correct. Use absolute paths if needed:

```bash
bash run.sh ~/Desktop/logo.png
```

### Non-Square Image Warning

If your image is not square, the script will center it on a transparent square canvas. For best results, crop your image to be square before running the script.

### ICO File Not Working

Make sure you've uploaded the favicon.ico file to your website's root directory. Clear your browser cache and try accessing your site in a private/incognito window.

### SVG Files Appearing Small

The script converts SVG files at 300 DPI to maintain quality. If the output is too small, try increasing the `-density` value in the script or export your SVG to a high-resolution PNG first.

## Testing Your Favicons

After installation, test your favicons:

1. **Browser Tab** - Check if the favicon appears in your browser tab
2. **Bookmarks** - Bookmark the page and check if the icon appears
3. **iOS** - Add to home screen on iPhone/iPad
4. **Android** - Add to home screen on Android device
5. **Favicon Checker** - Use online tools like [Favicon Checker](https://realfavicongenerator.net/favicon_checker)

## Why This Script?

This script provides a free, open-source alternative to online favicon generators like favicon.io:

- ✅ **Privacy** - No need to upload your logo to third-party websites
- ✅ **Offline** - Works without internet connection
- ✅ **Automation** - Can be integrated into build scripts
- ✅ **Free** - No limitations, no watermarks
- ✅ **Customizable** - Modify the script for your specific needs

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for a detailed history of changes to this project.

## Contributing

Found a bug or have a suggestion? Please open an issue on GitHub!

## Credits

Created by [BigBearTechWorld](https://github.com/BigBearTechWorld)

Inspired by [favicon.io](https://favicon.io) by John Sorrentino

## License

See the LICENSE file in the repository root.

## Support

If you find this script helpful, consider:

- ⭐ Starring the repository
- ☕ [Buying me a tea on Ko-fi](https://ko-fi.com/bigbeartechworld)
- 💬 Joining the [Big Bear Community](https://community.bigbeartechworld.com)
- 📺 Subscribing to the [YouTube channel](https://youtube.com/@bigbeartechworld)

## Related Scripts

Check out other useful scripts in the [big-bear-scripts](https://github.com/bigbeartechworld/big-bear-scripts) repository!
