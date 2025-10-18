#!/usr/bin/env bash
#
# This script includes functionality to automatically check SSL certificate validity.
# SSL certificate verification will only be disabled if necessary for problematic domains.
#
#           CasaOS Installer Script v0.4.15#
#   GitHub: https://github.com/IceWhaleTech/CasaOS
#   Issues: https://github.com/IceWhaleTech/CasaOS/issues
#   Requires: bash, mv, rm, tr, grep, sed, curl/wget, tar, smartmontools, parted, ntfs-3g, net-tools
#
#   This script installs CasaOS to your system.
#   Usage:
#
#   	$ wget -qO- https://get.casaos.io/ | bash
#   	  or
#   	$ curl -fsSL https://get.casaos.io/ | bash
#
#   In automated environments, you may want to run as root.
#   If using curl, we recommend using the -fsSL flags.
#
#   This only work on  Linux systems. Please
#   open an issue if you notice any bugs.
#
clear
echo -e "\e[0m\c"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Display Welcome
echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}BigBear CasaOS Installer V0.4${NC}"
echo -e "${BLUE}========================================${NC}"
echo "Here are some links:"
echo "https://community.bigbeartechworld.com"
echo "https://github.com/BigBearTechWorld"
echo ""
echo "If you would like to support me, please consider buying me a tea:"
echo "https://ko-fi.com/bigbeartechworld"
echo ""

# Check if get.casaos.io certificates are valid
CHECK_SSL=true
NEED_SSL_BYPASS=false

Check_SSL_Certificate() {
  echo "Checking SSL certificate for get.casaos.io..."
  if curl -s -o /dev/null --connect-timeout 5 https://get.casaos.io/; then
    echo "Certificate for get.casaos.io is valid."
    NEED_SSL_BYPASS=false
  else
    echo "Certificate for get.casaos.io validation failed. Will bypass certificate verification."
    NEED_SSL_BYPASS=true

    # Security warning prompt
    echo -e "\e[91m"
    echo "╔════════════════════════ SECURITY WARNING ════════════════════════╗"
    echo "║                                                                  ║"
    echo "║  This script will disable SSL/TLS certificate verification for:  ║"
    echo "║    - get.casaos.io domain                                        ║"
    echo "║    - Rclone installation files                                   ║"
    echo "║                                                                  ║"
    echo "║  This is needed because certificate validation is failing for    ║"
    echo "║  these domains in your environment.                              ║"
    echo "║                                                                  ║"
    echo "║  Proceed if you understand that this targeted bypass is needed   ║"
    echo "║  for installation in your environment.                           ║"
    echo "║                                                                  ║"
    echo "╚══════════════════════════════════════════════════════════════════╝"
    echo -e "\e[0m"

    # Require explicit user confirmation
    read -p "Do you understand and accept these risks? (yes/no): " confirmation
    if [[ "${confirmation,,}" != "yes" ]]; then
        echo "Installation aborted by user."
        exit 1
    fi
  fi
}

# Run the SSL check if enabled
if [ "$CHECK_SSL" = true ]; then
  Check_SSL_Certificate
fi

# shellcheck disable=SC2016
echo '
   _____                 ____   _____
  / ____|               / __ \ / ____|
 | |     __ _ ___  __ _| |  | | (___
 | |    / _` / __|/ _` | |  | |\___ \
 | |___| (_| \__ \ (_| | |__| |____) |
  \_____\__,_|___/\__,_|\____/|_____/

   --- Made by IceWhale with YOU ---
'
export PATH=/usr/sbin:$PATH
export DEBIAN_FRONTEND=noninteractive

set -e

###############################################################################
# GOLBALS                                                                     #
###############################################################################

((EUID)) && sudo_cmd="sudo"

# shellcheck source=/dev/null
source /etc/os-release

# SYSTEM REQUIREMENTS
readonly MINIMUM_DISK_SIZE_GB="5"
readonly MINIMUM_MEMORY="400"
readonly MINIMUM_DOCKER_VERSION="20"
readonly CASA_DEPANDS_PACKAGE=('wget' 'curl' 'smartmontools' 'parted' 'ntfs-3g' 'net-tools' 'udevil' 'samba' 'cifs-utils' 'mergerfs' 'unzip')
readonly CASA_DEPANDS_COMMAND=('wget' 'curl' 'smartctl' 'parted' 'ntfs-3g' 'netstat' 'udevil' 'smbd' 'mount.cifs' 'mount.mergerfs' 'unzip')

# SYSTEM INFO
PHYSICAL_MEMORY=$(LC_ALL=C free -m | awk '/Mem:/ { print $2 }')
readonly PHYSICAL_MEMORY

FREE_DISK_BYTES=$(LC_ALL=C df -P / | tail -n 1 | awk '{print $4}')
readonly FREE_DISK_BYTES

readonly FREE_DISK_GB=$((FREE_DISK_BYTES / 1024 / 1024))

LSB_DIST=$( ([ -n "${ID_LIKE}" ] && echo "${ID_LIKE}") || ([ -n "${ID}" ] && echo "${ID}"))
readonly LSB_DIST

DIST=$(echo "${ID}")
readonly DIST

UNAME_M="$(uname -m)"
readonly UNAME_M

UNAME_U="$(uname -s)"
readonly UNAME_U

readonly CASA_CONF_PATH=/etc/casaos/gateway.ini
readonly CASA_UNINSTALL_URL="https://raw.githubusercontent.com/IceWhaleTech/get/main/casaos-uninstall"
readonly CASA_UNINSTALL_PATH=/usr/bin/casaos-uninstall

# REQUIREMENTS CONF PATH
# Udevil
readonly UDEVIL_CONF_PATH=/etc/udevil/udevil.conf
readonly DEVMON_CONF_PATH=/etc/conf.d/devmon

# COLORS
readonly COLOUR_RESET='\e[0m'
readonly aCOLOUR=(
    '\e[38;5;154m' # green  	| Lines, bullets and separators
    '\e[1m'        # Bold white	| Main descriptions
    '\e[90m'       # Grey		| Credits
    '\e[91m'       # Red		| Update notifications Alert
    '\e[33m'       # Yellow		| Emphasis
)

readonly GREEN_LINE=" ${aCOLOUR[0]}─────────────────────────────────────────────────────$COLOUR_RESET"
readonly GREEN_BULLET=" ${aCOLOUR[0]}-$COLOUR_RESET"
readonly GREEN_SEPARATOR="${aCOLOUR[0]}:$COLOUR_RESET"

# CASAOS VARIABLES
TARGET_ARCH=""
TMP_ROOT=/tmp/casaos-installer
REGION="UNKNOWN"
CASA_DOWNLOAD_DOMAIN="https://github.com/"

trap 'onCtrlC' INT
onCtrlC() {
    echo -e "${COLOUR_RESET}"
    exit 1
}

###############################################################################
# Helpers                                                                     #
###############################################################################

#######################################
# Custom printing function
# Globals:
#   None
# Arguments:
#   $1 0:OK   1:FAILED  2:INFO  3:NOTICE
#   message
# Returns:
#   None
#######################################

Show() {
    # OK
    if (($1 == 0)); then
        echo -e "${aCOLOUR[2]}[$COLOUR_RESET${aCOLOUR[0]}  OK  $COLOUR_RESET${aCOLOUR[2]}]$COLOUR_RESET $2"
    # FAILED
    elif (($1 == 1)); then
        echo -e "${aCOLOUR[2]}[$COLOUR_RESET${aCOLOUR[3]}FAILED$COLOUR_RESET${aCOLOUR[2]}]$COLOUR_RESET $2"
        exit 1
    # INFO
    elif (($1 == 2)); then
        echo -e "${aCOLOUR[2]}[$COLOUR_RESET${aCOLOUR[0]} INFO $COLOUR_RESET${aCOLOUR[2]}]$COLOUR_RESET $2"
    # NOTICE
    elif (($1 == 3)); then
        echo -e "${aCOLOUR[2]}[$COLOUR_RESET${aCOLOUR[4]}NOTICE$COLOUR_RESET${aCOLOUR[2]}]$COLOUR_RESET $2"
    fi
}

Warn() {
    echo -e "${aCOLOUR[3]}$1$COLOUR_RESET"
}

GreyStart() {
    echo -e "${aCOLOUR[2]}\c"
}

ColorReset() {
    echo -e "$COLOUR_RESET\c"
}

# Clear Terminal
Clear_Term() {

    # Without an input terminal, there is no point in doing this.
    [[ -t 0 ]] || return

    # Printing terminal height - 1 newlines seems to be the fastest method that is compatible with all terminal types.
    lines=$(tput lines) i newlines
    local lines

    for ((i = 1; i < ${lines% *}; i++)); do newlines+='\n'; done
    echo -ne "\e[0m$newlines\e[H"

}

# Check file exists
exist_file() {
    if [ -e "$1" ]; then
        return 1
    else
        return 2
    fi
}

###############################################################################
# FUNCTIONS                                                                   #
###############################################################################

# 0 Get download url domain
# To solve the problem that Chinese users cannot access github.
Get_Download_Url_Domain() {
    # Use ipconfig.io/country and https://ifconfig.io/country_code to get the country code
    REGION=$(${sudo_cmd} curl --connect-timeout 2 -s ipconfig.io/country || echo "")
    if [ "${REGION}" = "" ]; then
       REGION=$(${sudo_cmd} curl --connect-timeout 2 -s https://ifconfig.io/country_code || echo "")
    fi
    if [[ "${REGION}" = "China" ]] || [[ "${REGION}" = "CN" ]]; then
        CASA_DOWNLOAD_DOMAIN="https://casaos.oss-cn-shanghai.aliyuncs.com/"
    fi
}

# 1 Check Arch
Check_Arch() {
    case $UNAME_M in
    *aarch64*)
        TARGET_ARCH="arm64"
        ;;
    *64*)
        TARGET_ARCH="amd64"
        ;;
    *armv7*)
        TARGET_ARCH="arm-7"
        ;;
    *)
        Show 1 "Aborted, unsupported or unknown architecture: $UNAME_M"
        exit 1
        ;;
    esac
    Show 0 "Your hardware architecture is : $UNAME_M"
    CASA_PACKAGES=(
        "${CASA_DOWNLOAD_DOMAIN}IceWhaleTech/CasaOS-Gateway/releases/download/v0.4.9-alpha4/linux-${TARGET_ARCH}-casaos-gateway-v0.4.9-alpha4.tar.gz"
"${CASA_DOWNLOAD_DOMAIN}IceWhaleTech/CasaOS-MessageBus/releases/download/v0.4.4-3-alpha2/linux-${TARGET_ARCH}-casaos-message-bus-v0.4.4-3-alpha2.tar.gz"
"${CASA_DOWNLOAD_DOMAIN}IceWhaleTech/CasaOS-UserService/releases/download/v0.4.8/linux-${TARGET_ARCH}-casaos-user-service-v0.4.8.tar.gz"
"${CASA_DOWNLOAD_DOMAIN}IceWhaleTech/CasaOS-LocalStorage/releases/download/v0.4.4/linux-${TARGET_ARCH}-casaos-local-storage-v0.4.4.tar.gz"
"${CASA_DOWNLOAD_DOMAIN}IceWhaleTech/CasaOS-AppManagement/releases/download/v0.4.10-alpha2/linux-${TARGET_ARCH}-casaos-app-management-v0.4.10-alpha2.tar.gz"
"${CASA_DOWNLOAD_DOMAIN}IceWhaleTech/CasaOS/releases/download/v0.4.15/linux-${TARGET_ARCH}-casaos-v0.4.15.tar.gz"
"${CASA_DOWNLOAD_DOMAIN}IceWhaleTech/CasaOS-CLI/releases/download/v0.4.4-3-alpha1/linux-${TARGET_ARCH}-casaos-cli-v0.4.4-3-alpha1.tar.gz"
"${CASA_DOWNLOAD_DOMAIN}IceWhaleTech/CasaOS-UI/releases/download/v0.4.20/linux-all-casaos-v0.4.20.tar.gz"
"${CASA_DOWNLOAD_DOMAIN}IceWhaleTech/CasaOS-AppStore/releases/download/v0.4.5/linux-all-appstore-v0.4.5.tar.gz"
    )
}

# PACKAGE LIST OF CASAOS (make sure the services are in the right order)
CASA_SERVICES=(
    "casaos-gateway.service"
"casaos-message-bus.service"
"casaos-user-service.service"
"casaos-local-storage.service"
"casaos-app-management.service"
"rclone.service"
"casaos.service"  # must be the last one so update from UI can work
)

# 2 Check Distribution
Check_Distribution() {
    sType=0
    notice=""
    case $LSB_DIST in
    *debian*) ;;

    *ubuntu*) ;;

    *raspbian*) ;;

    *openwrt*)
        Show 1 "Aborted, OpenWrt cannot be installed using this script."
        exit 1
        ;;
    *alpine*)
        Show 1 "Aborted, Alpine installation is not yet supported."
        exit 1
        ;;
    *trisquel*) ;;

    *)
        sType=3
        notice="We have not tested it on this system and it may fail to install."
        ;;
    esac
    Show ${sType} "Your Linux Distribution is : ${DIST} ${notice}"

    if [[ ${sType} == 1 ]]; then
        select yn in "Yes" "No"; do
            case $yn in
            [yY][eE][sS] | [yY])
                Show 0 "Distribution check has been ignored."
                break
                ;;
            [nN][oO] | [nN])
                Show 1 "Already exited the installation."
                exit 1
                ;;
            esac
        done < /dev/tty # < /dev/tty is used to read the input from the terminal
    fi
}

# 3 Check OS
Check_OS() {
    if [[ $UNAME_U == *Linux* ]]; then
        Show 0 "Your System is : $UNAME_U"
    else
        Show 1 "This script is only for Linux."
        exit 1
    fi
}

# 4 Check Memory
Check_Memory() {
    if [[ "${PHYSICAL_MEMORY}" -lt "${MINIMUM_MEMORY}" ]]; then
        Show 1 "requires atleast 400MB physical memory."
        exit 1
    fi
    Show 0 "Memory capacity check passed."
}

# 5 Check Disk
Check_Disk() {
    if [[ "${FREE_DISK_GB}" -lt "${MINIMUM_DISK_SIZE_GB}" ]]; then
        echo -e "${aCOLOUR[4]}Recommended free disk space is greater than ${MINIMUM_DISK_SIZE_GB}GB, Current free disk space is ${aCOLOUR[3]}${FREE_DISK_GB}GB${COLOUR_RESET}${aCOLOUR[4]}.\nContinue installation?${COLOUR_RESET}"
        select yn in "Yes" "No"; do
            case $yn in
            [yY][eE][sS] | [yY])
                Show 0 "Disk capacity check has been ignored."
                break
                ;;
            [nN][oO] | [nN])
                Show 1 "Already exited the installation."
                exit 1
                ;;
            esac
        done < /dev/tty  # < /dev/tty is used to read the input from the terminal
    else
        Show 0 "Disk capacity check passed."
    fi
}

# Check Port Use
Check_Port() {
    TCPListeningnum=$(${sudo_cmd} netstat -an | grep ":$1 " | awk '$1 == "tcp" && $NF == "LISTEN" {print $0}' | wc -l)
    UDPListeningnum=$(${sudo_cmd} netstat -an | grep ":$1 " | awk '$1 == "udp" && $NF == "0.0.0.0:*" {print $0}' | wc -l)
    ((Listeningnum = TCPListeningnum + UDPListeningnum))
    if [[ $Listeningnum == 0 ]]; then
        echo "0"
    else
        echo "1"
    fi
}

# Get an available port
Get_Port() {
    CurrentPort=$(${sudo_cmd} cat ${CASA_CONF_PATH} | grep HttpPort | awk '{print $3}')
    if [[ $CurrentPort == "$Port" ]]; then
        for PORT in {80..65536}; do
            if [[ $(Check_Port "$PORT") == 0 ]]; then
                Port=$PORT
                break
            fi
        done
    else
        Port=$CurrentPort
    fi
}

# Update package

Update_Package_Resource() {
    Show 2 "Updating package manager..."
    GreyStart
    if [ -x "$(command -v apk)" ]; then
        ${sudo_cmd} apk update
    elif [ -x "$(command -v apt-get)" ]; then
        ${sudo_cmd} apt-get update -qq
    elif [ -x "$(command -v dnf)" ]; then
        ${sudo_cmd} dnf check-update
    elif [ -x "$(command -v zypper)" ]; then
        ${sudo_cmd} zypper update
    elif [ -x "$(command -v yum)" ]; then
        ${sudo_cmd} yum update
    fi
    ColorReset
    Show 0 "Update package manager complete."
}

# Install depends package
Install_Depends() {
    for ((i = 0; i < ${#CASA_DEPANDS_COMMAND[@]}; i++)); do
        cmd=${CASA_DEPANDS_COMMAND[i]}
        if [[ ! -x $(${sudo_cmd} which "$cmd") ]]; then
            packagesNeeded=${CASA_DEPANDS_PACKAGE[i]}
            Show 2 "Install the necessary dependencies: \e[33m$packagesNeeded \e[0m"
            GreyStart
            if [ -x "$(command -v apk)" ]; then
                ${sudo_cmd} apk add --no-cache "$packagesNeeded"
            elif [ -x "$(command -v apt-get)" ]; then
                ${sudo_cmd} apt-get -y -qq install "$packagesNeeded" --no-upgrade
            elif [ -x "$(command -v dnf)" ]; then
                ${sudo_cmd} dnf install "$packagesNeeded"
            elif [ -x "$(command -v zypper)" ]; then
                ${sudo_cmd} zypper install "$packagesNeeded"
            elif [ -x "$(command -v yum)" ]; then
                ${sudo_cmd} yum install -y "$packagesNeeded"
            elif [ -x "$(command -v pacman)" ]; then
                ${sudo_cmd} pacman -S "$packagesNeeded"
            elif [ -x "$(command -v paru)" ]; then
                ${sudo_cmd} paru -S "$packagesNeeded"
            else
                Show 1 "Package manager not found. You must manually install: \e[33m$packagesNeeded \e[0m"
            fi
            ColorReset
        fi
    done
}

Check_Dependency_Installation() {
    for ((i = 0; i < ${#CASA_DEPANDS_COMMAND[@]}; i++)); do
        cmd=${CASA_DEPANDS_COMMAND[i]}
        if [[ ! -x $(${sudo_cmd} which "$cmd") ]]; then
            packagesNeeded=${CASA_DEPANDS_PACKAGE[i]}
            Show 1 "Dependency \e[33m$packagesNeeded \e[0m installation failed, please try again manually!"
            exit 1
        fi
    done
}

# Check Docker running
Check_Docker_Running() {
    for ((i = 1; i <= 3; i++)); do
        sleep 3
        if [[ ! $(${sudo_cmd} systemctl is-active docker) == "active" ]]; then
            Show 1 "Docker is not running, try to start"
            ${sudo_cmd} systemctl start docker
        else
            break
        fi
    done
}

#Check Docker Installed and version
Check_Docker_Install() {
    if [[ -x "$(command -v docker)" ]]; then
        Docker_Version=$(${sudo_cmd} docker version --format '{{.Server.Version}}')
        if [[ $? -ne 0 ]]; then
            Install_Docker
        elif [[ ${Docker_Version:0:2} -lt "${MINIMUM_DOCKER_VERSION}" ]]; then
            Show 1 "Recommended minimum Docker version is \e[33m${MINIMUM_DOCKER_VERSION}.xx.xx\e[0m,\Current Docker version is \e[33m${Docker_Version}\e[0m,\nPlease uninstall current Docker and rerun the CasaOS installation script."
            exit 1
        else
            Show 0 "Current Docker version is ${Docker_Version}."
        fi
    else
        Install_Docker
    fi
}

# Check Docker installed
Check_Docker_Install_Final() {
    if [[ -x "$(command -v docker)" ]]; then
        Docker_Version=$(${sudo_cmd} docker version --format '{{.Server.Version}}')
        if [[ $? -ne 0 ]]; then
            Install_Docker
        elif [[ ${Docker_Version:0:2} -lt "${MINIMUM_DOCKER_VERSION}" ]]; then
            Show 1 "Recommended minimum Docker version is \e[33m${MINIMUM_DOCKER_VERSION}.xx.xx\e[0m,\Current Docker version is \e[33m${Docker_Version}\e[0m,\nPlease uninstall current Docker and rerun the CasaOS installation script."
            exit 1
        else
            Show 0 "Current Docker version is ${Docker_Version}."
            Check_Docker_Running
        fi
    else
        Show 1 "Installation failed, please run 'curl -fsSL https://get.docker.com | bash' and rerun the CasaOS installation script."
        exit 1
    fi
}

# Function to check and uninstall Docker from Snap
Check_Docker_Snap() {
    if command -v snap &> /dev/null && ${sudo_cmd} snap list docker &> /dev/null; then
        Show 2 "Docker is installed via Snap."
        echo -e "${aCOLOUR[4]}Snap-based Docker installations can cause compatibility issues with CasaOS.${COLOUR_RESET}"
        echo -e "${aCOLOUR[4]}It's recommended to uninstall the Snap version before proceeding.${COLOUR_RESET}"

        # Prompt for confirmation
        read -p "Do you want to uninstall the Snap version of Docker? [y/n]: " yn
        case $yn in
            [Yy]*)
                Show 2 "Uninstalling Docker from Snap..."
                GreyStart
                ${sudo_cmd} snap remove docker
                ColorReset
                Show 0 "Docker has been uninstalled from Snap."
                ;;
            [Nn]*)
                Show 3 "Skipping Docker uninstallation from Snap. This may cause issues with CasaOS."
                ;;
            *)
                Show 3 "Invalid response. Skipping Docker uninstallation from Snap."
                ;;
        esac
    else
        Show 2 "Docker is not installed via Snap, or Snap is not installed."
    fi
}

#Install Docker
Install_Docker() {
    Show 2 "Install the necessary dependencies: \e[33mDocker \e[0m"

    # Check if Docker is installed via Snap and handle it
    Check_Docker_Snap

    if [[ ! -d "${PREFIX}/etc/apt/sources.list.d" ]]; then
        ${sudo_cmd} mkdir -p "${PREFIX}/etc/apt/sources.list.d"
    fi
    GreyStart
    if [[ "${REGION}" = "China" ]] || [[ "${REGION}" = "CN" ]]; then
        ${sudo_cmd} curl -fsSL https://play.cuse.eu.org/get_docker.sh | bash -s docker --mirror Aliyun
    else
        ${sudo_cmd} curl -fsSL https://get.docker.com | bash
    fi
    ColorReset
    if [[ $? -ne 0 ]]; then
        Show 1 "Installation failed, please try again."
        exit 1
    else
        Check_Docker_Install_Final
    fi
}

#Install Rclone
Install_rclone_from_source() {
  # Use official installer when certificates are valid, otherwise use direct download
  if [[ "$NEED_SSL_BYPASS" != true ]]; then
    Show 2 "Using official Rclone installer..."

    ${sudo_cmd} wget -qO ./install.sh https://rclone.org/install.sh
    if [[ "${REGION}" = "China" ]] || [[ "${REGION}" = "CN" ]]; then
      sed -i 's/downloads.rclone.org/casaos.oss-cn-shanghai.aliyuncs.com/g' ./install.sh
    else
      sed -i 's/downloads.rclone.org/get.casaos.io/g' ./install.sh
    fi
    ${sudo_cmd} chmod +x ./install.sh
    ${sudo_cmd} ./install.sh || {
      Show 3 "Official installer failed, falling back to direct download method."
      Install_rclone_direct_download
    }
    ${sudo_cmd} rm -rf install.sh
  else
    # Directly download and install when certificate issues exist
    Install_rclone_direct_download
  fi

  Show 0 "Rclone v1.61.1 installed successfully."
}

# Direct download method for environments with certificate issues
Install_rclone_direct_download() {
  Show 2 "Downloading and installing Rclone directly..."

  # Determine the system architecture for rclone download
  RCLONE_ARCH=""
  case $UNAME_M in
    *aarch64*)
      RCLONE_ARCH="arm64"
      ;;
    *64*)
      RCLONE_ARCH="amd64"
      ;;
    *armv7*)
      RCLONE_ARCH="arm-v7"
      ;;
    *)
      Show 1 "Unsupported architecture for Rclone: $UNAME_M"
      exit 1
      ;;
  esac

  # Create a temporary directory for rclone
  RCLONE_TMP_DIR=$(mktemp -d)
  cd "${RCLONE_TMP_DIR}" || Show 1 "Failed to create temporary directory for Rclone"

  # Download rclone
  ${sudo_cmd} wget --no-check-certificate -q --show-progress https://downloads.rclone.org/v1.61.1/rclone-v1.61.1-linux-${RCLONE_ARCH}.zip || {
    Show 1 "Failed to download Rclone"
    cd - || exit 1
    ${sudo_cmd} rm -rf "${RCLONE_TMP_DIR}"
    exit 1
  }

  # Unzip and install
  ${sudo_cmd} unzip -q rclone-v1.61.1-linux-${RCLONE_ARCH}.zip || Show 1 "Failed to extract Rclone"
  cd "rclone-v1.61.1-linux-${RCLONE_ARCH}" || Show 1 "Failed to enter Rclone directory"

  # Install binary
  ${sudo_cmd} cp rclone /usr/bin/
  ${sudo_cmd} chmod 755 /usr/bin/rclone

  # Install manpage
  ${sudo_cmd} mkdir -p /usr/local/share/man/man1
  ${sudo_cmd} cp rclone.1 /usr/local/share/man/man1/
  ${sudo_cmd} mandb -q

  # Create rclone service file if it doesn't exist
  if [[ ! -f /etc/systemd/system/rclone.service ]]; then
    ${sudo_cmd} tee /etc/systemd/system/rclone.service > /dev/null << 'EOT'
[Unit]
Description=rclone
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=/usr/bin/rclone rcd --rc-no-auth
Restart=on-abort
User=root

[Install]
WantedBy=multi-user.target
EOT
  fi

  # Clean up
  cd - || exit 1
  ${sudo_cmd} rm -rf "${RCLONE_TMP_DIR}"
}

Install_Rclone() {
  Show 2 "Install the necessary dependencies: Rclone"
  if [[ -x "$(command -v rclone)" ]]; then
    version=$(rclone --version 2>>errors | head -n 1)
    target_version="rclone v1.61.1"
    rclone1="${PREFIX}/usr/share/man/man1/rclone.1.gz"
    if [ "$version" != "$target_version" ]; then
      Show 3 "Will change rclone from $version to $target_version."
      rclone_path=$(command -v rclone)
      ${sudo_cmd} rm -rf "${rclone_path}"
      if [[ -f "$rclone1" ]]; then
        ${sudo_cmd} rm -rf "$rclone1"
      fi
      Install_rclone_from_source
    else
      Show 2 "Target version already installed."
    fi
  else
    Install_rclone_from_source
  fi
  ${sudo_cmd} systemctl enable rclone || Show 3 "Service rclone does not exist."
}

#Configuration Addons
Configuration_Addons() {
    Show 2 "Configuration CasaOS Addons"
    #Remove old udev rules
    if [[ -f "${PREFIX}/etc/udev/rules.d/11-usb-mount.rules" ]]; then
        ${sudo_cmd} rm -rf "${PREFIX}/etc/udev/rules.d/11-usb-mount.rules"
    fi

    if [[ -f "${PREFIX}/etc/systemd/system/usb-mount@.service" ]]; then
        ${sudo_cmd} rm -rf "${PREFIX}/etc/systemd/system/usb-mount@.service"
    fi

    #Udevil
    if [[ -f $PREFIX${UDEVIL_CONF_PATH} ]]; then

        # GreyStart
        # Add a devmon user
        USERNAME=devmon
        id ${USERNAME} &>/dev/null || {
            ${sudo_cmd} useradd -M -u 300 ${USERNAME}
            ${sudo_cmd} usermod -L ${USERNAME}
        }

        ${sudo_cmd} sed -i '/exfat/s/, nonempty//g' "$PREFIX"${UDEVIL_CONF_PATH}
        ${sudo_cmd} sed -i '/default_options/s/, noexec//g' "$PREFIX"${UDEVIL_CONF_PATH}
        ${sudo_cmd} sed -i '/^ARGS/cARGS="--mount-options nosuid,nodev,noatime --ignore-label EFI"' "$PREFIX"${DEVMON_CONF_PATH}

        # Add and start Devmon service
        GreyStart
        ${sudo_cmd} systemctl enable devmon@devmon
        ${sudo_cmd} systemctl start devmon@devmon
        ColorReset
        # ColorReset
    fi
}

# Download And Install CasaOS
DownloadAndInstallCasaOS() {
    if [ -z "${BUILD_DIR}" ]; then
        ${sudo_cmd} rm -rf ${TMP_ROOT}
        mkdir -p ${TMP_ROOT} || Show 1 "Failed to create temporary directory"
        TMP_DIR=$(${sudo_cmd} mktemp -d -p ${TMP_ROOT} || Show 1 "Failed to create temporary directory")

        pushd "${TMP_DIR}"

        for PACKAGE in "${CASA_PACKAGES[@]}"; do
            Show 2 "Downloading ${PACKAGE}..."
            GreyStart
            # Only add --no-check-certificate for get.casaos.io URLs if needed
            if [[ "$NEED_SSL_BYPASS" = true ]] && [[ "${PACKAGE}" == *"get.casaos.io"* ]]; then
                ${sudo_cmd} wget --no-check-certificate -t 3 -q --show-progress -c  "${PACKAGE}" || Show 1 "Failed to download package"
            else
                ${sudo_cmd} wget -t 3 -q --show-progress -c  "${PACKAGE}" || Show 1 "Failed to download package"
            fi
            ColorReset
        done

        for PACKAGE_FILE in linux-*.tar.gz; do
            Show 2 "Extracting ${PACKAGE_FILE}..."
            GreyStart
            ${sudo_cmd} tar zxf "${PACKAGE_FILE}" || Show 1 "Failed to extract package"
            ColorReset
        done

        BUILD_DIR=$(${sudo_cmd} realpath -e "${TMP_DIR}"/build || Show 1 "Failed to find build directory")

        popd
    fi

    for SERVICE in "${CASA_SERVICES[@]}"; do
        if ${sudo_cmd} systemctl --quiet is-active "${SERVICE}"; then
            Show 2 "Stopping ${SERVICE}..."
            GreyStart
            ${sudo_cmd} systemctl stop "${SERVICE}" || Show 3 "Service ${SERVICE} does not exist."
            ColorReset
        fi
    done

    MIGRATION_SCRIPT_DIR=$(realpath -e "${BUILD_DIR}"/scripts/migration/script.d || Show 1 "Failed to find migration script directory")

    for MIGRATION_SCRIPT in "${MIGRATION_SCRIPT_DIR}"/*.sh; do
        Show 2 "Running ${MIGRATION_SCRIPT}..."

        ${sudo_cmd} bash "${MIGRATION_SCRIPT}" || Show 1 "Failed to run migration script"

    done


    Show 2 "Installing CasaOS..."
    SYSROOT_DIR=$(realpath -e "${BUILD_DIR}"/sysroot || Show 1 "Failed to find sysroot directory")

    # Generate manifest for uninstallation
    MANIFEST_FILE=${BUILD_DIR}/sysroot/var/lib/casaos/manifest
    ${sudo_cmd} touch "${MANIFEST_FILE}" || Show 1 "Failed to create manifest file"

    GreyStart
    find "${SYSROOT_DIR}" -type f | ${sudo_cmd} cut -c ${#SYSROOT_DIR}- | ${sudo_cmd} cut -c 2- | ${sudo_cmd} tee "${MANIFEST_FILE}" >/dev/null || Show 1 "Failed to create manifest file"

    ${sudo_cmd} cp -rf "${SYSROOT_DIR}"/* / || Show 1 "Failed to install CasaOS"
    ColorReset

    SETUP_SCRIPT_DIR=$(realpath -e "${BUILD_DIR}"/scripts/setup/script.d || Show 1 "Failed to find setup script directory")

    for SETUP_SCRIPT in "${SETUP_SCRIPT_DIR}"/*.sh; do
        Show 2 "Running ${SETUP_SCRIPT}..."
        GreyStart
        ${sudo_cmd} bash "${SETUP_SCRIPT}" || Show 1 "Failed to run setup script"
        ColorReset
    done

    UI_EVENTS_REG_SCRIPT=/etc/casaos/start.d/register-ui-events.sh
    if [[ -f ${UI_EVENTS_REG_SCRIPT} ]]; then
        ${sudo_cmd} chmod +x $UI_EVENTS_REG_SCRIPT
    fi

    # Modify app store configuration
    sed -i "s#https://github.com/IceWhaleTech/_appstore/#${CASA_DOWNLOAD_DOMAIN}IceWhaleTech/_appstore/#g" "$PREFIX/etc/casaos/app-management.conf"

    #Download Uninstall Script
    if [[ -f $PREFIX/tmp/casaos-uninstall ]]; then
        ${sudo_cmd} rm -rf "$PREFIX/tmp/casaos-uninstall"
    fi
    # Download from GitHub
    ${sudo_cmd} curl -fsSL "$CASA_UNINSTALL_URL" >"$PREFIX/tmp/casaos-uninstall"
    ${sudo_cmd} cp -rf "$PREFIX/tmp/casaos-uninstall" $CASA_UNINSTALL_PATH || {
        Show 1 "Download uninstall script failed, Please check if your internet connection is working and retry."
        exit 1
    }

    ${sudo_cmd} chmod +x $CASA_UNINSTALL_PATH

    Install_Rclone

    for SERVICE in "${CASA_SERVICES[@]}"; do
        Show 2 "Starting ${SERVICE}..."
        GreyStart
        ${sudo_cmd} systemctl start "${SERVICE}" || Show 3 "Service ${SERVICE} does not exist."
        ColorReset
    done
}

Clean_Temp_Files() {
    Show 2 "Clean temporary files..."
    ${sudo_cmd} rm -rf "${TMP_DIR}" || Show 1 "Failed to clean temporary files"
}

Check_Service_status() {
    for SERVICE in "${CASA_SERVICES[@]}"; do
        Show 2 "Checking ${SERVICE}..."
        if [[ $(${sudo_cmd} systemctl is-active "${SERVICE}") == "active" ]]; then
            Show 0 "${SERVICE} is running."
        else
            Show 1 "${SERVICE} is not running, Please reinstall."
            exit 1
        fi
    done
}

# Get the IP and port for CasaOS
Get_IPs() {
    # Get port from config file with fallback to 80
    PORT=$(${sudo_cmd} cat ${CASA_CONF_PATH} 2>/dev/null | grep -E "^port=|^HttpPort" | awk '{print $NF}' | sed 's/port=//')
    # Default to port 80 if we couldn't get the port
    if [[ -z "$PORT" ]]; then
        PORT=80
    fi

    # Simple approach - get the first non-loopback IP (usually the LAN IP)
    # This is similar to the find-your-casaos-ip-and-port/run.sh approach
    LAN_IP=$(hostname -I 2>/dev/null | awk '{print $1}')

    # If we got a valid IP, display it
    if [[ -n "$LAN_IP" && "$LAN_IP" != "127."* ]]; then
        if [[ "$PORT" -eq "80" ]]; then
            echo -e "${GREEN_BULLET} http://$LAN_IP"
        else
            echo -e "${GREEN_BULLET} http://$LAN_IP:$PORT"
        fi
        return
    fi
    
    # If the simple approach failed, try more advanced methods
    # Try to identify and exclude Docker and other virtual interfaces
    if command -v ip >/dev/null 2>&1; then
        # Get list of interfaces, excluding loopback, docker, and other virtual interfaces
        INTERFACES=$(${sudo_cmd} ip -o link show | grep -v "lo:" | grep -v "docker" | grep -v "veth" | grep -v "br-" | grep -v "virtual" | awk -F': ' '{print $2}')

        for IFACE in $INTERFACES; do
            # Skip interfaces that don't exist or are down
            if ! ${sudo_cmd} ip link show dev "$IFACE" 2>/dev/null | grep -q "UP"; then
                continue
            fi

            # Get IPv4 addresses for this interface
            IPS=$(${sudo_cmd} ip -o -4 addr show dev "$IFACE" 2>/dev/null | awk '{print $4}' | cut -d'/' -f1)

            # Display each IP address
            for IP in $IPS; do
                # Skip loopback, link-local, and Docker addresses
                if [[ -n "$IP" && "$IP" != "127."* && "$IP" != "169.254."* && "$IP" != "172.17."* && "$IP" != "172.18."* && "$IP" != "172.19."* && "$IP" != "172.20."* && "$IP" != "172.21."* && "$IP" != "172.22."* ]]; then
                    if [[ "$PORT" -eq "80" ]]; then
                        echo -e "${GREEN_BULLET} http://$IP (${IFACE})"
                    else
                        echo -e "${GREEN_BULLET} http://$IP:$PORT (${IFACE})"
                    fi
                fi
            done
        done
    # Fallback to ifconfig if 'ip' is not available
    elif command -v ifconfig >/dev/null 2>&1; then
        # Get all interfaces except lo, docker, and other virtual interfaces
        ALL_NIC=$(${sudo_cmd} ifconfig -a | grep -E '^[a-zA-Z0-9]+:' | awk -F': ' '{print $1}' | grep -v -E 'lo|docker|veth|br-')

        for NIC in ${ALL_NIC}; do
            # Get IPv4 addresses
            IPS=$(${sudo_cmd} ifconfig "${NIC}" 2>/dev/null | grep "inet " | awk '{print $2}' | sed -e 's/addr://g')

            for IP in $IPS; do
                # Skip loopback, link-local, and Docker addresses
                if [[ -n "$IP" && "$IP" != "127."* && "$IP" != "169.254."* && "$IP" != "172.17."* && "$IP" != "172.18."* && "$IP" != "172.19."* && "$IP" != "172.20."* && "$IP" != "172.21."* && "$IP" != "172.22."* ]]; then
                    if [[ "$PORT" -eq "80" ]]; then
                        echo -e "${GREEN_BULLET} http://$IP (${NIC})"
                    else
                        echo -e "${GREEN_BULLET} http://$IP:$PORT (${NIC})"
                    fi
                fi
            done
        done
    fi

    # If no IPs were found, show a message
    if [[ -z "$(hostname -I 2>/dev/null | grep -v "127.0.0.1")" ]]; then
        echo -e "${GREEN_BULLET} Could not detect IP address. Please check your network configuration."
    fi
}

# Show Welcome Banner
Welcome_Banner() {
    CASA_TAG=$(casaos -v)

    echo -e "${GREEN_LINE}${aCOLOUR[1]}"
    echo -e " CasaOS ${CASA_TAG}${COLOUR_RESET} is running at${COLOUR_RESET}${GREEN_SEPARATOR}"
    echo -e "${GREEN_LINE}"
    Get_IPs
    echo -e " Open your browser and visit the above address."
    echo -e "${GREEN_LINE}"
    echo -e ""
    echo -e " ${aCOLOUR[2]}CasaOS Project  : https://github.com/IceWhaleTech/CasaOS"
    echo -e " ${aCOLOUR[2]}CasaOS Team     : https://github.com/IceWhaleTech/CasaOS#maintainers"
    echo -e " ${aCOLOUR[2]}CasaOS Discord  : https://discord.gg/knqAbbBbeX"
    echo -e " ${aCOLOUR[2]}Website         : https://www.casaos.io"
    echo -e " ${aCOLOUR[2]}Online Demo     : http://demo.casaos.io"
    echo -e ""
    echo -e " ${COLOUR_RESET}${aCOLOUR[1]}Uninstall       ${COLOUR_RESET}: casaos-uninstall"
    echo -e "${COLOUR_RESET}"
}

###############################################################################
# Main                                                                        #
###############################################################################

#Usage
usage() {
    cat <<-EOF
		Usage: install.sh [options]
		Valid options are:
		    -p <build_dir>          Specify build directory (Local install)
		    -h                      Show this help message and exit
	EOF
    exit "$1"
}

while getopts ":p:h" arg; do
    case "$arg" in
    p)
        BUILD_DIR=$OPTARG
        ;;
    h)
        usage 0
        ;;
    *)
        usage 1
        ;;
    esac
done

# Step 0 : Get Download Url Domain
Get_Download_Url_Domain
# Step 1: Check ARCH
Check_Arch

# Step 2: Check OS
Check_OS

# Step 3: Check Distribution
Check_Distribution

# Step 4: Check System Required
Check_Memory
Check_Disk

# Step 5: Install Depends
Update_Package_Resource
Install_Depends
Check_Dependency_Installation

# Step 6: Check And Install Docker
Check_Docker_Install


# Step 7: Configuration Addon
Configuration_Addons

# Step 8: Download And Install CasaOS
DownloadAndInstallCasaOS

# Step 9: Check Service Status
Check_Service_status

# Step 10: Clear Term and Show Welcome Banner
Welcome_Banner