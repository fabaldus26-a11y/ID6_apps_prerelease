[CmdletBinding()]
param(
    [string]$NbtIp = '169.254.199.119',
    [string]$HostKey = 'SHA256:ccBSjAKu0zGcw8z2GuJpODkfbHkHFg+6hJRdU9HjB2Q'
)

$ErrorActionPreference = 'Stop'
$remoteFile = '/var/opt/hmi/data/ID5/Plugins/XDriveControl/XDriveControl.xml'
$plink = 'C:\Program Files\PuTTY\plink.exe'
$xmlFile = Join-Path $PSScriptRoot 'XDriveControl.xml'
$runId = [Guid]::NewGuid().ToString('N')
$remoteStage = "/var/opt/hmi/data/ID5/Plugins/XDriveControl/.XDriveControl.xml.$runId.stage"
$remoteBackup = "$remoteFile.fap-backup-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
$passwordFile = Join-Path $env:TEMP "fap-xdrive-$runId.secret"
$uploaded = $false
$backupCreated = $false

if (-not (Test-Path -LiteralPath $plink -PathType Leaf)) { throw "PuTTY plink introuvable : $plink" }
if (-not (Test-Path -LiteralPath $xmlFile -PathType Leaf)) { throw "XML manquant : $xmlFile" }

function Quote-WindowsArgument([string]$Value) {
    '"' + $Value.Replace('"', '\"') + '"'
}

function Invoke-Plink([string]$RemoteCommand, [byte[]]$InputBytes = $null) {
    $arguments = @('-batch','-T','-ssh','-2','-P','22','-l','root','-hostkey',$HostKey,'-noagent','-a','-x','-pwfile',$passwordFile,$NbtIp,$RemoteCommand)
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $plink
    $psi.Arguments = (($arguments | ForEach-Object { Quote-WindowsArgument ([string]$_) }) -join ' ')
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    if ($null -ne $InputBytes) { $psi.RedirectStandardInput = $true }
    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $psi
    if (-not $process.Start()) { throw 'Impossible de démarrer PuTTY Plink.' }
    if ($null -ne $InputBytes) {
        $process.StandardInput.BaseStream.Write($InputBytes, 0, $InputBytes.Length)
        $process.StandardInput.BaseStream.Flush()
        $process.StandardInput.Close()
    }
    $stdout = $process.StandardOutput.ReadToEnd()
    $stderr = $process.StandardError.ReadToEnd()
    $process.WaitForExit()
    if ($stdout) { Write-Host $stdout.TrimEnd() }
    if ($process.ExitCode -ne 0) { throw "Plink a échoué ($($process.ExitCode)): $stderr" }
}

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

    Invoke-Plink "test -s '$remoteFile'"

    Invoke-Plink "cp -p '$remoteFile' '$remoteBackup'"
    $backupCreated = $true

    $xmlBytes = [System.IO.File]::ReadAllBytes($xmlFile)
    Invoke-Plink "cat > '$remoteStage'" $xmlBytes
    $uploaded = $true

    try {
        Invoke-Plink "test -s '$remoteStage' && mv '$remoteStage' '$remoteFile' && grep -q 'DSC_25 (0F1860): moteur tournant' '$remoteFile' && grep -q 'Boite en P; frein de parking serre' '$remoteFile'"
    } catch {
        if ($uploaded) { try { Invoke-Plink "mv '$remoteBackup' '$remoteFile'" } catch { Write-Warning "Restauration automatique échouée. Sauvegarde disponible ici : $remoteBackup" } }
        throw 'Vérification après copie échouée. Restauration de la sauvegarde demandée.'
    }

    Write-Host "XML remplacé et vérifié. Sauvegarde distante : $remoteBackup"
    Write-Host 'Redémarre iDrive à l’arrêt pour recharger le menu. Les actions xDrive n’ont pas été modifiées.'
    Write-Host 'Cette correction de présentation ne valide pas la compatibilité du DSC ni les commandes de transmission.'
} finally {
    if (Test-Path -LiteralPath $passwordFile) { Remove-Item -LiteralPath $passwordFile -Force -ErrorAction SilentlyContinue }
}
