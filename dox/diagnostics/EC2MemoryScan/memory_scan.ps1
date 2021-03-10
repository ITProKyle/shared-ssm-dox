<#
.SYNOPSIS
    Smart Ticket remediation script for high memory usage.

.DESCRIPTION
    Reports back diagnostic information related to memory usage.
    Supported: Yes
    Keywords: faws,memory,high,smarttickets
    Prerequisites: No
    Makes changes: No

.INPUTS
    None

.OUTPUTS
    System information and top process list sorted by WorkingSet64

#>

$Results = {{ResultCount}}

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

    # Get PageFile and System details.
    $PageFileUsage = Get-CimInstance -ClassName 'Win32_PageFileUsage' -Namespace 'root\CIMV2' -ErrorAction Stop
    $ComputerSystem = Get-CimInstance -ClassName 'Win32_ComputerSystem' -Namespace 'root\CIMV2' -ErrorAction Stop
    $PhysicalMemory = [math]::round($ComputerSystem.TotalPhysicalMemory / 1GB, 2)

    # Format System details
    $outputObject = New-Object PSObject -Property @{
        ComputerName = $ComputerSystem.Name;
        PageFile = $PageFileUsage.Name;
        AutomaticManagedPagefile = $ComputerSystem.AutomaticManagedPagefile
        AllocatedBaseSize_MB = $PageFileUsage.AllocatedBaseSize;
        PeakUsage_MB = $PageFileUsage.PeakUsage;
        CurrentUsage_MB = $PageFileUsage.CurrentUsage;
        isTempPageFile = $PageFileUsage.TempPageFile
        InstallDate = $PageFileUsage.InstallDate
        TotalPhysicalMemory = "$($PhysicalMemory)GB"
    } | Select-Object ComputerName, PageFile, AutomaticManagedPagefile, AllocatedBaseSize_MB, PeakUsage_MB, CurrentUsage_MB, isTempPageFile, InstallDate, TotalPhysicalMemory

    # Output System Details
    $outputObject | Format-List | Out-String

    # Output top {{ResultCount}} processes based on WorkingSet
    $Processes = Get-Process | Sort WS -Descending | Select-Object -First $Results
    $Services = gwmi Win32_service | Where-Object {$_.Started -eq "True" -and $_.ServiceType -eq "Share Process"} | Select-Object Name, ProcessId

    foreach ($Process in $Processes) {
        $Process | Add-Member -type NoteProperty -Name "Services" -Value (($Services | Where-Object {$_.ProcessId -eq $Process.Id}).Name -join ", ")
        $Process | Add-Member -type NoteProperty -Name "ApplicationPool" -Value $AppPools["$($Process.ID)"]
    }
    $ProcessTable = $Processes | Select-Object Handles,
    @{Label = "NPM(K)"; Expression = {[int]($_.NPM / 1024)}},
    @{Label = "PM(K)"; Expression = {[int]($_.PM / 1024)}},
    @{Label = "WS(K)"; Expression = {[int]($_.WS / 1024)}},
    @{Label = "VM(M)"; Expression = {[int]($_.VM / 1MB)}},
    @{Label = "CPU(s)"; Expression = {if ($_.CPU) {$_.CPU.ToString("N")}}},
    Id, ProcessName, ApplicationPool, Services | Format-Table -AutoSize -Wrap | Out-String -Width 120
    $ProcessTable -split "`n" | ForEach-Object {$_.trimend()}

    $w3wp = Get-Process -Name w3wp -ErrorAction SilentlyContinue | Select-Object Id,
    @{Label = "ApplicationPool"; Expression = {$AppPools["$($_.ID)"]}},
    Handles,
    @{Label = "NPM(K)"; Expression = {[int]($_.NPM / 1024)}},
    @{Label = "PM(K)"; Expression = {[int]($_.PM / 1024)}},
    @{Label = "WS(K)"; Expression = {[int]($_.WS / 1024)}},
    @{Label = "VM(M)"; Expression = {[int]($_.VM / 1MB)}},
    @{Label = "CPU(s)"; Expression = {if ($_.CPU) {$_.CPU.ToString("N")}}},
    SI

    if ($w3wp) {
        Write-Output ("=" * 10) "IIS Application Pool processes" ("=" * 10)
        ($w3wp | Format-Table -AutoSize -Wrap | Out-String -Width 120) -split "`n" | ForEach-Object {$_.trimend()}
    }
}
catch {
    Write-Output "Error encountered: $($_.Exception.Message)"
    exit 1
}
