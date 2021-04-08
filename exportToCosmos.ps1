<#
.SYNOPSIS
    A script to export data from Json documents to target cosmos containers. 
    It leverages dt.exe migration tool to transfer data across containers.
.DESCRIPTION
    An automation script to perform below tasks:
    1. Deletes the target container if exists.
    2. Create a fresh container updated with json docs provided in source file path.
.NOTES
    Version        : 1.1
    File Name      : exportToCosmos.ps1
    Author         : Pushpdeep Gupta (pusgup@microsoft.com)
    Creation Date  : March 22, 2021
    Prerequisites  : PowerShell V7.x, Azure Cosmos Data Migration tool (dt.exe)
    Purpose/Change : Initial script development
                     deletingExistingContainerRequired: New flag to skip container deletion if not needed.
#>
[CmdletBinding()]
param (
    [string] $userName,
    [string] $secret,
    [string] $tenantId,
    [string] $subscriptionId,
    [string] $sourceFilePath,
    [string] $targetContainerName,
     [bool] $deletingExistingContainerRequired,
    [string] $partitionKey,
    [string] $cosmosConnectionString,
    [string] $accountName,
    [string] $resourceGroup,
    [string] $databaseName,
    [Int32] $requestUnit,
    [string] $dmtPath
)
# Login to Azure Subscription
az Login --service-principal --username $userName --password $secret --tenant $tenantId

# set subscription 
az account set --subscription $subscriptionId

if($deletingExistingContainerRequired){
#Delete the container if exists
Write-Host "Deleting container $($targetContainerName) if exists..."
az cosmosdb sql container delete --account-name $accountName --database-name $databaseName --name $targetContainerName  --resource-group $resourceGroup --subscription $subscriptionId --yes -y
Write-Host "Existing container has been deleted"
}


# Upload documents from local machine to Cosmos Container
$exportArgs = "/s:JsonFile /s.Files:""$($sourceFilePath)"" /t:DocumentDB /t.ConnectionString:""$($cosmosConnectionString)"" /t.CollectionThroughput:""$($requestUnit)"" /t.Collection:""$($targetContainerName)"" /t.PartitionKey:""$($partitionKey)"""
Write-Host "Creating new container... Uploading documents from $($sourceFilePath)..."
Start-Process -NoNewWindow -Wait -FilePath $dmtPath -ArgumentList $exportArgs
Write-Host "Container $($targetContainerName) created with new documents from $($sourceFilePath)"
Write-Host "Container has been updated with new documents. Please match the documents count from backup container to newly created container. If matches migration was successful."
