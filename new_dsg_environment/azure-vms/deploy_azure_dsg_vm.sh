#! /bin/bash

# Constants for colourised output
BOLD="\033[1m"
RED="\033[0;31m"
BLUE="\033[0;36m"
END="\033[0m"

# Options which are configurable at the command line
SUBSCRIPTIONSOURCE="" # must be provided
SUBSCRIPTIONTARGET="" # must be provided
LDAP_SECRET_NAME=""
LDAP_USER=""
ADMIN_PASSWORD_SECRET_NAME=""
DOMAIN=""
AD_DC_NAME=""
IP_ADDRESS=""
DSG_NSG="NSG_Linux_Servers" # NB. this will disallow internet connection during deployment
SOURCEIMAGE="Ubuntu"
VERSION=""
MACHINENAME="DSG$(date '+%Y%m%d%H%M')"
RESOURCEGROUP="RG_DSG_COMPUTE"
USERNAME="atiadmin"
DSG_VNET="DSG_DSGROUPTEST_VNet1"
DSG_SUBNET="Subnet-Data"
VM_SIZE="Standard_DS2_v2"
CLOUD_INIT_YAML="cloud-init-compute-vm.yaml"
PYPI_MIRROR_IP=""
CRAN_MIRROR_IP=""

# Other constants
IMAGES_RESOURCEGROUP="RG_SH_IMAGEGALLERY"
IMAGES_GALLERY="SIG_SH_COMPUTE"
LOCATION="uksouth"
LDAP_RESOURCEGROUP="RG_SH_LDAP"
DEPLOYMENT_NSG="NSG_IMAGE_DEPLOYMENT" # NB. this will *allow* internet connection during deployment


# Document usage for this script
print_usage_and_exit() {
    echo "usage: $0 [-h] -s subscription_source -t subscription_target -m management_vault_name -l ldap_secret_name -j ldap_user -p password_secret_name -d domain -a ad_dc_name -q ip_address -e mgmnt_subnet_ip_range [-g nsg_name] [-i source_image] [-x source_image_version] [-n machine_name] [-r resource_group] [-u user_name] [-v vnet_name] [-w subnet_name] [-z vm_size] [-b ldap_base_dn] [-c ldap_bind_dn] [-f ldap_filter] [-y yaml_cloud_init ] [-k pypi_mirror_ip] [-o cran_mirror_ip]"
    echo "  -h                                    display help"
    echo "  -s subscription_source [required]     specify source subscription that images are taken from. (Test using 'Safe Haven Management Testing')"
    echo "  -t subscription_target [required]     specify target subscription for deploying the VM image. (Test using 'Data Study Group Testing')"
    echo "  -m management_vault_name [required]   specify name of KeyVault containing management secrets"
    echo "  -l ldap_secret_name [required]        specify name of KeyVault secret containing LDAP secret"
    echo "  -j ldap_user [required]               specify the LDAP user"
    echo "  -p password_secret_name [required]    specify name of KeyVault secret containing VM admin password"
    echo "  -d domain [required]                  specify domain name for safe haven"
    echo "  -a ad_dc_name [required]              specify Active Directory Domain Controller name"
    echo "  -q ip_address [required]              specify a specific IP address to deploy the VM to"
    echo "  -e mgmnt_subnet_ip_range [required]   specify IP range for safe haven management subnet"
    echo "  -g nsg_name                           specify which NSG to connect to (defaults to '${DSG_NSG}')"
    echo "  -i source_image                       specify source_image: either 'Ubuntu' (default) 'UbuntuTorch' (as default but with Torch included) or 'DataScience' (the Microsoft Azure DSVM) or 'DSG' (the current base image for Data Study Groups)"
    echo "  -x source_image_version               specify the version of the source image to use (defaults to prompting to select from available versions)"
    echo "  -n machine_name                       specify name of created VM, which must be unique in this resource group (defaults to '${MACHINENAME}')"
    echo "  -r resource_group                     specify resource group for deploying the VM image - will be created if it does not already exist (defaults to '${RESOURCEGROUP}')"
    echo "  -u user_name                          specify a username for the admin account (defaults to '${USERNAME}')"
    echo "  -v vnet_name                          specify a VNET to connect to (defaults to '${DSG_VNET}')"
    echo "  -w subnet_name                        specify a subnet to connect to (defaults to '${DSG_SUBNET}')"
    echo "  -z vm_size                            specify a VM size to use (defaults to '${VM_SIZE}')"
    echo "  -b ldap_base_dn                       specify LDAP base DN"
    echo "  -c ldap_bind_dn                       specify LDAP bind DN"
    echo "  -f ldap_filter                        specify LDAP filter"
    echo "  -y yaml_cloud_init                    specify a custom cloud-init YAML script"
    echo "  -k pypi_mirror_ip                     specify the IP address of the PyPI mirror (defaults to '${PYPI_MIRROR_IP}')"
    echo "  -o cran_mirror_ip                     specify the IP address of the CRAN mirror (defaults to '${CRAN_MIRROR_IP}')"
    exit 1
}

# Read command line arguments, overriding defaults where necessary
while getopts "a:b:c:d:e:f:g:hi:j:k:l:m:n:o:p:q:r:s:t:u:v:w:x:y:z:" opt; do
    case $opt in
        g)
            DSG_NSG=$OPTARG
            ;;
        h)
            print_usage_and_exit
            ;;
        i)
            SOURCEIMAGE=$OPTARG
            ;;
        x)
            VERSION=$OPTARG
            ;;
        n)
            MACHINENAME=$OPTARG
            ;;
        r)
            RESOURCEGROUP=$OPTARG
            ;;
        u)
            USERNAME=$OPTARG
            ;;
        s)
            SUBSCRIPTIONSOURCE=$OPTARG
            ;;
        t)
            SUBSCRIPTIONTARGET=$OPTARG
            ;;
        v)
            DSG_VNET=$OPTARG
            ;;
        w)
            DSG_SUBNET=$OPTARG
            ;;
        z)
            VM_SIZE=$OPTARG
            ;;
        m)
            MANAGEMENT_VAULT_NAME=$OPTARG
            ;;
        l)
            LDAP_SECRET_NAME=$OPTARG
            ;;
        p)
            ADMIN_PASSWORD_SECRET_NAME=$OPTARG
            ;;
        j)
            LDAP_USER=$OPTARG
            ;;
        d)
            DOMAIN=$OPTARG
            ;;
        a)
            AD_DC_NAME=$OPTARG
            ;;
        e)
            MGMNT_SUBNET_IP_RANGE=$OPTARG
            ;;
        b)
            LDAP_BASE_DN=$OPTARG
            ;;
        c)
            LDAP_BIND_DN=$OPTARG
            ;;
        f)
            LDAP_FILTER=$OPTARG
            ;;
        q)
            IP_ADDRESS=$OPTARG
            ;;
        y)
            CLOUD_INIT_YAML=$OPTARG
            ;;
        k)
            PYPI_MIRROR_IP=$OPTARG
            ;;
        o)
            CRAN_MIRROR_IP=$OPTARG
            ;;
        \?)
            echo "Invalid option: -$OPTARG" >&2
            ;;
    esac
done

# Check that a source subscription has been provided
if [ "$SUBSCRIPTIONSOURCE" = "" ]; then
    echo -e "${RED}Source subscription is a required argument!${END}"
    print_usage_and_exit
fi

# Check that a management KeyVault name has been provided
if [ "$MANAGEMENT_VAULT_NAME" = "" ]; then
    echo -e "${RED}Management KeyVault name is a required argument!${END}"
    print_usage_and_exit
fi

# Check that the machine name is valid
# NOTE: It looks like passing a blank string for machine name gives an "option requires and argument"
# error and the default value for $MACHINENAME set at the top of the script is preserved.
if [ "$MACHINENAME" = "" ]; then
    echo -e "${RED}Machine name cannot be blank!${END}"
    print_usage_and_exit
fi

# Check that an LDAP secret KeyVault secret name has been provided
if [ "$LDAP_SECRET_NAME" = "" ]; then
    echo -e "${RED}LDAP secret KeyVault secret name is a required argument!${END}"
    print_usage_and_exit
fi

# Check that an LDAP username has been provided
if [ "$LDAP_USER" = "" ]; then
    echo -e "${RED}LDAP user is a required argument!${END}"
    print_usage_and_exit
fi

# Check that an domain has been provided
if [ "$DOMAIN" = "" ]; then
    echo -e "${RED}Domain is a required argument!${END}"
    print_usage_and_exit
fi

# Check that an admin password KeyVault secret name has been provided
if [ "$ADMIN_PASSWORD_SECRET_NAME" = "" ]; then
    echo -e "${RED}Admin password KeyVault secret name is a required argument!${END}"
    print_usage_and_exit
fi

# Check that a target subscription has been provided
if [ "$SUBSCRIPTIONTARGET" = "" ]; then
    echo -e "${RED}Target subscription is a required argument!${END}"
    print_usage_and_exit
fi

# Look up specified image definition
az account set --subscription "$SUBSCRIPTIONSOURCE"
if [ "$(az account show --query 'name' | xargs)" != "$SUBSCRIPTIONSOURCE" ]; then
    echo -e "${RED}Could not set source subscription to ${BLUE}'${SUBSCRIPTIONSOURCE}'${END}${RED}. Are you a member? Current subscription is ${BLUE}'$(az account show --query 'name' | xargs)'${END}"
    print_usage_and_exit
fi

if [ "$SOURCEIMAGE" = "Ubuntu" ]; then
    IMAGE_DEFINITION="ComputeVM-Ubuntu1804Base"
elif [ "$SOURCEIMAGE" = "UbuntuTorch" ]; then
    IMAGE_DEFINITION="ComputeVM-UbuntuTorch1804Base"
elif [ "$SOURCEIMAGE" = "DataScience" ]; then
    IMAGE_DEFINITION="ComputeVM-DataScienceBase"
elif [ "$SOURCEIMAGE" = "DSG" ]; then
    IMAGE_DEFINITION="ComputeVM-DsgBase"
else
    echo -e "${RED}Could not interpret ${BLUE}${SOURCEIMAGE}${END} as an image type${END}"
    print_usage_and_exit
fi

# Prompt user to select version if not already supplied
if [ "$VERSION" = "" ]; then
    # List available versions and set the last one in the list as default
    echo -e "${BOLD}Found the following versions of ${BLUE}$IMAGE_DEFINITION${END}"
    VERSIONS=$(az sig image-version list \
                --resource-group $IMAGES_RESOURCEGROUP \
                --gallery-name $IMAGES_GALLERY \
                --gallery-image-definition $IMAGE_DEFINITION \
                --query "[].name" -o table)
    echo -e "$VERSIONS"
    DEFAULT_VERSION=$(echo -e "$VERSIONS" | tail -n1)
    echo -e "${BOLD}Please type the version you would like to use, followed by [ENTER]. To accept the default ${BLUE}$DEFAULT_VERSION${END} ${BOLD}simply press [ENTER]${END}"
    read VERSION
    if [ "$VERSION" = "" ]; then VERSION=$DEFAULT_VERSION; fi
fi

# Check that this is a valid version and then get the image ID
echo -e "${BOLD}Finding ID for image ${BLUE}${IMAGE_DEFINITION}${END} version ${BLUE}${VERSION}${END}${BOLD}...${END}"
if [ "$(az sig image-version show --resource-group $IMAGES_RESOURCEGROUP --gallery-name $IMAGES_GALLERY --gallery-image-definition $IMAGE_DEFINITION --gallery-image-version $VERSION 2>&1 | grep 'not found')" != "" ]; then
    echo -e "${RED}Version $VERSION could not be found.${END}"
    print_usage_and_exit
fi
IMAGE_ID=$(az sig image-version show --resource-group $IMAGES_RESOURCEGROUP --gallery-name $IMAGES_GALLERY --gallery-image-definition $IMAGE_DEFINITION --gallery-image-version $VERSION --query "id" | xargs)

# Switch subscription and setup resource groups if they do not already exist
# --------------------------------------------------------------------------
az account set --subscription "$SUBSCRIPTIONTARGET"
if [ "$(az account show --query 'name' | xargs)" != "$SUBSCRIPTIONTARGET" ]; then
    echo -e "${RED}Could not set target subscription to ${BLUE}'${SUBSCRIPTIONTARGET}'${END}${RED}. Are you a member? Current subscription is ${BLUE}'$(az account show --query 'name' | xargs)'${END}"
    print_usage_and_exit
fi

if [ "$(az group exists --name $RESOURCEGROUP)" != "true" ]; then
    echo -e "${BOLD}Creating resource group ${BLUE}$RESOURCEGROUP${END} ${BOLD}in ${BLUE}$SUBSCRIPTIONTARGET${END}"
    az group create --name $RESOURCEGROUP --location $LOCATION
fi

# Check that secure NSG exists
# ----------------------------
DSG_NSG_RG=""
DSG_NSG_ID=""
for RG in $(az group list --query "[].name" -o tsv); do
    if [ "$(az network nsg show --resource-group $RG --name $DSG_NSG 2> /dev/null)" != "" ]; then
        DSG_NSG_RG=$RG;
        DSG_NSG_ID=$(az network nsg show --resource-group $RG --name $DSG_NSG --query 'id' | xargs)
    fi
done
if [ "$DSG_NSG_RG" = "" ]; then
    echo -e "${RED}Could not find NSG ${BLUE}$DSG_NSG${END} ${RED}in any resource group${END}"
    print_usage_and_exit
else
    echo -e "${BOLD}Found NSG ${BLUE}$DSG_NSG${END} ${BOLD}in resource group ${BLUE}$DSG_NSG_RG${END}"
fi

# Ensure that NSG with outbound internet access exists (used for deployment only)
# -------------------------------------------------------------------------------
if [ "$(az network nsg show --resource-group $DSG_NSG_RG --name $DEPLOYMENT_NSG 2> /dev/null)" = "" ]; then
    echo -e "${BOLD}Creating NSG ${BLUE}$DEPLOYMENT_NSG${END} ${BOLD}with outbound internet access ${RED}(for use during deployment *only*)${END}${BOLD} in resource group ${BLUE}$DSG_NSG_RG${END}"
    az network nsg create --resource-group $DSG_NSG_RG --name $DEPLOYMENT_NSG

    # Inbound: allow LDAP then deny all
    az network nsg rule create \
        --resource-group $DSG_NSG_RG \
        --nsg-name $DEPLOYMENT_NSG \
        --direction Inbound \
        --name InboundAllowLDAP \
        --description "Inbound allow LDAP" \
        --access "Allow" \
        --source-address-prefixes $MGMNT_SUBNET_IP_RANGE \
        --source-port-ranges 88 389 636 \
        --destination-address-prefixes VirtualNetwork \
        --destination-port-ranges "*" \
        --protocol "*" \
        --priority 2000
    az network nsg rule create \
        --resource-group $DSG_NSG_RG \
        --nsg-name $DEPLOYMENT_NSG \
        --direction Inbound \
        --name InboundDenyAll \
        --description "Inbound deny all" \
        --access "Deny" \
        --source-address-prefixes "*" \
        --source-port-ranges "*" \
        --destination-address-prefixes "*" \
        --destination-port-ranges "*" \
        --protocol "*" \
        --priority 3000
    # Outbound: allow LDAP then deny all Virtual Network
    az network nsg rule create \
        --resource-group $DSG_NSG_RG \
        --nsg-name $DEPLOYMENT_NSG \
        --direction Outbound \
        --name OutboundAllowLDAP \
        --description "Outbound allow LDAP" \
        --access "Allow" \
        --source-address-prefixes VirtualNetwork \
        --source-port-ranges "*" \
        --destination-address-prefixes $MGMNT_SUBNET_IP_RANGE \
        --destination-port-ranges "*" \
        --protocol "*" \
        --priority 2000
    az network nsg rule create \
        --resource-group $DSG_NSG_RG \
        --nsg-name $DEPLOYMENT_NSG \
        --direction Outbound \
        --name OutboundDenyVNet \
        --description "Outbound deny virtual network" \
        --access "Deny" \
        --source-address-prefixes "*" \
        --source-port-ranges "*" \
        --destination-address-prefixes VirtualNetwork \
        --destination-port-ranges "*" \
        --protocol "*" \
        --priority 3000
fi
DEPLOYMENT_NSG_ID=$(az network nsg show --resource-group $DSG_NSG_RG --name $DEPLOYMENT_NSG --query 'id' | xargs)
echo -e "${BOLD}Deploying into NSG ${BLUE}$DEPLOYMENT_NSG${END} ${BOLD}with outbound internet access to allow package installation. Will switch NSGs at end of deployment.${END}"

# Check that VNET and subnet exist
# --------------------------------
DSG_SUBNET_RG=""
DSG_SUBNET_ID=""
for RG in $(az group list --query "[].name" -o tsv); do
    # Check that VNET exists with subnet inside it
    if [ "$(az network vnet subnet list --resource-group $RG --vnet-name $DSG_VNET 2> /dev/null | grep $DSG_SUBNET)" != "" ]; then
        DSG_SUBNET_RG=$RG;
        DSG_SUBNET_ID=$(az network vnet subnet list --resource-group $RG --vnet-name $DSG_VNET --query "[?name == '$DSG_SUBNET'].id | [0]" | xargs)
    fi
done
if [ "$DSG_SUBNET_RG" = "" ]; then
    echo -e "${RED}Could not find subnet ${BLUE}$DSG_SUBNET${END} ${RED}in vnet ${BLUE}$DSG_VNET${END} in ${RED}any resource group${END}"
    print_usage_and_exit
else
    echo -e "${BOLD}Found subnet ${BLUE}$DSG_SUBNET${END} ${BOLD}as part of VNET ${BLUE}$DSG_VNET${END} ${BOLD}in resource group ${BLUE}$DSG_SUBNET_RG${END}"
fi

# If using the Data Science VM then the terms must be added before creating the VM
PLANDETAILS=""
if [[ "$SOURCEIMAGE" == *"DataScienceBase"* ]]; then
    PLANDETAILS="--plan-name linuxdsvmubuntubyol --plan-publisher microsoft-ads --plan-product linux-data-science-vm-ubuntu"
fi

# Construct the cloud-init yaml file for the target subscription
# --------------------------------------------------------------
# Retrieve admin password from keyvault
ADMIN_PASSWORD=$(az keyvault secret show --vault-name $MANAGEMENT_VAULT_NAME --name $ADMIN_PASSWORD_SECRET_NAME --query "value" | xargs)

# Get LDAP secret file with password in it (can't pass as a secret at VM creation)
LDAP_SECRET_PLAINTEXT=$(az keyvault secret show --vault-name $MANAGEMENT_VAULT_NAME --name $LDAP_SECRET_NAME --query "value" | xargs)

# Create a new config file with the appropriate username and LDAP password
TMP_CLOUD_CONFIG_YAML="$(mktemp).yaml"
DOMAIN_UPPER=$(echo "$DOMAIN" | tr '[:lower:]' '[:upper:]')
DOMAIN_LOWER=$(echo "$DOMAIN" | tr '[:upper:]' '[:lower:]')
AD_DC_NAME_UPPER=$(echo "$AD_DC_NAME" | tr '[:lower:]' '[:upper:]')
AD_DC_NAME_LOWER=$(echo "$AD_DC_NAME" | tr '[:upper:]' '[:lower:]')

# Define regexes
USERNAME_REGEX="s/USERNAME/"${USERNAME}"/g"
LDAP_SECRET_REGEX="s/LDAP_SECRET_PLAINTEXT/"${LDAP_SECRET_PLAINTEXT}"/g"
MACHINE_NAME_REGEX="s/MACHINENAME/${MACHINENAME}/g"
LDAP_USER_REGEX="s/LDAP_USER/${LDAP_USER}/g"
DOMAIN_LOWER_REGEX="s/DOMAIN_LOWER/${DOMAIN_LOWER}/g"
DOMAIN_UPPER_REGEX="s/DOMAIN_UPPER/${DOMAIN_UPPER}/g"
LDAP_BASE_DN_REGEX="s/LDAP_BASE_DN/${LDAP_BASE_DN}/g"
LDAP_BIND_DN_REGEX="s/LDAP_BIND_DN/${LDAP_BIND_DN}/g"
# Escape ampersand in the LDAP filter as it is a special character for sed
LDAP_FILTER_ESCAPED=${LDAP_FILTER/"&"/"\&"}
LDAP_FILTER_REGEX="s/LDAP_FILTER/${LDAP_FILTER_ESCAPED}/g"
AD_DC_NAME_UPPER_REGEX="s/AD_DC_NAME_UPPER/${AD_DC_NAME_UPPER}/g"
AD_DC_NAME_LOWER_REGEX="s/AD_DC_NAME_LOWER/${AD_DC_NAME_LOWER}/g"
PYPI_MIRROR_IP_REGEX="s/PYPI_MIRROR_IP/${PYPI_MIRROR_IP}/"
CRAN_MIRROR_IP_REGEX="s/CRAN_MIRROR_IP/${CRAN_MIRROR_IP}/"

# Substitute regexes
sed -e "${USERNAME_REGEX}" -e "${LDAP_SECRET_REGEX}" -e "${MACHINE_NAME_REGEX}" -e "${LDAP_USER_REGEX}" -e "${DOMAIN_LOWER_REGEX}" -e "${DOMAIN_UPPER_REGEX}" -e "${LDAP_CN_REGEX}" -e "${LDAP_BASE_DN_REGEX}" -e "${LDAP_FILTER_REGEX}" -e "${LDAP_BIND_DN_REGEX}" -e  "${AD_DC_NAME_UPPER_REGEX}" -e "${AD_DC_NAME_LOWER_REGEX}" -e "${PYPI_MIRROR_IP_REGEX}" -e "${CRAN_MIRROR_IP_REGEX}" $CLOUD_INIT_YAML > $TMP_CLOUD_CONFIG_YAML

# Create the VM based off the selected source image
# -------------------------------------------------
echo -e "${BOLD}Creating VM ${BLUE}$MACHINENAME${END} ${BOLD}as part of ${BLUE}$RESOURCEGROUP${END}"
echo -e "${BOLD}This will use the ${BLUE}$SOURCEIMAGE${END}${BOLD}-based compute machine image${END}"
echo -e "Starting deployment at ${BOLD}$(date)${END}"
STARTTIME=$(date +%s)

if [ "$IP_ADDRESS" = "" ]; then
    echo -e "${BOLD}Requesting a dynamic IP address${END}"
    az vm create ${PLANDETAILS} \
        --admin-password $ADMIN_PASSWORD \
        --admin-username $USERNAME \
        --custom-data $TMP_CLOUD_CONFIG_YAML \
        --image $IMAGE_ID \
        --name $MACHINENAME \
        --nsg $DEPLOYMENT_NSG_ID \
        --os-disk-name "${MACHINENAME}OSDISK" \
        --os-disk-size-gb 1024 \
        --public-ip-address "" \
        --resource-group $RESOURCEGROUP \
        --size $VM_SIZE \
        --subnet $DSG_SUBNET_ID
else
    echo -e "${BOLD}Creating VM with static IP address ${BLUE}$IP_ADDRESS${END}"
    az vm create ${PLANDETAILS} \
        --admin-password $ADMIN_PASSWORD \
        --admin-username $USERNAME \
        --custom-data $TMP_CLOUD_CONFIG_YAML \
        --image $IMAGE_ID \
        --name $MACHINENAME \
        --nsg $DEPLOYMENT_NSG_ID \
        --os-disk-name "${MACHINENAME}OSDISK" \
        --os-disk-size-gb 1024 \
        --private-ip-address $IP_ADDRESS \
        --public-ip-address "" \
        --resource-group $RESOURCEGROUP \
        --size $VM_SIZE \
        --subnet $DSG_SUBNET_ID
fi
# Remove temporary init file if it exists
rm $TMP_CLOUD_CONFIG_YAML 2> /dev/null

# allow some time for the system to finish initialising
sleep 30

# Poll VM to see whether it has finished running
echo -e "${BOLD}Waiting for VM setup to finish (this will take 20+ minutes)...${END}"
while true; do
    VM_DOWN=$(az vm get-instance-view --resource-group $RESOURCEGROUP --name $MACHINENAME --query "((instanceView.statuses[?code=='PowerState/stopped'])[0].code=='PowerState/stopped' && (instanceView.statuses[?code=='ProvisioningState/succeeded'])[0].code=='ProvisioningState/succeeded')")
    if [ "$VM_DOWN" == "true" ]; then break; fi
    sleep 30
done

# VM must be off for us to switch NSG. Once done we restart
echo -e "${BOLD}Switching to secure NSG ${BLUE}${DSG_NSG}${END} at ${BOLD}$(date)${END}"
az network nic update --resource-group $RESOURCEGROUP --name "${MACHINENAME}VMNic" --network-security-group $DSG_NSG_ID
echo -e "${BOLD}Restarting VM: ${BLUE}${MACHINENAME}${END} at ${BOLD}$(date)${END}"
az vm start --resource-group $RESOURCEGROUP --name $MACHINENAME

# Poll VM to see whether it has finished restarting
echo -e "${BOLD}Waiting for VM to restart...${END}"
while true; do
    VM_UP=$(az vm get-instance-view --resource-group $RESOURCEGROUP --name $MACHINENAME --query "((instanceView.statuses[?code=='PowerState/running'])[0].code=='PowerState/running' && (instanceView.statuses[?code=='ProvisioningState/succeeded'])[0].code=='ProvisioningState/succeeded')")
    if [ "$VM_UP" == "true" ]; then break; fi
    sleep 10
done

# Get public IP address for this machine. Piping to echo removes the quotemarks around the address
PRIVATEIP=$(az vm list-ip-addresses --resource-group $RESOURCEGROUP --name $MACHINENAME --query "[0].virtualMachine.network.privateIpAddresses[0]" | xargs echo)
echo -e "Deployment complete at ${BOLD}$(date)${END}"
echo -e "${BOLD}This new VM can be accessed with SSH or remote desktop at ${BLUE}${PRIVATEIP}${END}"
