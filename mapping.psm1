<#
.SYNOPSIS
    Core Script that updates json objects based on user input.
.DESCRIPTION
    Script loads source property values to update the target values.

.NOTES
    Version        : 1.1
    File Name      : mapping.psm1
    Author         : Pushpdeep Gupta (pusgup@microsoft.com)
    Creation Date  : March 22, 2021
    Prerequisites  : PowerShell V7.x
    Purpose/Change : Initial script development
                     Added a new Method "SetValueBasedOnInputs" for updating values based on user inputs.  
#>
function SetValueBasedOnInputs {
    param (
        $targetObject,
        $targetProperty,
        $sourceValue,
        $cdt,
        $delTarget,
        $dt,
        $kv
    )

    if ($cdt) {
        switch ($dt) {
            "array" { $newDataTypeItem = New-Object System.Collections.Generic.List[System.Object]
                if($kv){                       
                           if([string]::IsNullOrEmpty($sourceValue)){
                               $targetObject.$targetProperty = $newDataTypeItem
                           }
                           else{
                               $newDataTypeItem.Add($sourceValue)
                               $targetObject.$targetProperty = $newDataTypeItem
                           }
                }
                else{
                    $targetObject.$targetProperty = $newDataTypeItem
                }
              }
              "string"{ $targetObject.$targetProperty = $kv ? [string]$sourceValue : "" }
              "int"{$targetObject.$targetProperty = $kv ? [System.Convert]::ToInt64($sourceValue,10) : ""}
              "decimal"{$targetObject.$targetProperty = $kv ? [System.Convert]::ToDecimal($sourceValue) : ""}
            Default { throw [System.InvalidOperationException] "Data type not supported. Please send array, string or number"}
        }
    }
    elseif ($delTarget) {
        $targetObject.PSObject.properties.remove($targetProperty)
    }
    else{
        $targetObject.$targetProperty = $sourceValue
    }
    
}

function GetorSetPropertyValues {
    param (
        $item,
        $sv,
        $copyValue,
        $changeDataType,
        $deleteTarget,
        $dataType,
        $keepOriginalValue,
        $property,
        $fr
    ) 
 $sp = $item
 [bool]$isPrevArray = $false
 $count = 0
 $spLst = $property.Split(".")
 #[string]$sv = ""
 foreach($splstitem in $spLst){   
     $prop = $splstitem.Replace("[]","")        
     if(($spLst.Length-1) -eq $count){
             if($copyValue){
                 if($isPrevArray){                    
                     if(($null -ne $sv) -and ($sv.GetType().Name -eq "Object[]")) {
                        $mappingCount = 0
                        foreach ($spItem in $sp) {
                            if($spItem.PSobject.Properties.Name-notcontains $prop){
                                $spItem | Add-Member -MemberType NoteProperty -Name $prop -Value $null
                                #$spItem.$prop = $null
                            }
                            if($fr){
                                SetValueBasedOnInputs -sourceValue $sv[$mappingCount] -targetObject $spItem  -targetProperty $prop -cdt $changeDataType -dt $dataType -kv $keepOriginalValue -delTarget $deleteTarget
                            }
                            else{
                                $fv = [string]::IsNullOrEmpty($spItem.$prop) ? $sv[$mappingCount] : $spItem.$prop
                                SetValueBasedOnInputs -sourceValue $fv -targetObject $spItem -targetProperty $prop -cdt $changeDataType -dt $dataType -kv $keepOriginalValue -delTarget $deleteTarget
                            }
                            $mappingCount++
                        }
                     }
                     else {
                        foreach ($spI in $sp) {
                            if($null -ne $spI){
                                if($spI.PSobject.Properties.Name -notcontains $prop){
                                    $spI | Add-Member -MemberType NoteProperty -Name $prop -Value $null
                                }

                                if($fr){
                                    SetValueBasedOnInputs -sourceValue $sv -targetObject $spI -targetProperty $prop -cdt $changeDataType -dt $dataType -kv $keepOriginalValue -delTarget $deleteTarget
                                }
                                else{
                                    $fvI = [string]::IsNullOrEmpty($spI.$prop) ? $sv : $spI.$prop
                                    SetValueBasedOnInputs -sourceValue $fvI -targetObject $spI -targetProperty $prop -cdt $changeDataType -dt $dataType -kv $keepOriginalValue -delTarget $deleteTarget
                                }
                            }                            
                        }
                     }                                             
                 }
                 else{
                     #$sp.$prop = $sv
                     if($sp.PSobject.Properties.Name -notcontains $prop){
                        $sp | Add-Member -MemberType NoteProperty -Name $prop -Value $null
                        #$sp.$prop = $null
                    }
                     if($fr){
                        $sp.$prop = $sv
                    }
                    else{
                        $sp.$prop = [string]::IsNullOrEmpty($sp.$prop) ? $sv : $sp.$prop
                    }
                     #UpdateValue -f $fr -sourceObject $sp -property $prop -value $sv
                 }
             }             
             else{
                 $sv = $sp.$prop
             }
         break;
     }

     if(!$isPrevArray){
         $sp = $sp.$prop
         $count++
     }
     else {
         $mapping = 0
         $temp = @()
         
         foreach($spitem in $sp){
             if($mapping -lt $sp.Length){
                if($spitem.$prop){
                    $temp += $spitem.$prop
                }
                # else{
                #    if (!$splstitem.Prop -contains ) {
                #        $spitem | Add-Member -MemberType NoteProperty -Name $prop -Value $null
                #        $temp += $spItem.$prop
                #    }    
                # }
                $mapping++
             }                            
         }
         $sp = $temp
         $isPrevArray = $true
         $count++
     }

     if($splstitem.Contains("[]") -and !$isPrevArray){
         $isPrevArray = $true
     }
 }
   return $sv
}