<#
.SYNOPSIS
    Creates a backUp container for input container. Forms Unique name for backup container if not provided explicitly.
.DESCRIPTION
    This is an automation script to perform below tasks
    1. Creates a backUp container for input container.
    2. Forms Unique name for backup container if not provided explicitly.

.NOTES
    Version        : 1.0
    File Name      : migration.ps1
    Author         : Pushpdeep Gupta (pusgup@microsoft.com)
    Creation Date  : March 22, 2021
    Prerequisites  : PowerShell V7.x, Azure Cosmos Data Migration tool (dt.exe)
    Purpose/Change : Initial script development
#>
[CmdletBinding()]
param (
    [string] $cosmosConnectionString,
    [string] $collectionName,
    [string] $backupCollection,
    [string] $dmtPath
)


#Create a back-Up collection
#Add current epoch time in back up collection name
$epochTime = Get-Date (Get-Date).ToUniversalTime() -UFormat %s
$finalBackUpCollection = [string]::IsNullOrEmpty($backupCollection) ? $collectionName + $epochTime : $backupCollection
Write-Host " Backup in progress. Backup name: $($finalBackUpCollection)"
$importArgs = "/s:DocumentDB /s.ConnectionString:""$($cosmosConnectionString)"" /s.Collection:""$($collectionName)"" /t:DocumentDB /t.ConnectionString:""$($cosmosConnectionString)"" /t.Collection:""$($finalBackUpCollection)"" /t.PartitionKey:/_partitionKey /t.CollectionThroughput:4000"
Start-Process -NoNewWindow -Wait -FilePath $dmtPath -ArgumentList $importArgs
Write-Host "Backup Completed. Container: $($finalBackUpCollection)"