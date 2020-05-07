# Rename this file to Settings.ps1
######################### value replacement #####################
[int16]  $Global:DaysToSave          = ""          # Days to save logs.
[string] $Global:ExchangeServerName  = ""          # Exchange server name.

######################### no replacement ########################

[string] $Global:IISLogPath          = "C:\inetpub\logs\LogFiles\"                                                              # IIS log path.
[string] $Global:ExchangeLoggingPath = "C:\Program Files\Microsoft\Exchange Server\V15\Logging\"                                # Exchange server logging path.
[string] $Global:ETLLoggingPath      = "C:\Program Files\Microsoft\Exchange Server\V15\Bin\Search\Ceres\Diagnostics\ETLTraces\" # Exchange server ETL logging path.
[string] $Global:DiagLoggingPath     = "C:\Program Files\Microsoft\Exchange Server\V15\Bin\Search\Ceres\Diagnostics\Logs"       # Exchange server diagnostic logging path.

[bool]  $Global:LocalSettingsSuccessfullyLoaded  = $true
# Error trap
    trap {
        $Global:LocalSettingsSuccessfullyLoaded = $False
        exit 1
    }
