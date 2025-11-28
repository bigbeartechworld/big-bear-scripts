#!/usr/bin/env bash

# Automated Test Runner for Unicode Security Scanner
# Tests both clean files (should pass) and malicious files (should detect threats)

# Don't exit on error - we need to check exit codes
set +e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCANNER="${SCRIPT_DIR}/../run.sh"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

passed=0
failed=0
total=0

echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║          Unicode Security Scanner - Test Suite              ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Test clean files (should exit 0 - no threats detected)
echo -e "${YELLOW}Testing clean files (expecting no detections)...${NC}"
for file in "${SCRIPT_DIR}"/*clean*.js; do
    ((total++))
    filename=$(basename "$file")
    if "$SCANNER" "$file" > /dev/null 2>&1; then
        echo -e "  ${GREEN}✓ PASS${NC}: $filename (no detections)"
        ((passed++))
    else
        echo -e "  ${RED}✗ FAIL${NC}: $filename (unexpected detections or error)"
        ((failed++))
    fi
done

echo ""

# Test emoji files with --exclude-emojis flag (should exit 0 - emojis excluded)
echo -e "${YELLOW}Testing emoji UI files with --exclude-emojis flag...${NC}"
for file in "${SCRIPT_DIR}"/*emoji*.jsx "${SCRIPT_DIR}"/*emoji*.js; do
    if [ -f "$file" ]; then
        ((total++))
        filename=$(basename "$file")
        if "$SCANNER" --exclude-emojis "$file" > /dev/null 2>&1; then
            echo -e "  ${GREEN}✓ PASS${NC}: $filename (emojis excluded, no threats)"
            ((passed++))
        else
            echo -e "  ${RED}✗ FAIL${NC}: $filename (unexpected detection with --exclude-emojis)"
            ((failed++))
        fi
    fi
done

echo ""

# Test documentation with --exclude-common flag (should exit 0 - common Unicode excluded)
echo -e "${YELLOW}Testing documentation with --exclude-common flag...${NC}"
for file in "${SCRIPT_DIR}"/*docs*.md "${SCRIPT_DIR}"/*typography*; do
    if [ -f "$file" ]; then
        ((total++))
        filename=$(basename "$file")
        if "$SCANNER" --exclude-common "$file" > /dev/null 2>&1; then
            echo -e "  ${GREEN}✓ PASS${NC}: $filename (common Unicode excluded)"
            ((passed++))
        else
            echo -e "  ${RED}✗ FAIL${NC}: $filename (unexpected detection with --exclude-common)"
            ((failed++))
        fi
    fi
done

echo ""

# Test malicious files (should exit 1 - threats detected)
echo -e "${YELLOW}Testing malicious files (expecting threat detections)...${NC}"
for file in "${SCRIPT_DIR}"/*injection* "${SCRIPT_DIR}"/*trojan*; do
    if [ -f "$file" ]; then
        ((total++))
        filename=$(basename "$file")
        if "$SCANNER" "$file" > /dev/null 2>&1; then
            echo -e "  ${RED}✗ FAIL${NC}: $filename (missed threats - no detections)"
            ((failed++))
        else
            exit_code=$?
            if [ $exit_code -eq 1 ]; then
                echo -e "  ${GREEN}✓ PASS${NC}: $filename (threats detected)"
                ((passed++))
            else
                echo -e "  ${RED}✗ FAIL${NC}: $filename (unexpected exit code: $exit_code)"
                ((failed++))
            fi
        fi
    fi
done

echo ""

# Test binary file handling
echo -e "${YELLOW}Testing binary file handling...${NC}"
if [ -f "${SCRIPT_DIR}/test.jar" ]; then
    ((total++))
    # Test that binary files are skipped by default
    if "$SCANNER" "${SCRIPT_DIR}/test.jar" 2>&1 | grep -q "Skipping.*binary"; then
        echo -e "  ${GREEN}✓ PASS${NC}: test.jar (binary file skipped by default)"
        ((passed++))
    else
        echo -e "  ${RED}✗ FAIL${NC}: test.jar (binary file was not skipped)"
        ((failed++))
    fi
    
    ((total++))
    # Test that binary files are scanned with --include-binary
    if "$SCANNER" --include-binary "${SCRIPT_DIR}/test.jar" 2>&1 | grep -q "Scanning.*test.jar"; then
        echo -e "  ${GREEN}✓ PASS${NC}: test.jar (binary file scanned with --include-binary)"
        ((passed++))
    else
        echo -e "  ${RED}✗ FAIL${NC}: test.jar (binary file not scanned with --include-binary)"
        ((failed++))
    fi
fi

echo ""

# Test allowlist functionality
echo -e "${YELLOW}Testing allowlist functionality...${NC}"

# Create a temp file with allowlisted dangerous Unicode
ALLOWLIST_TEST_FILE="${SCRIPT_DIR}/allowlist-test-temp.txt"
cat > "$ALLOWLIST_TEST_FILE" << 'EOF'
# This file has zero-width space and Cyrillic 'a' which are allowlisted
Test with zero-width: test​word
Test with Cyrillic a: аdmin
EOF

if [ -f "${SCRIPT_DIR}/.unicode-allowlist-test" ]; then
    ((total++))
    # Test that allowlisted characters are NOT detected
    if "$SCANNER" --allowlist "${SCRIPT_DIR}/.unicode-allowlist-test" "$ALLOWLIST_TEST_FILE" > /dev/null 2>&1; then
        echo -e "  ${GREEN}✓ PASS${NC}: allowlist-test (allowlisted characters ignored)"
        ((passed++))
    else
        echo -e "  ${RED}✗ FAIL${NC}: allowlist-test (allowlisted characters still detected)"
        ((failed++))
    fi
    
    ((total++))
    # Test that same file WITHOUT allowlist DOES detect the characters
    if "$SCANNER" "$ALLOWLIST_TEST_FILE" > /dev/null 2>&1; then
        echo -e "  ${RED}✗ FAIL${NC}: allowlist-verify (dangerous chars not detected without allowlist)"
        ((failed++))
    else
        echo -e "  ${GREEN}✓ PASS${NC}: allowlist-verify (dangerous chars detected without allowlist)"
        ((passed++))
    fi
fi

# Test range syntax in allowlist
RANGE_ALLOWLIST="${SCRIPT_DIR}/.allowlist-range-test"
cat > "$RANGE_ALLOWLIST" << 'EOF'
# Allow all basic Cyrillic (U+0400-U+04FF)
U+0400-U+04FF
EOF

# Create a test file with ONLY Cyrillic characters (no other dangerous Unicode)
CYRILLIC_TEST_FILE="${SCRIPT_DIR}/cyrillic-only-temp.txt"
cat > "$CYRILLIC_TEST_FILE" << 'EOF'
# This file only has Cyrillic lookalikes
Test with Cyrillic a: аdmin
Test with Cyrillic e: еmail
EOF

((total++))
# Test that range allowlist works (Cyrillic-only file should pass)
if "$SCANNER" --allowlist "$RANGE_ALLOWLIST" "$CYRILLIC_TEST_FILE" > /dev/null 2>&1; then
    echo -e "  ${GREEN}✓ PASS${NC}: range-allowlist (Cyrillic range allowed)"
    ((passed++))
else
    echo -e "  ${RED}✗ FAIL${NC}: range-allowlist (Cyrillic range not working)"
    ((failed++))
fi

# Test inline comments in allowlist
INLINE_ALLOWLIST="${SCRIPT_DIR}/.allowlist-inline-test"
cat > "$INLINE_ALLOWLIST" << 'EOF'
U+200B  # Zero-width space for i18n purposes
0430    # Cyrillic small a - needed for Russian text
EOF

((total++))
if "$SCANNER" --allowlist "$INLINE_ALLOWLIST" "$ALLOWLIST_TEST_FILE" > /dev/null 2>&1; then
    echo -e "  ${GREEN}✓ PASS${NC}: inline-comments (allowlist with inline comments works)"
    ((passed++))
else
    echo -e "  ${RED}✗ FAIL${NC}: inline-comments (allowlist with inline comments failed)"
    ((failed++))
fi

# Cleanup temp files
rm -f "$ALLOWLIST_TEST_FILE" "$RANGE_ALLOWLIST" "$INLINE_ALLOWLIST" "$CYRILLIC_TEST_FILE"

echo ""

# Test that malicious files are STILL caught even with exclusion flags
echo -e "${YELLOW}Testing malicious files with exclusion flags (should still detect)...${NC}"
for file in "${SCRIPT_DIR}"/*injection* "${SCRIPT_DIR}"/*trojan*; do
    if [ -f "$file" ]; then
        ((total++))
        filename=$(basename "$file")
        if "$SCANNER" --exclude-emojis --exclude-common "$file" > /dev/null 2>&1; then
            echo -e "  ${RED}✗ FAIL${NC}: $filename (missed threats with exclusions)"
            ((failed++))
        else
            exit_code=$?
            if [ $exit_code -eq 1 ]; then
                echo -e "  ${GREEN}✓ PASS${NC}: $filename (threats still detected despite exclusions)"
                ((passed++))
            else
                echo -e "  ${RED}✗ FAIL${NC}: $filename (unexpected exit code: $exit_code)"
                ((failed++))
            fi
        fi
    fi
done

echo ""
echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                        Test Results                          ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
echo -e "Total tests:  $total"
echo -e "${GREEN}Passed:       $passed${NC}"
if [ $failed -gt 0 ]; then
    echo -e "${RED}Failed:       $failed${NC}"
else
    echo -e "Failed:       $failed"
fi
echo ""

if [ $failed -eq 0 ]; then
    echo -e "${GREEN}✓ All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}✗ Some tests failed${NC}"
    exit 1
fi
