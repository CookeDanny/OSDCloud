#===================================================================================================
#   Scripts/Test-OSDModule.ps1
#   OSD Module Minimum Version
#   Since the OSD Module is doing much of the heavy lifting, it is important to ensure that old
#   OSD Module versions are not used long term as the OSDCloud script can change
#   This example allows you to control the Minimum Version allowed.  A Maximum Version can also be
#   controlled in a similar method
#   In WinPE, the latest version will be installed automatically
#   In Windows, this script is stopped and you will need to update manually
#===================================================================================================
[Version]$OSDVersionMin = '21.3.11.1'

if ((Get-Module -Name OSD -ListAvailable | `Sort-Object Version -Descending | Select-Object -First 1).Version -lt $OSDVersionMin) {
    Write-Warning "OSDCloud requires OSD $OSDVersionMin or newer"

    if ($env:SystemDrive -eq 'X:') {
        Write-Warning "Updating OSD PowerShell Module"
        Install-Module OSD -Force
    } else {
        Write-Warning "Run the following PowerShell command to update the OSD PowerShell Module"
        Write-Warning "Install-Module OSD -Force -Verbose"
        Break
    }
}
#===================================================================================================
#   Global Variables
#   These are set automatically by the OSD Module 21.3.11+ when executing Start-OSDCloud
#   $Global:GitHubBase = 'https://raw.githubusercontent.com'
#   $Global:GitHubUser = $User
#   $Global:GitHubRepository = $Repository
#   $Global:GitHubBranch = $Branch
#   $Global:GitHubScript = $Script
#   $Global:GitHubToken = $Token
#   $Global:GitHubUrl
#   As a backup, $Global:OSDCloudVariables is created with Get-Variable
#===================================================================================================
$Global:OSDCloudVariables = Get-Variable
#===================================================================================================
#   Build Variables
#   Set these Variables to control the Build Process
#===================================================================================================
$BuildName      = 'OSDCloud'
$RequiresWinPE  = $true
#===================================================================================================
#   Start-OSDCloud
#===================================================================================================
Write-Host -ForegroundColor DarkCyan    "================================================================="
Write-Host -ForegroundColor White       "$((Get-Date).ToString('yyyy-MM-dd-HHmmss'))"
Write-Host -ForegroundColor Green       "Start OSDCloud"
Write-Host -Foregroundcolor Cyan        $Global:GitHubUrl
Write-Warning "THIS IS CURRENTLY IN DEVELOPMENT FOR TESTING ONLY"
Write-Host -ForegroundColor DarkCyan "================================================================="
Write-Host "ENT " -ForegroundColor Green -BackgroundColor Black -NoNewline
Write-Host "    Windows 10 x64 20H1 Enterprise"

Write-Host "EDU " -ForegroundColor Green -BackgroundColor Black -NoNewline
Write-Host "    Windows 10 x64 20H1 Education"

Write-Host "PRO " -ForegroundColor Green -BackgroundColor Black -NoNewline
Write-Host "    Windows 10 x64 20H1 Pro"

Write-Host "X   " -ForegroundColor Green -BackgroundColor Black -NoNewline
Write-Host "    Exit"
Write-Host -ForegroundColor DarkCyan "================================================================="

do {
    $BuildImage = Read-Host -Prompt "Enter an option, or X to Exit"
}
until (
    (
        ($BuildImage -eq 'ENT') -or
        ($BuildImage -eq 'EDU') -or
        ($BuildImage -eq 'PRO') -or
        ($BuildImage -eq '1') -or
        ($BuildImage -eq '2') -or
        ($BuildImage -eq '3') -or
        ($BuildImage -eq '4') -or
        ($BuildImage -eq '5') -or
        ($BuildImage -eq '6') -or
        ($BuildImage -eq '7') -or
        ($BuildImage -eq 'X')
    ) 
)

Write-Host ""

if ($BuildImage -eq 'X') {
    Write-Host ""
    Write-Host "Adios!" -ForegroundColor Cyan
    Write-Host ""
    Break
}
#===================================================================================================
#   Require cURL
#===================================================================================================
if ($null -eq (Get-Command 'curl.exe' -ErrorAction SilentlyContinue)) { 
    Write-Host "cURL is required for this process to work"
    Start-Sleep -Seconds 10
    Break
}
#===================================================================================================
#   Require WinPE
#   OSDCloud won't continue past this point unless you are in WinPE
#   The reason for the late failure is so you can test the Menu
#===================================================================================================
if ($RequiresWinPE) {
    if ((Get-OSDGather -Property IsWinPE) -eq $false) {
        Write-Warning "$BuildName can only be run from WinPE"
        Start-Sleep -Seconds 10
        Break
    }
}
#===================================================================================================
#   Remove USB Drives
#===================================================================================================
if (Get-USBDisk) {
    do {
        Write-Warning "Remove all attached USB Drives at this time ..."
        $RemoveUSB = $true
        pause
    }
    while (Get-USBDisk)
}
#===================================================================================================
Write-Host -ForegroundColor DarkCyan    "================================================================="
Write-Host -ForegroundColor Green       "Enabling High Performance Power Plan"
Write-Host -ForegroundColor Gray        "Get-OSDPower -Property High"
Get-OSDPower -Property High
#===================================================================================================
#   Scripts/New-OSDisk.ps1
#===================================================================================================
Write-Host -ForegroundColor DarkCyan    "================================================================="
Write-Host -ForegroundColor White       "$((Get-Date).ToString('yyyy-MM-dd-HHmmss'))"
Write-Host -ForegroundColor Green       "Prepare OSDisk"
Clear-LocalDisk -Force -ShowWarning
New-OSDisk -Force
Start-Sleep -Seconds 3
if (-NOT (Get-PSDrive -Name 'C')) {
    Write-Warning "Disk does not seem to be ready.  Can't continue"
    Break
}
#===================================================================================================
#   Scripts/Update-BIOS.ps1
#===================================================================================================
if ((Get-MyComputerManufacturer -Brief) -eq 'Dell') {
    Write-Host -ForegroundColor DarkCyan    "================================================================="
    Write-Host -ForegroundColor White       "$((Get-Date).ToString('yyyy-MM-dd-HHmmss'))"
    Write-Host -ForegroundColor Green       "BIOS Update"
    Update-MyDellBIOS
}
#===================================================================================================
#   Scripts/Save-WindowsESD.ps1
#===================================================================================================
Write-Host -ForegroundColor DarkCyan    "================================================================="
Write-Host -ForegroundColor White       "$((Get-Date).ToString('yyyy-MM-dd-HHmmss'))"
Write-Host -ForegroundColor Green       "Download Windows ESD"
Install-Module OSDSUS -Force
Import-Module OSDSUS -Force

if (-NOT (Test-Path 'C:\OSDCloud\ESD')) {
    New-Item 'C:\OSDCloud\ESD' -ItemType Directory -Force -ErrorAction Stop | Out-Null
}

$WindowsESD = Get-OSDSUS -Catalog FeatureUpdate -UpdateArch x64 -UpdateBuild 2009 -UpdateOS "Windows 10" | Where-Object {$_.Title -match 'business'} | Where-Object {$_.Title -match 'en-us'} | Select-Object -First 1

if (-NOT ($WindowsESD)) {
    Write-Warning "Could not find a Windows 10 download"
    Break
}

$Source = ($WindowsESD | Select-Object -ExpandProperty OriginUri).AbsoluteUri
$OutFile = Join-Path 'C:\OSDCloud\ESD' $WindowsESD.FileName

if (-NOT (Test-Path $OutFile)) {
    Write-Host "Downloading Windows 10 using cURL" -Foregroundcolor Cyan
    Write-Host "Source: $Source" -Foregroundcolor Cyan
    Write-Host "Destination: $OutFile" -Foregroundcolor Cyan
    #cmd /c curl.exe -o "$Destination" $Source
    & curl.exe --location --output "$OutFile" --url $Source
    #& curl.exe --location --output "$OutFile" --progress-bar --url $Source
}

if (-NOT (Test-Path $OutFile)) {
    Write-Warning "Something went wrong in the download"
    Break
}
#===================================================================================================
#   Expand Windows ESD
#===================================================================================================
Write-Host -ForegroundColor DarkCyan    "================================================================="
Write-Host -ForegroundColor White       "$((Get-Date).ToString('yyyy-MM-dd-HHmmss'))"
Write-Host -ForegroundColor Green       "Expand Windows ESD"

if (-NOT (Test-Path 'C:\OSDCloud\Temp')) {
    New-Item 'C:\OSDCloud\Temp' -ItemType Directory -Force | Out-Null
}

if ($BuildImage -eq 'EDU') {Expand-WindowsImage -ApplyPath 'C:\' -ImagePath "$OutFile" -Index 4 -ScratchDirectory 'C:\OSDCloud\Temp'}
elseif ($BuildImage -eq 'PRO') {Expand-WindowsImage -ApplyPath 'C:\' -ImagePath "$OutFile" -Index 8 -ScratchDirectory 'C:\OSDCloud\Temp'}
else {Expand-WindowsImage -ApplyPath 'C:\' -ImagePath "$OutFile" -Index 6 -ScratchDirectory 'C:\OSDCloud\Temp'}

$SystemDrive = Get-Partition | Where-Object {$_.Type -eq 'System'} | Select-Object -First 1
if (-NOT (Get-PSDrive -Name S)) {
    $SystemDrive | Set-Partition -NewDriveLetter 'S'
}
bcdboot C:\Windows /s S: /f ALL
$SystemDrive | Remove-PartitionAccessPath -AccessPath "S:\"
#===================================================================================================
#   Download Windows Drivers
#===================================================================================================
Write-Host -ForegroundColor DarkCyan    "================================================================="
Write-Host -ForegroundColor White       "$((Get-Date).ToString('yyyy-MM-dd-HHmmss'))"
Write-Host -ForegroundColor Green       "Download Windows Drivers"

if ((Get-MyComputerManufacturer -Brief) -eq 'Dell') {
    Save-MyDellDriverCab
}
#===================================================================================================
#   Scripts/Apply-Drivers.ps1
#===================================================================================================
Write-Host -ForegroundColor DarkCyan    "================================================================="
Write-Host -ForegroundColor White       "$((Get-Date).ToString('yyyy-MM-dd-HHmmss'))"
Write-Host -ForegroundColor Green       "Installing Windows Drivers Offline"

$PathPanther = 'C:\Windows\Panther'
if (-NOT (Test-Path $PathPanther)) {
    New-Item -Path $PathPanther -ItemType Directory -Force | Out-Null
}

$UnattendDrivers = @'
<?xml version="1.0" encoding="utf-8"?>
<unattend xmlns="urn:schemas-microsoft-com:unattend">
    <settings pass="offlineServicing">
        <component name="Microsoft-Windows-PnpCustomizationsNonWinPE" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <DriverPaths>
                <PathAndCredentials wcm:keyValue="1" wcm:action="add">
                    <Path>C:\Drivers</Path>
                </PathAndCredentials>
            </DriverPaths>
        </component>
    </settings>
</unattend>
'@

$UnattendPath = Join-Path $PathPanther 'Unattend.xml'
Write-Verbose -Verbose "Setting Driver $UnattendPath"
$UnattendDrivers | Out-File -FilePath $UnattendPath -Encoding utf8

Write-Verbose -Verbose "Applying Use-WindowsUnattend $UnattendPath"
Use-WindowsUnattend -Path 'C:\' -UnattendPath $UnattendPath
#===================================================================================================
#   Save-AutoPilotModules.ps1
#===================================================================================================
Write-Host -ForegroundColor White "$((Get-Date).ToString('yyyy-MM-dd-HHmmss'))"

Save-Module -Name WindowsAutoPilotIntune -Path 'C:\Program Files\WindowsPowerShell\Modules' -Verbose
if (-NOT (Test-Path 'C:\Program Files\WindowsPowerShell\Scripts')) {
    New-Item -Path 'C:\Program Files\WindowsPowerShell\Scripts' -ItemType Directory -Force | Out-Null
}
Save-Script -Name Get-WindowsAutoPilotInfo -Path 'C:\Program Files\WindowsPowerShell\Scripts' -Verbose

$PathAutoPilot = 'C:\Windows\Provisioning\AutoPilot'
if (-NOT (Test-Path $PathAutoPilot)) {
    New-Item -Path $PathAutoPilot -ItemType Directory -Force | Out-Null
}












#===================================================================================================
#   COMPLETE
#===================================================================================================
Write-Host -ForegroundColor DarkCyan    "================================================================="
Write-Host -ForegroundColor White       "$((Get-Date).ToString('yyyy-MM-dd-HHmmss'))"
Write-Host -ForegroundColor Green       "OSDCloud is complete"
Write-Host -ForegroundColor DarkCyan    "================================================================="