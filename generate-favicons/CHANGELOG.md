# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.0.0] - 2025-10-24

### Added
- Initial release of Big Bear Favicon Generator
- Support for multiple input image formats (PNG, SVG, JPG, BMP, GIF, TIFF, WEBP)
- Automatic generation of 7 favicon files:
  - favicon.ico (multi-resolution: 16x16, 32x32, 48x48)
  - favicon-16x16.png
  - favicon-32x32.png
  - apple-touch-icon.png (180x180)
  - android-chrome-192x192.png
  - android-chrome-512x512.png
  - site.webmanifest
- Multi-resolution ICO file generation with embedded 16x16, 32x32, and 48x48 sizes
- Web app manifest (site.webmanifest) generation
- Non-square image handling with automatic square canvas creation
- SVG support with high-quality 300 DPI conversion
- Compatibility with both ImageMagick 6 and 7
- Automatic transparent background handling
- Comprehensive error checking and user-friendly error messages
- Interactive prompts for edge cases (non-square images)
- Command-line interface with input file and output directory options
- Detailed installation instructions in output
- Test suite (test.sh) for validating functionality
- Comprehensive documentation:
  - README.md with quick start guide
  - docs/QUICKSTART.md for fast-track setup
  - docs/INSTALLATION.md with platform-specific instructions
  - docs/EXAMPLES.md with real-world usage examples
  - PROJECT_SUMMARY.md with technical overview

### Security
- All processing happens locally - no data transmitted to external servers
- No network requests required for operation

[unreleased]: https://github.com/bigbeartechworld/big-bear-scripts/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/bigbeartechworld/big-bear-scripts/releases/tag/v1.0.0
