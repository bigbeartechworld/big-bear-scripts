#!/usr/bin/env bash

# Automated Test Runner for Unicode Security Scanner
# Tests both clean files (should pass) and malicious files (should detect threats)

set -e

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
