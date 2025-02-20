from __future__ import annotations

from pathlib import Path
from typing import ClassVar

import yaml
from azure.keyvault.keys import KeyVaultKey
from pydantic import BaseModel

from data_safe_haven import __version__
from data_safe_haven.directories import config_dir
from data_safe_haven.external import AzureSdk
from data_safe_haven.functions import alphanumeric
from data_safe_haven.serialisers import ContextBase
from data_safe_haven.types import AzureSubscriptionName, EntraGroupName, SafeString


class Context(ContextBase, BaseModel, validate_assignment=True):
    admin_group_name: EntraGroupName
    description: str
    name: SafeString
    subscription_name: AzureSubscriptionName
    storage_container_name: ClassVar[str] = "config"
    pulumi_storage_container_name: ClassVar[str] = "pulumi"
    pulumi_encryption_key_name: ClassVar[str] = "pulumi-encryption-key"

    _pulumi_encryption_key = None

    @property
    def tags(self) -> dict[str, str]:
        return {
            "description": self.description,
            "project": "Data Safe Haven",
            "shm_name": self.name,
            "version": __version__,
        }

    @property
    def work_directory(self) -> Path:
        return config_dir() / self.name

    @property
    def resource_group_name(self) -> str:
        return f"shm-{self.name}-rg"

    @property
    def storage_account_name(self) -> str:
        # https://learn.microsoft.com/en-us/azure/storage/common/storage-account-overview#storage-account-name
        #   Storage account names must be between 3 and 24 characters in length and may
        #   contain numbers and lowercase letters only.
        return f"shm{alphanumeric(self.name)[:21]}"

    @property
    def key_vault_name(self) -> str:
        # maximum of 24 characters allowed
        return f"shm-{self.name[:17]}-kv"

    @property
    def managed_identity_name(self) -> str:
        return f"shm-{self.name}-identity-reader"

    @property
    def pulumi_backend_url(self) -> str:
        return f"azblob://{self.pulumi_storage_container_name}"

    @property
    def pulumi_encryption_key(self) -> KeyVaultKey:
        if not self._pulumi_encryption_key:
            azure_sdk = AzureSdk(subscription_name=self.subscription_name)
            self._pulumi_encryption_key = azure_sdk.get_keyvault_key(
                key_name=self.pulumi_encryption_key_name,
                key_vault_name=self.key_vault_name,
            )
        return self._pulumi_encryption_key

    @property
    def pulumi_encryption_key_version(self) -> str:
        """ID for the Pulumi encryption key"""
        key_id: str = self.pulumi_encryption_key.id
        return key_id.split("/")[-1]

    @property
    def pulumi_secrets_provider_url(self) -> str:
        return f"azurekeyvault://{self.key_vault_name}.vault.azure.net/keys/{self.pulumi_encryption_key_name}/{self.pulumi_encryption_key_version}"

    def to_yaml(self) -> str:
        return yaml.dump(self.model_dump(), indent=2)
