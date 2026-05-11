# Mirror GitHub → Azure DevOps

Ce dépôt est synchronisé automatiquement vers un dépôt Azure Repos via un workflow GitHub Actions (`.github/workflows/mirror-to-azure-devops.yml`).

## Comportement

- À chaque `push` sur n'importe quelle branche → push mirror vers Azure DevOps.
- À chaque tag poussé → push mirror vers Azure DevOps.
- À chaque suppression de branche/tag sur GitHub → propagation côté Azure DevOps (comportement natif de `git push --mirror`).
- Déclenchement manuel possible via l'onglet **Actions** → *Mirror to Azure DevOps* → *Run workflow*.

GitHub reste la **source de vérité**. Ne pousse jamais directement sur Azure DevOps : tout commit y serait écrasé au prochain mirror.

## Configuration initiale (à faire une seule fois)

### 1. Créer le dépôt Azure DevOps de destination

Dans ton projet Azure DevOps → **Repos** → **+ New repository** → laisse-le **vide** (ne coche ni README, ni .gitignore).

Note son URL HTTPS, du type :
```
https://dev.azure.com/<organisation>/<projet>/_git/<repo>
```

### 2. Générer un PAT Azure DevOps

1. Va sur https://dev.azure.com/<organisation>/_usersSettings/tokens
2. **+ New Token**
3. Nom : `github-mirror`
4. Organisation : celle qui contient le repo cible
5. Expiration : 1 an max (à renouveler ensuite)
6. Scopes → **Custom defined** → coche **Code** → **Read, write, & manage**
7. Crée et **copie la valeur** (elle ne sera plus jamais affichée).

### 3. Ajouter les secrets dans GitHub

Dans ton repo GitHub → **Settings** → **Secrets and variables** → **Actions** → **New repository secret**, crée deux secrets :

| Nom | Valeur |
|---|---|
| `AZURE_DEVOPS_PAT` | Le PAT généré à l'étape 2 |
| `AZURE_DEVOPS_REPO_URL` | L'URL HTTPS du repo Azure DevOps (étape 1) |

### 4. Premier run

- Déclenche manuellement le workflow (**Actions** → *Mirror to Azure DevOps* → *Run workflow*), ou pousse n'importe quel commit.
- Vérifie côté Azure DevOps que toutes les branches et tags sont apparus.

## Renouvellement du PAT

Le PAT Azure DevOps a une expiration. Quand il approche de sa fin de vie :
1. Génère un nouveau PAT (étape 2).
2. Mets à jour la valeur du secret `AZURE_DEVOPS_PAT` dans GitHub.

## Dépannage

- **403 / authentication failed** → PAT expiré, mal copié, ou scopes insuffisants. Régénère-le avec le scope `Code: Read, write, & manage`.
- **`! [remote rejected] refs/pull/...`** → normal et ignoré dans une majorité de cas ; les refs `refs/pull/*` de GitHub ne sont pas reproductibles sur Azure DevOps. Le workflow ne synchronise que `refs/heads/*` et `refs/tags/*`.
- **Le workflow ne se déclenche pas** → vérifie qu'Actions est activé dans **Settings** → **Actions** → **General**, et que la branche pushée n'est pas exclue.
