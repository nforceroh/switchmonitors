
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
        15 = 'DP'    # DisplayPort value
        17 = 'HDMI1' # HDMI 1 value
    }

    Write-Host "Searching for monitor with instance name: $MonitorInstanceName"
    $monitor = Get-Monitor | Where-Object { $_.InstanceName -eq $MonitorInstanceName }
    $monitor_modifier = if ($monitor.InstanceName -like "*DEL*") { 3840 } else { 0 }

    if (-not $monitor) {
        Write-Host "Error: Monitor not found with instance name: $MonitorInstanceName" -ForegroundColor Red
        return
    }

    $currentInput = Get-MonitorVCPResponse -Monitor $monitor -VCPCode $vcpCode
    if ($monitor_modifier -ne 0) {
        $currentInputValue = [int]$currentInput.CurrentValue - $monitor_modifier
    } else {
        $currentInputValue = [int]$currentInput.CurrentValue
    }

    if ($currentInputValue -eq 15) {
        $nextInput = 17
        Write-Host "Switching from DP to HDMI1"
    } elseif ($currentInputValue -eq 17) {
        $nextInput = 15
        Write-Host "Switching from HDMI1 to DP"
    } else {
        Write-Host "Current input is not DP or HDMI1. No action taken." -ForegroundColor Yellow
        return
    }

    Get-Monitor -DeviceName $monitor.LogicalDisplay | Set-MonitorVCPValue -VCPCode $vcpCode -Value $nextInput
    Write-Host "Monitor input switched successfully." -ForegroundColor Green
}

function Switch-MonitorBetweenAllInputs {
    [CmdletBinding()]
    param (
        # The unique InstanceName of the monitor to control.
        # Can be found by running 'Get-Monitor'.
        [Parameter(Mandatory=$true)]
        [string]$MonitorInstanceName
    )

    # VCP Code for Input Select on most monitors is 0x60
    $vcpCode = 0x60

    # VCP values for DisplayPort and HDMI on your Dell monitor
    # Map input names to their VCP values
    $inputValues = @{
        15 = 'DP'    # DisplayPort value
        17 = 'HDMI1'  # HDMI 1 value
        18 = 'HDMI2'  # HDMI 2 value
    }

    Write-Host "Searching for monitor with instance name: $MonitorInstanceName"
    $monitor = Get-Monitor | Where-Object { $_.InstanceName -eq $MonitorInstanceName }
    $monitor_modifier = if ($monitor.InstanceName -like "*DEL*") { 3840 } else { 0 }

    if (-not $monitor) {
        Write-Host "Error: Monitor not found with instance name: $MonitorInstanceName" -ForegroundColor Red
        return
    }

    $currentInput = Get-MonitorVCPResponse -Monitor $monitor -VCPCode $vcpCode
    if ($monitor_modifier -ne 0) {
        $currentInputValue = [int]$currentInput.CurrentValue - $monitor_modifier
    } else {
        $currentInputValue = [int]$currentInput.CurrentValue
    }
    if ($inputValues.ContainsKey($currentInputValue)) {
        Write-Host "Current input : $($inputValues[$currentInputValue]) -- Value: $currentInputValue"
    } else {
        Write-Host "Current input : Unknown -- Value: $currentInputValue" -ForegroundColor Yellow
    }
    # Find the key of the current input value
    $currentInputKey = $currentInputValue

    # Get all input keys sorted
    $inputKeys = $inputValues.Keys | Sort-Object

    # Find index of current key
    $currentIndex = $inputKeys.IndexOf($currentInputKey)

    # Calculate next index (cycle to start if at end)
    $nextIndex = ($currentIndex + 1) % $inputKeys.Count

    # Get next input key and value
    $nextInputKey = $inputKeys[$nextIndex]
    $nextInput = $nextInputKey

    Write-Host "Cycling input: $currentInputKey -> $nextInputKey"Write-Host "Cycling input: $currentInputKey -> $nextInputKey"
    # Set the new VCP value
    Get-Monitor -DeviceName $monitor.LogicalDisplay | Set-MonitorVCPValue -VCPCode $vcpCode -Value $nextInput
    Write-Host "Monitor input switched successfully." -ForegroundColor Green
}

#PS C:\> Get-Monitor -DeviceName \\.\DISPLAY3 | Set-MonitorVCPValue -VCPCode 0xD6 -Value 4
#LogicalDisplay FriendlyName        InstanceName
#-------------- ------------        ------------
#\\.\DISPLAY1   GIGABYTE M32UC      DISPLAY\GBT3209\7&29938077&0&UID260
#\\.\DISPLAY6   Generic PnP Monitor DISPLAY\DELD107\5&2c99ba1c&0&UID512
#\\.\DISPLAY2   Generic PnP Monitor DISPLAY\DELD107\7&29938077&0&UID256
#\\.\DISPLAY7   AOC Q32G1WG4        DISPLAY\AOC3201\5&2c99ba1c&0&UID516
# param block moved to top of script

# Map friendly names to instance names
$monitorMap = @{
    'monitor1' = 'DISPLAY\DELD107\7&29938077&0&UID256'
    'monitor2' = 'DISPLAY\GBT3209\7&29938077&0&UID260'
    'monitor3' = 'DISPLAY\DELD107\5&2c99ba1c&0&UID512'
    'monitor4' = 'DISPLAY\AOC3201\5&2c99ba1c&0&UID516'
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
