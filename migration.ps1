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
                     Input parameters related to josn updates have been moved to josn file. Please use $inputJsonPath to provide update parameters.
#>

Using module .\InputParameters.psm1
[CmdletBinding()]
param (
    [string] $cosmosConnectionString,
    [string] $collectionName,
    [string] $backupCollection,
    [string] $dmtPath,
    [string] $directoryToStoreMigratedFiles,
    [bool] $importFromCosmosRequired,
    [string] $importedFileLocation,
    [string] $inputJsonPath,
    [bool] $forceReplace, 
    [string] $folderPrefix
)


Import-Module ".\mapping.psm1"

# Preparing Update variables
Write-Host "Preparing update varibales from input.json"
$inputJson = Get-Content $inputJsonPath | Out-String | ConvertFrom-Json
$inputParameter = [InputParameter]($inputJson)
$changeDataType = $inputParameter.command -eq "TypeConversion"

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

# Run migration tool to download documents from Source DB to json file in migration directory.
if($importFromCosmosRequired){
Write-Host "Importing Backup files for migration..."
$importArgs = "/s:DocumentDB /s.ConnectionString:""$($cosmosConnectionString)"" /s.Collection:""$($backupCollection)"" /t:JsonFile /t.File:""$($importedFileLocation)"""
Start-Process -NoNewWindow -Wait -FilePath $dmtPath -ArgumentList $importArgs
Write-Host "Import Competed. Imported file location: $($importedFileLocation)"
}

Write-Host "Loading records..."

# Update documents
$discardedIds = ''
$updatedRecordCount = 0
$json = Get-Content $importedFileLocation  | Out-String | ConvertFrom-Json

Write-Host "Total Documents: $($json.Length)"

if([string]::IsNullOrEmpty($filterProperty)){
    $filteredJson =  $json
}
else {
    $filteredJson =  $json | Where-Object {$_.$filterProperty -eq $filterPropertyValue}
}

Write-Host "Updating $($filteredJson.Length) Documents ..."

foreach($item in $filteredJson) {   
    try {
        # If Target property valus is provided.
        if(![string]::IsNullOrEmpty($inputParameter.targetPropertyConstantValue)){
            $sv = $inputParameter.targetPropertyConstantValue  
            
        }
                
        # If source property is not null
        elseif(![string]::IsNullOrEmpty($inputParameter.sourceProperty)){
            $sv =  GetorSetPropertyValues -item $item -sv $null -copyValue $false -changeDataType $false -dataType "" -keepOriginalValue $false -property $inputParameter.sourceProperty -fr $inputParameter.forceReplace 
        } 

        if($null -eq $sv){
            $sv = ''
        }
        

        $sv = GetorSetPropertyValues -item $item -sv $sv -copyValue $true -changeDataType $changeDataType -dataType $inputParameter.dataType -keepOriginalValue $inputParameter.keepTargetValueAfterDataTypeChange -property $inputParameter.targetProperty -fr $inputParameter.forceReplace
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


