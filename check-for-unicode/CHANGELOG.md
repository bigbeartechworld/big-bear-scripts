# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [2.1.0] - 2025-10-23 False Positive Fix

### Added
- 🎯 **Context-Aware Emoji Detection**: Automatically detects when emoji variation selectors are part of legitimate emoji sequences
- 🚫 **`--exclude-emojis` Flag**: Skip emoji-related Unicode characters to avoid false positives in UI code
  - Excludes emoji variation selectors (U+FE00-FE0F)
  - Excludes emoji tag characters (U+1F3F0-1F3FA)
  - Excludes zero-width joiner (U+200D) in emoji contexts
- 📝 **`--exclude-common` Flag**: Skip common typographic Unicode in documentation
  - Smart quotes (U+2018, U+2019, U+201C, U+201D)
  - En-dash and em-dash (U+2013, U+2014)
  - Ellipsis (U+2026)
  - Common spaces and punctuation
- 📋 **`.unicode-allowlist.example`**: Template file with comprehensive examples for:
  - Emoji and UI elements
  - Typography and documentation
  - Internationalization (i18n)
  - Mathematical and scientific content
  - Project-specific Unicode
- 🧪 **Enhanced Test Suite**: Added tests for emoji and typography exclusions
  - `emoji-ui-clean-test.jsx` - Tests emoji exclusion
  - `typography-docs-test.md` - Tests common Unicode exclusion
  - Total 9 tests covering all scenarios

### Fixed
- 🐛 **False Positives in UI Code**: Emoji characters (🏷️, 🏪, ✅) in React/Vue/Angular components no longer flagged
- 🐛 **False Positives in Documentation**: Smart quotes, dashes, and ellipsis in markdown/text files no longer flagged
- 🔧 **Test Runner**: Changed from `set -e` to `set +e` to properly handle exit code testing

### Changed
- 📈 **Version**: Bumped from 2.0.0 to 2.1.0
- 📚 **Documentation**: Added "Avoiding False Positives" section at top of README
- 📚 **Usage Examples**: Added examples for `--exclude-emojis` and `--exclude-common` flags
- 🔍 **is_common_unicode()**: Enhanced to cover U+2010-U+2015, U+2026, U+2030, U+2039-U+203A

### Security
- ✅ **Maintained Security**: All dangerous Unicode patterns still detected even with exclusion flags
  - Zero-width spaces (U+200B)
  - Homograph attacks (Cyrillic, Greek, Armenian, Thai)
  - Bidirectional overrides (CVE-2021-42574)
  - AI injection patterns
- 🎯 **Smart Detection**: Context-aware filtering only skips Unicode when it's clearly safe

## [2.0.0] - 2024 AI+ Release

### Added
- 🤖 **150+ Unicode Patterns**: Comprehensive detection targeting AI injection attacks
- 🌐 **Homograph Detection**: Cyrillic (7), Greek (4), Armenian (3), Thai (4) lookalikes
- 🔧 **CLI Options**: 
  - `--help, -h` - Show help message
  - `--version, -v` - Show version information
  - `--quiet, -q` - Suppress output for CI/CD
  - `--json` - Machine-readable JSON output
  - `--severity LEVEL` - Filter by severity (critical, high, medium, low)
  - `--allowlist FILE` - Skip legitimate Unicode codes
- 🧪 **Test Suite**: Automated testing with 4 comprehensive test files
  - Clean file validation (no false positives)
  - AI injection attack detection
  - Trojan Source (CVE-2021-42574) detection
  - Automated test runner with color output
- 🔍 **Dependency Validation**: Automatic checking for required tools on startup
- 📊 **JSON Output Mode**: Structured results for parsing and automation
- ✅ **Allowlist Support**: Configuration file for legitimate Unicode usage
- 🎯 **Exit Code Strategy**:
  - `0` - No threats detected (clean)
  - `1` - Threats found (security risk)
  - `2` - Error or invalid usage
- 📚 **Enhanced Documentation**:
  - Detailed Unicode tables with risk levels
  - CI/CD integration examples (GitHub Actions, GitLab CI)
  - Pre-commit hook examples
  - Attack vector explanations
  - Usage examples for all CLI options

### Fixed
- 🐛 **False Positives**: Implemented byte-aligned hex matching
  - Changed from contiguous hex (`efbbbf`) to space-separated (`ef bb bf`)
  - Pattern matching now enforces byte boundaries: `(^| )$pattern( |$)`
  - Prevents partial hex matches that caused false detections
- 🔧 **macOS Compatibility**: Refactored for Bash 3.2 compatibility
  - Removed associative arrays (`declare -A`)
  - Removed nameref variables (`local -n`)
  - Used space-delimited string approach for allowlist
- 📁 **File Detection**: Improved MIME type detection with fallback

### Changed
- 📈 **Version**: Bumped from 1.0.1 to 2.0.0 AI+
- 🎨 **Output Format**: Enhanced visual presentation with Unicode boxes
- 🔍 **Pattern Detection**: Hex-based matching instead of grep for accuracy
- 📝 **User Messages**: More informative output with line numbers and context

### Security
- 🛡️ **CVE-2021-42574**: Enhanced Trojan Source detection (9 BiDi patterns)
- 🛡️ **CVE-2017-5116**: Comprehensive homograph attack detection
- 🤖 **AI Security**: Patterns specifically for LLM/AI prompt injection
- 🔐 **Supply Chain**: Detection of hidden characters in code dependencies

## [1.0.1] - Previous Release

### Added
- Basic Unicode detection (50+ patterns)
- Recursive directory scanning
- CVE-2021-42574 basic protection
- Zero-width character detection
- BiDi control detection
