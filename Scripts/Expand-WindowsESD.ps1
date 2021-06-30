#===================================================================================================
#   Scripts/Expand-WindowsESD.ps1
#===================================================================================================
Write-Host -ForegroundColor DarkCyan    "================================================================="
Write-Host -ForegroundColor White       "$((Get-Date).ToString('yyyy-MM-dd-HHmmss')) " -NoNewline
Write-Host -ForegroundColor Green       "Scripts/Expand-WindowsESD.ps1"

if (-NOT ($Global:OSEdition)) {
    $Global:OSEdition = 'Enterprise'
}
Write-Host "OSEdition is set to $Global:OSEdition" -ForegroundColor Cyan

if (-NOT (Test-Path 'C:\OSDCloud\Temp')) {
    New-Item 'C:\OSDCloud\Temp' -ItemType Directory -Force | Out-Null
}
if ($Global:OSEdition -eq 'Education') {Expand-WindowsImage -ApplyPath 'C:\' -ImagePath "$OutFile" -Index 4 -ScratchDirectory 'C:\OSDCloud\Temp'}
elseif ($Global:OSEdition -eq 'Pro') {Expand-WindowsImage -ApplyPath 'C:\' -ImagePath "$OutFile" -Index 8 -ScratchDirectory 'C:\OSDCloud\Temp'}
else {Expand-WindowsImage -ApplyPath 'C:\' -ImagePath "$OutFile" -Index 6 -ScratchDirectory 'C:\OSDCloud\Temp'}

$SystemDrive = Get-Partition | Where-Object {$_.Type -eq 'System'} | Select-Object -First 1
if (-NOT (Get-PSDrive -Name S)) {
    $SystemDrive | Set-Partition -NewDriveLetter 'S'
}
bcdboot C:\Windows /s S: /f ALL
Start-Sleep -Seconds 10
$SystemDrive | Remove-PartitionAccessPath -AccessPath "S:\"
