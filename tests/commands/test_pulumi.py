from data_safe_haven.commands.pulumi import pulumi_command_group


class TestRun:
    def test_run_shm(
        self,
        runner,
        mock_config_from_remote,  # noqa: ARG002
        mock_pulumi_config_from_remote,  # noqa: ARG002
        mock_azure_cli_confirm,  # noqa: ARG001
        mock_install_plugins,  # noqa: ARG001
        mock_key_vault_key,  # noqa: ARG001
        offline_pulumi_account,  # noqa: ARG001
        local_project_settings,  # noqa: ARG001
    ):
        result = runner.invoke(pulumi_command_group, ["shm", "stack ls"])
        assert result.exit_code == 0
        assert "shm-acmedeployment*" in result.stdout

    def test_run_shm_invalid(
        self,
        runner,
        mock_config_from_remote,  # noqa: ARG002
        mock_pulumi_config_from_remote,  # noqa: ARG002
        mock_azure_cli_confirm,  # noqa: ARG001
        mock_install_plugins,  # noqa: ARG001
        mock_key_vault_key,  # noqa: ARG001
        offline_pulumi_account,  # noqa: ARG001
        local_project_settings,  # noqa: ARG001
    ):
        result = runner.invoke(pulumi_command_group, ["shm", "not a pulumi command"])
        assert result.exit_code == 1
