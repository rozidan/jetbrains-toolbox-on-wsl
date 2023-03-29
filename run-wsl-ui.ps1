param (
    [Parameter(Mandatory)]
    [String] $WslCommand,
    [Parameter(Mandatory)]
    [String] $DistroName
)

Write-Host "Closing this window will cause '$WslCommand' on '$DistroName' to be closed."
Write-Host "Close this window ether by pressing the close button or pressing 'Ctrl-C'"
wsl -d $DistroName bash -c "sleep 2 && source ~/.bashrc && source ~/.profile && $WslCommand && sleep infinity"
