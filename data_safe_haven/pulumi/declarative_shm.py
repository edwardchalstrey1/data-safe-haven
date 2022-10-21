"""Deploy Data Safe Haven Management environment with Pulumi"""
# Standard library imports
import pathlib

# Third party imports
import pulumi

# Local imports
from data_safe_haven.config import Config
from .components.shm_domain_controllers import (
    SHMDomainControllersComponent,
    SHMDomainControllersProps,
)
from .components.shm_monitoring import SHMMonitoringComponent, SHMMonitoringProps
from .components.shm_networking import SHMNetworkingComponent, SHMNetworkingProps
from .components.shm_state import SHMStateComponent, SHMStateProps


class DeclarativeSHM:
    """Deploy Data Safe Haven Management environment with Pulumi"""

    def __init__(self, config: Config, shm_name: str):
        self.cfg = config
        self.shm_name = shm_name
        self.stack_name = f"shm-{shm_name}"

    def work_dir(self, base_path: pathlib.Path):
        return base_path / self.stack_name

    def run(self):
        # Load pulumi configuration secrets
        self.secrets = pulumi.Config()

        # Deploy SHM networking
        networking = SHMNetworkingComponent(
            "shm_networking",
            self.stack_name,
            self.shm_name,
            SHMNetworkingProps(
                fqdn=self.cfg.shm.fqdn,
                location=self.cfg.azure.location,
                public_ip_range_admins=self.cfg.shm.admin_ip_addresses,
                record_domain_verification=self.secrets.require(
                    "verification-azuread-custom-domain"
                ),
            ),
        )

        # Deploy SHM state
        state = SHMStateComponent(
            "shm_state",
            self.stack_name,
            self.shm_name,
            SHMStateProps(
                admin_group_id=self.cfg.azure.admin_group_id,
                location=self.cfg.azure.location,
                tenant_id=self.cfg.azure.tenant_id,
            ),
        )

        # Deploy SHM monitoring
        monitoring = SHMMonitoringComponent(
            "shm_monitoring",
            self.stack_name,
            self.shm_name,
            SHMMonitoringProps(
                location=self.cfg.azure.location,
            ),
        )

        # Deploy firewall

        # Deploy update servers

        # Deploy domain controllers
        domain_controllers = SHMDomainControllersComponent(
            "shm_domain_controllers",
            self.stack_name,
            self.shm_name,
            SHMDomainControllersProps(
                automation_account_modules=monitoring.automation_account_modules,
                automation_account_name=monitoring.automation_account.name,
                automation_account_registration_key=monitoring.automation_account_primary_key,
                automation_account_registration_url=monitoring.automation_account_agentsvc_url,
                automation_account_resource_group_name=monitoring.resource_group_name,
                domain_fqdn=self.cfg.shm.fqdn,
                domain_netbios_name=self.stack_name[4:].upper(),  # drop initial 'shm-'
                location=self.cfg.azure.location,
                password_domain_admin=self.secrets.require("password-domain-admin"),
                password_domain_azuread_connect=self.secrets.require(
                    "password-domain-azure-ad-connect"
                ),
                password_domain_computer_manager=self.secrets.require(
                    "password-domain-computer-manager"
                ),
                subnet_ip_range=networking.subnet_users_iprange,
                subnet_name="UsersSubnet",
                subscription_name=self.cfg.subscription_name,
                virtual_network_name=networking.virtual_network.name,
                virtual_network_resource_group_name=networking.resource_group_name,
            ),
        )

        # Export values for later use
        pulumi.export("fqdn_nameservers", networking.dns_zone_nameservers)
