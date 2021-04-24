<#
.SYNOPSIS
    Creates a backUp container for input container. Forms Unique name for backup container if not provided explicitly.
.DESCRIPTION
    This is an automation script to perform below tasks
    1. Creates a backUp container for input container.
    2. Forms Unique name for backup container if not provided explicitly.

.NOTES
    Version        : 1.1
    File Name      : migration.ps1
    Author         : Pushpdeep Gupta (pusgup@microsoft.com)
    Creation Date  : March 22, 2021
    Prerequisites  : PowerShell V7.x, Azure Cosmos Data Migration tool (dt.exe)
    Purpose/Change : Initial script development
                     Removed unwanted variables.
                     Downloading data transfer tool as part of script execution.
                     Added mandatory/optional tags for parameters.
                     Accepting Partition key as an input
#>
[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)][string] $cosmosConnectionString,
    [Parameter(Mandatory = $true)][string] $sourceContainerName,
    [Parameter(Mandatory = $false)][string] $backupContainerName,
    [Parameter(Mandatory = $true)][string] $partitionKey,
    [Parameter(Mandatory= $true)][Int32] $requestUnit
)

Import-Module .\toolSetUp.psm1

# Create a Back-Up container
try {

    # Downaloding data transfer tool if not exist
    $dmtPath = downloadDataTransferToolIfNotExist($PSScriptRoot)

    # Add current epoch time in back up collection name
    $epochTime = Get-Date (Get-Date).ToUniversalTime() -UFormat %s
    $finalBackUpCollection = [string]::IsNullOrEmpty($backupContainerName) ? $sourceContainerName + $epochTime : $backupContainerName
    Write-Host "BackUp name $($finalBackUpCollection)"
    Write-Host "Backup in progress.."
    $importArgs = "/s:DocumentDB /s.ConnectionString:""$($cosmosConnectionString)"" /s.Collection:""$($sourceContainerName)"" /t:DocumentDB /t.ConnectionString:""$($cosmosConnectionString)"" /t.Collection:""$($finalBackUpCollection)"" /t.PartitionKey:""$($partitionKey)"" /t.CollectionThroughput:4000"

    # execute data transfer tool
    $process = Start-Process -NoNewWindow -PassThru -Wait -FilePath $dmtPath -ArgumentList $importArgs

    if ($process.ExitCode -eq -1) {
        throw New-Object System.Exception "BackUp stopped. Exception occoured while transferring the documents. Please verify all the input parameters."
    }

    Write-Host "Backup Completed : $($finalBackUpCollection)"
}
catch {
    Write-Host -ForegroundColor Red -BackgroundColor Black $_
}
