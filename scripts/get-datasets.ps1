# Downloads Atomic Red Team Sysmon logs from Splunk's attack_data repository.
# The first six tell the intrusion story; the last three are backups in case some are missing.

$techniques = "T1059.001", "T1105", "T1547.001", "T1003.001", "T1136.001", "T1070.001",
              "T1053.005", "T1562.001", "T1003.002"
$target = "D:\soc-project\datasets"
$media  = "https://media.githubusercontent.com/media/splunk/attack_data/master/datasets/attack_techniques"

# The progress bar makes downloads much slower in Windows PowerShell
$ProgressPreference = "SilentlyContinue"

function Test-SysmonLog($path) {
    $head = (Get-Content $path -TotalCount 5) -join " "
    return $head -match "<Event"
}

foreach ($technique in $techniques) {
    $outFile = Join-Path $target "${technique}_windows-sysmon.log"

    if ((Test-Path $outFile) -and (Test-SysmonLog $outFile)) {
        Write-Host "${technique}: already downloaded, skipping"
        continue
    }

    $url = "$media/$technique/atomic_red_team/windows-sysmon.log"
    try {
        Invoke-WebRequest $url -OutFile $outFile -UseBasicParsing -ErrorAction Stop
    } catch {
        Write-Warning "${technique}: no Atomic Red Team Sysmon log ($($_.Exception.Message))"
        Remove-Item $outFile -ErrorAction SilentlyContinue
        continue
    }

    $sizeMB = [math]::Round((Get-Item $outFile).Length / 1MB, 1)
    if (Test-SysmonLog $outFile) {
        Write-Host "${technique}: saved ($sizeMB MB)"
    } else {
        $preview = (Get-Content $outFile -TotalCount 3) -join " "
        Write-Warning "${technique}: not Sysmon XML ($sizeMB MB). Starts with: $($preview.Substring(0, [math]::Min(120, $preview.Length)))"
    }
}

Write-Host "`nFiles in ${target}:"
Get-ChildItem $target -Filter "*_windows-sysmon.log" | Select-Object Name, @{n="MB"; e={[math]::Round($_.Length/1MB, 1)}}