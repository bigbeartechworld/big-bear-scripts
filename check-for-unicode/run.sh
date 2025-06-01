#!/usr/bin/env bash

# List of dangerous Unicode characters for AI systems and security
harmful_unicodes=(
    # Zero-width and invisible characters
    "\u200B"  # Zero Width Space
    "\u200C"  # Zero Width Non-Joiner
    "\u200D"  # Zero Width Joiner
    "\u2060"  # Word Joiner
    "\u2061"  # Function Application
    "\u2062"  # Invisible Times
    "\u2063"  # Invisible Separator
    "\u2064"  # Invisible Plus
    "\uFEFF"  # Zero Width No-Break Space (BOM)
    "\u034F"  # Combining Grapheme Joiner
    
    # Bidirectional text controls (Trojan Source attacks - CVE-2021-42574)
    "\u202A"  # Left-to-Right Embedding
    "\u202B"  # Right-to-Left Embedding
    "\u202C"  # Pop Directional Formatting
    "\u202D"  # Left-to-Right Override
    "\u202E"  # Right-to-Left Override
    "\u2066"  # Left-to-Right Isolate
    "\u2067"  # Right-to-Left Isolate
    "\u2068"  # First Strong Isolate
    "\u2069"  # Pop Directional Isolate
    "\u061C"  # Arabic Letter Mark
    "\u200E"  # Left-to-Right Mark
    "\u200F"  # Right-to-Left Mark
    
    # Annotation and formatting characters
    "\uFFF9"  # Interlinear Annotation Anchor
    "\uFFFA"  # Interlinear Annotation Separator
    "\uFFFB"  # Interlinear Annotation Terminator
    "\uFFFC"  # Object Replacement Character
    "\uFFFD"  # Replacement Character
    
    # Line and paragraph separators
    "\u2028"  # Line Separator
    "\u2029"  # Paragraph Separator
    
    # Additional format characters
    "\u00AD"  # Soft Hyphen
    "\u115F"  # Hangul Choseong Filler
    "\u1160"  # Hangul Jungseong Filler
    "\u17B4"  # Khmer Vowel Inherent Aq
    "\u17B5"  # Khmer Vowel Inherent Aa
    "\u180E"  # Mongolian Vowel Separator
    "\u3164"  # Hangul Filler
    
    # Variation selectors (can change character appearance)
    "\uFE00"  # Variation Selector-1
    "\uFE01"  # Variation Selector-2
    "\uFE02"  # Variation Selector-3
    "\uFE03"  # Variation Selector-4
    "\uFE04"  # Variation Selector-5
    "\uFE05"  # Variation Selector-6
    "\uFE06"  # Variation Selector-7
    "\uFE07"  # Variation Selector-8
    "\uFE08"  # Variation Selector-9
    "\uFE09"  # Variation Selector-10
    "\uFE0A"  # Variation Selector-11
    "\uFE0B"  # Variation Selector-12
    "\uFE0C"  # Variation Selector-13
    "\uFE0D"  # Variation Selector-14
    "\uFE0E"  # Variation Selector-15
    "\uFE0F"  # Variation Selector-16
)

if [ $# -eq 0 ]; then
    echo "Usage: $0 <file/directory>"
    exit 1
fi

target="$1"

search_file() {
    file="$1"
    echo "Scanning: $file"
    
    # Check file encoding
    if ! file -bi "$file" | grep -q 'utf-8'; then
        echo "  Warning: Non-UTF8 file detected"
    fi

    # Search for each harmful character
    for code in "${harmful_unicodes[@]}"; do
        if grep --perl-regexp -q "$code" "$file"; then
            hex=$(printf "%04x" "0x${code:2:4}")
            echo "  [!] Found dangerous Unicode: U+$hex"
        fi
    done
}

export -f search_file
export harmful_unicodes

# Handle directories recursively
if [ -d "$target" ]; then
    find "$target" -type f -exec bash -c 'search_file "$0"' {} \;
else
    search_file "$target"
fi