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

# Function to get file size in human readable format
get_size() {
    local size
    size=$(du -sh "$1" 2>/dev/null | cut -f1)
    echo "${size:-0B}"
}

# Function to confirm action
confirm_action() {
    local message="$1"
    local response
    
    echo -e "\n${YELLOW}$message${NC} (y/n): "
    read -r response
    
    case "$response" in
        [yY]|[yY][eE][sS]) return 0 ;;
        *) return 1 ;;
    esac
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
    sizes=()
    while IFS= read -r item; do
        items+=("$item")
        sizes+=("$(get_size "$dir/$item")")
        echo -e "${YELLOW}$i)${NC} $item (${sizes[$((i-1))]})"
        ((i++))
    done < <(ls -A "$dir")
}

# Function to get selected items
get_selections() {
    local selections=()
    local selection_sizes=()
    local done=false
    local exclude_pattern=""
    
    # Ask for exclude pattern
    echo -e "\n${GREEN}Enter file patterns to exclude (e.g., '*.tmp *.log', or press Enter for none):${NC}"
    read -r exclude_pattern
    
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
                selection_sizes=("${sizes[@]}")
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
                selection_sizes=()
                valid_selections=true
                for num in $input; do
                    if [[ "$num" =~ ^[0-9]+$ ]] && [ "$num" -ge 1 ] && [ "$num" -le ${#items[@]} ]; then
                        selections+=("${items[$((num-1))]}")
                        selection_sizes+=("${sizes[$((num-1))]}")
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
    local total_count=${#selections[@]}
    echo -e "${YELLOW}Total files/directories: $total_count${NC}"
    
    for i in "${!selections[@]}"; do
        echo "${selections[$i]} (${selection_sizes[$i]})"
    done
    
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
    
    # Confirm transfer
    if ! confirm_action "Start transfer of $total_count items to $destination?"; then
        echo -e "${YELLOW}Transfer cancelled${NC}"
        exit 0
    fi
    
    # Prepare rsync exclude options
    local exclude_opts=""
    if [ -n "$exclude_pattern" ]; then
        for pattern in $exclude_pattern; do
            exclude_opts="$exclude_opts --exclude='$pattern'"
        done
    fi
    
    # Perform rsync for each selected item
    local success_count=0
    local failed_items=()
    
    for item in "${selections[@]}"; do
        echo -e "\n${GREEN}Syncing: $item${NC}"
        if eval rsync -av --info=progress2 $exclude_opts \""$SOURCE_DIR/$item"\" \""$destination/"\"; then
            ((success_count++))
        else
            failed_items+=("$item")
        fi
    done
    
    # Show summary
    echo -e "\n${GREEN}Transfer Summary:${NC}"
    echo -e "Successfully transferred: $success_count/$total_count"
    
    if [ ${#failed_items[@]} -gt 0 ]; then
        echo -e "\n${RED}Failed transfers:${NC}"
        printf '%s\n' "${failed_items[@]}"
    fi
}

# Main execution
display_items "$SOURCE_DIR"
get_selections
