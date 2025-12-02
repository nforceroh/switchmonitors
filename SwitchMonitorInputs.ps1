
param (
    [string]$MonitorArg
)

function Switch-MonitorDPHDMI1 {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string]$MonitorInstanceName
    )

    $vcpCode = 0x60
    $inputValues = @{
        15 = 'DP'
        16 = 'HDMI1'
        17 = 'HDMI2'
    }

    Write-Host "Searching for monitor with instance name: $MonitorInstanceName"
    $monitor = Get-Monitor | Where-Object { $_.InstanceName -eq $MonitorInstanceName }

    if (-not $monitor) {
        Write-Host "Error: Monitor not found with instance name: $MonitorInstanceName" -ForegroundColor Red
        return
    }

    # compute modifier only after confirming $monitor is present
    $monitor_modifier = if ($monitor.InstanceName -like "*DEL*") { 3840 } else { 0 }

    $currentInput = Get-MonitorVCPResponse -Monitor $monitor -VCPCode $vcpCode
    $currentInputValue = [int]$currentInput.CurrentValue
    if ($monitor_modifier -ne 0) {
        $currentInputValue = $currentInputValue - $monitor_modifier
    }

    if ($currentInputValue -eq 15) {
        $nextInput = 17
        Write-Host "Switching from DP to HDMI1"
    } elseif ($currentInputValue -eq 16) {
        $nextInput = 15
        Write-Host "Switching from HDMI1 to DP"        
    } elseif ($currentInputValue -eq 17) {
        $nextInput = 15
        Write-Host "Switching from HDMI2 to DP"
    } else {
        Write-Host "Current input is not DP or HDMI1. No action taken. Input = $currentInputValue" -ForegroundColor Yellow
        return
    }

    Get-Monitor -DeviceName $monitor.LogicalDisplay | Set-MonitorVCPValue -VCPCode $vcpCode -Value $nextInput
    Write-Host "Monitor input switched successfully." -ForegroundColor Green
}

function Switch-MonitorBetweenAllInputs {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string]$MonitorInstanceName
    )

    $vcpCode = 0x60
    $inputValues = @{
        15 = 'DP'
        17 = 'HDMI1'
        18 = 'HDMI2'
    }

    Write-Host "Searching for monitor with instance name: $MonitorInstanceName"
    $monitor = Get-Monitor | Where-Object { $_.InstanceName -eq $MonitorInstanceName }

    if (-not $monitor) {
        Write-Host "Error: Monitor not found with instance name: $MonitorInstanceName" -ForegroundColor Red
        return
    }

    $monitor_modifier = if ($monitor.InstanceName -like "*DEL*") { 3840 } else { 0 }

    $currentInput = Get-MonitorVCPResponse -Monitor $monitor -VCPCode $vcpCode
    $currentInputValue = [int]$currentInput.CurrentValue
    if ($monitor_modifier -ne 0) {
        $currentInputValue = $currentInputValue - $monitor_modifier
    }

    if ($inputValues.ContainsKey($currentInputValue)) {
        Write-Host "Current input : $($inputValues[$currentInputValue]) -- Value: $currentInputValue"
    } else {
        Write-Host "Current input : Unknown -- Value: $currentInputValue" -ForegroundColor Yellow
    }

    $currentInputKey = $currentInputValue
    $inputKeys = $inputValues.Keys | Sort-Object

    # use .NET Array IndexOf for arrays
    $currentIndex = [array]::IndexOf($inputKeys, $currentInputKey)
    if ($currentIndex -lt 0) {
        Write-Host "Current input not in configured input list. No action taken." -ForegroundColor Yellow
        return
    }

    $nextIndex = ($currentIndex + 1) % $inputKeys.Count
    $nextInputKey = $inputKeys[$nextIndex]
    $nextInput = $nextInputKey

    Write-Host "Cycling input: $currentInputKey -> $nextInputKey"
    Get-Monitor -DeviceName $monitor.LogicalDisplay | Set-MonitorVCPValue -VCPCode $vcpCode -Value $nextInput
    Write-Host "Monitor input switched successfully." -ForegroundColor Green
}

# PS C:\controlmymonitor> Get-Monitor
# LogicalDisplay FriendlyName        InstanceName
# -------------- ------------        ------------
# \\.\DISPLAY0  Generic PnP Monitor DISPLAY\DELD107\5&2c99ba1c&2&UID256
# \\.\DISPLAY1  Generic PnP Monitor DISPLAY\AOC3201\5&2c99ba1c&2&UID260
# \\.\DISPLAY6  Generic PnP Monitor DISPLAY\GBT3209\7&31c0062b&0&UID516
# \\.\DISPLAY7  Generic PnP Monitor DISPLAY\DELD107\7&31c0062b&0&UID512
# param block moved to top of script

# Map friendly names to instance names
$monitorMap = @{
    'monitor1' = 'DISPLAY\DELD107\7&31c0062b&0&UID516'
    'monitor2' = 'DISPLAY\GBT3209\7&31c0062b&0&UID512'
    'monitor3' = 'DISPLAY\DELD107\5&2c99ba1c&2&UID256'
    'monitor4' = 'DISPLAY\AOC3201\5&2c99ba1c&2&UID260'
}

if ($MonitorArg -and $monitorMap.ContainsKey($MonitorArg.ToLower())) {
    $resolvedInstanceName = $monitorMap[$MonitorArg.ToLower()]
} else {
    $resolvedInstanceName = $MonitorArg
}

if ($resolvedInstanceName) {
    Switch-MonitorDPHDMI1 -MonitorInstanceName $resolvedInstanceName
} else {
    Write-Host "No monitor argument provided or monitor not found in map." -ForegroundColor Red
}
