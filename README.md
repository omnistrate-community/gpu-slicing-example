# Container Based Service Template

Example on how to build and deploy a Container Based Service in (Omnistrate)[https://www.omnistrate.com]

## Configuration Setup
Before using the make commands, you need to set up the following configuration files:

1. `.env` file:
   ```
   OMNISTRATE_EMAIL=your-email@example.com
   ```

2. `.omnistrate.password` file:
   ```
   your-omnistrate-password
   ```
   Make sure to keep this file secure and never commit it to version control.

## Available Make Commands

- `make install-ctl`: Installs the Omnistrate CLI tool (omnistrate-ctl) via Homebrew
- `make upgrade-ctl`: Upgrades the Omnistrate CLI tool to the latest version
- `make login`: Logs in to Omnistrate using credentials from your environment
- `make release`: Builds and releases the service using the compose.yaml configuration
- `make create`: Creates a new instance of the service with the following defaults:
  - Environment: Dev
  - Cloud Provider: Azure
  - Region: eastus2
- `make list`: Lists all instances in JSON format
- `make delete-all`: Deletes all running instances immediately
- `make delete-all-wait`: Deletes all instances and waits for completion
- `make destroy`: Deletes all instances and removes the service completely
