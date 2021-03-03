<#
.SYNOPSIS
    Smart Ticket remediation script for high cpu usage.

.DESCRIPTION
    Reports back diagnostic information related to cpu usage.
    Supported: Yes
    Keywords: faws,cpu,high,smarttickets
    Prerequisites: No
    Makes changes: No

.INPUTS
    None

.OUTPUTS
    System information and top process list sorted by WorkingSet64

#>

$Results = {{ResultCount}}

try {
    $instancetype = Invoke-RestMethod -Uri http://169.254.169.254/latest/meta-data/instance-type
}
catch {
    $instancetype = "Not detected."
}

try {
    $ipaddress = Invoke-RestMethod -Uri http://169.254.169.254/latest/meta-data/local-ipv4
}
catch {
    $ipaddress = "Not detected."
}

try {
    $AppPools = @{}
    $AppCmd = "C:\Windows\system32\inetsrv\appcmd.exe"
    if (Test-Path $AppCmd) {
        $wps_list = "$AppCmd list wps" | Invoke-Expression
        if ($wps_list -is [system.array] -and $wps_list.Count -ge 2) {
            $wps_list | ForEach-Object {
                $null = $_ -match "WP \""([0-9]+)\"" \(applicationPool:(.*)\)"
                $AppPools[$matches[1]] = $matches[2]
            }
        }
    }

    $Processes = gwmi Win32_PerfFormattedData_PerfProc_Process -Filter "Name != '_Total' AND Name !='Idle'" | sort -Property PercentProcessorTime -Descending | Select-Object -First $Results Name, PercentProcessorTime, IDProcess
    $Services = gwmi Win32_service | Where-Object { $_.Started -eq "True" -and $_.ServiceType -eq "Share Process" } | Select-Object Name, ProcessId

    foreach ($Process in $Processes) {
        $Process | Add-Member -type NoteProperty -Name "Services" -Value (($Services | Where-Object { $_.ProcessId -eq $Process.IDProcess }).Name -join ", ")
        $Process | Add-Member -type NoteProperty -Name "ApplicationPool" -Value $AppPools["$($Process.IDProcess)"]
    }
    $ProcessTable = ($Processes | Select-Object Name, PercentProcessorTime, IDProcess, ApplicationPool, Services | Format-Table -AutoSize -Wrap | Out-String -Width 120) -split "`n" | ForEach-Object { $_.trimend() }

    Write-Output ("=" * 10) "VM and Process Information" ("=" * 10).TrimEnd()
    Write-Output "`ncomputer-name : $($env:COMPUTERNAME)".TrimEnd()
    Write-Output "ipv4-address  : $($ipaddress)".TrimEnd()
    Write-Output "instance-type : $($instancetype)".TrimEnd()

    $ProcessTable

    $w3wp = Get-Process -Name w3wp -ErrorAction SilentlyContinue | Select-Object Id,
    @{Label = "ApplicationPool"; Expression = { $AppPools["$($_.ID)"] } },
    Handles,
    @{Label = "NPM(K)"; Expression = { [int]($_.NPM / 1024) } },
    @{Label = "PM(K)"; Expression = { [int]($_.PM / 1024) } },
    @{Label = "WS(K)"; Expression = { [int]($_.WS / 1024) } },
    @{Label = "VM(M)"; Expression = { [int]($_.VM / 1MB) } },
    @{Label = "CPU(s)"; Expression = { if ($_.CPU) { $_.CPU.ToString("N") } } },
    SI

    if ($w3wp) {
        Write-Output ("=" * 10) "IIS Application Pool processes" ("=" * 10).TrimEnd()
        ($w3wp | Format-Table -AutoSize -Wrap | Out-String -Width 120) -split "`n" | ForEach-Object { $_.trimend() }
    }
}
catch {
    Write-Output "Error encountered :: Line# $($_.InvocationInfo.ScriptLineNumber) :: $($_.Exception.Message)"
    exit 1
}
