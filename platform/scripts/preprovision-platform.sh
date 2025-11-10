#!/bin/sh

# Preprovision script for Contoso Platform Team
#
# This script:
# 1. Creates a copy of the platform/infra/contoso directory as 'deploy'
# 2. Runs the upstream AILZ preprovision to build Template Specs for base wrappers
# 3. Prepares deploy/main.bicep and deploy/main-byo-vnet.bicep for deployment
#
# Environment Variables:
# - AZURE_SUBSCRIPTION_ID: Required. Azure subscription ID (GUID format)
# - AZURE_LOCATION: Required. Azure region (e.g., eastus2, westus3)
# - AZURE_RESOURCE_GROUP: Required. Resource group name
# - AZURE_TS_RG: If set, uses existing Template Specs from this resource group
#
# Usage: 
#   ./scripts/preprovision-platform.sh

set -e  # Exit on any error

# Default values
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLATFORM_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_ROOT="$(cd "$PLATFORM_ROOT/.." && pwd)"
BICEP_ROOT="$REPO_ROOT/bicep"
LOCATION="${AZURE_LOCATION:-}"
SUBSCRIPTION_ID="${AZURE_SUBSCRIPTION_ID:-}"
RESOURCE_GROUP="${AZURE_RESOURCE_GROUP:-}"
TEMPLATE_SPEC_RG="${AZURE_TS_RG:-}"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
GRAY='\033[0;90m'
WHITE='\033[1;37m'
NC='\033[0m'

# Helper functions
print_header() {
    echo ""
    printf "${CYAN}[*] Contoso Platform - Template Spec Preprovision${NC}\n"
    printf "${GRAY}===================================================${NC}\n"
    echo ""
}

print_error() {
    printf "${RED}[X] Error: %s${NC}\n" "$1"
}

print_warning() {
    printf "${YELLOW}[!] %s${NC}\n" "$1"
}

print_success() {
    printf "${GREEN}[+] %s${NC}\n" "$1"
}

print_step() {
    printf "${CYAN}[%s] %s${NC}\n" "$1" "$2"
}

print_gray() {
    printf "${GRAY}  %s${NC}\n" "$1"
}

print_white() {
    printf "${WHITE}  %s${NC}\n" "$1"
}

#===============================================================================
# INITIALIZATION
#===============================================================================

print_header

# Verify required environment variables
if [ -z "$LOCATION" ] || [ -z "$RESOURCE_GROUP" ] || [ -z "$SUBSCRIPTION_ID" ]; then
    print_error "Missing required environment variables"
    print_white "Required:"
    print_white "  AZURE_LOCATION"
    print_white "  AZURE_RESOURCE_GROUP"
    print_white "  AZURE_SUBSCRIPTION_ID"
    exit 1
fi

print_white "Configuration:"
print_white "  Subscription: $SUBSCRIPTION_ID"
print_white "  Location: $LOCATION"
print_white "  Resource Group: $RESOURCE_GROUP"
[ -n "$TEMPLATE_SPEC_RG" ] && print_white "  Template Spec RG: $TEMPLATE_SPEC_RG"
echo ""

#===============================================================================
# STEP 1: RUN UPSTREAM PREPROVISION
#===============================================================================

print_step "1" "Running upstream AILZ preprovision..."
cd "$BICEP_ROOT"

export AZURE_LOCATION="$LOCATION"
export AZURE_RESOURCE_GROUP="$RESOURCE_GROUP"
export AZURE_SUBSCRIPTION_ID="$SUBSCRIPTION_ID"
[ -n "$TEMPLATE_SPEC_RG" ] && export AZURE_TS_RG="$TEMPLATE_SPEC_RG"

if ./scripts/preprovision.sh; then
    print_success "Upstream preprovision complete"
else
    print_error "Upstream preprovision failed"
    exit 1
fi

#===============================================================================
# STEP 2: PREPARE PLATFORM DEPLOY DIRECTORY
#===============================================================================

echo ""
print_step "2" "Preparing platform deploy directory..."
cd "$PLATFORM_ROOT"

platform_infra_dir="$PLATFORM_ROOT/infra/contoso"
platform_deploy_dir="$PLATFORM_ROOT/deploy"

# Remove existing deploy directory
if [ -d "$platform_deploy_dir" ]; then
    rm -rf "$platform_deploy_dir"
    print_gray "Removed existing deploy directory"
fi

# Create deploy directory structure
mkdir -p "$platform_deploy_dir"

# Copy main.bicep and main-byo-vnet.bicep
cp "$platform_infra_dir/main.bicep" "$platform_deploy_dir/"
cp "$platform_infra_dir/main-byo-vnet.bicep" "$platform_deploy_dir/"
print_gray "Copied main.bicep and main-byo-vnet.bicep"

# Copy common directory (types.bicep)
if [ -d "$platform_infra_dir/common" ]; then
    cp -r "$platform_infra_dir/common" "$platform_deploy_dir/"
    print_gray "Copied common/ directory"
fi

print_success "Platform deploy directory ready"

#===============================================================================
# STEP 3: UPDATE BICEP REFERENCES
#===============================================================================

echo ""
print_step "3" "Updating bicep references..."

# Update path references in main.bicep to point to upstream deploy (using relative paths)
for bicep_file in "$platform_deploy_dir/main.bicep" "$platform_deploy_dir/main-byo-vnet.bicep"; do
    if [ -f "$bicep_file" ]; then
        # Replace platform infra paths with deploy paths (keep relative)
        # These paths work because platform/deploy/ -> ../../bicep/deploy/
        sed -i.bak "s|'../../../bicep/deploy/main.bicep'|'../../bicep/deploy/main.bicep'|g" "$bicep_file"
        sed -i.bak "s|'../../../bicep/infra/helpers/|'../../bicep/infra/helpers/|g" "$bicep_file"
        rm -f "${bicep_file}.bak"
        print_gray "Updated: $(basename "$bicep_file")"
    fi
done

# Update common/types.bicep to use correct relative path
if [ -f "$platform_deploy_dir/common/types.bicep" ]; then
    sed -i.bak "s|'../../../../bicep/infra/common/types.bicep'|'../../../bicep/infra/common/types.bicep'|g" "$platform_deploy_dir/common/types.bicep"
    rm -f "$platform_deploy_dir/common/types.bicep.bak"
    print_gray "Updated: common/types.bicep"
fi

print_success "References updated"

#===============================================================================
# COMPLETION
#===============================================================================

echo ""
print_success "[OK] Platform preprovision complete!"
print_white "  Deploy directory: $platform_deploy_dir"
print_white "  Ready to publish Template Specs:"
print_white "    - main.bicep (new VNet)"
print_white "    - main-byo-vnet.bicep (existing VNet)"
echo ""
