function downloadDataTransferToolIfNotExist {
    param (
        [string] $workspaceDirectory
    )
$dtRelativePath = "$($workspaceDirectory)\dt\drop\dt.exe"

# check if directory exists
$isExist = [System.IO.File]::Exists($dtRelativePath)
$toolLocation = "https://aka.ms/csdmtool"
if($isExist){
# skip download
Write-Host "[skipping download] Tool is already available."
}
else {
        # Download the migartion tool.
        Write-Host "[Tool not found] Downloading the packaged file.."
        Invoke-RestMethod $toolLocation -OutFile "$($workspaceDirectory)\dt.zip"     
        
        # Unzip the downloaded file
        [System.IO.Compression.ZipFile]::ExtractToDirectory("$($workspaceDirectory)\dt.zip", "$($workspaceDirectory)\dt")
}
return $dtRelativePath
}