# Journal de bord — Mention

Application iOS personnelle de capture vocale : dictée, transcription, mise en forme et rangement de notes dans une arborescence. Un seul utilisateur, distribution par IPA non signé (Codemagic → Sideloadly, Apple ID gratuit, réinstallation tous les 7 jours).

## État du projet

**2026-08-30 — Cadrage validé par l'utilisateur.** Arborescence par défaut à revoir plus tard avec lui.

**Appareil cible** : iPhone 16, iOS 26.2.

**2026-08-30 — Lot 0, partie locale terminée.**
- Flutter 3.47.2 stable installé dans `~/development/flutter` (PATH ajouté au `.bashrc`), prérequis Linux desktop installés (clang, cmake, ninja, GTK). `flutter doctor` : seul Android manque, hors périmètre.
- Projet créé : bundle `com.ediar.mention`, plateformes iOS + Linux. Structure `lib/src/{domain,ui}`, interface `DictationEngine` + `FakeDictationEngine` (substitut Linux), écran d'accueil câblé sur le moteur simulé.
- Vérifié : `flutter test` (3 tests OK), `flutter analyze` (0 problème), `flutter build linux --release` (OK).
- `codemagic.yaml` écrit : workflow `ios-unsigned`, build sans signature, empaquetage `mention-unsigned.ipa` en artefact, déclenchement manuel.

**Reste pour clore le lot 0** (nécessite les comptes de l'utilisateur) :
1. Créer un dépôt GitHub privé et pousser (`git remote add` + `git push`).
2. Connecter le dépôt à un compte Codemagic (gratuit) et lancer le workflow `ios-unsigned`.
3. Télécharger l'IPA, le signer avec Sideloadly, l'installer sur l'iPhone 16 et vérifier que l'app se lance et que la dictée simulée s'affiche.

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
