from data_safe_haven.config import SHMConfig
from data_safe_haven.context import Context
from data_safe_haven.exceptions import (
    DataSafeHavenAzureError,
)
from data_safe_haven.external import AzureApi
from data_safe_haven.logging import get_logger


class BackendInfrastructure:
    """Azure resources to support Data Safe Haven context"""

    def __init__(self, context: Context, config: SHMConfig) -> None:
        self.azure_api_: AzureApi | None = None
        self.config = config
        self.context = context
        self.nameservers: list[str] = []
        self.tags = {"component": "context"} | context.tags

    @property
    def azure_api(self) -> AzureApi:
        """Load AzureAPI on demand

        Returns:
            AzureApi: An initialised AzureApi object
        """
        if not self.azure_api_:
            self.azure_api_ = AzureApi(
                subscription_name=self.context.subscription_name,
            )
        return self.azure_api_

    def create(self, domain_verification_record: str) -> None:
        """Create all desired resources

        Raises:
            DataSafeHavenAzureError if any resources cannot be created
        """
        try:
            # Deploy the resources needed by Pulumi
            resource_group = self.azure_api.ensure_resource_group(
                location=self.context.location,
                resource_group_name=self.context.resource_group_name,
                tags=self.tags,
            )
            if not resource_group.name:
                msg = f"Resource group '{self.context.resource_group_name}' was not created."
                raise DataSafeHavenAzureError(msg)
            identity = self.azure_api.ensure_managed_identity(
                identity_name=self.context.managed_identity_name,
                location=resource_group.location,
                resource_group_name=resource_group.name,
            )
            storage_account = self.azure_api.ensure_storage_account(
                location=resource_group.location,
                resource_group_name=resource_group.name,
                storage_account_name=self.context.storage_account_name,
                tags=self.tags,
            )
            if not storage_account.name:
                msg = f"Storage account '{self.context.storage_account_name}' was not created."
                raise DataSafeHavenAzureError(msg)
            _ = self.azure_api.ensure_storage_blob_container(
                container_name=self.context.storage_container_name,
                resource_group_name=resource_group.name,
                storage_account_name=storage_account.name,
            )
            _ = self.azure_api.ensure_storage_blob_container(
                container_name=self.context.pulumi_storage_container_name,
                resource_group_name=resource_group.name,
                storage_account_name=storage_account.name,
            )
            keyvault = self.azure_api.ensure_keyvault(
                admin_group_id=self.context.admin_group_id,
                key_vault_name=self.context.key_vault_name,
                location=resource_group.location,
                managed_identity=identity,
                resource_group_name=resource_group.name,
                tags=self.tags,
            )
            if not keyvault.name:
                msg = f"Keyvault '{self.context.key_vault_name}' was not created."
                raise DataSafeHavenAzureError(msg)
            self.azure_api.ensure_keyvault_key(
                key_name=self.context.pulumi_encryption_key_name,
                key_vault_name=keyvault.name,
            )
            # Deploy common resources that will be needed by SREs
            zone = self.azure_api.ensure_dns_zone(
                resource_group_name=resource_group.name,
                zone_name=self.config.shm.fqdn,
            )
            if not zone.name_servers:
                msg = f"DNS zone '{self.config.shm.fqdn}' was not created."
                raise DataSafeHavenAzureError(msg)
            self.nameservers = [str(n) for n in zone.name_servers]
            self.azure_api.ensure_dns_caa_record(
                record_flags=0,
                record_name="@",
                record_tag="issue",
                record_value="letsencrypt.org",
                resource_group_name=resource_group.name,
                ttl=3600,
                zone_name=self.config.shm.fqdn,
            )
            self.azure_api.ensure_dns_txt_record(
                record_name="@",
                record_value=domain_verification_record,
                resource_group_name=resource_group.name,
                ttl=3600,
                zone_name=self.config.shm.fqdn,
            )
        except DataSafeHavenAzureError as exc:
            msg = "Failed to create context resources."
            raise DataSafeHavenAzureError(msg) from exc

    def teardown(self) -> None:
        """Destroy all created resources

        Raises:
            DataSafeHavenAzureError if any resources cannot be destroyed
        """
        logger = get_logger()
        try:
            logger.info(
                f"Removing context {self.context.name} resource group {self.context.resource_group_name}"
            )
            self.azure_api.remove_resource_group(self.context.resource_group_name)
        except DataSafeHavenAzureError as exc:
            msg = "Failed to destroy context resources."
            raise DataSafeHavenAzureError(msg) from exc
