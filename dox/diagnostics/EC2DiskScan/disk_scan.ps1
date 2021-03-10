<#
.SYNOPSIS
    SmartTicket remediation script for high disk usage.

.DESCRIPTION
    Reports back diagnostic information related to disk usage.
    Supported: Yes
    Keywords: faws,disk,high,smarttickets
    Prerequisites: No
    Makes changes: No

.INPUTS
    None

.OUTPUTS
    TBD

#>
[System.Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingWMICmdlet", "")]
Param()

$DriveLetter = "{{DriveLetter}}:" # Drive to Scan
$ResultsLimit = {{ResultCount}} # Number of results
$PerformRemediation = "{{PerformRemediation}}"

[System.Convert]::ToBoolean($PerformRemediation)

function ConvertTo-Gigabytes {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '')]
    [CmdletBinding()]
    [OutputType([double])]
    Param(
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)][long]$Bytes
    )

    process {
        $Gigabytes = $Bytes / 1GB
        [Math]::Round($Gigabytes, 2)
    }
}

Function Get-ServerRole {
    [CmdletBinding()]
    [OutputType([psobject])]
    Param()

    begin {
        $Output = New-Object PSObject -Property @{
            ActiveDirectory = $null
            IIS = $null
            DFSR = $null
            RemoteDesktop = $null
            Cluster = $null
            SQL = $null
            SharePoint = $null
            Exchange = $null
        }
    }

    process {
        $OSVersion = (Get-OsInformation).Version

        if (($OSVersion -ge [version]"6.1") -and ([IntPtr]::size -eq 8)) {
            # OS is 2008R2 or higher
            Import-Module ServerManager

            $InstalledRoles = Get-WindowsFeature | Where-Object {
                ($_.InstallState -eq "Installed") -or
                ($_.InstallState -eq "InstallPending") -or
                ($_.Installed)
            }

            $InstalledRoleNames = $InstalledRoles | Select-Object  -ExpandProperty Name
            $Output.IIS = $(($InstalledRoleNames -contains "Web-Server") -as [bool])
            $Output.ActiveDirectory = $(($InstalledRoleNames -contains "AD-Domain-Services") -as [bool])
            $Output.DFSR = $(($InstalledRoleNames -contains "FS-DFS-Replication") -as [bool])
            $Output.RemoteDesktop = $(($InstalledRoleNames -contains "Remote-Desktop-Services") -as [bool])
            $Output.Cluster = $(($InstalledRoleNames -contains "Failover-Clustering") -as [bool])
        }
        else {
            # required for Server 2008 backward compatibility where ServerManager module is not present
            $Output.RemoteDesktop = $((Get-WmiObject -Namespace "root\CIMV2\TerminalServices" -Class "Win32_TerminalServiceSetting").TerminalServerMode -as [bool])
            $Output.IIS = $((Get-Service w3svc -ErrorAction SilentlyContinue) -as [bool])
            # DCs are with value of 4 or 5 (from 0-5)
            $Output.ActiveDirectory = (Get-WmiObject Win32_ComputerSystem).DomainRole -match "(4|5)"
            $Output.DFSR = $((Get-Service DFSR -ErrorAction SilentlyContinue) -as [bool])
            $Output.Cluster = $((Get-WmiObject -Class MSCluster_ResourceGroup -Namespace root\mscluster -ErrorAction SilentlyContinue) -as [bool])
        }

        # SQL
        $SqlServerWmi = Get-WmiObject -Namespace "ROOT\Microsoft\SqlServer" -Class "__Namespace" -ErrorAction SilentlyContinue
        $Output.SQL = $($SqlServerWmi -as [bool])

        # Exchange
        $ExchangeService = Get-Service -name 'MSExchangeServiceHost' -ErrorAction SilentlyContinue
        $Output.Exchange = $($ExchangeService -as [bool])

        # SharePoint
        $SPSnapin = "Microsoft.SharePoint.PowerShell"
        $Output.SharePoint = (
            (Get-PSSnapin $SPSnapin -ErrorAction SilentlyContinue) -or
            (Get-PSSnapin $SPSnapin -Registered -ErrorAction SilentlyContinue)
        )

        return $Output
    }
}

function Get-FileSize {
    [CmdletBinding()]
    [OutputType([long])]
    param
    (
        # Non-mandatory, because we want null input to return 0
        [Parameter(Position = 0, ValueFromPipeline = $true)][string]$Path
    )

    begin {
        [long]$RunningTotal = 0
    }

    process {
        if (-not $Path -or -not (Test-Path "$Path")) {
            [long]$Sum = 0
        }
        else {
            $Item = $(Get-Item $Path -Force)

            # If path is a folder run Du if it's a file use Get-ChildItem
            if ($Item.PSIsContainer) {
                [long]$Sum = (Get-ChildItem -Path $Path -Recurse -Force -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum
            }
            else {
                [long]$Sum = $Item.Length
            }
        }

        $RunningTotal += $Sum
    }

    end {
        return $RunningTotal
    }
}

Function Get-PageFile {
    [CmdletBinding()]
    [OutputType([System.Collections.ArrayList])]
    Param()

    begin {
        Write-Verbose "[$(Get-Date)] Begin :: $($MyInvocation.MyCommand)"
        Write-Verbose "[$(Get-Date)] List of Parameters :: $($PSBoundParameters.GetEnumerator() | Out-String)"

        $OutputProperties = @(
            'Location',
            'InitialSizeGB',
            'MaxSizeGB',
            'PeakUsageGB'
        )

        $Output = New-Object System.Collections.ArrayList
    }

    process {
        # settings are actuate at the time of config
        $PageFiles = Get-WmiObject Win32_PageFileSetting |
        Select-Object Name, InitialSize, MaximumSize

        # some properties are only accurate after server is rebooted once config is changed
        $PageFileUsages = Get-WmiObject Win32_PageFileusage |
        Select-Object Name, PeakUsage

        If ($PageFiles) {
            Foreach ($PageFile in $PageFiles) {
                $OutputPSO = "" | Select-Object $OutputProperties
                $PeakUsage = $PageFileUsages |
                Where-Object { $_.Name -eq $PageFile.Name } |
                Select-Object -ExpandProperty PeakUsage

                $OutputPSO.'Location' = $PageFile.Name
                $OutputPSO.'InitialSizeGB' = [Math]::Round(($PageFile.InitialSize / 1024), 2)
                $OutputPSO.'MaxSizeGB' = [Math]::Round(($PageFile.MaximumSize / 1024), 2)
                $OutputPSO.'PeakUsageGB' = [Math]::Round(([int]$PeakUsage / 1024), 2)

                $Output.add($OutputPSO) | Out-Null
            }
        }
        else {
            $OutputPSO = "" | Select-Object $OutputProperties
            $OutputPSO.Location = "Pagefile not found"
            $Output.add($OutputPSO) | Out-Null
        }

        return $Output
    }

    end {
        Write-Verbose "[$(Get-Date)] End   :: $($MyInvocation.MyCommand)"
    }
}

Function Get-OSInformation {
    [CmdletBinding()]
    [OutputType([psobject])]
    Param()


    $OSInformation = Get-WmiObject Win32_OperatingSystem -ErrorAction Stop

    $InstallDateTime = $OSInformation.ConvertToDateTime($OSInformation.InstallDate)

    $ServicePack = $OSInformation.CSDVersion
    if (-not $ServicePack) { $ServicePack = "RTM" }

    $Output = New-Object PSObject -Property @{
        Hostname = $OSInformation.CSName
        Caption = $OSInformation.Caption
        Version = [version]$OSInformation.Version
        ServicePack = $ServicePack
        Architecture = $OSInformation.OSArchitecture
        InstallDate = $InstallDateTime
    }

    return $Output
}

Function Get-ShadowCopy {
    [CmdletBinding()]
    [OutputType([PSObject[]])]
    Param(
        [Parameter(Mandatory = $true, Position = 0)][ValidatePattern('^[A-Z]$')][string]$DriveLetter
    )

    begin {
        Write-Verbose "[$(Get-Date)] Begin :: $($MyInvocation.MyCommand)"
        Write-Verbose "[$(Get-Date)] List of Parameters :: $($PSBoundParameters.GetEnumerator() | Out-String)"

        $Output = New-Object PSObject -Property @{
            "UsedGB" = $null
            "MaxGB" = $null
        }
    }

    process {
        $Drive = "$DriveLetter" + ":"
        $VSS = Vssadmin list shadowstorage /On=$Drive
        switch -wildcard ($VSS) {
            "*Used Shadow Copy Storage space*" {
                $StorageUsedString = (($VSS |
                        Where-Object { $_ -like "*Used Shadow Copy Storage space*" }).Replace("Used Shadow Copy Storage space:", "")).Trim()

                [int32]$StorageUsed = $StorageUsedString.Split(" ")[0]
                $StorageUsedGB = [Math]::Round(($StorageUsed / 1024), 2)

                $MaxStorageSpaceString = (($VSS |
                        Where-Object { $_ -like "*Maximum Shadow Copy Storage space*" }).Replace("Maximum Shadow Copy Storage space:", "")).Trim()

                [int32]$MaxStorageSpace = $MaxStorageSpaceString.Split(" ")[0]
                $MaxStorageSpace = [Math]::Round($($MaxStorageSpace), 2)
            }
            "*No items found that satisfy the query.*" {
                $StorageUsedGB = 0
                $MaxStorageSpace = 0
            }
        }

        $Output.UsedGB = $StorageUsedGB
        $Output.MaxGB = $MaxStorageSpace

        Return $Output
    }

    end {
        Write-Verbose "[$(Get-Date)] End   :: $($MyInvocation.MyCommand)"
    }
}

function Get-WmiDirectory {
    [CmdletBinding()]
    [OutputType([wmi])]
    Param(
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)][string]$Folder
    )

    process {
        if (-not (Test-Path $Folder -PathType Container)) {
            Write-Error -Exception (
                New-Object System.Management.Automation.ItemNotFoundException ("Cannot find path '$Folder' because it does not exist or is not a directory.")
            )
            return
        }

        Get-WmiObject Win32_Directory -Filter "Name = '$($Folder -replace '\\', '\\')'"
    }
}


Function Start-JobTimeout {
    [CmdletBinding()]

    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseShouldProcessForStateChangingFunctions", "", Scope = "Function", Target = "Start-JobTimeout")]
    Param(
        [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][String]$StringScriptblock,
        [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][String]$JobName,
        # timeout for job 300 seconds = 5 minutes, max time out allowed is 999 seconds
        [Parameter()][ValidatePattern("^[1-9]{1}[0-9]{0,2}$")][Int]$TimeOut = 300,
        [Parameter()][Switch]$TestJob
    )

    Write-Verbose "Start of $($MyInvocation.MyCommand)"

    #################### Test Jobs - BEGIN ####################
    # region

    # Convert string to scriptblock
    $scriptBlock = [Scriptblock]::Create($StringScriptblock)

    # Run a test PS Job and make sure device can run jobs. Any exception means, most likely, PSRemoting is disabled or similar.
    [Switch]$UseJobs = $true

    # Output Job PSO
    $Result = New-Object PSObject -Property @{
        JobOutput = "";
        JobStatus = "";
        JobError = $false;
        JobTimeout = "$timeout";
        JobScript = "$scriptBlock"
        JobLoopTime = ""
    }

    # Test if jobs work on this server, use switch param TestJob
    If ($TestJob) {
        Try {
            Write-Verbose "Starting - Powershell Job Test"

            $TestString = "Can I Job it?"
            ($TestingJob = Start-Job { Write-Output $args } -ArgumentList $TestString) | Out-Null
            Wait-Job $TestingJob | Out-Null
            $TestJobResult = Receive-Job $TestingJob
            Remove-Job $TestingJob | Out-Null
            If ($TestJobResult -ne $TestString) {
                # job failed to return expected result
                Throw "Failed to create a powershell job"
            }
            Write-Verbose "Completed - Powershell Job Test"
        }
        Catch {
            # Failed to create job
            Write-Verbose "Failed - Powershell Job Test"
            $UseJobs = $False

            # Output Job PSO
            $Result.JobError = $true
            $Result.JobOutput = "Powershell failed to start a simple test Job, psremoting may not be enabled"
            Return $Result
        }
    }

    # end region
    ##################### Test Jobs - END #####################

    #################### Check if Job Already Exists - BEGIN ####################
    # region

    # Successfully ran job before to will try to use jobs for get-ChildObject
    If ($UseJobs) {
        # Check if already job exists and quit if it does exist.
        # if the name doesn't exist it would error which is why silently continue is set.
        $JobState = Get-Job -Name "$JobName" -ErrorAction SilentlyContinue
        If ($JobState) {
            # Quits and returns error
            Write-Verbose  "Failed - Powershell Job ($JobName) already exists"

            # Output Job PSO
            $Result.JobError = $true
            $Result.JobStatus = "Duplicate Job"
            $Result.JobOutput = "Powershell Job ($JobName) is already present, preventing creation of duplicate job"
            Return $Result
            # running, File search is disabled in this run of the template
        }
    }

    # end region
    ##################### Check if Job Already Exists - END #####################

    #################### Start and Loop Job - BEGIN ####################
    # region

    Write-Verbose "Starting - Powershell Job ($JobName)"
    Write-Verbose "Powershell Job ($JobName) Script block:"
    Write-Verbose "$Scriptblock"

    # Try starting the job
    Try {
        Start-Job -Name "$JobName" -ScriptBlock $Scriptblock -ErrorAction Stop | Out-Null
        Write-Verbose "Created - Powershell Job ($JobName)"
    }
    Catch {
        # Quits and returns error
        # Output Job PSO
        $Result.JobError = $true
        $Result.JobOutput = "Powershell Job ($JobName) failed to created"
        Return $Result
    }

    # Vars for job check loop
    [Switch]$jobresult = $false # check if job has returned a result
    [Int]$sleepseconds = 5 # Sleep between checks
    [Int]$runtime = 0 # counts the run time

    # If job was created check the status of the job
    Do {
        # Gets the status of the job
        $JobState = Get-Job -Name "$JobName" -ErrorAction SilentlyContinue

        Write-Verbose "Powershell Job ($JobName) - Job State ($($JobState.State) | Run Time ($runtime)"

        # Checks the status of the job
        If ($JobState.State -eq "Running") {
            # job not complete so start sleep for x seconds.
            Start-Sleep $sleepseconds
            $runtime += $sleepseconds
        }
        Else {
            # job complete
            $jobresult = $true
        }
    }
    Until (($runtime -gt $timeout) -or ($jobresult -eq $true))
    # Quits if running time of the loop is more than the timeout value
    # Quits if job completed

    # Powershell Job status and runtime
    $result.JobStatus = $($JobState.State)
    $result.JobLoopTime = $runtime


    # Check if result returned or timed out.
    If ($runtime -gt $timeout) {
        # Output Job PSO
        $Result.JobError = $true
        $Result.JobOutput = "Expected Exception:PowerShell job over ran timed out ($timeout seconds) and was stopped to prevent performance impact "
    }
    ElseIf ($JobState.State -eq "Completed") {
        Try {
            $JobContent = Receive-Job -Name "$JobName" -ErrorAction Stop
            $Result.JobOutput = $JobContent | Select-Object -Property * -ExcludeProperty PSComputerName, PSShowComputerName, RunspaceId
            Write-Verbose "Receive Job - Powershell Job ($JobName)"
        }
        Catch {
            # Output Job PSO
            $Result.JobError = $true
            $Result.JobOutput = "Error Job Failed to return a result "
        }
    }
    Else {
        # Output Job PSO
        $Result.JobError = $true
        $Result.JobOutput = "Error Job ($JobName) Status ($($JobState.State)) "
    }

    # Clean up jobs
    Stop-Job -Name $JobName -ErrorAction SilentlyContinue | Out-Null
    Remove-Job -Name $JobName -Force -ErrorAction SilentlyContinue | Out-Null

    # end region
    ##################### Start and Loop Job - END #####################

    Write-Verbose "End of $($MyInvocation.MyCommand)"

    return $Result
}

Function Get-LargeFiles {
    [CmdletBinding()]
    [OutputType([PSObject[]])]
    Param(
        [Parameter(Mandatory = $true, Position = 0)][ValidatePattern('^[A-Z]$')][string]$DriveLetter
    )
    try {
        $Drive = "$DriveLetter" + ":"
        $RunTop10 = $true

        If ($RunTop10) {
            # Run job to get Top 10 Largest files on the disk
            $GetChildItemJob1 = Start-JobTimeout -StringScriptblock "Get-ChildItem $Drive\ -Recurse -ErrorAction SilentlyContinue | Sort-Object Length -descending | select-object FullName, @{Name='Size (MB)';Expression={[Math]::Truncate(`$_.Length / 1MB)}} -First $ResultsLimit -ErrorAction SilentlyContinue" -JobName "JobChildItemDrive" -TestJob -Timeout 300

            # Check if there was an error
            If ($GetChildItemJob1.JobError -eq $false) {
                #List of top 10 files
                $Output = $GetChildItemJob1.JobOutput | Select-Object -Property * -ExcludeProperty PSComputerName, PSShowComputerName, RunspaceId

                # Add Top10Files variable to Output
                # $output."Top 10 files" = ConvertTo-ASCII -Data $Top10Files -NoAddBlankLine
            }
            Else {
                $output = "Error Nothing returned: $($GetChildItemJob1.JobOutput) "
            }
        }
        Else {
            # Error return job error message
            $output += "Error: Unable to run Top to File check. "
            $output += $GetChildItemJob1.JobOutput
        }
        return $output
    }
    catch {
        Write-Output "An error occurred while while running Get-LargeFiles that could not be resolved"
    }
}

Function Get-DiskSpaceReportP1 {
    [CmdletBinding()]
    [OutputType([psobject])]
    Param(
        [Parameter(Mandatory = $true, Position = 0)][ValidatePattern('^[A-Za-z](:\\?)?$')][string]$DriveLetter
    )

    begin {
        Write-Verbose "[$(Get-Date)] Begin :: $($MyInvocation.MyCommand)"
        Write-Verbose "[$(Get-Date)] List of Parameters :: $($PSBoundParameters.GetEnumerator() | Out-String)"

        # Normalize C, C: or C:\ into C
        # Lookahead matches ^\w, i.e. keeps first letter, then replaces everything else
        [string]$DriveLetter = $DriveLetter -replace '(?<=^\w).*'
        [string]$Mountpoint = "$DriveLetter`:"

        # Priority 1
        $RecycleBin = Join-Path $Mountpoint '$Recycle.Bin\'
        $RsPkgs = Join-Path $Mountpoint 'rs-pkgs\'
        $Sources = Join-Path $Mountpoint 'Windows\Sources\'
        $SoftwareDistribution = Join-Path $Mountpoint 'Windows\SoftwareDistribution\Download\'
        $CbsLogs = Join-Path $Mountpoint 'Windows\Logs\CBS\'
        $TempFiles = Join-Path $Mountpoint 'Windows\Temp\'
        $DumpFiles = Join-Path $Mountpoint 'Windows\'
        $WerReportQueue = Join-Path $Mountpoint 'ProgramData\Microsoft\Windows\WER\ReportQueue\'

        # Folder paths for observations
        $Folders = New-Object -TypeName PSObject -Property @{
            SoftwareDistributionGB = $SoftwareDistribution
            RecycleBinGB = $RecycleBin
            InstallWimGB = $Sources
            RsPkgsGB = $RsPkgs
            CbsCabFilesGB = $CbsLogs
            TempFiles = $TempFiles
            WerReportQueueGB = $WerReportQueue
            DumpfilesGB = $DumpFiles
        }

        # Output
        $Output = New-Object -TypeName PSObject -Property @{
            Drive = $null
            Roles = $null
            P1Folders1 = $null
            P1Folders2 = $null
            RsPkgsShouldNotDelete = $null
            P1CompressibleFolders = $null
            Folders = $Folders
        }

        $Drive = New-Object -TypeName PSObject -Property @{
            DriveLetter = $DriveLetter
            OSDrive = $null
            SizeGB = $null
            FreeSpaceGB = $null
            FreeSpacePercent = $null
        }

        $P1Folders1 = New-Object -TypeName PSObject -Property @{
            SoftwareDistributionGB = $null
            RecycleBinGB = $null
            InstallWimGB = $null
        }

        $P1Folders2 = New-Object -TypeName PSObject -Property @{
            RsPkgsGB = $null
            CbsCabFilesGB = $null
            TempFilesGB = $null
            WerReportQueueGB = $null
            DumpfilesGB = $null
        }

        $OSdrive = (Get-WmiObject Win32_OperatingSystem).SystemDrive
        $OSdrive = $OSdrive -replace '(?<=^\w).*'

        $VarParams = @{
            'Name' = 'DISK_SPACE_COMPRESSIBLE_FOLDER_PATHS'
            'Value' = @(
                "$($OSdrive):\Windows\Installer",
                "$($OSdrive):\Windows\inf",
                "$($OSdrive):\Windows\ServiceProfiles\NetworkService\AppData\Local\Temp",
                "$($OSdrive):\ProgramData\Microsoft\Windows\WER\ReportQueue",
                "$($OSdrive):\inetpub\logs\LogFiles"
            )
            'Description' = 'Folders declared by the Standardization team to be OK for NTFS compression'
            'Scope' = 'Script'
            'Force' = $True
            'Option' = 'ReadOnly'
        }
        Set-Variable @VarParams

        $VarParams = @{
            'Name' = 'DISK_SPACE_SHOULD_NOT_DELETE_PATTERN'
            'Value' = (
                '^\d{6}-\d{5}$', # Match Core ticket ref
                'delete',
                'not',
                '^Wex$',
                '^E2E$'
            ) -join '|'
            'Description' = 'Regex pattern for files and folders in C:\rs-pkgs that should not be deleted'
            'Scope' = 'Script'
            'Force' = $True
            'Option' = 'ReadOnly'
        }
        Set-Variable @VarParams
    }

    process {
        $LogicalDiskSplat = @{
            Class = 'Win32_LogicalDisk'
            Filter = "DeviceID = '$DriveLetter`:'"
        }
        $LogicalDisk = Get-WmiObject @LogicalDiskSplat

        $Wmi = (Get-WmiObject Win32_OperatingSystem).SystemDrive -replace '(?<=^\w).*'
        If ($Wmi -eq $DriveLetter) {
            $Drive.OSDrive = $true
        }
        else {
            $Drive.OSDrive = $false
        }

        $Drive.SizeGB = $LogicalDisk.Size | ConvertTo-Gigabytes
        $Drive.FreeSpaceGB = $LogicalDisk.FreeSpace | ConvertTo-Gigabytes
        $Drive.FreeSpacePercent = [Math]::Round(($LogicalDisk.FreeSpace * 100 / $LogicalDisk.Size), 2)
        $Output.Drive = $Drive

        $Roles = Get-ServerRole | Select-Object Cluster, IIS, Sql, Dfsr, ActiveDirectory
        $Output.Roles = $Roles

        $P1Folders1.RecycleBinGB = $RecycleBin | Get-FileSize | ConvertTo-Gigabytes
        $P1Folders1.InstallWimGB = $Sources | Get-FileSize | ConvertTo-Gigabytes
        $P1Folders1.SoftwareDistributionGB = $SoftwareDistribution | Get-FileSize | ConvertTo-Gigabytes
        $Output.P1Folders1 = $P1Folders1

        $P1Folders2.WerReportQueueGB = $WerReportQueue | Get-FileSize | ConvertTo-Gigabytes

        if (Test-Path $RsPkgs) {
            $P1Folders2.RsPkgsGB = $RsPkgs | Get-FileSize | ConvertTo-Gigabytes

            $Output.RsPkgsShouldNotDelete = Get-ChildItem $RsPkgs |
            Where-Object { $_.Name -match $Script:DISK_SPACE_SHOULD_NOT_DELETE_PATTERN } |
            ForEach-Object { New-Object psobject -Property @{
                    Name = $_.FullName
                    SizeGB = $_.FullName | Get-FileSize | ConvertTo-Gigabytes
                } } |
            Sort-Object SizeGB -Descending
        }
        else {
            $P1Folders2.RsPkgsGB = 0
        }

        # If there is no windows dir on this then skip all checks for files in the folder
        If (Test-Path $DumpFiles) {
            $P1Folders2.DumpfilesGB = $DumpFiles |
            Get-ChildItem -Filter 'Minidump*.dmp' |
            Where-Object { $_.LastWriteTime -lt [datetime]::Now.AddDays(-30) } |
            Select-Object -ExpandProperty FullName | Get-FileSize | ConvertTo-Gigabytes

            $CbsLogSize = $CbsLogs | Get-FileSize
            $TempFilesSize = $TempFiles | Get-ChildItem |
            Where-Object { $_.CreationTime -lt [datetime]::Now.AddDays(-30) } |
            Select-Object -ExpandProperty FullName | Get-FileSize
            $P1Folders2.CbsCabFilesGB = $CbsLogSize | ConvertTo-Gigabytes
            $P1Folders2.TempFilesGB = $TempFilesSize | ConvertTo-Gigabytes
        }
        else {
            $P1Folders2.DumpfilesGB = 0
            $P1Folders2.CbsCabFilesGB = 0
            $P1Folders2.TempFilesGB = 0
        }
        $Output.P1Folders2 = $P1Folders2

        if ($Drive.OSDrive) {
            $Output.P1CompressibleFolders = $Script:DISK_SPACE_COMPRESSIBLE_FOLDER_PATHS |
            Get-Item -Force -ErrorAction SilentlyContinue |
            ForEach-Object {
                $WmiDirectory = Get-WmiDirectory $_
                $WmiDirectory.Name = $_.FullName  # Fixes lower-case
                $WmiDirectory |
                Add-Member AliasProperty -Name IsCompressed -Value Compressed -PassThru |
                Add-Member NoteProperty -Name UncompressedSizeGB -Value (
                    $_.FullName | Get-FileSize | ConvertTo-Gigabytes
                ) -PassThru
            } |
            Sort-Object UncompressedSizeGB -Descending
        }

        return $Output
    }

    end {
        Write-Verbose "[$(Get-Date)] End   :: $($MyInvocation.MyCommand)"
    }
}

Function Compress-NtfsFolder {
    [CmdletBinding()]
    [OutputType([void])]
    Param(
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)][string]$Path
    )

    begin {
        # https://docs.microsoft.com/en-us/windows/desktop/cimwin32prov/compressex-method-in-class-win32-directory
        $CompressReturnLookup = @{
            0 = 'The request was successful.'
            2 = 'Access was denied.'
            8 = 'An unspecified failure occurred.'
            9 = 'The name specified was not valid.'
            10 = 'The object specified already exists.'
            11 = 'The file system is not an NTFS.'
            12 = 'The platform is not Windows.'
            13 = 'The drive is not the same.'
            14 = 'The directory is not empty.'
            15 = 'There has been a sharing violation.'
            16 = 'The start file specified was not valid.'
            17 = 'A privilege required for the operation is not held.'
            21 = 'A parameter specified is not valid.'
        }
    }

    process {
        $Path | Get-WmiDirectory -ErrorAction SilentlyContinue | ForEach-Object {

            # https://docs.microsoft.com/en-us/windows/desktop/cimwin32prov/win32-directory
            # CompressEx blocks until completed, has no effect if compression is already enabled.
            $StopFileName = ""     # out parameter
            $Recurse = $true
            $Retval = $_.CompressEx($StopFileName, $Recurse)

            $MsgKey = [int]$RetVal.ReturnValue
            $Message = "Compressing $($_.Name): $($CompressReturnLookup[$MsgKey])"

            if ($RetVal.ReturnValue -eq 15) {
                # Probably, file has a write lock; typical with IIS logs
                Write-Verbose $Message
            }
            elseif ($RetVal.ReturnValue -ne 0) {
                Write-Error $Message -ErrorAction SilentlyContinue
            }
        }
    }
}

Function Clear-DiskSpace {
    [CmdletBinding()]
    [OutputType([void])]
    Param(
        [Parameter(Mandatory = $true, Position = 0)][ValidatePattern('^[A-Za-z](:\\?)?$')][string]$DriveLetter,
        [Parameter(Position = 1)][switch]$SkipPriority1,
        [Parameter()][switch]$ClearP2AspNet,
        [Parameter()][switch]$ClearP2ShadowCopy,
        [Parameter()][int]$ResizeP2PageFileMaxGB,
        [Parameter()][int]$ResizeP2PageFileInitialGB,
        [Parameter()][ValidatePattern('^[A-Za-z](:\\?)?$')][string]$MoveP3PageFile,
        [Parameter()][switch]$ClearP3UsnJournal
    )

    begin {
        Write-Verbose "[$(Get-Date)] Begin :: $($MyInvocation.MyCommand)"
        Write-Verbose "[$(Get-Date)] List of Parameters :: $($PSBoundParameters.GetEnumerator() | Out-String)"

        # Normalize C, C: or C:\ into C
        # Lookahead matches ^\w, i.e. keeps first letter, then replaces everything else
        [string]$DriveLetter = $DriveLetter -replace '(?<=^\w).*'
        [string]$Mountpoint = "$DriveLetter`:"

        # Priority 1
        $RecycleBin = Join-Path $Mountpoint '$Recycle.Bin\'
        $RsPkgs = Join-Path $Mountpoint 'rs-pkgs\'
        $Sources = Join-Path $Mountpoint 'Windows\Sources\'
        $SoftwareDistribution = Join-Path $Mountpoint 'Windows\SoftwareDistribution\Download\'
        $CbsLogs = Join-Path $Mountpoint 'Windows\Logs\CBS\'
        $TempFiles = Join-Path $Mountpoint 'Windows\Temp\'
        $DumpFiles = Join-Path $Mountpoint 'Windows\'
        $WerReportQueue = Join-Path $Mountpoint 'ProgramData\Microsoft\Windows\WER\ReportQueue\'
    }

    process {
        $OSdrive = (Get-WmiObject Win32_OperatingSystem).SystemDrive

        $VarParams = @{
            'Name' = 'DISK_SPACE_COMPRESSIBLE_FOLDER_PATHS'
            'Value' = @(
                "$($OSdrive)\Windows\Installer",
                "$($OSdrive)\Windows\inf",
                "$($OSdrive)\Windows\ServiceProfiles\NetworkService\AppData\Local\Temp",
                "$($OSdrive)\ProgramData\Microsoft\Windows\WER\ReportQueue",
                "$($OSdrive)\inetpub\logs\LogFiles"
            )
            'Description' = 'Folders declared by the Standardization team to be OK for NTFS compression'
            'Scope' = 'Script'
            'Force' = $True
            'Option' = 'ReadOnly'
        }
        Set-Variable @VarParams

        $VarParams = @{
            'Name' = 'DISK_SPACE_SHOULD_NOT_DELETE_PATTERN'
            'Value' = (
                '^\d{6}-\d{5}$', # Match Core ticket ref
                'delete',
                'not',
                '^Wex$',
                '^E2E$'
            ) -join '|'
            'Description' = 'Regex pattern for files and folders in C:\rs-pkgs that should not be deleted'
            'Scope' = 'Script'
            'Force' = $True
            'Option' = 'ReadOnly'
        }
        Set-Variable @VarParams

        $FindSplat = @{
            Recurse = [switch]::Present
            Force = [switch]::Present
            ErrorAction = 'SilentlyContinue'
        }

        # Skip code if SkipPriority1 is $true
        If (-Not $SkipPriority1) {
            # Priority1 - actioned by default
            $RsPkgsToRemove = $RsPkgs |
            Get-ChildItem -ErrorAction 'SilentlyContinue' |
            Where-Object { $_.Name -notmatch $Script:DISK_SPACE_SHOULD_NOT_DELETE_PATTERN }

            if ($RsPkgsToRemove) {
                Remove-Item $RsPkgsToRemove.FullName @FindSplat
            }

            # temporarily stop 'TrustedInstaller' service - required for CBS and Temp folders
            $TrustedService = Get-Service 'TrustedInstaller'
            if ($TrustedService.Status -eq 'Running') {
                Stop-Service 'TrustedInstaller' -ErrorAction SilentlyContinue
                $RestartTrustedInstallerService = $true
            }

            @(
                (Get-ChildItem $RecycleBin @FindSplat),
                (Get-ChildItem $Sources @FindSplat),
                (Get-ChildItem $SoftwareDistribution @FindSplat),
                (Get-ChildItem $CbsLogs @FindSplat),
                (Get-ChildItem $TempFiles @FindSplat |
                    Where-Object { $_.CreationTime -lt [datetime]::Now.AddDays(-30) }),
                (Get-ChildItem $DumpFiles -Filter 'Minidump*.dmp' @FindSplat |
                    Where-Object { $_.LastWriteTime -lt [datetime]::Now.AddDays(-30) }),
                (Get-ChildItem $WerReportQueue @FindSplat)
            ) |
            ForEach-Object { $_ } | # unroll
            Remove-Item @FindSplat

            if ($RestartTrustedInstallerService) {
                Start-Service 'TrustedInstaller' -ErrorAction SilentlyContinue
            }

            if ($OSDrive -eq $DriveLetter) {
                $Script:DISK_SPACE_COMPRESSIBLE_FOLDER_PATHS | Compress-NtfsFolder
            }
        }

    }

    end {
        Write-Verbose "[$(Get-Date)] End   :: $($MyInvocation.MyCommand)"
    }
}

Function Get-DiskSpaceReportP2 {
    [CmdletBinding()]
    [OutputType([psobject])]
    Param(
        [Parameter(Mandatory = $true, Position = 0)][ValidatePattern('^[A-Za-z](:\\?)?$')][string]$DriveLetter
    )

    begin {
        Write-Verbose "[$(Get-Date)] Begin :: $($MyInvocation.MyCommand)"
        Write-Verbose "[$(Get-Date)] List of Parameters :: $($PSBoundParameters.GetEnumerator() | Out-String)"

        # Normalize C, C: or C:\ into C
        # Lookahead matches ^\w, i.e. keeps first letter, then replaces everything else
        [string]$DriveLetter = $DriveLetter -replace '(?<=^\w).*'
        [string]$Mountpoint = "$DriveLetter`:"

        # Priority 2
        $WinSxs = Join-Path $Mountpoint 'Windows\WinSxS\'

        $AspNetFolder = Join-Path $Mountpoint 'Windows\Microsoft.NET\'
        $AspNet = Join-Path $Mountpoint 'Windows\Microsoft.NET\Framework*\v*\Temporary ASP.NET Files\'
        $UserProfiles = Join-Path $Mountpoint 'Users\'

        # Folder paths for observations
        $Folders = New-Object -TypeName PSObject -Property @{
            WinSxSGB = $WinSxs
            UserProfilesGB = $UserProfiles
            AspNetGB = $AspNet
        }

        # Output
        $Output = New-Object -TypeName PSObject -Property @{
            Drive = $null
            Priority2 = $null
            Folders = $Folders
            LargeFiles = $null
        }

        $Drive = New-Object -TypeName PSObject -Property @{
            DriveLetter = $DriveLetter
            OSDrive = $null
            SizeGB = $null
            FreeSpaceGB = $null
            FreeSpacePercent = $null
        }

        $Priority2 = New-Object -TypeName PSObject -Property @{
            WinSxSGB = $null
            PageFileGB = $null
            UserProfilesGB = $null
            ShadowCopyGB = $null
            AspNetGB = $null
        }

        $OSdrive = (Get-WmiObject Win32_OperatingSystem).SystemDrive
        $OSdrive = $OSdrive -replace '(?<=^\w).*'
    }

    process {
        $LogicalDiskSplat = @{
            Class = 'Win32_LogicalDisk'
            Filter = "DeviceID = '$DriveLetter`:'"
        }
        $LogicalDisk = Get-WmiObject @LogicalDiskSplat

        $Wmi = (Get-WmiObject Win32_OperatingSystem).SystemDrive -replace '(?<=^\w).*'
        If ($Wmi -eq $DriveLetter) {
            $Drive.OSDrive = $true
        }
        else {
            $Drive.OSDrive = $false
        }

        $Drive.SizeGB = $LogicalDisk.Size | ConvertTo-Gigabytes
        $Drive.FreeSpaceGB = $LogicalDisk.FreeSpace | ConvertTo-Gigabytes
        $Drive.FreeSpacePercent = [Math]::Round(($LogicalDisk.FreeSpace * 100 / $LogicalDisk.Size), 2)
        $Output.Drive = $Drive

        # Top 5 large file
        $Top5 = Get-LargeFiles -DriveLetter $DriveLetter
        $Output.LargeFiles = $Top5

        # Priority 2
        $PageFile = Get-PageFile
        $PageFileSize = $PageFile |
        Where-Object { $_.Location -like "$DriveLetter*" } |
        Select-Object -ExpandProperty "MaxSizeGB" |
        Measure-Object -Sum |
        Select-Object -ExpandProperty Sum
        $Priority2.PageFileGB = $PageFileSize

        $Priority2.ShadowCopyGB = Get-ShadowCopy -DriveLetter $DriveLetter |
        Select-Object -ExpandProperty UsedGB

        $Priority2.WinSxSGB = $WinSxs | Get-FileSize | ConvertTo-Gigabytes
        $Priority2.UserProfilesGB = $UserProfiles | Get-FileSize | ConvertTo-Gigabytes

        # Converts a wildcard path into a list of directories
        If (Test-Path $AspNetFolder) {
            $AspNetFolders = $AspNet |
            Get-ChildItem -Recurse |
            Where-Object { $_.PSisContainer }
            $Priority2.AspNetGB = $AspNetFolders | Get-FileSize | ConvertTo-Gigabytes
        }
        Else {
            $Priority2.AspNetGB = 0
        }
        $Output.Priority2 = $Priority2

        return $Output
    }

    end {
        Write-Verbose "[$(Get-Date)] End   :: $($MyInvocation.MyCommand)"
    }
}

try {
    $Subtitle = ":"
    $BeforeDiskSpaceReport = Get-DiskSpaceReportP1 -DriveLetter $DriveLetter

    if ($PerformRemediation -and $BeforeDiskSpaceReport.Drive.OSDrive) {
        $Subtitle = " - Before Remediation:"
        # Delete and compress P1 folders
        Clear-DiskSpace -DriveLetter $DriveLetter
    }

    # Used to compare disk space totals and provide P2 folder and top file report
    $AfterDiskSpaceReport = Get-DiskSpaceReportP2 -DriveLetter $DriveLetter

    # Outputs
    $Output = $null
    $Output += "Disk Space Summary$Subtitle"
    $Output += $BeforeDiskSpaceReport.Drive | Select-Object DriveLetter, SizeGB, FreeSpaceGB, FreeSpacePercent, OSDrive | Sort-Object SizeGB -Descending | Format-Table -AutoSize | Out-String  -Width 1024
    $Output += "Top $ResultsLimit Largest Files$Subtitle"
    $Output += $AfterDiskSpaceReport.LargeFiles | Format-Table "Size (MB)", FullName -AutoSize | Out-String -Width 1024

    if ($BeforeDiskSpaceReport.Drive.OSDrive) {
        $Output += "`nRecommended Disk Cleanup Tasks (https://rax.io/lowdiskspace)`n`n"
        $Output += "P1.1 Summary$Subtitle"
        $Output += $BeforeDiskSpaceReport.P1Folders1 | Format-Table -AutoSize | Out-String -Width 1024
        $Output += "P1.2 Summary$Subtitle"
        $Output += $BeforeDiskSpaceReport.P1Folders2 | Format-Table -AutoSize | Out-String -Width 1024
        $Output += "P2 Summary$Subtitle"
        $Output += $AfterDiskSpaceReport.Priority2 | Format-Table -AutoSize | Out-String -Width 1024

        if ($PerformRemediation) {
            $Output += "`nDisk Space Summary - Post Remediation:"
            $Output += $AfterDiskSpaceReport.Drive | Select-Object SizeGB, FreeSpaceGB, FreeSpacePercent, OSDrive | Sort-Object SizeGB -Descending | Format-Table -AutoSize | Out-String  -Width 1024
            $Output += "`nThe P1.1 and P1.2 recommendations have been performed."
        }
        else {
            $Output += "`nRackspace recommends that the P1.1 and P1.2 actions be performed to recover disk space."
        }
        $Output += "`nIf additional disk space needs to be reclaimed, the P2 recommendations and Top $ResultsLimit files should be evaluated."
    }
    else {
        $Output += "`nIn the meantime, please feel free to review the 'Top $ResultsLimit largest Files' output and help us recover the necessary disk space."
    }
    $Output -split "`n" | ForEach-Object { $_.trimend() }
}
catch {
    Write-Output "Error encountered: Line# $($_.InvocationInfo.ScriptLineNumber) :: $($_.Exception.Message)"
    exit 1
}
