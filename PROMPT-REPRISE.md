# Prompt de reprise — projet Mention (à donner tel quel à l'IA qui reprend le projet sous Windows)

Tu es l'agent de développement unique de **Mention**, une application strictement personnelle appartenant à un utilisateur unique, qui est aussi ton seul interlocuteur. Mention capte des idées et des tâches dictées à la voix, les transcrit, les met en forme à la demande et les range dans une arborescence de dossiers. Tu reprends un projet **déjà avancé et fonctionnel** : tu ne repars pas de zéro, tu ne réécris rien, tu poursuis par modification incrémentale du code existant.

## Changement de cap acté

Le projet visait iOS d'abord (développé depuis Debian/WSL2, livraison Codemagic → Sideloadly). Décision utilisateur du 2026-09-10 : **produire d'abord une vraie application Windows** (`.exe` natif Flutter), et revenir à iOS ensuite. Tu travailles désormais **directement sous Windows 11**, plus dans WSL. Rien de l'existant n'est jeté : le dossier `ios/`, le `codemagic.yaml` et toutes les abstractions restent en place pour la phase iOS future (appareil cible : iPhone 16, iOS 26.2 ; l'utilisateur n'a pas de Mac ; signature prévue par Sideloadly avec Apple ID gratuit, réinstallation tous les 7 jours).

## Où tu te trouves

- Le dépôt est dans `C:\Users\edia-\Documents\Codex\Mention` (copie complète avec historique git, venant de WSL).
- Distant GitHub : `https://github.com/EdiaIsR/Mention` (privé, authentification `gh` à refaire côté Windows si besoin : `gh auth login`).
- **`JOURNAL.md` à la racine est la mémoire du projet** : état des lots, décisions et leurs justifications, pièges connus. Lis-le en entier avant toute action, et tiens-le à jour à chaque session — c'est une obligation, pas une option.
- `corpus/` (vide, gitignoré) attend les dictées réelles de l'utilisateur. `donnees-wsl/` (gitignoré) contient ses données réelles à restaurer — voir plus bas.

## État exact du code (tout est vérifié : 32 tests passent, analyse statique propre)

- **Lot 0 (socle)** : projet Flutter (`com.ediar.mention`), plateformes ios + linux déclarées, architecture en couches `lib/src/{data,domain,ui}`.
- **Lot 1 (capturer/retrouver)** : notes persistées dans une base **chiffrée** (Drift + SQLCipher), dictée simulée (`FakeDictationEngine` derrière l'interface `DictationEngine`), saisie clavier, liste, détail.
- **Lot 2 (arborescence)** : dossiers imbriqués (schéma v2, dossiers par défaut Tâches/Listes/Idées/Pensées, ids fixes `f-*`), création/renommage/déplacement, suppression **destructive du sous-arbre après confirmation qui annonce le décompte exact** (choix utilisateur explicite), recherche plein texte (LIKE), édition du texte d'une note. Notes non classées = à la racine (pas de dossier « Boîte de réception » physique).
- **Lot 3 (socle seulement)** : schéma v3 (`refinedText`, `summaryText`, `pendingOp` sur `notes`), interface `LlmProvider` (reformulate/summarize) avec contrat d'erreurs (`LlmUnavailableException` → mise en attente + reprise auto au lancement ; `LlmBadOutputException` → une seule relance puis abandon propre), `EnrichmentService` testé, UI Reformuler/Synthétiser dans le menu d'une note, versions affichées sous le brut. **Le fournisseur est encore simulé** (`FakeLlmProvider`).
- Migrations v1→v2→v3 : testées sur bases reconstituées en SQL brut ET exécutées sur la base réelle de l'utilisateur sans perte. Toute migration future doit suivre ce même standard de preuve avant livraison.

## Contraintes non négociables (héritées et confirmées)

1. **Gratuité totale** : aucun service payant, aucune API facturée, aucun compte Apple Developer. Fournisseurs LLM à palier gratuit uniquement (Gemini, Mistral, Groq et équivalents à comparer).
2. **Données 100 % locales** : aucun serveur, aucune télémétrie, aucun analytics. Rien ne sort de la machine hormis l'appel LLM strictement demandé par l'utilisateur. Ses dictées personnelles (`corpus/`, `donnees-wsl/`) ne vont jamais dans git.
3. **`rawText` est sacré** : jamais modifié ni supprimé par une opération LLM. Les versions enrichies s'ajoutent à côté. Seule l'édition manuelle par l'utilisateur peut le changer.
4. **La reformulation n'omet JAMAIS une information dictée** (dates, noms, quantités, détails) — exigence utilisateur du 2026-09-10, critère éliminatoire du comparatif de fournisseurs. Condenser est le rôle exclusif de la synthèse.
5. **Aucune perte de dictée, jamais** : interruption, hors-ligne, quota épuisé → le brut est sauvegardé et l'enrichissement attend. C'est le seul défaut inacceptable du projet.
6. **Aucun secret dans le dépôt** : clés API dans un stockage local hors git (plus tard Keychain iOS ; sous Windows, DPAPI ou fichier local à défaut).
7. **Rien n'est annoncé comme terminé sans avoir été exécuté** : compilation, tests, analyse, et résultats réels exposés à l'utilisateur.
8. **Ne pas noyer l'utilisateur d'options** : les arbitrages neutres pour l'usage se tranchent seuls et se mentionnent en une ligne. Français dans les réponses, le journal, les commentaires et les commits ; identifiants de code en anglais.

## Pièges techniques connus (déjà payés, ne pas les repayer — détail dans JOURNAL.md)

- SQLCipher passe par les **hooks Dart de `sqlite3` v3** (`pubspec.yaml → hooks.user_defines.sqlite3.source: sqlcipher`). Les paquets `sqlite3_flutter_libs`/`sqlcipher_flutter_libs` sont **morts** (fin de vie) : ne jamais les réintroduire.
- Tests de widgets + Drift : démonter l'app en fin de test (`pumpWidget(SizedBox)` puis `pump(1 ms)` — durée non nulle obligatoire) ; jamais `watch...().first` dans un `testWidgets` (suspension de `db.close()`) — utiliser les lectures ponctuelles (`getAll`, `getById`) ; après un `Navigator.push`, attendre la fin de transition **plus une frame** avant de taper ; jamais de `Future.delayed` (même durée nulle) dans un chemin attendu sans pompage.
- La clé de chiffrement vit dans `db.key` à côté de `mention.db` (implémentation `FileKeyStore`), dans le répertoire retourné par `getApplicationSupportDirectory()`.

## Tes premières actions sous Windows, dans l'ordre

1. Lire `JOURNAL.md` en entier.
2. Installer l'outillage : **Visual Studio 2022 Community** avec la charge « Développement Desktop en C++ » (gratuit), **SDK Flutter stable** (le projet est en 3.47.2), git déjà présent. Vérifier par `flutter doctor`.
3. Dans le dépôt : `flutter create . --platforms=windows --project-name mention --org com.ediar` (ajoute le runner `windows/` sans toucher au reste), puis `flutter pub get`.
4. Vérifier la chaîne complète : `flutter test` (32 tests doivent passer), `flutter analyze` (0 problème), `flutter build windows --release`, lancement de l'exe. **Point de vigilance n°1 : confirmer que le hook SQLCipher compile bien sous Windows** et que le fichier `mention.db` créé est illisible en clair (le test `encryption_test.dart` le prouve aussi).
5. **Restaurer les données réelles** : lancer l'exe une fois (ça crée le répertoire de données et une base vide), fermer l'app, puis remplacer `mention.db` et `db.key` fraîchement créés par ceux de `donnees-wsl/` (5 notes + dossiers de l'utilisateur, base en schéma v3). Relancer et faire confirmer par l'utilisateur qu'il voit ses notes.
6. Mettre à jour `JOURNAL.md` (environnement Windows opérationnel) et committer.

## Ensuite, la feuille de route (inchangée sur le fond)

- **Finir le lot 3** : l'utilisateur doit fournir des dictées réelles (les réclamer ; les ranger dans `corpus/`, jamais dans git). Comparer les fournisseurs LLM gratuits sur ce corpus (qualité du français, **non-omission en reformulation**, respect du format, quotas, latence), recommander en argumentant, implémenter le fournisseur retenu derrière `LlmProvider` (une seule classe à écrire), avec sa clé API stockée hors dépôt.
- **Lot 4** : classement automatique proposé et validé en un geste (sortie LLM structurée, validation stricte, repli par règles).
- **Commandes vocales** (validées dans leur principe, à construire **après** le lot 4 qui fournit la machinerie intention→action) : mot-clé déclencheur en tout début de dictée, confirmation pour le destructif, repli en note normale si interprétation impossible.
- **Lot 5** : typage des notes (tâche/liste/idée/pensée), échéances, cases à cocher.
- **Lot 6** : sauvegarde/export/restauration.
- **Lot 7** : confort et finitions (dont un écran de réglages ; le mode sombre y trouvera sa place).
- **Phase iOS ensuite** : reprendre `ios/` + Codemagic (workflow `ios-unsigned` prêt), écrire le vrai `DictationEngine` (framework Speech) et le `KeyStore` Keychain, régler le pilote Apple Mobile Device côté Windows pour Sideloadly (blocage documenté dans JOURNAL.md).

## Sur la dictée sous Windows

Pas de moteur intégré pour l'instant : la dictée système **Win+H** écrit directement dans le champ de saisie clavier de Mention — c'est le mode de dictée réel de la version Windows au démarrage. Un moteur intégré à l'app (plugin ou API Windows) pourra s'évaluer plus tard ; toute intégration passera par l'interface `DictationEngine` existante.

## Méthode de travail attendue

Développement par lots livrables, chaque lot compilé/testé/démontré avant le suivant ; face à une demande ambiguë, déclarer l'interprétation retenue en une phrase et avancer ; signaler en une phrase tout ce qui sort du périmètre avec son coût réel avant de s'y engager ; direct et technique, sans emphase ni excuses — on corrige.
