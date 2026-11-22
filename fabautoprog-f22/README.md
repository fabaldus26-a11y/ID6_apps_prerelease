# FabAutoProg F22 — adaptation ID6 v0.7.6

Patch de traduction française de BoostDeck pour inotbarnacle/ID6_apps_prerelease, préversion `installer-v0.7.6`, commit `21004504ec92fe6dfb7b76c4a80a60195cdaf757`. Le commit suivant `60704f8` réorganise la galerie, sans modifier les sources natives.

- `boostdeck-v076-fr.patch` traduit le XML, les légendes de télémétrie et les messages des réglages, en conservant la géométrie, les identifiants RHMI et les définitions de signaux. Le générateur reprend les légendes françaises de `boost_signals.def`. Générer les archives à partir du checkout v0.7.6 en suivant la documentation de build amont, puis appliquer ce patch au XML généré et aux sources avant la compilation native. Le patch est prévu pour le XML 1280 × 480 de la préversion.
- `apercu-f22.html` fonctionne hors ligne. Il présente une maquette du M Grip Meter et des libellés de clapet. Les valeurs de démonstration sont fictives. L’état du clapet y représente uniquement le choix du bouton.
- Aucun paquet QNX compilé. La télémétrie Grip Meter demande un collecteur en lecture seule et une validation des sources véhicule (accélération, freinage, lacet, dérive et patinage). Une valeur indisponible s’affiche par un tiret.
- Les cartographies FabAutoProg, ShiftDeck, xDrive Control, les commandes de clapets et refroidissement, BEAMer et le diagnostic véhicule ne sont pas inclus dans ce patch. Pour les défauts moteur, la procédure amont prévoit le véhicule à l’arrêt, contact mis et moteur coupé avant l’effacement confirmé.

Sur un checkout propre de la v0.7.6, vérifier le patch avec `git apply --check /chemin/boostdeck-v076-fr.patch`. La paire AppFramework/CoreFramework correspondant à V20153I figure dans la matrice amont. Vérifier aussi la résolution et la configuration de télémétrie de l’installation avant de remplacer BoostDeck. La compatibilité du binaire et des ressources doit encore être vérifiée sur NBT.
