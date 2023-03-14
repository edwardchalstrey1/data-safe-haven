from enum import Enum


class NetworkingPriorities(int, Enum):
    """Priorities for network security group rules."""

    # Azure services: 0 - 999
    AZURE_CLOUD = 100
    AZURE_GATEWAY_MANAGER = 200
    AZURE_LOAD_BALANCER = 300
    # Internal connections: 1000-1999
    INTERNAL_SELF = 1000
    INTERNAL_SHM_BASTION = 1100
    INTERNAL_SHM_LDAP_TCP = 1200
    INTERNAL_SHM_LDAP_UDP = 1250
    INTERNAL_SHM_MONITORING_TOOLS = 1300
    INTERNAL_SHM_UPDATE_SERVERS = 1400
    INTERNAL_SRE_REMOTE_DESKTOP = 1500
    INTERNAL_DSH_VIRTUAL_NETWORK = 1999
    # Authorised external IPs: 2000-2999
    AUTHORISED_EXTERNAL_ADMIN_IPS = 2000
    AUTHORISED_EXTERNAL_USER_IPS = 2100
    # Wider internet: 3000-3999
    EXTERNAL_LINUX_UPDATES = 3600
    EXTERNAL_INTERNET = 3999
    # Deny all other: 4096
    ALL_OTHER = 4096
