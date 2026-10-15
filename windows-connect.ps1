# Optional helper for Windows PowerShell
# Run: .\windows-connect.ps1
$ErrorActionPreference = "Stop"

Write-Host "Android Termux Media Server - Windows connection helper" -ForegroundColor Cyan
$hostName = Read-Host "Enter Android phone's Tailscale IP or MagicDNS hostname"
$termuxUser = Read-Host "Enter Termux username (often u0_aXXX)"

Write-Host "`nTesting service ports on $hostName ..." -ForegroundColor Cyan
foreach ($port in @(8022, 8096, 8080)) {
    $result = Test-NetConnection -ComputerName $hostName -Port $port -WarningAction SilentlyContinue
    $state = if ($result.TcpTestSucceeded) { "OPEN" } else { "NOT REACHABLE" }
    Write-Host ("Port {0}: {1}" -f $port, $state)
}

Write-Host "`nURLs and SSH command:" -ForegroundColor Cyan
Write-Host ("Jellyfin:     http://{0}:8096" -f $hostName)
Write-Host ("File Browser: http://{0}:8080" -f $hostName)
Write-Host ("SSH:          ssh -p 8022 {0}@{1}" -f $termuxUser, $hostName)

$answer = Read-Host "`nStart SSH session now? (y/N)"
if ($answer -match '^(y|yes)$') {
    ssh -p 8022 "$termuxUser@$hostName"
}
