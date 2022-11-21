"""Interact with users in an Azure Active Directory"""
# Standard library imports
import base64
import pathlib
from typing import Sequence

# Local imports
from data_safe_haven.external import AzureApi
from data_safe_haven.helpers import FileReader
from data_safe_haven.mixins import LoggingMixin
from .research_user import ResearchUser


class ActiveDirectoryUsers(LoggingMixin):
    """Interact with users in an Azure Active Directory"""

    def __init__(
        self,
        resource_group_name,
        subscription_name,
        vm_name,
        *args,
        **kwargs,
    ):
        super().__init__(*args, **kwargs)
        self.azure_api = AzureApi(subscription_name)
        self.resource_group_name = resource_group_name
        self.resources_path = (
            pathlib.Path(__file__).parent.parent.parent / "resources"
        ).resolve()
        self.vm_name = vm_name

    def add(self, new_users: Sequence[ResearchUser]) -> None:
        """Add list of users to local Active Directory"""
        add_users_script = FileReader(
            self.resources_path / "active_directory" / "add_users.ps1"
        )
        csv_contents = ["SamAccountName;GivenName;Surname;Mobile;Email;Country"]
        for user in new_users:
            csv_contents += [
                ";".join(
                    [
                        user.username,
                        user.given_name,
                        user.surname,
                        user.phone_number,
                        user.email_address,
                        user.country,
                    ]
                )
            ]
        user_details_b64 = base64.b64encode("\n".join(csv_contents).encode("utf-8"))
        output = self.azure_api.run_remote_script(
            self.resource_group_name,
            add_users_script.file_contents(),
            {"UserDetailsB64": user_details_b64.decode()},
            self.vm_name,
        )
        for line in output.split("\n"):
            self.info(line)

    def list(self) -> Sequence[ResearchUser]:
        """List users in a local Active Directory"""
        list_users_script = FileReader(
            self.resources_path / "active_directory" / "list_users.ps1"
        )
        output = self.azure_api.run_remote_script(
            self.resource_group_name,
            list_users_script.file_contents(),
            {},
            self.vm_name,
        )
        users = []
        for line in output.split("\n"):
            tokens = line.split(";")
            if len(tokens) >= 6:
                users.append(
                    ResearchUser(
                        email_address=tokens[4],
                        given_name=tokens[1],
                        phone_number=tokens[3],
                        sam_account_name=tokens[0],
                        surname=tokens[2],
                        user_principal_name=tokens[5],
                    )
                )
        return users
