<#
    .SYNOPSIS
    Using "Jetbrains Toolbox" from within "WSL" under the "Fedora" distribution.
    .DESCRIPTION
    Once installed, you may use "Jetbrains Toolbox" from within "WSL" under the "Fedora" distribution.
    This image contains minimal Fedora with pre-installed packages: X11 packages, git, gnome-terminal, gedit, and the JDK Adoptium repository configured with dnf package manager.
    In addition, "systemctl" is enabled by default, and an unprivileged user named "wsl" exists, with password "wsl".

#>

[CmdletBinding(DefaultParameterSetName = 'Help')]
param (
    [Parameter(Mandatory, ParameterSetName = 'Install', Position=0)]
    [Switch]$Install,
    [Parameter(Mandatory, ParameterSetName = 'Shortcut', Position=0)]
    [Switch]$Shortcut,

    [Parameter(ParameterSetName = 'Install', HelpMessage = 'The Path to the "Jetbrains-Toolbox-on-WSL" Tar image')]
    [String] $InstallTarPath,
 
    [Parameter(ParameterSetName = 'Install', HelpMessage = 'The Path to the "Jetbrains-Toolbox-on-WSL" wsl installation (default is current folder)')]
    [String] $InstallPath = ".",

    [Parameter(ParameterSetName = 'Install', HelpMessage = 'The WSL distro name to be created (default is "jetbrains-toolbox-wsl")')]
    [Parameter(ParameterSetName = 'Shortcut', HelpMessage = 'The WSL distro name to be shortcut with (default is "jetbrains-toolbox-wsl")')]
    [String] $WslDistroName = "jetbrains-toolbox-wsl",

    [Parameter(ParameterSetName = 'Shortcut', HelpMessage = 'The shortcut name that will be created on your desktop')]
     [String] $ShortcutName,
 
    [Parameter(ParameterSetName = 'Shortcut', HelpMessage = 'The shortcut command on the WSL distro')]
    [String] $ShortcutWslCommand,

    [Parameter(ParameterSetName = 'Shortcut', HelpMessage = 'The shortcut path')]
    [String] $ShortcutPath = (Get-ItemPropertyValue -Path "Registry::HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders" -Name "Desktop")
)

# Disable StrictMode in this script
Set-StrictMode -Off

function Write-InstallInfo
{
    param(
        [Parameter(Mandatory)]
        [String] $String,
        [Parameter()]
        [System.ConsoleColor] $ForegroundColor = $host.UI.RawUI.ForegroundColor
    )

    $backup = $host.UI.RawUI.ForegroundColor

    if ($ForegroundColor -ne $host.UI.RawUI.ForegroundColor)
    {
        $host.UI.RawUI.ForegroundColor = $ForegroundColor
    }

    Write-Host "$String"

    $host.UI.RawUI.ForegroundColor = $backup
}

function Deny-Install
{
    param(
        [String] $Message,
        [Int] $ErrorCode = 1
    )

    Write-InstallInfo -String $Message -ForegroundColor Red
    Write-InstallInfo "Abort."

    # Don't abort if invoked with iex that would close the PS session
    if ($null -eq $MyInvocation.MyCommand.Path)
    {
        break
    }
    else
    {
        exit $ErrorCode
    }
}

function Test-Prerequisite
{
    # Scoop requires PowerShell 5 at least
    if (($PSVersionTable.PSVersion.Major) -lt 5 -or 
        (($PSVersionTable.PSVersion.Major) -eq 5) -and (($PSVersionTable.PSVersion.Minor) -lt 1))
    {
        Deny-Install "PowerShell 5.1 or later is required to run"
    }

    if (([System.Environment]::OSVersion.Version.Major) -lt 10 )
    {
        Deny-Install "Windows 10 20h2 (build 19042) or later is required to run"
    }

    if (([System.Environment]::OSVersion.Version.Major) -eq 10 -and ([System.Environment]::OSVersion.Version.Build) -lt 19042)
    {
        Deny-Install "Windows 10 20h2 (10.0.19042.2604) or later is required to run"
    }
}

function Confirm-ParamsShortcut {
    if ($ShortcutName -notmatch "\S") {
        Deny-Install "'ShortcutName' is required"
    }
    if ($ShortcutWslCommand -notmatch "\S") {
        Deny-Install "'ShortcutWslCommand' is required"
    }
    if ($ShortcutPath -notmatch "\S") {
        Deny-Install "'ShortcutPath' is required"
    }
    if (-not(Test-Path -Path $ShortcutPath)) 
    {
        Deny-Install 'The Path entered (ShortcutPath) does not exist'
    }
}

function Confirm-ParamsInstall {
    if ($InstallTarPath -notmatch "\S") {
        Deny-Install "'InstallTarPath' is required"
    }
    if ($InstallPath -notmatch "\S") {
        Deny-Install "'InstallPath' is required"
    }
    if (-not(Test-Path -Path $InstallTarPath -PathType Leaf)) 
    {
        Deny-Install 'The Path entered (InstallTarPath) does not exist'
    }
    if (-not(Test-Path -Path $InstallPath )) 
    {
        Deny-Install 'The Path entered (InstallPath) does not exist'
    }
}

function Invoke-CommandHelp { 
    Get-Help $PSCommandPath -Detailed
}

function Add-ShortcutOnDesktop {
    Write-InstallInfo "Creating '$ShortcutName' shortcut on your desktop..."
    $CurLoc = Get-Location
    $ShortcutPath = "$ShortcutPath\$ShortcutName.lnk"
    $WScriptObj = New-Object -ComObject ("WScript.Shell")
    $shortcut = $WscriptObj.CreateShortcut($ShortcutPath)
    $shortcut.TargetPath = "cmd"
    $shortcut.Arguments = "/c powershell.exe -File `"$CurLoc\run-wsl-ui.ps1`" -WslCommand `"$ShortcutWslCommand`" -DistroName `"$WslDistroName`""
    $shortcut.Save()
    Write-InstallInfo "Done."
}

function Install-JetbrainsToolboxOnWsl {
    if ((wsl --list --all -q) -contains $WslDistroName) {
        Deny-Install "WSL distro name '$WslDistroName' already exists"
    }
    Write-InstallInfo "Installing 'Jetbrains Toolbox on WSL' image..."
    wsl --import $WslDistroName $InstallPath $InstallTarPath
    wsl --system -u root -d $WslDistroName tdnf update -y
    wsl --system -u root -d $WslDistroName tdnf install -y gdb
    Write-Output "[wsl2]`nmemory=8GB`nlocalhostforwarding=true`nguiApplications=true`n" > $Env:USERPROFILE\.wslconfig
    Write-Output "[system-distro-env]`nLIBGL_ALWAYS_SOFTWARE=1`nWESTON_RDPRAIL_SHELL_ALLOW_ZAP=true`n" > $Env:USERPROFILE\.wslgconfig
    wsl -d $WslDistroName --shutdown
    Write-InstallInfo "Done."
}

# Quit if anything goes wrong
$oldErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = 'Stop'
# Executes the command, but doesn't display the progress bar
$oldProgressPreference = $ProgressPreference
$ProgressPreference = "SilentlyContinue"

switch ($PsCmdlet.ParameterSetName) {
    "Install" { 
        Test-Prerequisite
        Confirm-ParamsInstall
        Install-JetbrainsToolboxOnWsl
     }
    "Shortcut" {
        Test-Prerequisite
        Confirm-ParamsShortcut
        Add-ShortcutOnDesktop -ShortcutName $ShortcutName -WslCommand $ShortcutWslCommand
    }
    "Help" {
        Invoke-CommandHelp
    }
    Default {
        Invoke-CommandHelp
    }
}

# Reset $ErrorActionPreference & $ProgressPreference to original value
$ErrorActionPreference = $oldErrorActionPreference
$ProgressPreference = $oldProgressPreference
