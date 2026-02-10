param (
    [string]$MonitorInstanceName
)

# Map for convenience
$monitorMap = @{
    'monitor1' = 'DISPLAY\DELD107\7&1638f3cd&2&UID772'
    'monitor2' = 'DISPLAY\GBT3209\7&1638f3cd&2&UID768'
    'monitor3' = 'DISPLAY\DELD107\7&1638f3cd&2&UID776'
    'monitor4' = 'DISPLAY\AOC3201\7&1638f3cd&2&UID780'
}

if ($MonitorInstanceName -and $monitorMap.ContainsKey($MonitorInstanceName.ToLower())) {
    $resolvedInstanceName = $monitorMap[$MonitorInstanceName.ToLower()]
} else {
    $resolvedInstanceName = $MonitorInstanceName
}

$monitor = Get-Monitor | Where-Object { $_.InstanceName -eq $resolvedInstanceName }

if (-not $monitor) {
    Write-Host "Error: Monitor not found: $resolvedInstanceName" -ForegroundColor Red
    return
}

Write-Host "Monitor: $($monitor.InstanceName)" -ForegroundColor Cyan
Write-Host "Logical Display: $($monitor.LogicalDisplay)" -ForegroundColor Cyan

# Test multiple VCP codes that monitors use for input switching
$vcpCodesToTest = @(
    @{Code = 0x60; Name = "Input Source (Standard)"},
    @{Code = 0xF4; Name = "Input Source (Alternate)"},
    @{Code = 0xE0; Name = "Input Source (Some Gigabyte)"},
    @{Code = 0xCC; Name = "OSD Language (DDC/CI Test)"}
)

Write-Host "`nScanning for supported VCP codes..." -ForegroundColor Yellow

$supportedCodes = @()
foreach ($vcpInfo in $vcpCodesToTest) {
    try {
        $response = Get-MonitorVCPResponse -Monitor $monitor -VCPCode $vcpInfo.Code
        Write-Host "  VCP 0x$("{0:X}" -f $vcpInfo.Code) ($($vcpInfo.Name)): Current=$($response.CurrentValue), Max=$($response.MaxValue)" -ForegroundColor Green
        $supportedCodes += $vcpInfo.Code
    } catch {
        Write-Host "  VCP 0x$("{0:X}" -f $vcpInfo.Code) ($($vcpInfo.Name)): NOT SUPPORTED" -ForegroundColor DarkGray
    }
}

if ($supportedCodes.Count -eq 0) {
    Write-Host "`nNo VCP codes responded. Possible issues:" -ForegroundColor Red
    Write-Host "  1. DDC/CI is disabled in monitor's OSD menu - CHECK YOUR MONITOR SETTINGS" -ForegroundColor Yellow
    Write-Host "  2. Monitor doesn't support DDC/CI input switching" -ForegroundColor Yellow
    Write-Host "  3. Cable or connection issue preventing DDC/CI communication" -ForegroundColor Yellow
    Write-Host "`nPlease check your monitor's OSD menu for:" -ForegroundColor Cyan
    Write-Host "  - DDC/CI setting (enable it)" -ForegroundColor Cyan
    Write-Host "  - DDC setting (enable it)" -ForegroundColor Cyan
    Write-Host "  - DP 1.2 setting (may need to be enabled)" -ForegroundColor Cyan
} else {
    Write-Host "`nMonitor responds to $($supportedCodes.Count) VCP code(s). DDC/CI is working!" -ForegroundColor Green
    
    # If we found a working input code, test values
    $inputCodes = $supportedCodes | Where-Object { $_ -in @(0x60, 0xF4, 0xE0) }
    if ($inputCodes.Count -gt 0) {
        $testCode = $inputCodes[0]
        Write-Host "`nTesting input values on VCP 0x$("{0:X}" -f $testCode)..." -ForegroundColor Yellow
        $testValues = @(15, 16, 17, 18, 0x0F, 0x11, 0x12)
        
        foreach ($testValue in $testValues) {
            try {
                Get-Monitor -DeviceName $monitor.LogicalDisplay | Set-MonitorVCPValue -VCPCode $testCode -Value $testValue
                Start-Sleep -Milliseconds 800
                $newResponse = Get-MonitorVCPResponse -Monitor $monitor -VCPCode $testCode
                Write-Host "  Value $testValue (0x$("{0:X}" -f $testValue)) - Monitor now reports: $($newResponse.CurrentValue)" -ForegroundColor Green
            } catch {
                Write-Host "  Value $testValue (0x$("{0:X}" -f $testValue)) - FAILED" -ForegroundColor Red
            }
            Start-Sleep -Milliseconds 300
        }
    }
}
