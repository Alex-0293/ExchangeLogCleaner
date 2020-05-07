<#
    .SYNOPSIS 
        .AUTOR
        .DATE
        .VER
    .DESCRIPTION
    .PARAMETER
    .EXAMPLE
#>
Clear-Host
$Global:ScriptName = $MyInvocation.MyCommand.Name
$InitScript        = "C:\DATA\Projects\GlobalSettings\SCRIPTS\Init.ps1"
if (. "$InitScript" -MyScriptRoot (Split-Path $PSCommandPath -Parent)) { exit 1 }

# Error trap
trap {
    if ($Global:Logger) {
       Get-ErrorReporting $_
        . "$GlobalSettings\$SCRIPTSFolder\Finish.ps1"  
    }
    Else {
        Write-Host "There is error before logging initialized." -ForegroundColor Red
    }
    exit 1
}
################################# Script start here #################################

$Scriptblock = {
    Function Remove-LogFiles {    
        param(
            [Parameter(Mandatory = $true, Position = 0, HelpMessage = "Folder path for search." )]
            [ValidateNotNullOrEmpty()] 
            [string] $TargetFolder,
            [Parameter(Mandatory = $true, Position = 1, HelpMessage = "Number of days to save logs." )]
            [ValidateNotNullOrEmpty()] 
            [int16] $DaysToSave
        )        
        $LastPref = $Global:ErrorActionPreference
        $Global:ErrorActionPreference = 'SilentlyContinue'
        [array]$LogMessages = @()
        Write-Host "Processing [$TargetFolder]."
        $PSO = [PSCustomObject]@{
            Message = "Processing [$TargetFolder]."
            Status  = "Info"
            Level   = "1"
        }
        $LogMessages += $PSO

        if (Test-Path $TargetFolder) {
            $Now = Get-Date
            $LastWrite = $Now.AddDays(-$DaysToSave)            
            try {
                $Files = Get-ChildItem $TargetFolder -Include *.log, *.blg, *.etl -Recurse -ErrorAction SilentlyContinue | Where-Object { $_.LastWriteTime -le $LastWrite }
                $Files
                foreach ($File in $Files) {
                    Write-Host $File
                    $FullFileName = $File.FullName  
                    Write-Host "Deleting file [$FullFileName]."
                    $PSO = [PSCustomObject]@{
                        Message = "Deleting file [$FullFileName]."
                        Status  = "Info"
                        Level   = "2"
                    }
                    $LogMessages += $PSO
                    
                    Remove-Item $FullFileName -ErrorAction SilentlyContinue | Out-Null
                }      
            }
            Catch{
                $PSO = [PSCustomObject]@{
                    Message = "Cant process file [$FullFileName] error [$_]. "
                    Status  = "Error"
                    Level   = "2"
                }
                $LogMessages += $PSO
            }      
        }
        Else {
            Write-Host "The folder [$TargetFolder] doesn't exist! Check the folder path!" -ForegroundColor Red
            $PSO = [PSCustomObject]@{
                    Message = "The folder [$TargetFolder] doesn't exist! Check the folder path!"
                    Status  = "Error"
                    Level   = "2"
            }
            $LogMessages += $PSO
        }        
        
        $Global:ErrorActionPreference = $LastPref
        return $LogMessages
    }

    trap {
        write-host  $_ | select *        
    }

    [array] $LogMessages = @()
    $IISLogPath          = $Using:IISLogPath
    $ExchangeLoggingPath = $Using:ExchangeLoggingPath
    $ETLLoggingPath      = $Using:ETLLoggingPath
    $DiagLoggingPath     = $Using:DiagLoggingPath
    $DaysToSave          = $Using:DaysToSave

    $LogMessages += (Remove-LogFiles -TargetFolder $IISLogPath -DaysToSave $DaysToSave )
    $LogMessages += (Remove-LogFiles -TargetFolder $ExchangeLoggingPath -DaysToSave $DaysToSave )
    $LogMessages += (Remove-LogFiles -TargetFolder $ETLLoggingPath -DaysToSave $DaysToSave )
    $LogMessages += (Remove-LogFiles -TargetFolder $DiagLoggingPath -DaysToSave $DaysToSave )

    return $LogMessages
}

$User = Get-VarFromAESFile $Global:GlobalKey1 $Global:APP_SCRIPT_ADMIN_Login
$Pass = Get-VarFromAESFile $Global:GlobalKey1 $Global:APP_SCRIPT_ADMIN_Pass
if ($User -and $Pass) {
    $Credentials = New-Object System.Management.Automation.PSCredential -ArgumentList (Get-VarToString $User), $Pass
    $LogMessages = Invoke-PSScriptBlock -Computer $ExchangeServerName -Credentials $Credentials -ScriptBlock $Scriptblock -TestComputer
}

foreach ($item in $LogMessages){
    Add-ToLog -Message $item.Message -logFilePath $ScriptLogFilePath -display -status $item.Status -level ($ParentLevel + $item.Level)
}

################################# Script end here ###################################
. "$GlobalSettings\$SCRIPTSFolder\Finish.ps1"