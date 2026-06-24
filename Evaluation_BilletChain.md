# Évaluation finale — BilletChain (journée complète)

---

## Consignes générales

- Vous êtes **libres de toute l'architecture** : c'est aussi ce qui est évalué. Faites des
  choix, et soyez prêts à les justifier.
- Le sujet décrit **le comportement attendu**, pas comment l'obtenir. À vous de traduire ces
  exigences métier en Solidity sûr, lisible et économe.
- Rendez un code qui **compile**.

---

## 1. Le contexte métier

Une salle de concert veut vendre et gérer ses billets **directement sur la blockchain**,
sans intermédiaire. Vous êtes la personne chargée d'écrire le ou les smart contracts.

Le système doit répondre à **quatre besoins** exprimés par le client :

1. **Des billets uniques et infalsifiables.** Chaque billet vendu est un objet **unique**
   (place identifiée), qui appartient à son acheteur et peut changer de mains. Deux billets
   ne sont jamais interchangeables.

2. **Un prix affiché en euros, payé en cryptomonnaie.** Le client raisonne en euros (« le
   billet est à 50 € »), mais les spectateurs paient en monnaie native de la chaîne. Le
   contrat doit donc connaître le **taux de change** au moment de chaque achat et faire payer
   le **montant juste**, sans dépendre d'une valeur figée en dur dans le code.

3. **Une revente entre particuliers, mais encadrée.** Un détenteur peut revendre son billet à
   quelqu'un d'autre. Pour lutter contre la spéculation, la revente est **plafonnée** : on ne
   peut jamais revendre un billet à plus de **110 % de son prix d'achat initial**.

4. **Aucune perte d'argent, aucune faille.** L'organisateur et les revendeurs doivent pouvoir
   **récupérer** ce qui leur revient de façon fiable. Le système ne doit jamais permettre à un
   acheteur de payer moins que le prix, ni à un attaquant de détourner des fonds.

C'est tout ce que dit le client. Le reste — les structures, les fonctions, les protections,
les cas d'erreur — c'est **à vous de le concevoir**.

---

## 2. Exigences fonctionnelles détaillées (le « quoi », pas le « comment »)

### 2.1 Vente initiale
- N'importe qui peut **acheter un billet neuf** tant qu'il en reste (le nombre total de
  billets de l'événement est fixé à la création du système).
- Le **prix à payer** est déterminé à partir d'un prix nominal en euros **et** d'un taux de
  change euro → monnaie native obtenu **dynamiquement** (le contrat ne peut pas, par nature,
  appeler une API : réfléchissez à comment une donnée du monde réel entre dans un contrat).
- L'acheteur doit payer **le montant exact** : ni plus, ni moins. Tout écart doit être rejeté.
- À l'achat, l'acheteur devient **propriétaire** de son billet, et le **prix d'achat initial**
  de ce billet doit être mémorisé (il servira au plafond de revente).
- Quand l'événement est **complet**, toute nouvelle tentative d'achat doit être rejetée.

### 2.2 Revente (marché secondaire)
- Le **propriétaire** d'un billet, et lui seul, peut le **mettre en vente** à un prix de son
  choix.
- Ce prix ne peut **jamais** dépasser **110 %** du prix d'achat initial du billet. Une mise en
  vente au-dessus de ce plafond doit être rejetée.
- Pour qu'une revente puisse aboutir, le système doit pouvoir **transférer** le billet du
  vendeur vers l'acheteur le moment venu. Réfléchissez à ce que cela implique côté
  **autorisation** (un standard de tokens uniques impose un mécanisme précis pour qu'un tiers
  déplace un bien : c'est à vous de l'employer correctement).
- Un **acheteur** peut alors acquérir un billet mis en vente, en payant **le montant exact**
  demandé. Le billet lui est transféré, et le **vendeur** est crédité de la somme.
- Acheter un billet **non mis en vente** doit être rejeté.

### 2.3 Encaissement
- L'organisateur (ventes initiales) et les revendeurs (ventes secondaires) ne reçoivent
  **pas** l'argent automatiquement au moment de la vente : ils doivent pouvoir le
  **retirer** eux-mêmes, de façon sûre. (Souvenez-vous du pattern vu en formation pour
  manipuler de l'argent sans risque.)
- Une tentative de retrait alors qu'on n'a rien à percevoir doit être rejetée.

### 2.4 Consultation
- Le système doit offrir un moyen de **savoir, pour une liste de billets donnée, combien sont
  actuellement en vente**. Cette fonction de lecture sera regardée sous l'angle du **coût en
  gas** : on attend une implémentation **économe**.

### 2.5 Qualité attendue (transversale, notée)
- **Sécurité** : le contrat doit être robuste face aux vulnérabilités étudiées en formation
  (réentrance, contrôle d'accès, données externes non fiables/périmées, paiements). À vous
  d'identifier lesquelles s'appliquent et de vous en protéger.
- **Lisibilité** : nommage clair, erreurs explicites, événements pertinents pour suivre la vie
  des billets.
- **Gas** : éviter les écritures inutiles, surtout dans les boucles.

---

## 3. Tests (vous concevez votre propre suite) — *évalué*

Vous devez écrire **vos propres tests automatisés** (Foundry) qui démontrent que votre
contrat respecte les exigences ci-dessus. On attend **au minimum** un test par règle métier
importante, **y compris les cas d'échec** (paiement incorrect, dépassement du plafond, achat
quand c'est complet, retrait sans solde, donnée externe invalide ou périmée…).

> Le taux de change réel n'étant pas disponible en test local, vous devrez trouver le moyen de
> **simuler** cette donnée externe dans vos tests (réfléchissez à comment isoler une dépendance
> externe pour la rendre testable). La qualité de cette approche fait partie de la note.

---

## 4. Partie théorique (à rendre par écrit)

Répondez de façon argumentée (quelques lignes chacune). Ces questions couvrent J1 → journée
avancée.

- **Q1 — Fondamentaux.** Pourquoi l'exécution d'un smart contract est-elle **déterministe et
  répliquée** sur tous les nœuds ? En quoi cela explique-t-il qu'un contrat ne puisse pas, par
  lui-même, connaître une donnée du monde réel (taux de change, météo, hasard) ?
- **Q2 — Cryptographie.** Lorsqu'un spectateur achète un billet, sa transaction est signée.
  Expliquez brièvement le rôle de la **signature** et de la **clé privée**, et comment le
  réseau vérifie qui est l'émetteur **sans connaître** la clé privée.
- **Q3 — Tokens.** Pourquoi le billet de ce sujet relève-t-il d'un standard de tokens
  **uniques** plutôt que d'un standard de tokens **interchangeables** ? Donnez un cas d'usage
  où le second serait pertinent à la place.
- **Q4 — Sécurité.** Citez **deux** vulnérabilités étudiées en formation qui menacent ce
  système, et expliquez **précisément** comment votre code s'en protège.
- **Q5 — Gas.** Donnez deux décisions concrètes que vous avez prises dans votre code pour
  réduire le coût en gas, et expliquez pourquoi elles fonctionnent.

---

## 5. Bonus (points au-delà de la note de base)

Au choix, si vous avez terminé l'essentiel :
- **Frais de plateforme** : prélever un pourcentage de chaque revente au profit de
  l'organisateur, en plus du vendeur.
- **Remboursement du trop-perçu** : tolérer un paiement supérieur au prix et rendre la
  différence proprement.
- **Mise en pause d'urgence** : pouvoir geler les ventes en cas d'incident.
- **Test de propriété (fuzzing)** : prouver par fuzzing qu'aucune mise en vente ne peut jamais
  dépasser le plafond, quelle que soit l'entrée.

---

## 6. Livrables et déploiement

À rendre en fin de journée :
1. Le(s) fichier(s) **`.sol`** de votre solution (qui compile).
2. Votre **suite de tests** Foundry.
3. Vos **réponses théoriques** (Q1 → Q5).
4. Une **note de déploiement** d'une demi-page : sur quel réseau de test vous le déploieriez,
   quelles valeurs vous passeriez à la création, et **où vous récupéreriez l'adresse de la
   source de taux de change** sur ce réseau.

