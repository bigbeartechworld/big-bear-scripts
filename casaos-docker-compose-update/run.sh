#!/bin/bash

MESSAGE="Made by BigBearTechWorld"

# Function to print a decorative line
print_decorative_line() {
    printf "%s\n" "------------------------------------------------------"
}

# Print the introduction message with decorations
echo
print_decorative_line
echo "CasaOS Docker Compose update script"
print_decorative_line
echo
echo "$MESSAGE"
echo
print_decorative_line
echo
echo "If this is useful, please consider supporting my work at: https://ko-fi.com/bigbeartechworld"
echo
print_decorative_line

# Check if jq is installed
if ! command -v jq &> /dev/null; then
    read -p "jq is not installed. Do you want to install it? (y/N) " choice
    if [[ $choice == "y" || $choice == "Y" ]]; then
        sudo apt update
        sudo apt install -y jq
    else
        echo "jq is required for this script. Exiting."
        exit 1
    fi
fi

# Check if yq is installed
if ! command -v yq &> /dev/null; then
    read -p "yq is not installed. Do you want to install it? (y/N) " choice
    if [[ $choice == "y" || $choice == "Y" ]]; then
        # Determine system architecture
        ARCH=$(uname -m)
        if [[ "$ARCH" == "x86_64" ]]; then
            BINARY="yq_linux_amd64"
        elif [[ "$ARCH" == "aarch64" ]]; then
            BINARY="yq_linux_arm64"
        else
            echo "Unsupported architecture. Exiting."
            exit 1
        fi

        # Fetch the latest version of yq
        VERSION=$(curl -s https://api.github.com/repos/mikefarah/yq/releases/latest | jq -r '.tag_name')

        # Download and install yq
        wget "https://github.com/mikefarah/yq/releases/download/${VERSION}/${BINARY}.tar.gz" -O - |\
        tar xz && sudo mv ${BINARY} /usr/bin/yq
    else
        echo "yq is required for this script. Exiting."
        exit 1
    fi
fi

# Check if skopeo is installed
if ! command -v skopeo &> /dev/null; then
    read -p "skopeo is not installed. Do you want to install it? (y/N) " choice
    if [[ $choice == "y" || $choice == "Y" ]]; then
        sudo apt update
        sudo apt install -y skopeo
    else
        echo "skopeo is required for this script. Exiting."
        exit 1
    fi
fi

# Function to compare semantic version numbers
compare_versions() {
    # Extract numeric part and suffix (if exists) from version strings
    VER1_NUMERIC=$(echo "$1" | sed -E 's/([0-9.]+).*/\1/')
    VER1_SUFFIX=$(echo "$1" | sed -E 's/[0-9.]+//')
    VER2_NUMERIC=$(echo "$2" | sed -E 's/([0-9.]+).*/\1/')
    VER2_SUFFIX=$(echo "$2" | sed -E 's/[0-9.]+//')

    IFS='.' read -ra NUM1 <<< "$VER1_NUMERIC"
    IFS='.' read -ra NUM2 <<< "$VER2_NUMERIC"

    for i in "${!NUM1[@]}"; do
        if [[ -z "${NUM2[i]}" ]]; then
            NUM2[i]=0
        fi

        # Ensure the segments are numeric before comparing
        if [[ "${NUM1[i]}" =~ ^[0-9]+$ && "${NUM2[i]}" =~ ^[0-9]+$ ]]; then
            if ((10#${NUM1[i]} > 10#${NUM2[i]})); then
                return 0
            elif ((10#${NUM1[i]} < 10#${NUM2[i]})); then
                return 1
            fi
        fi
    done

    # If numeric parts are the same, compare the suffixes
    if [[ "$VER1_SUFFIX" > "$VER2_SUFFIX" ]]; then
        return 0
    elif [[ "$VER1_SUFFIX" < "$VER2_SUFFIX" ]]; then
        return 1
    fi

    return 2
}

BASE_DIR="/var/lib/casaos/apps"

# Loop through all directories in BASE_DIR
for DIR in $BASE_DIR/*/; do

    # Construct the path to the Docker Compose file in the current directory
    FILE="${DIR}docker-compose.yml"

    if [[ -f $FILE ]]; then
        SERVICE_NAME=$(yq eval '.name' $FILE)
        FULL_IMAGE_NAME=$(yq eval '.services.*.image' $FILE)
        IMAGE_NAME=$(echo $FULL_IMAGE_NAME | cut -d':' -f1)
        CURRENT_TAG=$(echo $FULL_IMAGE_NAME | cut -d':' -f2)

        # Fetch tags containing numbers for the image using skopeo
        ALL_TAGS=$(skopeo list-tags docker://$IMAGE_NAME | jq -r '.Tags[]' | grep '[0-9]')

        # Sort tags using version sort and reverse the order to have latest first
        SORTED_TAGS=$(echo "$ALL_TAGS" | sort -Vr)

        # Extract version and variant from current tag
        CURRENT_VERSION=$(echo $CURRENT_TAG | grep -oE '^[0-9]+\.[0-9]+\.[0-9]+')
        CURRENT_VARIANT=$(echo $CURRENT_TAG | sed "s/$CURRENT_VERSION//")

        # Get the latest 30 tags
        NUMERIC_TAGS=$(echo "$SORTED_TAGS" | grep -E '^[0-9]+\.[0-9]+\.[0-9]+.*' | head -n 30)

        LATEST_NUMERIC_TAG_WITH_VARIANT=""
        LATEST_NUMERIC_TAG=""
        for TAG in $NUMERIC_TAGS; do
            if [[ "$TAG" == *"$CURRENT_VARIANT"* ]]; then
                LATEST_NUMERIC_TAG_WITH_VARIANT="$TAG"
                LATEST_NUMERIC_TAG="${TAG%%$CURRENT_VARIANT}"
            fi

            # Check if both tags have been found and exit the loop
            if [[ -n "$LATEST_NUMERIC_TAG_WITH_VARIANT" && -n "$LATEST_NUMERIC_TAG" ]]; then
                break
            fi
        done

        # If the Docker Compose file uses the 'latest' tag
        if [[ "$CURRENT_TAG" == "latest" ]]; then
            read -p "The image $IMAGE_NAME is using the 'latest' tag. Do you want to switch to a specific tag? (y/N) " choice
            if [[ $choice == "y" || $choice == "Y" ]]; then
                echo "Available numeric tags for $IMAGE_NAME:"
                select TAG in $NUMERIC_TAGS; do
                    if [[ -n $TAG ]]; then
                        yq eval -i ".services.*.image = \"$IMAGE_NAME:$TAG\"" $FILE
                        echo "Updated $FILE with tag $TAG"

                        # Run the casaos-cli command
                        casaos-cli app-management apply $SERVICE_NAME --file=/var/lib/casaos/apps/$SERVICE_NAME/docker-compose.yml
                        echo "Applying changes to $SERVICE_NAME..."
                        break
                    else
                        echo "Invalid choice. Try again."
                    fi
                done
            else
                echo "Skipping $IMAGE_NAME..."
            fi
        # If the Docker Compose file uses a specific tag
        else
            compare_versions "$CURRENT_TAG" "$LATEST_NUMERIC_TAG"
            RESULT=$?
            if [[ $RESULT -eq 1 ]]; then
                echo "Current tag for $IMAGE_NAME is $CURRENT_TAG. Newer numeric tags available:"
                select TAG in $NUMERIC_TAGS "Skip and proceed to next container"; do
                    if [[ $TAG == "Skip and proceed to next container" ]]; then
                        echo "Skipping $IMAGE_NAME and proceeding to next container..."
                        break # Breaks the select loop and continues with the next iteration of the for loop
                    elif [[ -n $TAG ]]; then
                        yq eval -i ".services.*.image = \"$IMAGE_NAME:$TAG\"" $FILE
                        echo "Updated $FILE with tag $TAG"

                        # Run the casaos-cli command
                        casaos-cli app-management apply $SERVICE_NAME --file=/var/lib/casaos/apps/$SERVICE_NAME/docker-compose.yml
                        echo "Applying changes to $SERVICE_NAME..."
                        break
                    else
                        echo "Invalid choice. Try again."
                    fi
                done
            else
                echo "The image $IMAGE_NAME is up-to-date with the tag $CURRENT_TAG."
            fi
        fi
    fi
done
