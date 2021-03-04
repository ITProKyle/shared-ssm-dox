$LASTEXITCODE = 0
try {
    $region = (Invoke-RestMethod http://169.254.169.254/latest/dynamic/instance-identity/document).region
    if (Get-Service | Where-Object {$_.name -eq "codedeployagent"}) {
        $Status = "CodeDeploy agent already installed."
        if ( (Get-Service codedeployagent).status -ne 'Running' ) {
            $Status = "CodeDeploy agent not running.  Restarting."
            Restart-Service codedeployagent
        }
    }
    else {
        $cd_uri = "https://aws-codedeploy-$region.s3.amazonaws.com/latest/codedeploy-agent.msi"
        $cd_file = "$($env:TEMP)\codedeploy-agent.msi"
        $cd_log = "$($env:TEMP)\host-agent-install.log"

        $cdu_uri = "https://aws-codedeploy-us-east-1.s3.amazonaws.com/latest/codedeploy-agent-updater.msi"
        $cdu_file = "$($env:TEMP)\codedeploy-agent-updater.msi"
        $cdu_log = "$($env:TEMP)\host-agent-updater.log"

        Invoke-WebRequest -Uri $cd_uri -OutFile $cd_file
        Start-Process -FilePath $cd_file -ArgumentList "/quiet /l $cd_log" -Wait

        Invoke-WebRequest -Uri $cdu_uri -OutFile $cdu_file
        Start-Process -FilePath $cdu_file -ArgumentList "/quiet /l $cdu_log" -Wait
        $status = "CodeDeploy Agent installed successfully"
    }
}
catch {
    $Status = "Error encountered: $($_.Exception.Message)"
    $LASTEXITCODE = 1
}
finally {
    Write-Output "Status:    $Status"
    Write-Output "Exit Code: $LASTEXITCODE"
    exit $LASTEXITCODE
}
