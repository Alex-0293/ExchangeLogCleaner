<#
    .SYNOPSIS 
        .AUTOR
        .DATE
        .VER
    .DESCRIPTION
    .PARAMETER
    .EXAMPLE
#>
Param (
    [Parameter( Mandatory = $false, Position = 0, HelpMessage = "Initialize global settings." )]
    [bool] $InitGlobal = $true,
    [Parameter( Mandatory = $false, Position = 1, HelpMessage = "Initialize local settings." )]
    [bool] $InitLocal = $true   
)

$Global:ScriptInvocation = $MyInvocation
if ($env:AlexKFrameworkInitScript){. "$env:AlexKFrameworkInitScript" -MyScriptRoot (Split-Path $PSCommandPath -Parent) -InitGlobal $InitGlobal -InitLocal $InitLocal} Else {Write-host "Environmental variable [AlexKFrameworkInitScript] does not exist!" -ForegroundColor Red; exit 1}
if ($LastExitCode) { exit 1 }

# Error trap
trap {
    if (get-module -FullyQualifiedName AlexkUtils) {
        Get-ErrorReporting $_        
        . "$GlobalSettings\$SCRIPTSFolder\Finish.ps1" 
    }
    Else {
        Write-Host "[$($MyInvocation.MyCommand.path)] There is error before logging initialized. Error: $_" -ForegroundColor Red
    }  
    $Global:GlobalSettingsSuccessfullyLoaded = $false
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

        Add-ToLog -Message "Processing [$TargetFolder]." -logFilePath $ScriptLogFilePath -Display -Status "Info" -Level ($ParentLevel + 1)

        if (Test-Path $TargetFolder) {
            $Now = Get-Date
            $LastWrite = $Now.AddDays(-$DaysToSave)            
            try {
                $Files = Get-ChildItem $TargetFolder -Include *.log, *.blg, *.etl -Recurse -ErrorAction SilentlyContinue | Where-Object { $_.LastWriteTime -le $LastWrite }
                foreach ($File in $Files) {  
                    $FullFileName = $File.FullName           
                    Add-ToLog -Message "Deleting file [$FullFileName]." -logFilePath $ScriptLogFilePath -Display -Status "Info" -Level ($ParentLevel + 1)
                    Remove-Item $FullFileName -ErrorAction SilentlyContinue | Out-Null
                }      
            }
            Catch{
                Add-ToLog -Message "Cant process file [$FullFileName] error [$_]." -logFilePath $ScriptLogFilePath -Display -Status "Error" -Level ($ParentLevel + 1)
            }      
        }
        Else {            
            Add-ToLog -Message "The folder [$TargetFolder] doesn't exist! Check the folder path!" -logFilePath $ScriptLogFilePath -Display -Status "Error" -Level ($ParentLevel + 1)
        }        
        
        $Global:ErrorActionPreference = $LastPref
        return $LogMessages
    }

    $Res = [PSCustomObject]@{
        LogBuffer          = @()
        FreeDiskSpace      = 0
        NewFreeDiskSpace   = 0
    }

    $IISLogPath          = $Using:IISLogPath
    $ExchangeLoggingPath = $Using:ExchangeLoggingPath
    $ETLLoggingPath      = $Using:ETLLoggingPath
    $DiagLoggingPath     = $Using:DiagLoggingPath
    $DaysToSave          = $Using:DaysToSave

    $Res.FreeDiskSpace   = [math]::Round((Get-PSDrive ((Get-Item $IISLogPath).PSDrive.Name)).Free / 1gb, 2)

    Remove-LogFiles -TargetFolder $IISLogPath -DaysToSave $DaysToSave 
    Remove-LogFiles -TargetFolder $ExchangeLoggingPath -DaysToSave $DaysToSave 
    Remove-LogFiles -TargetFolder $ETLLoggingPath -DaysToSave $DaysToSave
    Remove-LogFiles -TargetFolder $DiagLoggingPath -DaysToSave $DaysToSave 

    $Res.NewFreeDiskSpace = [math]::Round((Get-PSDrive ((Get-Item $IISLogPath).PSDrive.Name)).Free / 1gb, 2)
    $Res.LogBuffer        = $Global:LogBuffer

    return $Res
}

$User = Get-VarFromAESFile $Global:GlobalKey1 $Global:APP_SCRIPT_ADMIN_Login
$Pass = Get-VarFromAESFile $Global:GlobalKey1 $Global:APP_SCRIPT_ADMIN_Pass
if ($User -and $Pass) {
    $Credentials = New-Object System.Management.Automation.PSCredential -ArgumentList (Get-VarToString $User), $Pass
    $Res = Invoke-PSScriptBlock -Computer $ExchangeServerName -Credentials $Credentials -ScriptBlock $Scriptblock -TestComputer -ImportLocalModule "AlexkUtils"
}

if ($Res.LogBuffer) {
    foreach ($item in $Res.LogBuffer) {
        Add-ToLog @item
    }            
}
if (($Res.NewFreeDiskSpace) -and ($Res.FreeDiskSpace)) {
    Add-ToLog -Message "Free disk [$($IISLogPath.Substring(0, 1)):] space changed on [$ExchangeServerName] from [$($Res.FreeDiskSpace) GB] to [$($Res.NewFreeDiskSpace) GB], difference [$([math]::round(($Res.NewFreeDiskSpace - $Res.FreeDiskSpace),2)) GB]" -logFilePath $ScriptLogFilePath -Display -Status "Info" -Level ($ParentLevel + 1)
}

################################# Script end here ###################################
. "$GlobalSettings\$SCRIPTSFolder\Finish.ps1"