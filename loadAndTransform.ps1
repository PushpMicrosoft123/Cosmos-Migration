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
    Version        : 1.2
    File Name      : migration.ps1
    Author         : Pushpdeep Gupta (pusgup@microsoft.com)
    Creation Date  : March 22, 2021
    Prerequisites  : PowerShell V7.x, Azure Cosmos Data Migration tool (dt.exe)
    Purpose/Change : Initial script development
                     Moving backUp creation code to new powershell script to reduce coupling.
                     New parameter for providing imported file location if you want to skip downlaod from Cosmos.
                     importFromCosmosRequired: New flag to skip download in case not required and file is passed through importedFileLocation.
                     Input parameters related to josn updates have been moved to josn file. Please use $inputJsonPath to provide update parameters.
                     Removed unwanted unwanted parameters.
                     Loading data transfer tool as part of script execution.
#>

Using module .\InputParameters.psm1

[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)][string] $cosmosConnectionString,
    [Parameter(Mandatory = $true)][string] $sourceContainerName,
    [Parameter(Mandatory = $true)][string] $directoryToStoreUpdatedDocuments,
    [bool] $importFromCosmosRequired,
    [string] $importedFileLocation,
    [Parameter(Mandatory = $true)][string] $inputJsonPath,
    [string] $folderPrefix
)


Import-Module .\toolSetUp.psm1
Import-Module .\mapping.psm1
try {
    # Downaloding data transfer tool if not exist
    $dmtPath = downloadDataTransferToolIfNotExist($PSScriptRoot)

    # Preparing Update variables
    Write-Host "Preparing update varibales from input.json"
    $inputJson = Get-Content $inputJsonPath | Out-String | ConvertFrom-Json
    $inputParameter = [InputParameter]($inputJson)
    $changeDataType = $inputParameter.command -eq "TypeConversion"
    $deleteTargetProperty = $inputParameter.command -eq "DeleteTarget"
    $copyToTarget = $true
 
    # Get current timestamp
    $day = Get-Date -Format "dd"
    $month = Get-Date -Format "MM"
    $year = Get-Date -Format "yyyy"
    $hour = Get-Date -Format "HH"
    $minute = Get-Date -Format "mm"
    $second = Get-Date -Format "ss"
    $timestamp = "$($day)_$($month)_$($year)_$($hour)_$($minute)_$($second)"
 
    # create new folder to store updated documents
    $appendedFolder = "$($timestamp)-$($folderPrefix)"
    $basePath = "$($directoryToStoreUpdatedDocuments)\$($appendedFolder)"
    New-Item -ItemType Directory -Force -Path $basePath
 
    $importedFileLocation = $importFromCosmosRequired ? "$($directoryToStoreUpdatedDocuments)\$($appendedFolder)\imported-file.json" : $importedFileLocation
    $importSelectedDocumentsLocation = $importFromCosmosRequired ? "$($directoryToStoreUpdatedDocuments)\$($appendedFolder)\imported-filter-file.json" : $importedFileLocation
    $migratedFileLocation = "$($directoryToStoreUpdatedDocuments)\$($appendedFolder)\migrated-file.json"
    $migratedFilterFileLocation = "$($directoryToStoreUpdatedDocuments)\$($appendedFolder)\migrated-filter-file.json"
 
    # Run data transfer tool to download documents from Source DB to json file in the input directory.
    if ($importFromCosmosRequired) {
        Write-Host "Importing all documents for transformation.."
        # Import all the documents
        $importArgs = "/s:DocumentDB /s.ConnectionString:""$($cosmosConnectionString)"" /s.Collection:""$($sourceContainerName)"" /t:JsonFile /t.File:""$($importedFileLocation)"""
        # $p = Start-Process -NoNewWindow -PassThru -Wait -FilePath $dmtPath -ArgumentList $importArgs
        
        # if ($p.ExitCode -eq -1) {
        #     throw New-Object System.Exception "Import failed. Exception occoured while transferring the documents. Please verify all the input parameters."
        # }
        
        Write-Host "Import Competed. File location: $($importedFileLocation)"
        if(![string]::IsNullOrEmpty($inputParameter.selectQuery)){
            # Import douments as per select query
            Write-Host "Importing filtered docuemnts for transformation..."
        $importArgs = "/s:DocumentDB /s.ConnectionString:""$($cosmosConnectionString)"" /s.Collection:""$($sourceContainerName)"" /s.Query:""$($inputParameter.selectQuery)"" /t:JsonFile /t.File:""$($importSelectedDocumentsLocation)"""
        $p = Start-Process -NoNewWindow -PassThru -Wait -FilePath $dmtPath -ArgumentList $importArgs

        if ($p.ExitCode -eq -1) {
            throw New-Object System.Exception "Import failed. Exception occoured while transferring the documents. Please verify all the input parameters."
        }
 
        Write-Host "Import Competed for selected documents. File location: $($importSelectedDocumentsLocation)"
        }        
    }
 
    Write-Host "Loading records for transformation.."
    $importedFileLocation = "C:\Pushpdeep\POCs\Cosmos-Migration\Cosmos-Migration\24_04_2021_20_13_31-qa\migrated-file.json"

    # Update documents
    $discardedIds = ''
    $updatedRecordCount = 0
    
    if($importFromCosmosRequired -and ![string]::IsNullOrEmpty($inputParameter.selectQuery)){
        $json = Get-Content $importSelectedDocumentsLocation  | Out-String | ConvertFrom-Json
    }
    else{
        $json = Get-Content $importedFileLocation  | Out-String | ConvertFrom-Json
    }
    
 
    Write-Host "Total Documents: $($json.Length)"
 
    Write-Host "Updating $($json.Length) Documents after filter..."
 
    foreach ($item in $json) {   
        try {
            if (!$deleteTargetProperty) {
                # If Target property valus is provided.
                if (![string]::IsNullOrEmpty($inputParameter.targetPropertyConstantValue)) {
                    $sv = $inputParameter.targetPropertyConstantValue  
             
                }
                 
                # If source property is not null
                elseif (![string]::IsNullOrEmpty($inputParameter.sourceProperty)) {
                    $sv = GetorSetPropertyValues -item $item -sv $null -copyValue $false -changeDataType $false -dataType "" -keepOriginalValue $false -property $inputParameter.sourceProperty -fr $inputParameter.forceReplace 
                } 
 
            }
 
            if ($null -eq $sv) {
                $sv = ''
            }
         
            # Update Target
            $sv = GetorSetPropertyValues -item $item -sv $sv -copyValue $copyToTarget -changeDataType $changeDataType -dataType $inputParameter.dataType -keepOriginalValue $inputParameter.keepTargetValueAfterDataTypeChange -property $inputParameter.targetProperty -fr $inputParameter.forceReplace -deleteTarget $deleteTargetProperty
            $updatedRecordCount++     
        }
        catch {
            $discardedIds = "$($discardedIds), $($item.id)"
            Write-Error $PSItem.Exception
        }
    }
    
    # Merge updated documents to complete all json documents.
    if($importFromCosmosRequired -and ![string]::IsNullOrEmpty($inputParameter.selectQuery)) {
        $json | ConvertTo-Json -Depth 9 | Set-Content $migratedFilterFileLocation
        Write-Host "Update completed for $($updatedRecordCount) documents. Migrated file for filter documents: $($migratedFilterFileLocation)"
        
        $allDocuments = Get-Content $importedFileLocation | Out-String | ConvertFrom-Json
        foreach ($item in $json) {
            # $orgItem = $allDocuments | Where-Object {$_.id -eq $item.id}
            $index = [Array]::FindIndex($allDocuments, [System.Predicate[pscustomobject]] {$args[0].id -eq $item.id})
            if($index -ne -1){
                $allDocuments[$index] = $item
            }
        }
        $allDocuments | ConvertTo-Json -Depth 9 | Set-Content $migratedFileLocation
    }
    else{
        $json | ConvertTo-Json -Depth 9 | Set-Content $migratedFileLocation
    }

    
    Write-Host "Update completed for $($updatedRecordCount) documents. Migrated file for all documents: $($migratedFileLocation)"
    Write-Output "Douments errored out: $($discardedIds.Length). Ids: $($discardedIds)" 
}
catch {
    Write-Host -ForegroundColor Red -BackgroundColor Black $_
}
 

