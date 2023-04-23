<#
.SYNOPSIS
    Using "Jetbrains Toolbox" from within "WSL" under the "Fedora" distribution.
.DESCRIPTION
    Once installed, you may use "Jetbrains Toolbox" from within "WSL" under the "Fedora" distribution.
    This image contains minimal Fedora with pre-installed packages: X11 packages, git, gnome-terminal, gedit, and the JDK Adoptium repository configured with dnf package manager.
    In addition, "systemctl" is enabled by default, and an unprivileged user named "wsl" exists, with password "wsl".
.PARAMETER JbtwslDir
    Specifies Jbtwsl root path.
    If not specified, Jbtwsl will be installed to '$env:USERPROFILE\jbtwsl'.
.PARAMETER NoProxy
    Bypass system proxy during the installation.
.PARAMETER Proxy
    Specifies proxy to use during the installation.
.PARAMETER ProxyCredential
    Specifies credential for the given proxy.
.PARAMETER ProxyUseDefaultCredentials
    Use the credentials of the current user for the proxy server that is specified by the -Proxy parameter.
.PARAMETER InstallTarPath
    The Path to the "Jetbrains-Toolbox-on-WSL" Tar image.
    If not specified, Jbtwsl image will be downloaded to '$env:USERPROFILE\jbtwsl\jbtwsl.tar'.
    If specified and not exists, Jbtwsl image will be downloaded that path.
.PARAMETER WslDistroName
    The WSL distro name to be shortcut with.
    If not specified, the distro name will be installed with the name 'jbtwsl'
.PARAMETER ShortcutName
    The shortcut name that will be created
.PARAMETER WslCommand
    The shortcut command that will be execure on the WSL distro
.PARAMETER ShortcutPath
    The WSL distro name to be created.
    If not specified, the shortcut will be created on your Desktop
.LINK
    https://github.com/rozidan/jetbrains-toolbox-on-wsl
#>

[CmdletBinding(DefaultParameterSetName = 'Quick')]
param (
    [Parameter(ParameterSetName = 'Install')]
    [String] $JbtwslDir,
    [Parameter(ParameterSetName = 'Install')]
    [Switch] $NoProxy,
    [Parameter(ParameterSetName = 'Install')]
    [Uri] $Proxy,
    [Parameter(ParameterSetName = 'Install')]
    [System.Management.Automation.PSCredential] $ProxyCredential,
    [Parameter(ParameterSetName = 'Install')]
    [Switch] $ProxyUseDefaultCredentials,
    [Parameter(ParameterSetName = 'Install')]
    [String] $InstallTarPath,
    [Parameter(ParameterSetName = 'Install')]
    [Parameter(ParameterSetName = 'Shortcut')]
    [String] $WslDistroName,
    [Parameter(ParameterSetName = 'Shortcut')]
    [String] $ShortcutName,
    [Parameter(ParameterSetName = 'Shortcut')]
    [String] $WslCommand,
    [Parameter(ParameterSetName = 'Shortcut')]
    [String] $ShortcutPath,
    [Parameter(ParameterSetName = 'Help')]
    [Switch] $Help
)

# Disable StrictMode in this script
Set-StrictMode -Off

function Write-InstallInfo {
    param(
        [Parameter(Mandatory = $True, Position = 0)]
        [String] $String,
        [Parameter(Mandatory = $False, Position = 1)]
        [System.ConsoleColor] $ForegroundColor = $host.UI.RawUI.ForegroundColor
    )

    $backup = $host.UI.RawUI.ForegroundColor

    if ($ForegroundColor -ne $host.UI.RawUI.ForegroundColor) {
        $host.UI.RawUI.ForegroundColor = $ForegroundColor
    }
    Write-Output "$String"

    $host.UI.RawUI.ForegroundColor = $backup
}

function Deny-Install {
    param(
        [String] $Message,
        [Int] $ErrorCode = 1
    )

    Write-InstallInfo -String $Message -ForegroundColor DarkRed
    Write-InstallInfo "Abort."

    # Don't abort if invoked with iex that would close the PS session
    if ($IS_EXECUTED_FROM_IEX) {
        break
    } else {
        exit $ErrorCode
    }
}

function Test-ValidateParameterInstall {
    if ($null -eq $Proxy -and ($null -ne $ProxyCredential -or $ProxyUseDefaultCredentials)) {
        Deny-Install "Provide a valid proxy URI for the -Proxy parameter when using the -ProxyCredential or -ProxyUseDefaultCredentials."
    }

    if ($ProxyUseDefaultCredentials -and $null -ne $ProxyCredential) {
        Deny-Install "ProxyUseDefaultCredentials is conflict with ProxyCredential. Don't use the -ProxyCredential and -ProxyUseDefaultCredentials together."
    }

    if ($InstallTarPath -and -not(Test-Path -Path $(Split-Path $InstallTarPath -Parent))) {
        Deny-Install 'The Path parent entered (InstallTarPath) does not exist'
    }

}

function Test-ValidateParameterShortcut {
    if ($ShortcutName -notmatch "\S") {
        Deny-Install "'ShortcutName' is required"
    }

    if ($WslCommand -notmatch "\S") {
        Deny-Install "'WslCommand' is required"
    }

    if ($ShortcutPath -and -not(Test-Path -Path $ShortcutPath)) {
        Deny-Install 'The Path entered (ShortcutPath) does not exist'
    }

}

function Test-Prerequisite {
    # Jbtwsl requires PowerShell 5 at least
    if (($PSVersionTable.PSVersion.Major) -or
        (($PSVersionTable.PSVersion.Major) -eq 5) -and (($PSVersionTable.PSVersion.Minor) -lt 1)) {
        Deny-Install "PowerShell 5 or later is required to run Jbtwsl. Go to https://microsoft.com/powershell to get the latest version of PowerShell."
    }

    if (([System.Environment]::OSVersion.Version.Major) -lt 10 ) {
        Deny-Install "Windows 10 20h2 (build 19042) or later is required to run"
    }

    if (([System.Environment]::OSVersion.Version.Major) -eq 10 -and ([System.Environment]::OSVersion.Version.Build) -lt 19042) {
        Deny-Install "Windows 10 20h2 (10.0.19042.2604) or later is required to run"
    }

    # Jbtwsl requires TLS 1.2 SecurityProtocol, which exists in .NET Framework 4.5+
    if ([System.Enum]::GetNames([System.Net.SecurityProtocolType]) -notcontains 'Tls12') {
        Deny-Install "Jbtwsl requires .NET Framework 4.5+ to work. Go to https://microsoft.com/net/download to get the latest version of .NET Framework."
    }

    # Test if jbtwsl is installed, by checking if jbtwsl command exists.
    if ($PsCmdlet.ParameterSetName -ne 'Shortcut') {
        if ([bool](Get-Command -Name 'jbtwsl' -ErrorAction SilentlyContinue)) {
            Deny-Install "Jbtwsl is already installed"
        }
    }
}

function Optimize-SecurityProtocol {
    # .NET Framework 4.7+ has a default security protocol called 'SystemDefault',
    # which allows the operating system to choose the best protocol to use.
    # If SecurityProtocolType contains 'SystemDefault' (means .NET4.7+ detected)
    # and the value of SecurityProtocol is 'SystemDefault', just do nothing on SecurityProtocol,
    # 'SystemDefault' will use TLS 1.2 if the webrequest requires.
    $isNewerNetFramework = ([System.Enum]::GetNames([System.Net.SecurityProtocolType]) -contains 'SystemDefault')
    $isSystemDefault = ([System.Net.ServicePointManager]::SecurityProtocol.Equals([System.Net.SecurityProtocolType]::SystemDefault))

    # If not, change it to support TLS 1.2
    if (!($isNewerNetFramework -and $isSystemDefault)) {
        # Set to TLS 1.2 (3072), then TLS 1.1 (768), and TLS 1.0 (192). Ssl3 has been superseded,
        # https://docs.microsoft.com/en-us/dotnet/api/system.net.securityprotocoltype?view=netframework-4.5
        [System.Net.ServicePointManager]::SecurityProtocol = 3072 -bor 768 -bor 192
        Write-Verbose "SecurityProtocol has been updated to support TLS 1.2"
    }
}

function Get-Downloader {
    $downloadSession = New-Object System.Net.WebClient

    # Set proxy to null if NoProxy is specificed
    if ($NoProxy) {
        $downloadSession.Proxy = $null
    } elseif ($Proxy) {
        # Prepend protocol if not provided
        if (!$Proxy.IsAbsoluteUri) {
            $Proxy = New-Object System.Uri("http://" + $Proxy.OriginalString)
        }

        $Proxy = New-Object System.Net.WebProxy($Proxy)

        if ($null -ne $ProxyCredential) {
            $Proxy.Credentials = $ProxyCredential.GetNetworkCredential()
        } elseif ($ProxyUseDefaultCredentials) {
            $Proxy.UseDefaultCredentials = $true
        }

        $downloadSession.Proxy = $Proxy
    }

    return $downloadSession
}

function Invoke-DownloadFile {
    param (
        [Parameter(Mandatory = $True, Position = 0)]
        [String] $Uri,
        [Parameter(Mandatory = $True, Position = 1)]
        [String] $FileName
    )

    trap {
        try {
            Unregister-Event -SourceIdentifier WebClient.DownloadProgressChanged | Out-Null
        } catch {

        }
    }

    $webClient = Get-Downloader
    $webClient.DownloadFile($Uri, $FileName)
    $webClient.Dispose()
}

function Get-Env {
    param(
        [String] $Name,
        [Switch] $Global
    )

    $RegisterKey = if ($Global) {
        Get-Item -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager'
    } else {
        Get-Item -Path 'HKCU:'
    }

    $EnvRegisterKey = $RegisterKey.OpenSubKey('Environment')
    $RegistryValueOption = [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames
    $EnvRegisterKey.GetValue($Name, $null, $RegistryValueOption)
}

function Write-Env {
    param(
        [String] $Name,
        [String] $Val,
        [Switch] $Global
    )

    $RegisterKey = if ($Global) {
        Get-Item -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager'
    } else {
        Get-Item -Path 'HKCU:'
    }

    $EnvRegisterKey = $RegisterKey.OpenSubKey('Environment', $true)
    if ($Val -eq $null) {
        $EnvRegisterKey.DeleteValue($Name)
    } else {
        $RegistryValueKind = if ($Val.Contains('%')) {
            [Microsoft.Win32.RegistryValueKind]::ExpandString
        } elseif ($EnvRegisterKey.GetValue($Name)) {
            $EnvRegisterKey.GetValueKind($Name)
        } else {
            [Microsoft.Win32.RegistryValueKind]::String
        }
        $EnvRegisterKey.SetValue($Name, $Val, $RegistryValueKind)
    }
}

function Add-JbtwslDirToPath {
    # Get $env:PATH of current user
    $userEnvPath = Get-Env 'PATH'

    if ($userEnvPath -notmatch [Regex]::Escape($JBTWSL_DIR)) {
        $h = (Get-PSProvider 'FileSystem').Home
        if (!$h.EndsWith('\')) {
            $h += '\'
        }

        if (!($h -eq '\')) {
            $friendlyPath = "$JBTWSL_DIR" -Replace ([Regex]::Escape($h)), "~\"
            Write-InstallInfo "Adding $friendlyPath to your path."
        } else {
            Write-InstallInfo "Adding $JBTWSL_DIR to your path."
        }

        # For future sessions
        Write-Env 'PATH' "$JBTWSL_DIR;$userEnvPath"
        # For current session
        $env:PATH = "$JBTWSL_DIR;$env:PATH"
    }
}

function Test-CommandAvailable {
    param (
        [Parameter(Mandatory = $True, Position = 0)]
        [String] $Command
    )
    return [Boolean](Get-Command $Command -ErrorAction Ignore)
}

function Install-Jbtwsl {
    Write-InstallInfo "Initializing..."
    # Enable TLS 1.2
    Optimize-SecurityProtocol

    $distroName = $JBTWSL_DEFAULT_DISTRO_NAME
    if ($WslDistroName) {
        $distroName = $WslDistroName
    }

    # Stop installation when distro name already exists
    if ((wsl --list --all -q) -contains $distroName) {
        Deny-Install "Jbtwsl distro name '$distroName' already exists"
    }

    $tarPath = $JBTWSL_DEFAULT_IMAGE_PATH
    if ($InstallTarPath) {
        $tarPath = $InstallTarPath
    }

    # Downloading jbtwsl image if 'InstallTarPath' is not set or not exists
    if (-not(Test-Path -Path $tarPath)) {
        Write-InstallInfo "Downloading Jbtwsl image..."
        New-Item -ItemType Directory -Force -Path $(Split-Path $tarPath -Parent) | Out-Null
        Invoke-DownloadFile -Uri $JBTWSL_IMAGE_URL -FileName $tarPath
    } else {
        Write-InstallInfo "Image file already presents, skip download..."
    }

    Write-InstallInfo "Installing Jbtwsl image..."
    $res = wsl --import $distroName $JBTWSL_DIR $tarPath
    if ($res -contains 'Error code: Wsl/Service/E_FAIL') {
        Deny-Install "Installation failed: $res`nMaybe the tar file is corrupted, try to delete it and run installer again. (rm '$tarPath')"
    }
    if (!((wsl --list --all -q) -contains $distroName)) {
        Deny-Install "Installation failed: $res"
    }

    Write-InstallInfo "Updating Jbtwsl (it will take some time)... "
    wsl -u root -d jbtwsl --exec bash -c "dnf update -y &>/dev/null"

    wsl --terminate $distroName | Out-Null
}

function Install-JbtwslQuick {
    # Install Jbtwsl
    Install-Jbtwsl

    # Add shortcut to desktop
    Add-JbtwslShortcut -name 'Jetbrains-Toolbox on WSL' -command 'jetbrains-toolbox'

    # Install Jbtwsl tool
    Write-InstallInfo 'Installing Jbtwsl tool...'
    Invoke-DownloadFile -Uri $JBTWSL_TOOL_URL -FileName "$JBTWSL_DIR\jbtwsl.ps1"
    Invoke-DownloadFile -Uri $JBTWSL_RUN_UI_URL -FileName "$JBTWSL_DIR\run-wsl-ui.ps1"
    Add-JbtwslDirToPath

    Write-InstallInfo ' '
    Write-InstallInfo 'Now you can start Jetbrains-Toolbox from your desktop!'
    Write-InstallInfo 'Get more help by exec `jbtwsl.ps1 -Help`'
    Write-InstallInfo ' '
}

function Add-JbtwslShortcut {
    param (
        [String]$name,
        [String]$command,
        [String]$pathTo,
        [String]$distro
    )

    $path = $JBTWSL_DEFAULT_SHORTCUT_PATH
    if ($pathTo) {
        $path = $pathTo
    }

    $distroName = $JBTWSL_DEFAULT_DISTRO_NAME
    if ($distro) {
        $distroName = $distro
    }

    Write-InstallInfo "Creating '$name' shortcut..."
    $fullPath = "$path\$name.lnk"
    $WScriptObj = New-Object -ComObject ("WScript.Shell")
    $shortcut = $WscriptObj.CreateShortcut($fullPath)
    $shortcut.TargetPath = "cmd"
    $shortcut.Arguments = "/c powershell.exe -File `"$JBTWSL_DIR\run-wsl-ui.ps1`" -WslCommand `"$command`" -DistroName `"$distroName`""
    $shortcut.Save()
    
}

function Invoke-CommandHelp {
    Get-Help $PSCommandPath -Detailed
}

function Write-DebugInfo {
    param($BoundArgs)

    Write-Verbose "-------- PSBoundParameters --------"
    $BoundArgs.GetEnumerator() | ForEach-Object { Write-Verbose $_ }
    Write-Verbose "-------- Environment Variables --------"
    Write-Verbose "`$env:USERPROFILE: $env:USERPROFILE"
    Write-Verbose "`$env:JBTWSL: $env:JBTWSL"
    Write-Verbose "-------- Selected Variables --------"
    Write-Verbose "JBTWSL_DIR: $JBTWSL_DIR"
}

# Prepare variables
$IS_EXECUTED_FROM_IEX = ($null -eq $MyInvocation.MyCommand.Path)

# Jbtwsl root directory
$JBTWSL_DIR = $JbtwslDir, $env:JBTWSL, "$env:USERPROFILE\jbtwsl" | Where-Object { -not [String]::IsNullOrEmpty($_) } | Select-Object -First 1
$JBTWSL_DEFAULT_DISTRO_NAME = 'jbtwsl'
$JBTWSL_IMAGE_URL = 'https://github.com/rozidan/jetbrains-toolbox-on-wsl/releases/download/v1.0.0/jbtwsl.tar'
$JBTWSL_TOOL_URL = 'https://raw.githubusercontent.com/rozidan/jetbrains-toolbox-on-wsl/main/install.ps1'
$JBTWSL_RUN_UI_URL = 'https://raw.githubusercontent.com/rozidan/jetbrains-toolbox-on-wsl/main/run-wsl-ui.ps1'
$JBTWSL_DEFAULT_IMAGE_PATH = "$JBTWSL_DIR\jbtwsl.tar"
$JBTWSL_DEFAULT_SHORTCUT_PATH = Get-ItemPropertyValue -Path "Registry::HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders" -Name "Desktop"

# Quit if anything goes wrong
$oldErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = 'Stop'

# Logging debug info
Write-DebugInfo $PSBoundParameters

switch ($PsCmdlet.ParameterSetName) {
    "Install" {
        Test-Prerequisite
        Test-ValidateParameterInstall
        Install-Jbtwsl
    }
    "Shortcut" {
        Test-Prerequisite
        Test-ValidateParameterShortcut
        Add-JbtwslShortcut -command $WslCommand -name $ShortcutName -path $ShortcutPath -distro $WslDistroName
    }
    "Quick" {
        Test-Prerequisite
        Install-JbtwslQuick
    }
    "Help" {
        Invoke-CommandHelp
    }
    Default {
        Invoke-CommandHelp
    }
}

Write-InstallInfo 'Done!'
Write-InstallInfo ' '

# Reset $ErrorActionPreference to original value
$ErrorActionPreference = $oldErrorActionPreference
