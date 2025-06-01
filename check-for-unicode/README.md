# Check for Unicode

A security-focused script that scans files and directories for potentially dangerous Unicode characters that could be exploited in AI systems or cause display/parsing issues.

## Purpose

This script helps identify hidden or dangerous Unicode characters that can:

- Cause security vulnerabilities in AI systems
- Create invisible text manipulation
- Lead to text rendering issues
- Enable social engineering attacks through character spoofing

## Detected Unicode Characters

The script scans for the following potentially harmful Unicode characters:

### Zero-Width and Invisible Characters

| Unicode                   | Code Point | Description                                         | Risk Level |
| ------------------------- | ---------- | --------------------------------------------------- | ---------- |
| Zero Width Space          | U+200B     | Invisible character that can hide malicious content | High       |
| Zero Width Non-Joiner     | U+200C     | Can break text parsing logic                        | Medium     |
| Zero Width Joiner         | U+200D     | Can create unexpected character combinations        | Medium     |
| Word Joiner               | U+2060     | Invisible character that prevents line breaks       | Medium     |
| Function Application      | U+2061     | Mathematical invisible operator                     | Low        |
| Invisible Times           | U+2062     | Mathematical invisible operator                     | Low        |
| Invisible Separator       | U+2063     | Mathematical invisible operator                     | Low        |
| Invisible Plus            | U+2064     | Mathematical invisible operator                     | Low        |
| Zero Width No-Break Space | U+FEFF     | Byte Order Mark, can cause parsing issues           | Medium     |
| Combining Grapheme Joiner | U+034F     | Can create unexpected character combinations        | Medium     |

### Bidirectional Text Controls (Trojan Source - CVE-2021-42574)

| Unicode                    | Code Point | Description                              | Risk Level |
| -------------------------- | ---------- | ---------------------------------------- | ---------- |
| Left-to-Right Embedding    | U+202A     | Can manipulate text direction            | High       |
| Right-to-Left Embedding    | U+202B     | Can manipulate text direction            | High       |
| Pop Directional Formatting | U+202C     | Ends directional formatting              | High       |
| Left-to-Right Override     | U+202D     | Forces left-to-right text direction      | High       |
| Right-to-Left Override     | U+202E     | Can reverse text direction for spoofing  | High       |
| Left-to-Right Isolate      | U+2066     | Isolates text direction                  | High       |
| Right-to-Left Isolate      | U+2067     | Isolates text direction                  | High       |
| First Strong Isolate       | U+2068     | Isolates based on first strong character | High       |
| Pop Directional Isolate    | U+2069     | Ends directional isolation               | High       |
| Arabic Letter Mark         | U+061C     | Marks Arabic text direction              | Medium     |
| Left-to-Right Mark         | U+200E     | Marks left-to-right text direction       | Medium     |
| Right-to-Left Mark         | U+200F     | Marks right-to-left text direction       | Medium     |

### Annotation and Formatting Characters

| Unicode                           | Code Point | Description                         | Risk Level |
| --------------------------------- | ---------- | ----------------------------------- | ---------- |
| Interlinear Annotation Anchor     | U+FFF9     | Can hide annotations                | Medium     |
| Interlinear Annotation Separator  | U+FFFA     | Separates annotation components     | Medium     |
| Interlinear Annotation Terminator | U+FFFB     | Terminates annotations              | Medium     |
| Object Replacement Character      | U+FFFC     | Placeholder for embedded objects    | Medium     |
| Replacement Character             | U+FFFD     | Used for unknown/invalid characters | Low        |

### Line and Paragraph Separators

| Unicode             | Code Point | Description             | Risk Level |
| ------------------- | ---------- | ----------------------- | ---------- |
| Line Separator      | U+2028     | Can break parsing logic | Medium     |
| Paragraph Separator | U+2029     | Can break parsing logic | Medium     |

### Additional Format Characters

| Unicode                   | Code Point | Description                 | Risk Level |
| ------------------------- | ---------- | --------------------------- | ---------- |
| Soft Hyphen               | U+00AD     | Invisible hyphenation point | Low        |
| Hangul Choseong Filler    | U+115F     | Korean text filler          | Low        |
| Hangul Jungseong Filler   | U+1160     | Korean text filler          | Low        |
| Khmer Vowel Inherent Aq   | U+17B4     | Khmer script formatting     | Low        |
| Khmer Vowel Inherent Aa   | U+17B5     | Khmer script formatting     | Low        |
| Mongolian Vowel Separator | U+180E     | Mongolian script formatting | Low        |
| Hangul Filler             | U+3164     | Korean text filler          | Low        |

### Variation Selectors

| Unicode                 | Code Point  | Description                     | Risk Level |
| ----------------------- | ----------- | ------------------------------- | ---------- |
| Variation Selector 1-16 | U+FE00-FE0F | Can change character appearance | Medium     |

## Usage

### Quick Run (Remote)

```bash
bash -c "$(wget -qLO - https://raw.githubusercontent.com/bigbeartechworld/big-bear-scripts/master/check-for-unicode/run.sh)" -- .
```

### Local Usage

#### Scan a single file:

```bash
./run.sh /path/to/file.txt
```

#### Scan a directory recursively:

```bash
./run.sh /path/to/directory
```

#### Scan current directory:

```bash
./run.sh .
```

## Example Output

```
Scanning: ./suspicious_file.txt
  Warning: Non-UTF8 file detected
  [!] Found dangerous Unicode: U+200b

Scanning: ./clean_file.txt

Scanning: ./another_file.md
  [!] Found dangerous Unicode: U+202e
```

## Features

- **Recursive Directory Scanning**: Automatically scans all files in subdirectories
- **File Encoding Detection**: Warns about non-UTF8 files that might contain hidden characters
- **Comprehensive Unicode Detection**: Checks for 50+ different types of potentially dangerous Unicode characters including:
  - Zero-width and invisible characters
  - Bidirectional text controls (Trojan Source attacks)
  - Annotation and formatting characters
  - Line and paragraph separators
  - Variation selectors
- **CVE-2021-42574 Protection**: Specifically detects Trojan Source attack vectors
- **Clear Output**: Shows which files are being scanned and exactly which Unicode characters are found
- **Cross-Platform**: Works on Linux, macOS, and other Unix-like systems

## Requirements

- Bash shell
- `grep` with Perl regex support (`--perl-regexp`)
- `file` command for encoding detection
- `find` command for directory traversal

## Security Considerations

This script is particularly useful for:

- **Code Review**: Detecting hidden characters in source code
- **Content Moderation**: Identifying potentially malicious text submissions
- **AI System Security**: Preventing Unicode-based prompt injection attacks
- **Data Validation**: Ensuring clean text data in databases and files

## Exit Codes

- `0`: Scan completed successfully (may or may not have found Unicode characters)
- `1`: Invalid usage (no file/directory specified)

## Notes

- The script uses Perl-compatible regular expressions for accurate Unicode detection
- All files are scanned regardless of extension
- Binary files may produce warnings but will still be scanned
- Large directories may take some time to process completely
