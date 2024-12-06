#!/bin/bash

# Function to print header
print_header() {
    echo "================================================"
    echo "$1"
    echo "================================================"
    echo
}

# Colors for better visibility
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to display menu
show_menu() {
    clear
    print_header "Big Bear Interactive Rsync V0.0.1"

    echo "Here are some links:"
    echo "https://community.bigbeartechworld.com"
    echo "https://github.com/BigBearTechWorld"
    echo ""
    echo "If you would like to support me, please consider buying me a tea:"
    echo "https://ko-fi.com/bigbeartechworld"
    echo ""
}

# Set source directory to current directory if not provided
SOURCE_DIR="${1:-.}"

# Check if source directory exists
if [ ! -d "$SOURCE_DIR" ]; then
    show_menu
    echo -e "${RED}Error: Source directory '$SOURCE_DIR' does not exist${NC}"
    exit 1
fi

# Function to display numbered list of files/directories
display_items() {
    local dir="$1"
    local i=1
    
    show_menu
    echo -e "\n${GREEN}Available items in $dir:${NC}"
    echo "--------------------------------"
    
    # Store items in an array
    items=()
    while IFS= read -r item; do
        items+=("$item")
        echo -e "${YELLOW}$i)${NC} $item"
        ((i++))
    done < <(ls -A "$dir")
}

# Function to get selected items
get_selections() {
    local selections=()
    local done=false
    
    while [ "$done" = false ]; do
        echo -e "\nEnter the numbers of items you want to sync (space-separated)"
        echo "Or press Enter when done, 'a' for all, 'q' to quit"
        read -r input
        
        # Convert to lowercase
        input=$(echo "$input" | tr '[:upper:]' '[:lower:]')
        
        case "$input" in
            "q")
                show_menu
                echo "Quitting..."
                exit 0
                ;;
            "a")
                echo "Selected all items"
                selections=("${items[@]}")
                done=true
                ;;
            "")
                if [ ${#selections[@]} -gt 0 ]; then
                    done=true
                else
                    echo -e "${RED}No items selected. Please select at least one item.${NC}"
                fi
                ;;
            *)
                selections=()
                valid_selections=true
                for num in $input; do
                    if [[ "$num" =~ ^[0-9]+$ ]] && [ "$num" -ge 1 ] && [ "$num" -le ${#items[@]} ]; then
                        selections+=("${items[$((num-1))]}")
                    else
                        echo -e "${RED}Invalid selection: $num${NC}"
                        valid_selections=false
                        break
                    fi
                done
                if [ "$valid_selections" = true ]; then
                    done=true
                fi
                ;;
        esac
    done
    
    show_menu
    echo -e "\n${GREEN}Selected items:${NC}"
    printf '%s\n' "${selections[@]}"
    
    # Ask for destination
    echo -e "\n${GREEN}Enter destination path:${NC}"
    read -r destination
    
    # Validate destination
    if [ -z "$destination" ]; then
        echo -e "${RED}Error: Destination cannot be empty${NC}"
        exit 1
    fi
    
    # Create destination if it doesn't exist
    mkdir -p "$destination"
    
    # Perform rsync for each selected item
    for item in "${selections[@]}"; do
        echo -e "\n${GREEN}Syncing: $item${NC}"
        rsync -av --info=progress2 "$SOURCE_DIR/$item" "$destination/"
    done
}

# Main execution
display_items "$SOURCE_DIR"
get_selections
