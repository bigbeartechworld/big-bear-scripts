#!/usr/bin/env bash

# Unicode Security Scanner
# Detects dangerous Unicode characters that can be used in security attacks
# Including Trojan Source attacks (CVE-2021-42574) and other invisible characters

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
)

if [ $# -eq 0 ]; then
    echo -e "\033[1;31mError:\033[0m No target specified"
    echo -e "\033[1;33mUsage:\033[0m $0 <file/directory>"
    echo -e "\033[1;36mExample:\033[0m $0 ./src/"
    echo -e "\033[1;36mExample:\033[0m $0 script.py"
    exit 1
fi

target="$1"

echo -e "\033[1;35m╔══════════════════════════════════════════════════════════════╗\033[0m"
echo -e "\033[1;35m║            Big Bear Unicode Security Scanner 1.0.1           ║\033[0m"
echo -e "\033[1;35m║             Detecting dangerous Unicode characters           ║\033[0m"
echo -e "\033[1;35m║                       Please support me!                     ║\033[0m"
echo -e "\033[1;35m║               https://ko-fi.com/bigbeartechworld             ║\033[0m"
echo -e "\033[1;35m║                           Thank you!                         ║\033[0m"
echo -e "\033[1;35m║                  https://bigbeartechworld.com                ║\033[0m"
echo -e "\033[1;35m╚══════════════════════════════════════════════════════════════╝\033[0m"
echo

# Initialize counters for summary
total_files=0
files_with_issues=0

# Single file search function
search_file() {
    file="$1"
    echo -e "\n\033[1;34mScanning:\033[0m $file"
    
    # Check file encoding - be more lenient with ASCII files
    file_info=$(file -bi "$file")
    if ! echo "$file_info" | grep -qE '(utf-8|us-ascii)'; then
        echo -e "  \033[1;33mWarning:\033[0m Non-UTF8 file detected ($file_info)"
    fi

    found_any=false
    
    # Convert file to hex for pattern matching
    hex_content=$(hexdump -ve '1/1 "%.2x"' "$file" 2>/dev/null)
    
    if [ -z "$hex_content" ]; then
        echo -e "  \033[1;33mWarning:\033[0m Could not read file as binary"
        ((total_files++))
        return
    fi
    
    # Search for each harmful pattern
    for pattern_info in "${harmful_patterns[@]}"; do
        IFS=':' read -r hex_pattern unicode_code description <<< "$pattern_info"
        
        if echo "$hex_content" | grep -q "$hex_pattern"; then
            if [ "$found_any" = false ]; then
                echo -e "  \033[1;31m[!] Dangerous Unicode characters found:\033[0m"
                found_any=true
                ((files_with_issues++))
            fi
            
            echo -e "      \033[1;91mU+$unicode_code\033[0m ($description)"
            
            # Find line numbers by searching the original file
            # Create a temporary file with the actual Unicode character for line matching
            temp_char=$(echo "$hex_pattern" | sed 's/../\\x&/g')
            line_matches=$(grep -n "$(printf "$temp_char")" "$file" 2>/dev/null || echo "")
            
            if [ -n "$line_matches" ]; then
                echo "$line_matches" | while IFS=':' read -r line_num line_content; do
                    echo -e "        \033[36mLine $line_num:\033[0m $line_content"
                done
            else
                echo -e "        \033[33m(Character found but line detection failed)\033[0m"
            fi
            echo
        fi
    done
    
    if [ "$found_any" = false ]; then
        echo -e "  \033[1;32m✓ No dangerous Unicode characters found\033[0m"
    fi
    
    ((total_files++))
}

# Handle directories recursively
if [ -d "$target" ]; then
    # Use a simpler approach - collect all files first, then process them
    echo "Collecting files..."
    file_list=$(find "$target" -type f)
    
    while IFS= read -r file; do
        if [ -n "$file" ]; then
            search_file "$file"
        fi
    done <<< "$file_list"
else
    search_file "$target"
fi

# Print summary
echo -e "\n\033[1;35m╔══════════════════════════════════════════════════════════════╗\033[0m"
echo -e "\033[1;35m║                           Summary                            ║\033[0m"
echo -e "\033[1;35m╚══════════════════════════════════════════════════════════════╝\033[0m"
echo -e "\033[1;36mTotal files scanned:\033[0m $total_files"
echo -e "\033[1;36mFiles with issues:\033[0m $files_with_issues"

if [ $files_with_issues -eq 0 ]; then
    echo -e "\033[1;32m✓ No dangerous Unicode characters detected!\033[0m"
    exit 0
else
    echo -e "\033[1;31m⚠ Found dangerous Unicode characters in $files_with_issues file(s)\033[0m"
    exit 1
fi