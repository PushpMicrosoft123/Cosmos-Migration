<#
.SYNOPSIS
    A script to export data from Json documents to target cosmos containers. 
    It leverages dt.exe migration tool to transfer data across containers.
.DESCRIPTION
    An automation script to perform below tasks:
    1. Deletes the target container if exists.
    2. Create a fresh container updated with json docs provided in source file path.
.NOTES
    Version        : 1.0
    File Name      : exportToCosmos.ps1
    Author         : Pushpdeep Gupta (pusgup@microsoft.com)
    Creation Date  : March 22, 2021
    Prerequisites  : PowerShell V7.x, Azure Cosmos Data Migration tool (dt.exe), Azure CLI
    Purpose/Change : Initial script development
                     deletingExistingContainerRequired: New flag to skip container deletion if not needed.
                     Loading data transfer tool as part of script execution.
#>
[CmdletBinding()]
param (
    [string] $userName,
    [string] $secret,
    [string] $tenantId,
    [string] $subscriptionId,
    [string] $accountName,
    [string] $resourceGroup,
    [string] $databaseName,
    [string] $sourceFilePath,
    [string] $targetContainerName,
    [bool] $deletingExistingContainerRequired,
    [string] $partitionKey,
    [string] $cosmosConnectionString,
    [Int32] $requestUnit
)

try {
    # Downaloding data transfer tool if not exist
    $dmtPath = downloadDataTransferToolIfNotExist($PSScriptRoot)
    if ($deletingExistingContainerRequired) {
        # Login to Azure Subscription
        az Login --service-principal --username $userName --password $secret --tenant $tenantId

        # set subscription 
        az account set --subscription $subscriptionId

        # Delete the container if exists
        Write-Host "Deleting container $($targetContainerName) if exists..."
        az cosmosdb sql container delete --account-name $accountName --database-name $databaseName --name $targetContainerName  --resource-group $resourceGroup --subscription $subscriptionId --yes -y
        Write-Host "Delete completed"
    }

    # Upload documents from local machine to Cosmos Container
    $exportArgs = "/s:JsonFile /s.Files:""$($sourceFilePath)"" /t:DocumentDB /t.ConnectionString:""$($cosmosConnectionString)"" /t.CollectionThroughput:""$($requestUnit)"" /t.Collection:""$($targetContainerName)"" /t.PartitionKey:""$($partitionKey)"""
    Write-Host "Creating new container: $($targetContainerName)"
    Write-Host "Uploading documents from $($sourceFilePath)"
    $process = Start-Process -NoNewWindow -PassThru -Wait -FilePath $dmtPath -ArgumentList $exportArgs

    if ($process.ExitCode -eq -1) {
        throw New-Object System.Exception "BackUp stopped. Exception occoured while transferring the documents. Please verify all the input parameters."
    }

    Write-Host "Container $($targetContainerName) created with new documents from $($sourceFilePath)"
}
catch {
    Write-Host -ForegroundColor Red -BackgroundColor Black $_
}
