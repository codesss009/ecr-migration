# ecr-migration
Powershell Script to migrate Ecr images from source -> dest AWS Account
```markdown
# ecr-migration

PowerShell scripts to migrate ECR images from a source AWS account to a destination AWS account.

## Overview

This repository contains scripts and instructions to copy Docker container images stored in Amazon ECR from one AWS account (source) to another (destination). The scripts handle authentication, optional repository creation, pulling, tagging, and pushing images across accounts and regions.

Use-cases:
- Consolidating images into a central account.
- Migrating images for account cutover.
- Backing up images to a different account.

## Features

- Authenticate to ECR using AWS CLI credentials or assumed roles.
- List images in a repository and migrate specific tags or all tags.
- Optionally create the destination repository if it doesn't exist.
- Dry-run mode to preview actions without performing network operations.

## Prerequisites

- PowerShell 5.1+ (Windows) or PowerShell Core (cross-platform).
- Docker CLI installed and configured.
- AWS CLI v2 configured with profiles or credentials for source and destination accounts.
- IAM permissions to list, describe, create, and push to ECR in both accounts (see IAM section below).

Quick checks:
```bash
pwsh --version
docker --version
aws --version
```

## Before you start

Decide how you will authenticate to each account. Two common approaches:

1. Use two separate AWS CLI profiles (recommended for simplicity):
   - `aws configure --profile source`
   - `aws configure --profile dest`

2. Assume cross-account IAM roles using `aws sts assume-role` and temporary credentials, or configure profiles that already assume roles.

## Usage

General approach used by the scripts:
1. Authenticate to the source account's ECR registry.
2. Authenticate to the destination account's ECR registry.
3. Pull the image from the source registry.
4. Tag the image for the destination registry.
5. Push the image to the destination registry.

Example variables:
- SOURCE_ACCOUNT_ID: 111111111111
- DEST_ACCOUNT_ID: 222222222222
- REGION: us-east-1
- REPOSITORY: my-app
- TAG: latest

Example manual commands (useful to understand what the script does):

1. Authenticate (AWS CLI v2):
```powershell
aws ecr get-login-password --profile source --region $REGION | docker login --username AWS --password-stdin $SOURCE_ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com

aws ecr get-login-password --profile dest --region $REGION | docker login --username AWS --password-stdin $DEST_ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com
```

2. Pull, retag, and push:
```powershell
docker pull $SOURCE_ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/$REPOSITORY:$TAG
docker tag $SOURCE_ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/$REPOSITORY:$TAG $DEST_ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/$REPOSITORY:$TAG
docker push $DEST_ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/$REPOSITORY:$TAG
```

3. Create destination repository if needed:
```powershell
aws ecr describe-repositories --repository-names $REPOSITORY --profile dest --region $REGION || `
  aws ecr create-repository --repository-name $REPOSITORY --profile dest --region $REGION
```

## Example PowerShell script usage

Assuming the repository includes a script `migrate-ecr.ps1` (adjust the script name as required):

```powershell
# Example invocation
.\migrate-ecr.ps1 `
  -SourceProfile "source" `
  -DestProfile "dest" `
  -Region "us-east-1" `
  -Repository "my-app" `
  -Tags @("latest", "1.2.3") `
  -CreateDestRepository:$true `
  -DryRun:$false
```

Common flags:
- `-SourceProfile`: AWS CLI profile for source account
- `-DestProfile`: AWS CLI profile for destination account
- `-Region`: AWS region
- `-Repository`: ECR repository name
- `-Tags`: Array of tags to migrate (omit to migrate all)
- `-CreateDestRepository`: Create the destination repo if missing
- `-DryRun`: Show what would happen without performing actions

If your script uses different parameter names, adapt these examples accordingly.

## IAM permissions

Minimum permissions required for the source account profile:
- ecr:DescribeRepositories
- ecr:ListImages
- ecr:DescribeImages
- ecr:GetAuthorizationToken (or use AWS CLI `get-login-password`)

Minimum permissions required for the destination account profile:
- ecr:DescribeRepositories
- ecr:CreateRepository (if creating repos)
- ecr:PutImage
- ecr:BatchCheckLayerAvailability
- ecr:InitiateLayerUpload
- ecr:UploadLayerPart
- ecr:CompleteLayerUpload
- ecr:GetAuthorizationToken (or use AWS CLI `get-login-password`)

If using Docker pushes, ensure the IAM principal has permissions to push images (PutImage and the layer upload permissions).

## Troubleshooting

- Authentication errors:
  - Confirm AWS profiles are configured and active.
  - Ensure `aws ecr get-login-password` works for both profiles and regions.
- Docker login fails:
  - Ensure Docker daemon is running and you can login manually.
- Missing repository:
  - Create the destination repository or enable the script's create option.
- Large images/timeouts:
  - Ensure network stability and sufficient disk space for image pulls.
- Tag not found:
  - Verify tags with `aws ecr list-images --repository-name $REPOSITORY --profile source --region $REGION`.

## Tips

- Use `--profile` per-account to avoid credential confusion.
- Run with `-DryRun` first to confirm what will be migrated.
- For many repositories/tags, consider scripting pagination and retries for robustness.

## Contributing

Contributions are welcome. Open an issue or submit a PR with improvements, additional scripts, or bug fixes. Please include test steps and, if appropriate, reference AWS CLI versions used during testing.

## License

No License as of now

## Contact

codesss009
```
