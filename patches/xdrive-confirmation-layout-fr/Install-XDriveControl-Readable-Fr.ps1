[CmdletBinding()]
param(
    [string]$NbtIp = '169.254.199.119',
    [string]$HostKey = 'SHA256:ccBSjAKu0zGcw8z2GuJpODkfbHkHFg+6hJRdU9HjB2Q'
)

$ErrorActionPreference = 'Stop'
$remoteFile = '/var/opt/hmi/data/ID5/Plugins/XDriveControl/XDriveControl.xml'
$plink = 'C:\Program Files\PuTTY\plink.exe'
$pscp = 'C:\Program Files\PuTTY\pscp.exe'
$xmlFile = Join-Path $PSScriptRoot 'XDriveControl.xml'
$runId = [Guid]::NewGuid().ToString('N')
$remoteStage = "/var/opt/hmi/data/ID5/Plugins/XDriveControl/.XDriveControl.xml.$runId.stage"
$remoteBackup = "$remoteFile.fap-backup-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
$passwordFile = Join-Path $env:TEMP "fap-xdrive-$runId.secret"
$uploaded = $false
$backupCreated = $false

if (-not (Test-Path -LiteralPath $plink -PathType Leaf)) { throw "PuTTY plink introuvable : $plink" }
if (-not (Test-Path -LiteralPath $pscp -PathType Leaf)) { throw "PuTTY pscp introuvable : $pscp" }
if (-not (Test-Path -LiteralPath $xmlFile -PathType Leaf)) { throw "XML manquant : $xmlFile" }

try {
    [xml]$xml = Get-Content -LiteralPath $xmlFile -Raw -Encoding UTF8
    $actions = @($xml.pluginApps.pluginApp.actions.raAction | ForEach-Object { $_.id }) -join ','
    if ($actions -ne '21,22,23') { throw 'Le XML ne contient pas les trois actions attendues; abandon avant connexion.' }
    $stateTexts = @($xml.pluginApps.pluginApp.hmiStates.hmiState | Where-Object { $_.id -in '101','102' } | ForEach-Object { $_.components.label.text })
    if (-not ($stateTexts -contains 'Vehicule immobile') -or -not ($stateTexts -contains 'Boite en P; frein de parking serre')) {
        throw 'Les libelles de confirmation attendus sont absents; abandon avant connexion.'
    }

    $secure = Read-Host 'Mot de passe SSH root du NBT' -AsSecureString
    $ptr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
    try {
        $plain = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr)
        [System.IO.File]::WriteAllText($passwordFile, $plain + "`n", [System.Text.Encoding]::ASCII)
    } finally {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr)
        $plain = $null
    }

    $sshPrefix = @('-batch','-T','-ssh','-2','-P','22','-l','root','-hostkey',$HostKey,'-noagent','-a','-x','-pwfile',$passwordFile,$NbtIp)
    & $plink @sshPrefix "test -s '$remoteFile'"
    if ($LASTEXITCODE -ne 0) { throw "Connexion ou XML actif indisponible sur $NbtIp; aucune modification effectuée." }

    & $plink @sshPrefix "cp -p '$remoteFile' '$remoteBackup'"
    if ($LASTEXITCODE -ne 0) { throw 'Sauvegarde distante impossible; aucune modification effectuée.' }
    $backupCreated = $true

    & $pscp -batch -scp -P 22 -l root -hostkey $HostKey -pwfile $passwordFile $xmlFile "${NbtIp}:$remoteStage"
    if ($LASTEXITCODE -ne 0) { throw 'Transfert du XML temporaire échoué. La sauvegarde distante est conservée.' }
    $uploaded = $true

    & $plink @sshPrefix "test -s '$remoteStage' && mv '$remoteStage' '$remoteFile' && grep -q 'DSC_25 (0F1860): moteur tournant' '$remoteFile' && grep -q 'Boite en P; frein de parking serre' '$remoteFile'"
    if ($LASTEXITCODE -ne 0) {
        if ($uploaded) { & $plink @sshPrefix "mv '$remoteBackup' '$remoteFile'" | Out-Null }
        throw 'Vérification après copie échouée. Restauration de la sauvegarde demandée.'
    }

    Write-Host "XML remplacé et vérifié. Sauvegarde distante : $remoteBackup"
    Write-Host 'Redémarre iDrive à l’arrêt pour recharger le menu. Les actions xDrive n’ont pas été modifiées.'
    Write-Host 'Cette correction de présentation ne valide pas la compatibilité du DSC ni les commandes de transmission.'
} finally {
    if (Test-Path -LiteralPath $passwordFile) { Remove-Item -LiteralPath $passwordFile -Force -ErrorAction SilentlyContinue }
}
