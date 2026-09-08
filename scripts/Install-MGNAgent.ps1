$directoryPath = "C:\MGN"
$executableUri = "https://aws-application-migration-service-us-east-1.s3.us-east-1.amazonaws.com/latest/windows/AwsReplicationWindowsInstaller.exe"
$executablePath = "$directoryPath\AwsReplicationWindowsInstaller.exe"
$region = "us-east-1"
$awsAccessKeyId = "ACCESSKEY"
$awsSecretAccessKey = "SECRETACCESSKEY"

# Create directory if it doesn't exist
if (-Not (Test-Path -Path $directoryPath)) {
    New-Item -ItemType Directory -Path $directoryPath
}

# Download the executable
Invoke-WebRequest -Uri $executableUri -OutFile $executablePath

# Define arguments for MGN installer
$arguments = "--region $region --aws-access-key-id $awsAccessKeyId --aws-secret-access-key $awsSecretAccessKey --no-prompt --user-provided-id $env:COMPUTERNAME"

# Run the executable with parameters
Start-Process -FilePath $executablePath -ArgumentList $arguments -Wait