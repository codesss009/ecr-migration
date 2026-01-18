#Requires -Version 5.1
$ErrorActionPreference = "Stop"

########################################
# CONFIG
########################################
$Region        = "us-east-1"  # Humanity's single point of Failure
$SourceAccount = "<SOURCE_AWS_ACCOUNT_ID>"
$DestAccount   = "<DEST_AWS_ACCOUNT_ID>"

$SrcProfile = "src"
$DstProfile = "dst"

$Images = @(
    @{ src = "<source-repo-name>"; dst = "<dest-repo-name>"; tag = "<tag1>" }
    @{ src = "<source-repo-name>"; dst = "<dest-repo-name>"; tag = "<tag2>" }
    @{ src = "<source-repo-name>"; dst = "<dest-repo-name>"; tag = "<tag3>" }
    @{ src = "<source-repo-name>"; dst = "<dest-repo-name>"; tag = "<tag4>" }
    @{ src = "<source-repo-name>"; dst = "<dest-repo-name>"; tag = "<tag5>" }
    # Any more Images that needs to be migrated can be added here accordingly.
)

########################################
# FUNCTIONS
########################################
function Login-ECR {
    param (
        [string]$Account,
        [string]$Profile
    )

    Write-Host "Logging into ECR: $Account ($Profile)"

    $password = aws --profile $Profile ecr get-login-password --region $Region
    if (-not $password) {
        throw "Failed to get ECR login password for $Profile"
    }

    $loginServer = "$Account.dkr.ecr.$Region.amazonaws.com"
    $password | docker login --username AWS --password-stdin $loginServer
}

function Ensure-DestinationRepo {
    param (
        [string]$Repo
    )

    try {
        aws --profile $DstProfile ecr describe-repositories --repository-names $Repo --region $Region | Out-Null
        Write-Host "Repo exists: $Repo"
    }
    catch {
        Write-Host "Creating repo: $Repo"
        aws --profile $DstProfile ecr create-repository --repository-name $Repo --region $Region | Out-Null
    }
}

function Migrate-Image {
    param (
        [string]$SrcRepo,
        [string]$DstRepo,
        [string]$Tag
    )

    $srcUri = "$SourceAccount.dkr.ecr.$Region.amazonaws.com/${SrcRepo}:$Tag"
    $dstUri = "$DestAccount.dkr.ecr.$Region.amazonaws.com/${DstRepo}:$Tag"

    Write-Host "Pulling $srcUri"
    docker pull $srcUri

    Write-Host "Tagging $dstUri"
    docker tag $srcUri $dstUri

    Write-Host "Pushing $dstUri"
    docker push $dstUri

    Write-Host "Migrated ${SrcRepo}:$Tag -> ${DstRepo}:$Tag"
}

########################################
# MAIN
########################################
Write-Host "Starting ECR migration..."

Login-ECR -Account $SourceAccount -Profile $SrcProfile
Login-ECR -Account $DestAccount   -Profile $DstProfile

foreach ($image in $Images) {
    Ensure-DestinationRepo -Repo $image.dst
    Migrate-Image -SrcRepo $image.src -DstRepo $image.dst -Tag $image.tag
}

Write-Host "All images migrated successfully." 
