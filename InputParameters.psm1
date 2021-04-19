<#
.SYNOPSIS
    Powershell class that holds all input parameters required to update documents.
.DESCRIPTION
    Powershell class that holds all input parameters required to update documents.
    Please json jaon values as needed.
    For $command, please pass any of these parameters "TypeConversion", "AddTarget", "CopyToTarget" and "DeleteSource"
    $dataType can be "array", "string" or "number"

.NOTES
    Version        : 1.0
    File Name      : InputParameters.psm1
    Author         : Pushpdeep Gupta (pusgup@microsoft.com)
    Creation Date  : April 19, 2021
    Prerequisites  : PowerShell V7.x
    Purpose/Change : Initial script development
#>
class InputParameter {
    [string]$command
    [string]$sourceProperty
    [string]$targetProperty
    [System.Object]$targetPropertyConstantValue
    [string]$dataType
    [bool]$keepTargetValueAfterDataTypeChange
    [bool]$forceReplace
    [string]$filterProperty
    [string]$filterPropertyValue
}