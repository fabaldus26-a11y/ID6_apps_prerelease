# XDrive Control — confirmations lisibles en français

Ce correctif est limité à l'interface RHMI de `XDriveControl.xml`. Les identifiants d'actions et leurs cibles sont conservés. Il répartit les préconditions sur trois libellés courts afin de limiter le tronquage horizontal constaté sur l'écran de confirmation.

## Conditions affichées

- Véhicule immobile
- Boîte en P et frein de stationnement serré
- Moteur tournant uniquement pour DSC_25 (0F1860)

Les textes XML sont volontairement en ASCII pour éviter les conversions de page de code observées dans la console PuTTY. Le texte affiché reste du français sans accents.

## Installation sur l'unité

Depuis Windows PowerShell 5.1, dans ce dossier, exécuter :

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\Install-XDriveControl-Readable-Fr.ps1
```

Le script vérifie le XML local, utilise l'empreinte SSH déjà validée, crée une sauvegarde distante horodatée, envoie le XML par l'entrée standard de Plink vers un nom temporaire, remplace le XML actif et vérifie deux libellés avant de confirmer. Il ne touche ni au worker `xdrive-control-qnx`, ni à `libXDriveControl.so`, ni aux commandes/actions du menu. Le mot de passe est demandé à l'exécution et le fichier temporaire local est supprimé à la fin.

Redémarrer l'iDrive à l'arrêt pour recharger le XML. La compatibilité des commandes xDrive et l'affichage réel sur le véhicule n'ont pas été validés par ce correctif d'interface. Ne pas utiliser une commande de mode tant que la variante DSC/LMV n'est pas explicitement prise en charge.
