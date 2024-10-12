<#
.NOTES
    Author         : Chris Titus @christitustech
    Runspace Author: @DeveloperDurp
    GitHub         : https://github.com/ChrisTitusTech
    Version        : #{replaceme}
#>

# Create a param-block containing the script's parameters.
param (
    [switch]$Debug,
    [string]$Config,
    [switch]$Run
)

# Clear all previously displayed console output messages.
Clear-Host

# Initialize an empty array to store the script's arguments.
$argsList = @()

# Iterate over the parameters and append them to $argsList.
$PSBoundParameters.GetEnumerator() | ForEach-Object {
    $argsList += if ($_.Value -is [switch] -and $_.Value) {
        "-$($_.Key)"
    } elseif ($_.Value) {
        "-$($_.Key) `"$($_.Value)`""
    }
}

# Set DebugPreference based on the -Debug switch.
if ($Debug) {
    $DebugPreference = "Continue"
}

# Handle the -Config parameter.
if ($Config) {
    $PARAM_CONFIG = $Config
}

# Handle the -Run switch.
$PARAM_RUN = $false
if ($Run) {
    Write-Host "Running config file tasks..."
    $PARAM_RUN = $true
}

# Load DLLs.
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName System.Windows.Forms

# Variable to sync between runspaces.
$sync = [Hashtable]::Synchronized(@{})
$sync.PSScriptRoot = $PSScriptRoot
$sync.version = "#{replaceme}"
$sync.configs = @{}
$sync.ProcessRunning = $false

# Store the latest script URL in a variable.
$latestScriptURL = "https://github.com/ChrisTitusTech/winutil/releases/latest/download/winutil.ps1"

# Store the elevation status of the process.
$isElevated = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

# Check if the script is running as administrator.
if (!$isElevated) {
    # Let the user know the script needs to run as admin.
    Write-Output "WinUtil needs to be run as administrator. Attempting to relaunch."

    # Create a script construct and store it in-memory.
    $script = if ($MyInvocation.MyCommand.Path) {
        "& '" + $MyInvocation.MyCommand.Path + "' $argsList"
    }

    # Setup the processes used to launch the script.
    $powershellCmd = if (Get-Command pwsh.exe -ErrorAction SilentlyContinue) { "pwsh.exe" } else { "powershell.exe" }
    $processCmd = if (Get-Command wt.exe -ErrorAction SilentlyContinue) { "wt.exe" } else { $powershellCmd }

    # Use a local script to work around arguments issues.
    if ($MyInvocation.MyCommand.Definition) {
        # Create the path to the downloaded script file.
        $scriptLocation = Join-Path "$env:TEMP" "winutil.ps1"

        # Download the script to the '$env:TEMP' folder.
        $OriginalProgressPreference = $ProgressPreference
        $ProgressPreference = "SilentlyContinue"
        Invoke-WebRequest -Uri $latestScriptURL -OutFile $scriptLocation
        $ProgressPreference = $OriginalProgressPreference

        # Start a new script instance with elevated privileges.
        Start-Process $processCmd -ArgumentList "$powershellCmd -ExecutionPolicy Bypass -NoProfile -File $scriptLocation $argsList" -Verb RunAs
        break
    }

    # Start a new script instance with elevated privileges.
    Start-Process $processCmd -ArgumentList "$powershellCmd -ExecutionPolicy Bypass -NoProfile -Command $script $argsList" -Verb RunAs
    break
}

# Start WinUtil transcript logging.
$dateTime = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$logdir = "$env:localappdata\winutil\logs"
[System.IO.Directory]::CreateDirectory("$logdir") | Out-Null
Start-Transcript -Path "$logdir\winutil_$dateTime.log" -Append -NoClobber | Out-Null

# Set the fallback PowerShell window title.
$fallbackWindowTitle = "WinUtil"

# Set the PowerShell window title.
try {
    if ($MyInvocation.MyCommand.Path) {
        $Host.UI.RawUI.WindowTitle = "(Admin) " + $MyInvocation.MyCommand.Path
    } else {
        $Host.UI.RawUI.WindowTitle = "(Admin) " + $MyInvocation.MyCommand.Definition
    }
} catch {
    Write-Host "Exception setting `"WindowTitle`": Window title is too long. Using fallback window title." -ForegroundColor Yellow
    $Host.UI.RawUI.WindowTitle = "(Admin) " + $fallbackWindowTitle
}