$InstallIfDomainMember = '{{WindowsConfigureIfDomainMember}}'
$AWSTimeServer = '169.254.169.123'
$reg = Get-ItemProperty -Path HKLM:\SYSTEM\CurrentControlSet\Services\W32Time\Parameters
$NTPServer = $reg.NtpServer
if ((!$env:USERDNSDOMAIN) -or ($InstallIfDomainMember -eq 'True' )) {
    if ($NTPServer -ne $AWSTimeServer) {
        net stop w32time
        w32tm /config /syncfromflags:manual /manualpeerlist:"169.254.169.123"
        w32tm /config /reliable:yes
        net start w32time
        Start-Sleep 20
        w32tm /query /status
    }
}
else {
    Write-Output 'Instance not configured due to domain membership.'
}
