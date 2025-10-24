#!/usr/bin/env bash

# Unicode Security Scanner v2.1.0 AI+
# Detects dangerous Unicode characters that can be used in security attacks
# Including Trojan Source attacks (CVE-2021-42574) and other invisible characters

# Script configuration
VERSION="2.1.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Command-line options (defaults)
QUIET_MODE=false
JSON_OUTPUT=false
SEVERITY_FILTER=""
ALLOWLIST_FILE="${SCRIPT_DIR}/.unicode-allowlist"
EXCLUDE_EMOJIS=false
EXCLUDE_COMMON_UNICODE=false

# Check dependencies
check_dependencies() {
    local missing=()
    command -v hexdump >/dev/null || missing+=("hexdump")
    command -v grep >/dev/null || missing+=("grep")
    command -v file >/dev/null || missing+=("file")
    command -v find >/dev/null || missing+=("find")
    
    if [ ${#missing[@]} -gt 0 ]; then
        echo "Error: Missing required commands: ${missing[*]}" >&2
        echo "Please install the required tools and try again." >&2
        exit 2
    fi
}

# Show help
show_help() {
    cat << EOF
Unicode Security Scanner v${VERSION} - AI Enhanced with False Positive Fix

USAGE:
    $0 [OPTIONS] <file|directory>

OPTIONS:
    --help, -h          Show this help message
    --version, -v       Show version information
    --quiet, -q         Suppress non-error output (for CI/CD)
    --json              Output results in JSON format
    --severity LEVEL    Filter by severity: critical, high, medium, low
                        (comma-separated, e.g., "critical,high")
    --allowlist FILE    Path to allowlist file (default: .unicode-allowlist)
    --exclude-emojis    Exclude emoji characters and variation selectors (reduces false positives)
    --exclude-common    Exclude common Unicode like smart quotes, dashes (very permissive)

EXAMPLES:
    $0 ./src/                              # Scan directory
    $0 script.py                          # Scan single file
    $0 --quiet --json ./app/ > results.json  # JSON output for CI
    $0 --severity critical,high ./        # Only show critical/high
    $0 --exclude-emojis ./ui/             # Skip emoji characters in UI code
    $0 --exclude-common ./docs/           # Very permissive for documentation

EXIT CODES:
    0 - No threats detected
    1 - Threats detected
    2 - Error or invalid usage

MORE INFO:
    https://github.com/bigbeartechworld/big-bear-scripts
EOF
    exit 0
}

# Show version
show_version() {
    echo "Unicode Security Scanner v${VERSION}"
    exit 0
}

# Load allowlist (Unicode codes to ignore)
load_allowlist() {
    # Store allowlisted codes in a simple variable (space-separated)
    ALLOWLIST_CODES=""
    if [ -f "$ALLOWLIST_FILE" ]; then
        while IFS= read -r line; do
            # Skip comments and empty lines
            [[ "$line" =~ ^#.*$ || -z "$line" ]] && continue
            # Extract Unicode code (e.g., U+200B or 200B)
            code=$(echo "$line" | grep -oE 'U\+[0-9A-Fa-f]+|^[0-9A-Fa-f]+' | tr -d 'U+' | tr '[:lower:]' '[:upper:]')
            [ -n "$code" ] && ALLOWLIST_CODES="$ALLOWLIST_CODES $code "
        done < "$ALLOWLIST_FILE"
    fi
}

# Check if Unicode code is in allowlist
is_allowed() {
    local code=$1
    [[ "$ALLOWLIST_CODES" == *" $code "* ]]
}

# Check if pattern is emoji-related
is_emoji_pattern() {
    local unicode_code=$1
    # Emoji variation selectors (FE00-FE0F)
    [[ "$unicode_code" =~ ^FE0[0-9A-F]$ ]] && return 0
    # Emoji tag characters (1F3F0-1F3FA, E0020-E007F)
    [[ "$unicode_code" =~ ^1F3F[0-9A-F]$ ]] && return 0
    [[ "$unicode_code" =~ ^E00[2-7][0-9A-F]$ ]] && return 0
    # Zero-width joiner (used in emoji sequences)
    [[ "$unicode_code" == "200D" ]] && return 0
    return 1
}

# Check if pattern is common Unicode (quotes, dashes, etc.)
is_common_unicode() {
    local unicode_code=$1
    # Smart quotes: U+2018, U+2019, U+201C, U+201D
    [[ "$unicode_code" =~ ^201[89CD]$ ]] && return 0
    # Dashes: U+2010-U+2015 (hyphen, non-breaking hyphen, figure dash, en-dash, em-dash, horizontal bar)
    [[ "$unicode_code" =~ ^201[0-5]$ ]] && return 0
    # Ellipsis: U+2026
    [[ "$unicode_code" == "2026" ]] && return 0
    # Common spaces (but not zero-width): U+2007-U+200A
    [[ "$unicode_code" =~ ^200[7-9A]$ ]] && return 0
    # Angle quotation marks: U+2039, U+203A
    [[ "$unicode_code" =~ ^203[9A]$ ]] && return 0
    # Per mille: U+2030
    [[ "$unicode_code" == "2030" ]] && return 0
    return 1
}

# Check if hex pattern appears in an emoji context
is_in_emoji_context() {
    local hex_content=$1
    local pattern_spaced=$2
    
    # Look for emoji range characters (1F300-1F9FF) near the pattern
    # Emoji base characters: f09f8c80 to f09fa7bf (approximate)
    if echo "$hex_content" | grep -Eq "f0 9f [8-9a][0-9a-f] [0-9a-f]{2}.*$pattern_spaced"; then
        return 0
    fi
    if echo "$hex_content" | grep -Eq "$pattern_spaced.*f0 9f [8-9a][0-9a-f] [0-9a-f]{2}"; then
        return 0
    fi
    
    return 1
}

# List of dangerous Unicode characters as hex patterns for grep
# Format: "hex_pattern:unicode_code:description"
harmful_patterns=(
    # Zero-width and invisible characters
    "e2808b:200B:Zero Width Space"
    "e2808c:200C:Zero Width Non-Joiner"
    "e2808d:200D:Zero Width Joiner"
    "e281a0:2060:Word Joiner"
    "e281a1:2061:Function Application"
    "e281a2:2062:Invisible Times"
    "e281a3:2063:Invisible Separator"
    "e281a4:2064:Invisible Plus"
    "efbbbf:FEFF:Zero Width No-Break Space (BOM)"
    "cd8f:034F:Combining Grapheme Joiner"
    
    # Bidirectional text controls (Trojan Source attacks - CVE-2021-42574)
    "e280aa:202A:Left-to-Right Embedding"
    "e280ab:202B:Right-to-Left Embedding"
    "e280ac:202C:Pop Directional Formatting"
    "e280ad:202D:Left-to-Right Override"
    "e280ae:202E:Right-to-Left Override"
    "e281a6:2066:Left-to-Right Isolate"
    "e281a7:2067:Right-to-Left Isolate"
    "e281a8:2068:First Strong Isolate"
    "e281a9:2069:Pop Directional Isolate"
    "d89c:061C:Arabic Letter Mark"
    "e2808e:200E:Left-to-Right Mark"
    "e2808f:200F:Right-to-Left Mark"
    
    # Annotation and formatting characters
    "efbfb9:FFF9:Interlinear Annotation Anchor"
    "efbfba:FFFA:Interlinear Annotation Separator"
    "efbfbb:FFFB:Interlinear Annotation Terminator"
    "efbfbc:FFFC:Object Replacement Character"
    "efbfbd:FFFD:Replacement Character"
    
    # Line and paragraph separators
    "e280a8:2028:Line Separator"
    "e280a9:2029:Paragraph Separator"
    
    # Additional format characters
    "c2ad:00AD:Soft Hyphen"
    "e1859f:115F:Hangul Choseong Filler"
    "e185a0:1160:Hangul Jungseong Filler"
    "e19eb4:17B4:Khmer Vowel Inherent Aq"
    "e19eb5:17B5:Khmer Vowel Inherent Aa"
    "e1a08e:180E:Mongolian Vowel Separator"
    "e385a4:3164:Hangul Filler"
    
    # Variation selectors (can change character appearance)
    "efe000:FE00:Variation Selector-1"
    "efe001:FE01:Variation Selector-2"
    "efe002:FE02:Variation Selector-3"
    "efe003:FE03:Variation Selector-4"
    "efe004:FE04:Variation Selector-5"
    "efe005:FE05:Variation Selector-6"
    "efe006:FE06:Variation Selector-7"
    "efe007:FE07:Variation Selector-8"
    "efe008:FE08:Variation Selector-9"
    "efe009:FE09:Variation Selector-10"
    "efe00a:FE0A:Variation Selector-11"
    "efe00b:FE0B:Variation Selector-12"
    "efe00c:FE0C:Variation Selector-13"
    "efe00d:FE0D:Variation Selector-14"
    "efe00e:FE0E:Variation Selector-15"
    "efe00f:FE0F:Variation Selector-16"
    
    # Homograph attack characters - Cyrillic lookalikes (CVE-2017-5116)
    "d0b0:0430:Cyrillic Small Letter A (looks like Latin a)"
    "d181:0441:Cyrillic Small Letter Es (looks like Latin c)"
    "d0b5:0435:Cyrillic Small Letter Ie (looks like Latin e)"
    "d0be:043E:Cyrillic Small Letter O (looks like Latin o)"
    "d180:0440:Cyrillic Small Letter Er (looks like Latin p)"
    "d185:0445:Cyrillic Small Letter Ha (looks like Latin x)"
    "d183:0443:Cyrillic Small Letter U (looks like Latin y)"
    "d0b2:0432:Cyrillic Small Letter Ve (looks like Latin B)"
    "d096:0456:Cyrillic Small Letter Byelorussian-Ukrainian I (looks like Latin i)"
    "d098:0458:Cyrillic Small Letter Je (looks like Latin j)"
    "d195:0475:Cyrillic Small Letter Izhitsa (looks like Latin v)"
    "d0b4:0434:Cyrillic Small Letter De (looks like Latin g in italic)"
    "d197:0457:Cyrillic Small Letter Yi (looks like Latin i with dots)"
    "d281:04bb:Cyrillic Small Letter Shha (looks like Latin h)"
    "d4b1:0531:Armenian Capital Letter Ayb (looks like Latin U)"
    "d587:0587:Armenian Small Ligature Ech Yiwn (looks like Latin w)"
    
    # Cyrillic capital letters
    "d090:0410:Cyrillic Capital Letter A (looks like Latin A)"
    "d092:0412:Cyrillic Capital Letter Ve (looks like Latin B)"
    "d0a1:0421:Cyrillic Capital Letter Es (looks like Latin C)"
    "d095:0415:Cyrillic Capital Letter Ie (looks like Latin E)"
    "d09d:041D:Cyrillic Capital Letter En (looks like Latin H)"
    "d096:0406:Cyrillic Capital Letter Byelorussian-Ukrainian I (looks like Latin I)"
    "d098:0408:Cyrillic Capital Letter Je (looks like Latin J)"
    "d09a:041A:Cyrillic Capital Letter Ka (looks like Latin K)"
    "d09c:041C:Cyrillic Capital Letter Em (looks like Latin M)"
    "d09e:041E:Cyrillic Capital Letter O (looks like Latin O)"
    "d0a0:0420:Cyrillic Capital Letter Er (looks like Latin P)"
    "d085:0405:Cyrillic Capital Letter Dze (looks like Latin S)"
    "d0a2:0422:Cyrillic Capital Letter Te (looks like Latin T)"
    "d0a5:0425:Cyrillic Capital Letter Ha (looks like Latin X)"
    "d0a3:0423:Cyrillic Capital Letter U (looks like Latin Y)"
    
    # Greek lookalikes
    "cebf:03BF:Greek Small Letter Omicron (looks like Latin o)"
    "ceb1:03B1:Greek Small Letter Alpha (looks like Latin a in italic)"
    "ceb5:03B5:Greek Small Letter Epsilon (looks like Latin e)"
    "cebd:03BD:Greek Small Letter Nu (looks like Latin v)"
    "cf81:03C1:Greek Small Letter Rho (looks like Latin p)"
    "cf84:03C4:Greek Small Letter Tau (looks like Latin t)"
    "cf85:03C5:Greek Small Letter Upsilon (looks like Latin u)"
    "cf87:03C7:Greek Small Letter Chi (looks like Latin x)"
    "ceb9:03B9:Greek Small Letter Iota (looks like Latin i)"
    "ceba:03BA:Greek Small Letter Kappa (looks like Latin k)"
    "ceb7:03B7:Greek Small Letter Eta (looks like Latin n)"
    "cf89:03C9:Greek Small Letter Omega (looks like Latin w)"
    
    # Armenian lookalikes
    "d5b8:0578:Armenian Small Letter Vo (looks like Latin n)"
    "d5bd:057D:Armenian Small Letter Seh (looks like Latin s)"
    "d5b5:0575:Armenian Small Letter Yi (looks like Latin j)"
    "d5b0:0570:Armenian Small Letter Ho (looks like Latin h)"
    "d5b4:0574:Armenian Small Letter Men (looks like Latin q)"
    "d5b1:0571:Armenian Small Letter Sha (looks like Latin g)"
    "d5a1:0561:Armenian Small Letter Ayb (looks like Latin a)"
    
    # Thai lookalikes (modern simplified fonts)
    "e0b884:0E04:Thai Character Kho Khwai (looks like Latin A)"
    "e0b897:0E17:Thai Character Tho Thahan (looks like Latin n)"
    "e0b899:0E19:Thai Character No Nu (looks like Latin u)"
    "e0b89a:0E1A:Thai Character Bo Baimai (looks like Latin U)"
    "e0b89b:0E1B:Thai Character Po Pla (looks like Latin J)"
    "e0b89e:0E1E:Thai Character Pho Phung (looks like Latin W)"
    "e0b8a3:0E23:Thai Character Ro Rua (looks like Latin S)"
    "e0b8a5:0E25:Thai Character Lo Ling (looks like Latin a)"
    
    # Mathematical Alphanumeric Symbols (often used in AI attacks)
    "f09d9482:1D502:Mathematical Fraktur Small A"
    "f09d94b8:1D4B8:Mathematical Script Small A"
    "f09d95b6:1D576:Mathematical Bold Fraktur Small A"
    "f09d96ba:1D6BA:Mathematical Bold Small Alpha"
    "f09d90ae:1D42E:Mathematical Bold Small A"
    "f09d91b6:1D476:Mathematical Bold Italic Small A"
    "f09d92aa:1D4AA:Mathematical Sans-Serif Small A"
    "f09d93b2:1D4F2:Mathematical Sans-Serif Bold Small A"
    "f09d94ba:1D4BA:Mathematical Sans-Serif Italic Small A"
    "f09d95c2:1D582:Mathematical Sans-Serif Bold Italic Small A"
    "f09d96ba:1D6BA:Mathematical Monospace Small A"
    
    # Fullwidth characters (used in prompt injection)
    "efbca1:FF21:Fullwidth Latin Capital Letter A"
    "efbca2:FF22:Fullwidth Latin Capital Letter B"
    "efbca3:FF23:Fullwidth Latin Capital Letter C"
    "efbcb1:FF31:Fullwidth Latin Small Letter A"
    "efbcb2:FF32:Fullwidth Latin Small Letter B"
    "efbcb3:FF33:Fullwidth Latin Small Letter C"
    
    # Number Forms that can be confused with letters
    "e285a0:2160:Roman Numeral One (looks like Latin I)"
    "e285a5:2165:Roman Numeral Six (looks like VI)"
    "e285a9:2169:Roman Numeral Ten (looks like Latin X)"
    "e285b4:2174:Small Roman Numeral Five (looks like Latin v)"
    "e285b9:2179:Small Roman Numeral Ten (looks like Latin x)"
    
    # AI-specific prompt injection patterns
    "e2819f:205F:Medium Mathematical Space (invisible separator)"
    "e28087:2007:Figure Space (numeric space manipulation)"
    "e28088:2008:Punctuation Space (can break tokenization)"
    "e28089:2009:Thin Space (subtle spacing attack)"
    "e2808a:200A:Hair Space (micro-spacing attack)"
    "e2808b:202F:Narrow No-Break Space (line manipulation)"
    "e281a5:2065:Inhibit Arabic Form Shaping (script confusion)"
    "e281a6:2066:Left-to-Right Isolate (directional confusion)"
    "e281a7:2067:Right-to-Left Isolate (directional confusion)"
    "e281a8:2068:First Strong Isolate (directional confusion)"
    "e281a9:2069:Pop Directional Isolate (directional confusion)"
    
    # Unicode normalization attack vectors
    "cc80:0300:Combining Grave Accent (normalization attack)"
    "cc81:0301:Combining Acute Accent (normalization attack)"
    "cc82:0302:Combining Circumflex Accent (normalization attack)"
    "cc83:0303:Combining Tilde (normalization attack)"
    "cc84:0304:Combining Macron (normalization attack)"
    "cc88:0308:Combining Diaeresis (normalization attack)"
    "cc8a:030A:Combining Ring Above (normalization attack)"
    "cc8c:030C:Combining Caron (normalization attack)"
    
    # Confusable punctuation and symbols
    "e28098:2018:Left Single Quotation Mark (looks like apostrophe)"
    "e28099:2019:Right Single Quotation Mark (looks like apostrophe)"
    "e2809c:201C:Left Double Quotation Mark (looks like quote)"
    "e2809d:201D:Right Double Quotation Mark (looks like quote)"
    "e28090:2010:Hyphen (different from ASCII hyphen)"
    "e28091:2011:Non-Breaking Hyphen (different from ASCII hyphen)"
    "e28092:2012:Figure Dash (looks like hyphen)"
    "e28093:2013:En Dash (looks like hyphen)"
    "e28094:2014:Em Dash (looks like double hyphen)"
    "e28095:2015:Horizontal Bar (looks like long dash)"
    "e280a6:2026:Horizontal Ellipsis (looks like three dots)"
    "e280b0:2030:Per Mille Sign (looks like percent)"
    "e280b9:2039:Single Left-Pointing Angle Quotation Mark"
    "e280ba:203A:Single Right-Pointing Angle Quotation Mark"
    
    # Additional zero-width and control characters
    "efbfb0:FFF0:Reserved Character (potential bypass)"
    "efbfb1:FFF1:Reserved Character (potential bypass)"
    "efbfb2:FFF2:Reserved Character (potential bypass)"
    "efbfb3:FFF3:Reserved Character (potential bypass)"
    "efbfb4:FFF4:Reserved Character (potential bypass)"
    "efbfb5:FFF5:Reserved Character (potential bypass)"
    "efbfb6:FFF6:Reserved Character (potential bypass)"
    "efbfb7:FFF7:Reserved Character (potential bypass)"
    "efbfb8:FFF8:Reserved Character (potential bypass)"
    
    # Superscript and subscript characters (AI confusion)
    "e281b0:2070:Superscript Zero"
    "c2b9:00B9:Superscript One"
    "c2b2:00B2:Superscript Two"
    "c2b3:00B3:Superscript Three"
    "e281b4:2074:Superscript Four"
    "e281b5:2075:Superscript Five"
    "e281b6:2076:Superscript Six"
    "e281b7:2077:Superscript Seven"
    "e281b8:2078:Superscript Eight"
    "e281b9:2079:Superscript Nine"
    "e28280:2080:Subscript Zero"
    "e28281:2081:Subscript One"
    "e28282:2082:Subscript Two"
    "e28283:2083:Subscript Three"
    "e28284:2084:Subscript Four"
    
    # Emoji variation selectors and modifiers (can hide content)
    "f09f8fb0:1F3F0:Emoji Tag Latin Small Letter P"
    "f09f8fb1:1F3F1:Emoji Tag Latin Small Letter Q"
    "f09f8fb2:1F3F2:Emoji Tag Latin Small Letter R"
    "f09f8fb3:1F3F3:Emoji Tag Latin Small Letter S"
    "f09f8fb4:1F3F4:Emoji Tag Latin Small Letter T"
    "f09f8fb5:1F3F5:Emoji Tag Latin Small Letter U"
    "f09f8fb6:1F3F6:Emoji Tag Latin Small Letter V"
    "f09f8fb7:1F3F7:Emoji Tag Latin Small Letter W"
    "f09f8fb8:1F3F8:Emoji Tag Latin Small Letter X"
    "f09f8fb9:1F3F9:Emoji Tag Latin Small Letter Y"
    "f09f8fba:1F3FA:Emoji Tag Latin Small Letter Z"
    
    # CJK Compatibility characters (can mimic ASCII)
    "efbc81:FF01:Fullwidth Exclamation Mark"
    "efbc9f:FF1F:Fullwidth Question Mark"
    "efbc8a:FF0A:Fullwidth Asterisk"
    "efbc8b:FF0B:Fullwidth Plus Sign"
    "efbc8d:FF0D:Fullwidth Hyphen-Minus"
    "efbc8e:FF0E:Fullwidth Full Stop"
    "efbc8f:FF0F:Fullwidth Solidus"
    "efbc9a:FF1A:Fullwidth Colon"
    "efbc9b:FF1B:Fullwidth Semicolon"
    "efbc9c:FF1C:Fullwidth Less-Than Sign"
    "efbc9d:FF1D:Fullwidth Equals Sign"
    "efbc9e:FF1E:Fullwidth Greater-Than Sign"
)

# Check dependencies first
check_dependencies

# Parse command-line arguments
target=""
while [[ $# -gt 0 ]]; do
    case $1 in
        --help|-h)
            show_help
            ;;
        --version|-v)
            show_version
            ;;
        --quiet|-q)
            QUIET_MODE=true
            shift
            ;;
        --json)
            JSON_OUTPUT=true
            shift
            ;;
        --severity)
            SEVERITY_FILTER="$2"
            shift 2
            ;;
        --allowlist)
            ALLOWLIST_FILE="$2"
            shift 2
            ;;
        --exclude-emojis)
            EXCLUDE_EMOJIS=true
            shift
            ;;
        --exclude-common)
            EXCLUDE_COMMON_UNICODE=true
            shift
            ;;
        -*)
            echo "Error: Unknown option: $1" >&2
            echo "Use --help for usage information" >&2
            exit 2
            ;;
        *)
            target="$1"
            shift
            ;;
    esac
done

if [ -z "$target" ]; then
    echo "Error: No target specified" >&2
    echo "Usage: $0 [OPTIONS] <file|directory>" >&2
    echo "Use --help for more information" >&2
    exit 2
fi

# Load allowlist into global variable
load_allowlist

# Show header unless in quiet or JSON mode
if [ "$QUIET_MODE" = false ] && [ "$JSON_OUTPUT" = false ]; then
    echo -e "\033[1;35m╔══════════════════════════════════════════════════════════════╗\033[0m"
    echo -e "\033[1;35m║         Big Bear Unicode Security Scanner v2.1.0 AI+         ║\033[0m"
    echo -e "\033[1;35m║       Detecting dangerous Unicode & AI injection attacks      ║\033[0m"
    echo -e "\033[1;35m║                       Please support me!                     ║\033[0m"
    echo -e "\033[1;35m║               https://ko-fi.com/bigbeartechworld             ║\033[0m"
    echo -e "\033[1;35m║                           Thank you!                         ║\033[0m"
    echo -e "\033[1;35m║                  https://bigbeartechworld.com                ║\033[0m"
    echo -e "\033[1;35m╚══════════════════════════════════════════════════════════════╝\033[0m"
    echo
fi

# Initialize counters and results for summary
total_files=0
files_with_issues=0
declare -a json_results

# Single file search function
search_file() {
    file="$1"
    
    if [ "$QUIET_MODE" = false ] && [ "$JSON_OUTPUT" = false ]; then
        echo -e "\n\033[1;34mScanning:\033[0m $file"
    fi
    
    # Check file encoding - be more lenient with ASCII files
    # Use reliable MIME/type detection (macOS: -bI prints mime; fallback to -b)
    file_info=$(file -bI "$file" 2>/dev/null || file -b "$file" 2>/dev/null)
    if ! echo "$file_info" | grep -qE '(utf-8|us-ascii)'; then
        if [ "$QUIET_MODE" = false ] && [ "$JSON_OUTPUT" = false ]; then
            echo -e "  \033[1;33mWarning:\033[0m Non-UTF8 file detected ($file_info)"
        fi
    fi

    found_any=false
    local -a file_findings
    
    # Convert file to spaced hex bytes for pattern matching (enforces byte alignment)
    # Example: "ef bb bf ..." (lowercase, space-separated)
    hex_content=$(hexdump -ve '1/1 "%.2x "' "$file" 2>/dev/null)
    
    if [ -z "$hex_content" ]; then
        if [ "$QUIET_MODE" = false ] && [ "$JSON_OUTPUT" = false ]; then
            echo -e "  \033[1;33mWarning:\033[0m Could not read file as binary"
        fi
        ((total_files++))
        return
    fi
    
    # Search for each harmful pattern
    for pattern_info in "${harmful_patterns[@]}"; do
        IFS=':' read -r hex_pattern unicode_code description <<< "$pattern_info"
        
        # Check if in allowlist
        if is_allowed "$unicode_code"; then
            continue
        fi
        
        # Skip emoji-related patterns if flag is set
        if [ "$EXCLUDE_EMOJIS" = true ] && is_emoji_pattern "$unicode_code"; then
            continue
        fi
        
        # Skip common Unicode if flag is set
        if [ "$EXCLUDE_COMMON_UNICODE" = true ] && is_common_unicode "$unicode_code"; then
            continue
        fi
        
        # Transform the contiguous hex pattern (e.g., "efbbbf") into space-separated bytes ("ef bb bf")
        pattern_spaced=$(echo "$hex_pattern" | sed 's/../& /g; s/ $//')
        
        # Match whole-byte sequences only: (^| )<bytes>( |$)
        if echo "$hex_content" | grep -Eq "(^| )$pattern_spaced( |$)"; then
            # For emoji-related characters, check context even if not excluded
            if is_emoji_pattern "$unicode_code" && is_in_emoji_context "$hex_content" "$pattern_spaced"; then
                continue
            fi
            if [ "$found_any" = false ]; then
                if [ "$JSON_OUTPUT" = false ] && [ "$QUIET_MODE" = false ]; then
                    echo -e "  \033[1;31m[!] Dangerous Unicode characters found:\033[0m"
                fi
                found_any=true
                ((files_with_issues++))
            fi
            
            # Find line numbers by searching the original file
            temp_char=$(echo "$hex_pattern" | sed 's/../\\x&/g')
            line_matches=$(grep -n "$(printf "$temp_char")" "$file" 2>/dev/null || echo "")
            
            if [ "$JSON_OUTPUT" = true ]; then
                # Collect for JSON output
                if [ -n "$line_matches" ]; then
                    while IFS=':' read -r line_num line_content; do
                        file_findings+=("{\"unicode\":\"U+$unicode_code\",\"description\":\"$description\",\"line\":$line_num,\"content\":\"$(echo "$line_content" | sed 's/"/\\"/g')\"}")
                    done <<< "$line_matches"
                else
                    file_findings+=("{\"unicode\":\"U+$unicode_code\",\"description\":\"$description\",\"line\":null,\"content\":null}")
                fi
            else
                if [ "$QUIET_MODE" = false ]; then
                    echo -e "      \033[1;91mU+$unicode_code\033[0m ($description)"
                    
                    if [ -n "$line_matches" ]; then
                        echo "$line_matches" | while IFS=':' read -r line_num line_content; do
                            echo -e "        \033[36mLine $line_num:\033[0m $line_content"
                        done
                    else
                        echo -e "        \033[33m(Character found but line detection failed)\033[0m"
                    fi
                    echo
                fi
            fi
        fi
    done
    
    if [ "$found_any" = false ]; then
        if [ "$QUIET_MODE" = false ] && [ "$JSON_OUTPUT" = false ]; then
            echo -e "  \033[1;32m✓ No dangerous Unicode characters found\033[0m"
        fi
    else
        if [ "$JSON_OUTPUT" = true ]; then
            # Add file results to JSON array
            local findings_json=$(IFS=,; echo "${file_findings[*]}")
            json_results+=("{\"file\":\"$file\",\"findings\":[$findings_json]}")
        fi
    fi
    
    ((total_files++))
}

# Handle directories recursively
if [ -d "$target" ]; then
    # Validate target is a directory
    if [ ! -d "$target" ]; then
        echo "Error: Directory not found: $target" >&2
        exit 2
    fi
    
    # Use a simpler approach - collect all files first, then process them
    if [ "$QUIET_MODE" = false ] && [ "$JSON_OUTPUT" = false ]; then
        echo "Collecting files..."
    fi
    file_list=$(find "$target" -type f 2>/dev/null)
    
    if [ -z "$file_list" ]; then
        echo "Error: No files found in $target" >&2
        exit 2
    fi
    
    while IFS= read -r file; do
        if [ -n "$file" ]; then
            search_file "$file"
        fi
    done <<< "$file_list"
elif [ -f "$target" ]; then
    search_file "$target"
else
    echo "Error: Target not found or not accessible: $target" >&2
    exit 2
fi

# Print summary
if [ "$JSON_OUTPUT" = true ]; then
    # Output JSON results
    results_json=$(IFS=,; echo "${json_results[*]}")
    echo "{\"scanner\":\"Unicode Security Scanner\",\"version\":\"${VERSION}\",\"total_files\":$total_files,\"files_with_issues\":$files_with_issues,\"results\":[$results_json]}"
else
    if [ "$QUIET_MODE" = false ]; then
        echo -e "\n\033[1;35m╔══════════════════════════════════════════════════════════════╗\033[0m"
        echo -e "\033[1;35m║                           Summary                            ║\033[0m"
        echo -e "\033[1;35m╚══════════════════════════════════════════════════════════════╝\033[0m"
        echo -e "\033[1;36mTotal files scanned:\033[0m $total_files"
        echo -e "\033[1;36mFiles with issues:\033[0m $files_with_issues"
    fi

    if [ $files_with_issues -eq 0 ]; then
        if [ "$QUIET_MODE" = false ]; then
            echo -e "\033[1;32m✓ No dangerous Unicode characters detected!\033[0m"
        fi
        exit 0
    else
        if [ "$QUIET_MODE" = false ]; then
            echo -e "\033[1;31m⚠ Found dangerous Unicode characters in $files_with_issues file(s)\033[0m"
        fi
        exit 1
    fi
fi