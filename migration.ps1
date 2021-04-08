<#
.SYNOPSIS
    This script is for restructuring or updating json documents in DocumentDB. 
    It leverages dt.exe migration tool to transfer data across containers.
.DESCRIPTION
    This is an automation script to perform below tasks
    1. Create a new backup container before restructuring data.
    2. Import all the documents in a single json file called "imported-file.json" and that gets stored in the same directory.
    3. Unique folder is generated on each run.
    4. Calls script "mapping.psm1" to update json objects based on user input.
    5. Once migrated, new file with updated records is created in the same running folder, and named as "migrated-file.json"

.NOTES
    Version        : 1.1
    File Name      : migration.ps1
    Author         : Pushpdeep Gupta (pusgup@microsoft.com)
    Creation Date  : March 22, 2021
    Prerequisites  : PowerShell V7.x, Azure Cosmos Data Migration tool (dt.exe)
    Purpose/Change : Initial script development
                     Moving backUp creation code to new powershell script to reduce coupling.
                     New parameter for providing imported file location if you want to skip downlaod from Cosmos.
                     importFromCosmosRequired: New flag to skip download in case not required and file is passed through importedFileLocation.
#>
[CmdletBinding()]
param (
    [string] $cosmosConnectionString,
    [string] $collectionName,
    [string] $backupCollection,
    [string] $dmtPath,
    [string] $directoryToStoreMigratedFiles,
    [bool] $importFromCosmosRequired,
    [string] $importedFileLocation,
    [string] $sourceProperty,
    [string] $targetProperty,
    [string] $targetPropertyValue,
    [string] $filterProperty,
    [string] $filterPropertyValue,
    [bool] $forceReplace, 
    [string] $folderPrefix
)

Import-Module ".\mapping.psm1"

# Get current timestamp
$day = Get-Date -Format "dd"
$month = Get-Date -Format "MM"
$year = Get-Date -Format "yyyy"
$hour = Get-Date -Format "HH"
$minute = Get-Date -Format "mm"
$second = Get-Date -Format "ss"
$timestamp = "$($day)_$($month)_$($year)_$($hour)_$($minute)_$($second)"

#create Base path if not exists
$appendedFolder = "$($timestamp)-$($folderPrefix)"
$basePath = "$($directoryToStoreMigratedFiles)\$($appendedFolder)"
New-Item -ItemType Directory -Force -Path $basePath

$importedFileLocation = $importFromCosmosRequired ? "$($directoryToStoreMigratedFiles)\$($appendedFolder)\imported-file.json" : $importedFileLocation
$migratedFileLocation = "$($directoryToStoreMigratedFiles)\$($appendedFolder)\migrated-file.json"

if($importFromCosmosRequired){
#Import documents into single json file from source Cosmos DB
# Run migration tool to donlaod documents in migration directory.
Write-Host "Importing Backup files for migration..."
$importArgs = "/s:DocumentDB /s.ConnectionString:""$($cosmosConnectionString)"" /s.Collection:""$($backupCollection)"" /t:JsonFile /t.File:""$($importedFileLocation)"""
Start-Process -NoNewWindow -Wait -FilePath $dmtPath -ArgumentList $importArgs
Write-Host "Import Competed. Imported file location: $($importedFileLocation)"
}

Write-Host "Loading records..."
#Property remapping
$discardedIds = ''
$json = Get-Content $importedFileLocation  | Out-String | ConvertFrom-Json
$filteredJson = $json | Where-Object {$_.$filterProperty -eq $filterPropertyValue}
Write-Host "Updating properties of $($json.Length) Documents ..."
foreach($item in $filteredJson) {   
    try {
        #Source
        if(![string]::IsNullOrEmpty($targetPropertyValue)){
            $sv = $targetPropertyValue  
            
        }
        else{
            $sv =  GetorSetPropertyValues -item $item -sv $null -copyValue $false -property $sourceProperty -fr $forceReplace
        } 
        if($null -eq $sv){
            $sv = ''
        }   

        $sv = GetorSetPropertyValues -item $item -sv $sv -copyValue $true -property $targetProperty -fr $forceReplace
        $updatedRecordCount++     
    }
    catch {
        $discardedIds = "$($discardedIds), $($item.id)"
        Write-Error $PSItem.Exception
    }
}

$json | ConvertTo-Json -Depth 9 | Set-Content $migratedFileLocation
Write-Host "Update completed for $($updatedRecordCount) documents. Migrated file: $($migratedFileLocation)"
Write-Output "Douments errored out: $($discardedIds.Length). Ids: $($discardedIds)"

