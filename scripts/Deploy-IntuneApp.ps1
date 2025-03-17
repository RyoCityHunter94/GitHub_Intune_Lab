param (
    [Parameter(Mandatory = $true)]
    [string]$TenantId,
    
    [Parameter(Mandatory = $true)]
    [string]$ClientId,
    
    [Parameter(Mandatory = $true)]
    [string]$ClientSecret,
    
    [Parameter(Mandatory = $false)]
    [string]$Version = "24.08"
)

# Configuration pour 7-Zip
$ApplicationName = "7-Zip"
$WorkFolder = Join-Path -Path $env:TEMP -ChildPath "7ZipDeploy"
$DownloadFolder = Join-Path -Path $WorkFolder -ChildPath "Source"
$OutputFolder = Join-Path -Path $WorkFolder -ChildPath "Output"

# Créer les dossiers nécessaires
if (-not (Test-Path -Path $WorkFolder)) {
    New-Item -Path $WorkFolder -ItemType Directory -Force | Out-Null
}
if (-not (Test-Path -Path $DownloadFolder)) {
    New-Item -Path $DownloadFolder -ItemType Directory -Force | Out-Null
}
if (-not (Test-Path -Path $OutputFolder)) {
    New-Item -Path $OutputFolder -ItemType Directory -Force | Out-Null
}

Write-Output "Téléchargement de 7-Zip version $Version"

# Télécharger 7-Zip x64
$7ZipURL = "https://www.7-zip.org/a/7z$($Version.Replace('.',''))-x64.exe"
$7ZipInstaller = Join-Path -Path $DownloadFolder -ChildPath "7z-x64.exe"
Invoke-WebRequest -Uri $7ZipURL -OutFile $7ZipInstaller -UseBasicParsing

# Créer les scripts d'installation et de détection
$InstallScriptContent = @'
@echo off
REM Installation silencieuse de 7-Zip
%~dp07z-x64.exe /S
exit /b 0
'@

$DetectionScriptContent = @'
# Détection de l'installation de 7-Zip
$7zPath = "${env:ProgramFiles}\7-Zip\7zFM.exe"

if (Test-Path -Path $7zPath) {
    Write-Output "7-Zip est installé"
    exit 0
} else {
    Write-Output "7-Zip n'est pas installé"
    exit 1
}
'@

$UninstallScriptContent = @'
@echo off
REM Désinstallation silencieuse de 7-Zip
"%ProgramFiles%\7-Zip\Uninstall.exe" /S
exit /b 0
'@

# Écrire les scripts dans le dossier source
$InstallScriptPath = Join-Path -Path $DownloadFolder -ChildPath "install.cmd"
$DetectionScriptPath = Join-Path -Path $DownloadFolder -ChildPath "detection.ps1"
$UninstallScriptPath = Join-Path -Path $DownloadFolder -ChildPath "uninstall.cmd"

Set-Content -Path $InstallScriptPath -Value $InstallScriptContent
Set-Content -Path $DetectionScriptPath -Value $DetectionScriptContent
Set-Content -Path $UninstallScriptPath -Value $UninstallScriptContent

# Connexion à Microsoft Graph
Write-Output "Connexion à Microsoft Graph..."
$SecureClientSecret = ConvertTo-SecureString -String $ClientSecret -AsPlainText -Force
$ClientSecretCredential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $ClientId, $SecureClientSecret

# Installation des modules nécessaires si non présents
if (-not (Get-Module -ListAvailable -Name Microsoft.Graph)) {
    Write-Output "Installation du module Microsoft.Graph..."
    Install-Module -Name Microsoft.Graph -Scope CurrentUser -Force
}
if (-not (Get-Module -ListAvailable -Name IntuneWin32App)) {
    Write-Output "Installation du module IntuneWin32App..."
    Install-Module -Name IntuneWin32App -Scope CurrentUser -Force
}

Import-Module Microsoft.Graph
Import-Module IntuneWin32App

# Connexion à Microsoft Graph
Connect-MgGraph -TenantId $TenantId -ClientSecretCredential $ClientSecretCredential -NoWelcome

# Télécharger l'outil de packaging Microsoft Win32 Content Prep Tool
$Win32ContentPrepToolURL = "https://github.com/microsoft/Microsoft-Win32-Content-Prep-Tool/raw/master/IntuneWinAppUtil.exe"
$Win32ContentPrepToolPath = Join-Path -Path $WorkFolder -ChildPath "IntuneWinAppUtil.exe"
Invoke-WebRequest -Uri $Win32ContentPrepToolURL -OutFile $Win32ContentPrepToolPath

# Créer le fichier .intunewin
$IntuneWinFile = Join-Path -Path $OutputFolder -ChildPath "7-Zip.intunewin"
Write-Output "Création du package .intunewin..."

& $Win32ContentPrepToolPath -c $DownloadFolder -s "7z-x64.exe" -o $OutputFolder -q

# Définir les paramètres de l'application
Write-Output "Configuration des paramètres de déploiement..."
$Win32AppParameters = @{
    FilePath                = $IntuneWinFile
    DisplayName             = "7-Zip"
    Description             = "7-Zip version $Version - Déployé automatiquement via GitHub Actions"
    Publisher               = "Igor Pavlov"
    InstallExperience       = "system"
    RestartBehavior         = "suppress"
    DetectionRule           = New-IntuneWin32AppDetectionRuleScript -ScriptFile $DetectionScriptPath -EnforceSignatureCheck $false -RunAs32Bit $false
    InstallCommandLine      = "cmd.exe /c install.cmd"
    UninstallCommandLine    = "cmd.exe /c uninstall.cmd"
    RequirementRule         = New-IntuneWin32AppRequirementRule -Architecture "x64" -MinimumSupportedOperatingSystem "1909"
}

# Publier l'application dans Intune
Write-Output "Publication de l'application dans Intune..."
$IntuneApp = Add-IntuneWin32App @Win32AppParameters

# Créer une assignation pour tous les appareils (facultatif, décommentez pour activer)
# Write-Output "Assignation de l'application à tous les appareils..."
# $AllDevicesGroup = Get-MgGroup -Filter "displayName eq 'All Devices'"
# if ($AllDevicesGroup) {
#     Add-IntuneWin32AppAssignmentGroup -ID $IntuneApp.id -GroupID $AllDevicesGroup.id -Intent "required"
#     Write-Output "Application assignée au groupe 'All Devices'"
# }

Write-Output "7-Zip version $Version déployé avec succès dans Intune!"
Disconnect-MgGraph