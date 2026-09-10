# Journal de bord — Mention

Application iOS personnelle de capture vocale : dictée, transcription, mise en forme et rangement de notes dans une arborescence. Un seul utilisateur, distribution par IPA non signé (Codemagic → Sideloadly, Apple ID gratuit, réinstallation tous les 7 jours).

## État du projet

**2026-09-10 — Passation.** Décision utilisateur : produire d'abord une vraie application **Windows** (.exe natif), iOS ensuite. Le développement quitte WSL ; le projet est repris par une IA travaillant directement sous Windows. Copie complète (dépôt + historique git + données réelles) déposée dans `C:\Users\edia-\Documents\Codex\Mention`. Instructions de reprise : `PROMPT-REPRISE.md` à la racine. Les données réelles (base chiffrée + clé, 5 notes, schéma v3) sont dans `donnees-wsl/` (hors git) — à restaurer dans le répertoire de données de l'app Windows au premier lancement.

**2026-08-30 — Cadrage validé par l'utilisateur.** Arborescence par défaut à revoir plus tard avec lui.

**Appareil cible** : iPhone 16, iOS 26.2.

**2026-08-30 — Lot 0, partie locale terminée.**
- Flutter 3.47.2 stable installé dans `~/development/flutter` (PATH ajouté au `.bashrc`), prérequis Linux desktop installés (clang, cmake, ninja, GTK). `flutter doctor` : seul Android manque, hors périmètre.
- Projet créé : bundle `com.ediar.mention`, plateformes iOS + Linux. Structure `lib/src/{domain,ui}`, interface `DictationEngine` + `FakeDictationEngine` (substitut Linux), écran d'accueil câblé sur le moteur simulé.
- Vérifié : `flutter test` (3 tests OK), `flutter analyze` (0 problème), `flutter build linux --release` (OK).
- `codemagic.yaml` écrit : workflow `ios-unsigned`, build sans signature, empaquetage `mention-unsigned.ipa` en artefact, déclenchement manuel.

**Reste pour clore le lot 0** (nécessite les comptes de l'utilisateur) :
1. ~~Créer un dépôt GitHub privé et pousser~~ — fait le 2026-08-30 (github.com/EdiaIsR/Mention, auth via gh).
2. Codemagic connecté ; build lancé, résultat non confirmé.
3. Sideloadly bloqué : le pilote « Apple Mobile Device USB Driver » ne s'accroche pas à l'iPhone (l'Explorateur le voit, iTunes non). Pistes données : redémarrage, devmgmt.msc → forcer le pilote depuis `C:\Program Files\Common Files\Apple\Mobile Device Support\Drivers`. **En attente — à reprendre à la prochaine livraison iPhone.**

**2026-09-09 — Réorientation validée : développement PC d'abord.** L'app est utilisée sur ce PC via la cible Linux + WSLg (fenêtre native sur le bureau Windows 11, vérifié). Même code pour l'iPhone plus tard ; pas de build Windows natif (hors périmètre). La dictée reste simulée sur PC ; la saisie clavier a été ajoutée au lot 1 pour un usage réel.

**2026-09-09 — Lot 1 livré (version PC).**
- Persistance : Drift + **SQLCipher via les hooks Dart de `sqlite3` v3** (`pubspec.yaml → hooks.user_defines.sqlite3.source: sqlcipher`). Les paquets `sqlite3_flutter_libs`/`sqlcipher_flutter_libs` sont morts (fin de vie) — ne pas les réintroduire. Chiffrement au repos prouvé par test et vérifié sur le fichier réel (`file` → « data »).
- Clé : `FileKeyStore` (fichier local, dev PC). Keychain iOS à faire à la livraison iPhone.
- Schéma v1 : table `notes` (id, rawText, folderId?, createdAt, updatedAt). `rawText` immuable.
- UI : liste (flux réactif Drift), page de dictée (enregistrement auto à la fin de session, y compris interruption — jamais de perte), saisie clavier, détail lecture seule.
- Vérifié : 11 tests OK, analyze 0 problème, build linux OK, app lancée et base chiffrée créée.

**2026-09-09 — Lot 2 livré (version PC).**
- Schéma v2 : table `folders` (id, name, parentId?, position). Migration v1→v2 testée sur base v1 fabriquée en SQL brut **et** exécutée avec succès sur la base réelle de l'utilisateur (note préservée, dossiers créés, user_version=2).
- Dossiers par défaut : Tâches, Listes, Idées, Pensées (ids fixes `f-*`). La « Boîte de réception » du cadrage est virtuelle : les notes non classées vivent à la racine.
- Suppression d'un dossier = **destruction du sous-arbre entier** (choix utilisateur du 2026-09-09, remplace la remontée au parent initialement livrée). La confirmation annonce le décompte exact (notes, sous-dossiers) avant d'agir.
- UI : navigation par dossier (un écran par dossier, la racine mêle dossiers et notes non classées), menus ⋮ (renommer/supprimer un dossier, déplacer/supprimer une note), création de note dans le dossier courant (dictée comme clavier), édition du texte d'une note (seule opération autorisée à modifier rawText, avec l'utilisateur aux commandes), recherche plein texte (LIKE, insensible casse ASCII — pas aux accents ; FTS possible plus tard si besoin).
- Vérifié : 23 tests OK, analyze 0 problème, build linux OK, migration réelle OK.

**2026-09-10 — Socle du lot 3 livré (fournisseur LLM simulé).** En attente des dictées réelles de l'utilisateur pour le comparatif des fournisseurs gratuits.
- Schéma v3 : `notes` + `refinedText`, `summaryText`, `pendingOp` (migration v2→v3 testée + exécutée sur la base réelle : v3, 5 notes intactes).
- `LlmProvider` (reformulate/summarize) avec contrat d'erreurs : `LlmUnavailableException` → mise en attente + reprise auto (`retryPending` au lancement) ; `LlmBadOutputException` → une seule relance puis abandon propre. `FakeLlmProvider` pour PC/tests.
- `EnrichmentService` : validation stricte de sortie, jamais d'exception vers l'UI (enum `EnrichmentOutcome`), rawText jamais modifié par le LLM.
- UI : menu « Reformuler »/« Synthétiser » sur une note, versions affichées sous le brut (cartes), état « en attente » visible, snackbars sobres.
- Vérifié : 32 tests OK, analyze 0, build linux OK, migration réelle OK.
- Reste pour clore le lot 3 : corpus de dictées réelles → comparatif Gemini/Mistral/Groq et équivalents (qualité FR, quotas, latence) → implémentation du fournisseur retenu (clé API dans le Keychain iOS / fichier local PC) → recommandation argumentée.

**2026-09-10 — Exigence produit : la reformulation n'omet jamais une information dictée** (dates, noms, quantités, détails). Elle nettoie la forme sans condenser — condenser est le rôle exclusif de la synthèse. Critère éliminatoire du comparatif de fournisseurs ; à vérifier sur chaque échantillon du corpus.

**2026-09-10 — Idée utilisateur à l'étude : commandes vocales** (créer/renommer dossier, mode sombre…) déclenchées par un mot-clé distinct en début de dictée. Avis rendu : faisable, recommandé après le lot 4 (le classement automatique fournira la machinerie intention→action structurée + validation). Décision d'engagement en attente.

### Pièges de test appris (ne pas re-découvrir)
- `tester.pump()` sans durée n'avance pas l'horloge simulée → les timers Drift à durée nulle ne se déclenchent pas. Toujours démonter l'app en fin de test de widget (`pumpWidget(SizedBox)` + `pump(1ms)`).
- Ne jamais appeler `watchAll().first` (flux Drift) dans un `testWidgets` : l'annulation en plein `addStream` bloque `db.close()` → suite entière suspendue. Utiliser `getAll()`.
- Après un `Navigator.push`, attendre la fin de la transition (~300 ms) **plus une frame** avant de taper un bouton de la nouvelle page (IgnorePointer de transition).
- Jamais de `Future.delayed` (même à durée nulle) dans un chemin attendu directement par un test de widget sans pompage : sous FakeAsync le timer ne se déclenche jamais → suspension. Garder les substituts purs microtâches quand le délai est nul.

## Cadrage proposé le 2026-08-30

### Modèle de données

- **Folder** : `id`, `name`, `parentId` (nullable → racine), `position`. Profondeur libre.
- **Note** : `id`, `folderId`, `rawText` (transcription brute, immuable), `refinedText` (nullable — reformulation demandée), `summaryText` (nullable — synthèse demandée), `type` (`task | list | idea | thought | none`), `dueDate` (nullable), `createdAt`, `updatedAt`, `pendingEnrichment` (enrichissement LLM en attente réseau/quota).
- **ChecklistItem** : `id`, `noteId`, `label`, `checked`, `position` — pour les notes de type liste.

Principe : `rawText` n'est jamais modifié ni supprimé par une opération LLM. Les versions enrichies s'ajoutent à côté.

### Arborescence par défaut

```
Boîte de réception   ← toute note non classée atterrit ici
Tâches
Listes
Idées                ← sous-dossiers par sujet, créés au fil de l'eau
Pensées
```

### Lots

- **Lot 0 — Socle** : Flutter installé et vérifié, projet créé, architecture en couches, dépendances natives derrière des interfaces avec substituts (l'app tourne en cible Linux desktop pour itérer sans iPhone), un test qui passe, pipeline Codemagic produisant un IPA non signé installé avec succès via Sideloadly.
- **Lot 1 — Dicter et retrouver** : dictée avec transcription temps réel (framework Speech via plugin ou MethodChannel Swift), enregistrement automatique de la note brute, liste des notes, consultation.
- **Lot 2 — Arborescence** : créer/renommer/déplacer/supprimer dossiers et notes, recherche plein texte.
- **Lot 3 — Reformulation et synthèse** à la demande, brut toujours conservé. Comparatif préalable des fournisseurs LLM gratuits sur dictées réelles.
- **Lot 4 — Classement automatique** proposé, validé ou corrigé en un geste.
- **Lot 5 — Typage et vues** : échéances, cases à cocher.
- **Lot 6 — Sauvegarde/export/restauration** à travers les réinstallations. (Filet dès le lot 1 : installation Sideloadly en mode mise à jour qui conserve les données + export manuel rudimentaire.)
- **Lot 7 — Confort** : rapidité d'ouverture, geste de dictée immédiat, finitions.

### Critères d'acceptation du lot 1

1. Ouvrir l'app, lancer la dictée en un geste, voir la transcription apparaître en temps réel, en français, hors connexion.
2. Arrêter la dictée : la note brute est enregistrée sans action supplémentaire et apparaît dans la liste (date + premières lignes).
3. Ouvrir une note et lire son texte intégral.
4. Interruption (appel entrant, limite de session Speech) : le texte déjà transcrit est sauvegardé, rien ne s'évapore.
5. Les données survivent à une réinstallation en mode mise à jour via Sideloadly.
6. Sur WSL : `flutter test` et `flutter analyze` passent ; l'app tourne en cible Linux avec un moteur de dictée simulé.

### Décisions techniques

| Sujet | Choix | Raison |
|---|---|---|
| Base locale | Drift + SQLCipher (chiffrement au repos) | migrations de schéma outillées, requêtes testables sans device |
| État | à trancher au lot 0 (Riverpod pressenti) | — |
| Voix | plugin `speech_to_text` si à jour, sinon MethodChannel Swift maison | à vérifier au lot 1 |
| LLM | interface `LlmProvider`, fournisseur choisi au lot 3 sur dictées réelles | paliers gratuits uniquement |

## Problèmes ouverts

- Modèle d'iPhone et version iOS : à demander (fait le 2026-08-30, réponse attendue).
- Palier gratuit Codemagic : 500 min/mois macOS — budget à surveiller, livraisons groupées.

## À vérifier sur appareil

(rien pour l'instant — aucun IPA livré)
