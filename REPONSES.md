# Réponses théoriques

## Q1

Un smart contract tourne de la même façon sur tous les nœuds parce que l'EVM est déterministe : à partir des mêmes données d'entrée (transaction, état du contrat), tout le monde arrive au même résultat. C'est ce qui permet au réseau de se mettre d'accord.

Du coup un contrat ne peut pas appeler une API tout seul parce que chaque nœud obtiendrait une valeur différente selon le moment où il exécute le code, ce qui casserait le consensus. Pour avoir une donnée externe comme un taux de change, on passe par un oracle (Chainlink dans notre cas) qui publie la donnée directement sur la blockchain via une transaction, comme ça elle est disponible pour tous les nœuds de la même façon.

## Q2

Quand on envoie une transaction, elle est signée avec la clé privée via ECDSA. La signature prouve qu'on est bien le propriétaire de l'adresse sans avoir à révéler la clé.

Pour vérifier, le réseau recalcule la clé publique à partir de la signature et du hash de la transaction, puis en déduit l'adresse Ethereum. Si ça correspond à l'adresse émettrice, c'est bon. La clé privée ne transite jamais sur le réseau.

## Q3

Un billet de concert c'est unique : il correspond à une place précise, une date, etc. Deux billets ne sont pas interchangeables, d'où le choix d'un ERC-721 où chaque token a son propre ID.

Un ERC-20 serait pertinent pour des tokens fongibles comme une monnaie ou des crédits de plateforme, où une unité en vaut une autre. Par exemple si on voulait créer un token "crédit concert" utilisable dans plusieurs salles, on utiliserait un ERC-20.

## Q4

**Réentrance** : dans `withdraw`, on remet le solde à 0 avant d'envoyer l'argent avec `.call`. Si un contrat malveillant essayait de rappeler `withdraw` dans sa fonction `receive`, son solde serait déjà à 0 donc ça ne ferait rien.

**Oracle périmé** : dans `ticketPriceInWei` on vérifie que la donnée de Chainlink date de moins d'une heure (`updatedAt`), et que le prix est positif. Ça évite qu'un attaquant profite d'un oracle planté qui retournerait un vieux taux avantageux.

## Q5

**calldata dans countListed** : en déclarant le tableau en `calldata` plutôt qu'en `memory`, on évite de le copier en mémoire lors de l'appel, ce qui économise du gas sur des grands tableaux.

**unchecked sur le i++** : dans la boucle de `countListed`, le `++i` est dans un bloc `unchecked`. Solidity 0.8 vérifie par défaut les débordements mais ici c'est inutile vu qu'on ne peut pas dépasser la longueur du tableau. Ça enlève des vérifications inutiles à chaque tour de boucle.

---

## Note de déploiement

Je déploierais sur **Sepolia** qui est le testnet Ethereum principal et qui a les feeds Chainlink disponibles.

Pour le constructeur :
- `_totalTickets` : 500
- `_priceEUR` : 50
- `_priceFeed` : adresse du feed ETH/EUR sur Sepolia, disponible sur docs.chain.link dans la section Price Feeds > Ethereum Sepolia

Pour l'adresse du feed on va sur docs.chain.link, on cherche ETH/EUR sur Sepolia et on copie l'adresse du proxy. Si ce feed n'existe pas sur Sepolia on pourrait utiliser ETH/USD et adapter le calcul dans `ticketPriceInWei`.
