$msiGuid = "{23170F69-40C1-2702-2409-000001000000}"

# Vérifier la présence du MSI dans le registre
$paths = @(
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\$msiGuid",
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\$msiGuid"
)

$msiFound = $false
foreach ($path in $paths) {
    if (Test-Path $path) {
        $msiFound = $true
        break
    }
}

if ($msiFound) {
    Write-Output "MSI trouvé"
    exit 0
} else {
    Write-Output "MSI non trouvé"
    exit 1
}