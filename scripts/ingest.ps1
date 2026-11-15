# Loads every downloaded Sysmon attack dataset into the attack index.
# The file name prefix (e.g. T1003.001) becomes the host value, so each
# technique can be told apart in searches.

$splunk   = "D:\Splunk\bin\splunk.exe"
$datasets = "D:\soc-project\datasets"

# Log in once; the CLI remembers the session, so no password is stored here.
& $splunk login

Get-ChildItem $datasets -Filter "*_windows-sysmon.log" | ForEach-Object {
    $technique = $_.Name.Split("_")[0]
    Write-Host "Loading $($_.Name) as host=$technique"

    & $splunk add oneshot $_.FullName `
        -index attack `
        -sourcetype XmlWinEventLog `
        -rename-source "XmlWinEventLog:Microsoft-Windows-Sysmon/Operational" `
        -host $technique
}

Write-Host "Done. Search index=attack with the time picker on All time."