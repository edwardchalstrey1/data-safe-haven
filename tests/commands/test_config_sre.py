from pathlib import Path

from data_safe_haven.commands.config import config_command_group
from data_safe_haven.config import ContextManager, SREConfig
from data_safe_haven.config.sre_config import sre_config_name
from data_safe_haven.exceptions import (
    DataSafeHavenAzureStorageError,
    DataSafeHavenConfigError,
    DataSafeHavenError,
)
from data_safe_haven.external import AzureSdk


class TestShowSRE:
    def test_show(self, mocker, runner, context, sre_config_yaml):
        sre_name = "sandbox"
        mock_method = mocker.patch.object(
            AzureSdk, "download_blob", return_value=sre_config_yaml
        )
        result = runner.invoke(config_command_group, ["show", sre_name])

        assert result.exit_code == 0
        assert sre_config_yaml in result.stdout

        mock_method.assert_called_once_with(
            sre_config_name(sre_name),
            context.resource_group_name,
            context.storage_account_name,
            context.storage_container_name,
        )

    def test_show_file(self, mocker, runner, sre_config_yaml, tmp_path):
        mocker.patch.object(AzureSdk, "download_blob", return_value=sre_config_yaml)
        template_file = (tmp_path / "template_show.yaml").absolute()
        result = runner.invoke(
            config_command_group, ["show", "sre-name", "--file", str(template_file)]
        )

        assert result.exit_code == 0
        with open(template_file) as f:
            template_text = f.read()
        assert sre_config_yaml in template_text

    def test_no_context(self, mocker, runner):
        sre_name = "sandbox"
        mocker.patch.object(
            ContextManager, "from_file", side_effect=DataSafeHavenConfigError(" ")
        )
        result = runner.invoke(config_command_group, ["show", sre_name])
        assert "No context is selected" in result.stdout
        assert result.exit_code == 1

    def test_no_selected_context(self, mocker, runner):
        sre_name = "sandbox"
        mocker.patch.object(
            ContextManager, "assert_context", side_effect=DataSafeHavenConfigError(" ")
        )
        result = runner.invoke(config_command_group, ["show", sre_name])
        assert "No context is selected" in result.stdout
        assert result.exit_code == 1

    def test_no_storage_account(self, mocker, runner):
        sre_name = "sandbox"
        mocker.patch.object(
            SREConfig,
            "from_remote_by_name",
            side_effect=DataSafeHavenAzureStorageError(" "),
        )
        result = runner.invoke(config_command_group, ["show", sre_name])
        assert "Ensure SHM is deployed" in result.stdout
        assert result.exit_code == 1

    def test_incorrect_sre_name(self, mocker, runner):
        sre_name = "sandbox"
        mocker.patch.object(
            SREConfig, "from_remote_by_name", side_effect=DataSafeHavenError(" ")
        )
        result = runner.invoke(config_command_group, ["show", sre_name])
        assert "No configuration exists for an SRE" in result.stdout
        assert result.exit_code == 1


class TestTemplateSRE:
    def test_template(self, runner):
        result = runner.invoke(config_command_group, ["template"])
        assert result.exit_code == 0
        assert (
            "subscription_id: ID of the Azure subscription that the SRE will be deployed to"
            in result.stdout
        )
        assert "sre:" in result.stdout

    def test_template_file(self, runner, tmp_path):
        template_file = (tmp_path / "template_create.yaml").absolute()
        result = runner.invoke(
            config_command_group, ["template", "--file", str(template_file)]
        )
        assert result.exit_code == 0
        with open(template_file) as f:
            template_text = f.read()
        assert (
            "subscription_id: ID of the Azure subscription that the SRE will be deployed to"
            in template_text
        )
        assert "sre:" in template_text


class TestUploadSRE:
    def test_upload_new(
        self, mocker, context, runner, sre_config_yaml, sre_config_file
    ):
        sre_name = "SandBox"
        sre_filename = sre_config_name(sre_name)
        mock_exists = mocker.patch.object(
            SREConfig, "remote_exists", return_value=False
        )
        mock_upload = mocker.patch.object(AzureSdk, "upload_blob", return_value=None)
        result = runner.invoke(
            config_command_group,
            ["upload", str(sre_config_file)],
        )
        assert result.exit_code == 0

        mock_exists.assert_called_once_with(context, filename=sre_filename)
        mock_upload.assert_called_once_with(
            sre_config_yaml,
            sre_filename,
            context.resource_group_name,
            context.storage_account_name,
            context.storage_container_name,
        )

    def test_upload_no_changes(
        self, mocker, context, runner, sre_config, sre_config_file
    ):
        sre_name = "SandBox"
        sre_filename = sre_config_name(sre_name)
        mock_exists = mocker.patch.object(SREConfig, "remote_exists", return_value=True)
        mock_from_remote = mocker.patch.object(
            SREConfig, "from_remote", return_value=sre_config
        )
        mock_upload = mocker.patch.object(AzureSdk, "upload_blob", return_value=None)
        result = runner.invoke(
            config_command_group,
            ["upload", str(sre_config_file)],
        )
        assert result.exit_code == 0

        mock_exists.assert_called_once_with(context, filename=sre_filename)
        mock_from_remote.assert_called_once_with(context, filename=sre_filename)
        mock_upload.assert_not_called()

        assert "No changes, won't upload configuration." in result.stdout

    def test_upload_changes(
        self,
        mocker,
        context,
        runner,
        sre_config_alternate,
        sre_config_file,
        sre_config_yaml,
    ):
        sre_name = "sandbox"
        sre_filename = sre_config_name(sre_name)
        mock_exists = mocker.patch.object(SREConfig, "remote_exists", return_value=True)
        mock_from_remote = mocker.patch.object(
            SREConfig, "from_remote", return_value=sre_config_alternate
        )
        mock_upload = mocker.patch.object(AzureSdk, "upload_blob", return_value=None)
        result = runner.invoke(
            config_command_group,
            ["upload", str(sre_config_file)],
            input="y\n",
        )
        assert result.exit_code == 0

        mock_exists.assert_called_once_with(context, filename=sre_filename)
        mock_from_remote.assert_called_once_with(context, filename=sre_filename)
        mock_upload.assert_called_once_with(
            sre_config_yaml,
            sre_filename,
            context.resource_group_name,
            context.storage_account_name,
            context.storage_container_name,
        )

        assert "--- remote" in result.stdout
        assert "+++ local" in result.stdout

    def test_upload_changes_n(
        self, mocker, context, runner, sre_config_alternate, sre_config_file
    ):
        sre_name = "SandBox"
        sre_filename = sre_config_name(sre_name)
        mock_exists = mocker.patch.object(SREConfig, "remote_exists", return_value=True)
        mock_from_remote = mocker.patch.object(
            SREConfig, "from_remote", return_value=sre_config_alternate
        )
        mock_upload = mocker.patch.object(AzureSdk, "upload_blob", return_value=None)
        result = runner.invoke(
            config_command_group,
            ["upload", str(sre_config_file)],
            input="n\n",
        )
        assert result.exit_code == 0

        mock_exists.assert_called_once_with(context, filename=sre_filename)
        mock_from_remote.assert_called_once_with(context, filename=sre_filename)
        mock_upload.assert_not_called()

        assert "--- remote" in result.stdout
        assert "+++ local" in result.stdout

    def test_upload_no_file(self, mocker, runner):
        mocker.patch.object(AzureSdk, "upload_blob", return_value=None)
        result = runner.invoke(
            config_command_group,
            ["upload"],
        )
        assert result.exit_code == 2

    def test_upload_file_does_not_exist(self, mocker, runner):
        mocker.patch.object(Path, "is_file", return_value=False)
        result = runner.invoke(config_command_group, ["upload", "fake_config.yaml"])
        assert "Configuration file 'fake_config.yaml' not found." in result.stdout
        assert result.exit_code == 1
