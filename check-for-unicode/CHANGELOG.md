# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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
