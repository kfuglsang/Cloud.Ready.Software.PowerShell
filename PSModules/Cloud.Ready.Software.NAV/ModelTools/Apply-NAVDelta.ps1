﻿<#
.Synopsis
   Applies a folder with Deltafiles to a Serverinstance
.DESCRIPTION
   Steps:
     -Export objects
.PREREQUISITES
   - Run on ServiceTier.  
   - NAVModeltools must be present!
.EXAMPLE
   
#>
Function Apply-NAVDelta {
    [CmdLetBinding()]
    param(
        [parameter(Mandatory=$true)]
        [Alias('Fullname')]
        [String] $DeltaPath,
        [Parameter(Mandatory=$true)]
        [Alias('ServerInstance')] 
        [String] $TargetServerInstance,
        [Parameter(Mandatory=$true)]        
        [String] $Workingfolder,
        [Parameter(Mandatory=$false)]
        [switch] $OpenWorkingfolder,
        [Parameter(Mandatory=$false)]
        [switch] $DoNotImportAndCompileResult=$false,
        [Parameter(Mandatory=$false)]
        [ValidateSet('Force','No','Yes')]
        [String] $SynchronizeSchemaChanges='Yes',
        [Parameter(Mandatory=$false)]
        [ValidateSet('FromModified','FromTarget','No','Yes')]
        [String] $ModifiedProperty = 'Yes',
        [Parameter(Mandatory=$false)]
        [ValidateSet('Add','Remove')]
        [String] $VersionListAction = 'Add'
    )
    begin{
        #Set Constants
        $ExportFolder = Join-Path $WorkingFolder 'TargetObjects'
        $ResultFolder = Join-Path $WorkingFolder 'ApplyResult'
        $ReverseFolder = join-path $WorkingFolder 'ReverseDeltas'

        $TargetServerInstanceObject = Get-NAVServerInstanceDetails -ServerInstance $TargetServerInstance

        #Set up workingfolder
        if (!(test-path $WorkingFolder)){
            $null = new-item -Path $WorkingFolder -ItemType directory -Force -ErrorAction Stop
        }

        $null = Remove-Item -Path $ExportFolder -Force -Recurse -ErrorAction Ignore
        $null = Remove-Item -Path $ResultFolder -Force -Recurse -ErrorAction Ignore
        $null = remove-item -Path $ReverseFolder -Force -Recurse -ErrorAction Ignore
        $null = new-item -Path $ExportFolder -ItemType directory -Force -ErrorAction stop
        $null = new-item -Path $ResultFolder -ItemType directory -Force -ErrorAction stop
        $null = New-Item -Path $ReverseFolder -ItemType directory -Force -ErrorAction stop
    }
    process{ 
        $NAVObjects = get-ChildItem $DeltaPath | Get-NAVApplicationObjectPropertyFromDelta -ErrorAction Stop
             
        Write-Host "Export objects to $ExportFolder" -ForegroundColor Green 
        foreach ($NAVObject in $NAVObjects){
            $ExportFile =
                Export-NAVApplicationObject2 `
                Write-Host "  $($ExportFile.Name) exported." -ForegroundColor Gray
            if ($ExportFile.Length -eq 0) {
                $null = $ExportFile | Remove-Item -Force
            }        
        }

        Write-Host 'Applying deltas' -ForegroundColor Green         
        $UpdateResult = 
                -DateTimeProperty Now `
                -ErrorAction Stop `

        Write-Host 'Updating versionlist' -ForegroundColor Green 
        $UpdateResult |
                Where-Object {$_.UpdateResult –eq 'Updated' -or $_.MergeResult –eq 'Conflict'}  |  
                    Foreach {
                        $CurrObject = Get-NAVApplicationObjectProperty -Source $_.Result
                        If ($VersionListAction -eq 'Add'){
                            $null = $CurrObject | Set-NAVApplicationObjectProperty -VersionListProperty (Add-NAVVersionListMember -VersionList $CurrObject.VersionList -AddVersionList $Name)         
                        }
                        else {
                            $null = $CurrObject | Set-NAVApplicationObjectProperty -VersionListProperty (Remove-NAVVersionListMember -VersionList $CurrObject.VersionList -RemoveVersionList $Name)                
                        }
                    }            
        $UpdateResult |
                Where-Object {$_.UpdateResult –eq 'Inserted'}  |  
                    Foreach {
                        $CurrObject = Get-NAVApplicationObjectProperty -Source $_.Result
                        $null = $CurrObject | Set-NAVApplicationObjectProperty -VersionListProperty $Name
                    }

        #Create reversedeltas
        Write-Host "Creating reverse deltas to $ReverseFolder" -ForegroundColor Green         
        $null =

        if(!($DoNotImportAndCompileResult)){
            #Import 
            Write-Host "Importing result from $ResultFolder" -ForegroundColor Green         
            $null = 
                Get-ChildItem $ResultFolder -File -Filter '*.txt' |
                    Import-NAVApplicationObject2 `
                        -ServerInstance $TargetServerInstanceObject.ServerInstance `
                        -ImportAction Overwrite `
                        -Confirm:$false  
    
            #Delete objects
            Write-Host "Deleting objects to $ExportFolder" -ForegroundColor Green 
            $UpdateResult |
                    Where-Object {$_.UpdateResult –eq 'Deleted'}  |  
                            Foreach {    
                                $null =
                                    Delete-NAVApplicationObject2 `
                                Write-Host "  $($_.ObjectType) $($_.Id) deleted." -ForegroundColor Gray

            Write-Host 'Compiling uncompiled' -ForegroundColor Green         
            $null =
                Compile-NAVApplicationObject2 `
                    -ServerInstance $TargetServerInstanceObject.ServerInstance `
                    -Filter 'Compiled=0' `
        }
    }
    end{        
        if($OpenWorkingfolder){Start-Process $Workingfolder}
        Write-Host 'Apply-NAVDelta done!' -ForegroundColor Green
    }
}