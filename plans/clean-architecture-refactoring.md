# Plan: Clean Architecture Refactoring

## Objectif

Refactorer l'application AOwl pour une Clean Architecture plus stricte en:
1. Déplaçant les providers partagés hors des features vers un layer `application/`
2. Éliminant les dépendances circulaires entre layers
3. Appliquant la règle de dépendance (les couches internes ne connaissent pas les couches externes)

---

## Problèmes Identifiés

### 1. Violations de la règle de dépendance

| Fichier | Problème |
|---------|----------|
| `core/services/cleanup_service.dart` | Importe depuis `features/exchange/domain/` |
| `features/unlock/providers/crypto_provider.dart` | Provider partagé dans une feature spécifique |
| `features/unlock/providers/storage_provider.dart` | Provider partagé dans une feature spécifique |

### 2. Providers mal placés

Les providers suivants sont dans `features/unlock/providers/` mais utilisés par toute l'application:
- `cryptoServiceProvider` - utilisé par exchange, unlock, setup
- `secureStorageProvider` - utilisé par plusieurs features
- `vaultRepositoryProvider` - utilisé par exchange, cleanup

### 3. Dépendances cross-features

- `exchange/presentation/` importe depuis `unlock/providers/`
- `core/` importe depuis `features/`

---

## Architecture Cible

```
lib/
├── application/                    # NOUVEAU - Layer application
│   ├── providers/                  # Providers partagés
│   │   ├── crypto_provider.dart
│   │   ├── storage_provider.dart
│   │   ├── vault_provider.dart
│   │   └── cleanup_provider.dart
│   └── services/                   # Services applicatifs
│       └── cleanup_service.dart    # Déplacé depuis core/
│
├── core/                           # Infrastructure pure (pas de features)
│   ├── crypto/                     # Logique crypto
│   ├── github/                     # Client GitHub
│   └── storage/                    # Stockage local
│
├── domain/                         # NOUVEAU - Domain partagé
│   └── models/                     # Modèles partagés entre features
│       └── vault_entry.dart        # Déplacé depuis exchange/domain
│
├── features/
│   ├── exchange/
│   │   ├── domain/                 # Modèles spécifiques à exchange
│   │   │   └── retention_period.dart
│   │   ├── presentation/
│   │   │   ├── exchange_screen.dart
│   │   │   └── widgets/
│   │   └── providers/              # Providers UI spécifiques
│   │       └── exchange_notifier.dart
│   │
│   ├── unlock/
│   │   ├── presentation/
│   │   └── providers/              # Providers UI spécifiques
│   │
│   └── setup/
│       ├── presentation/
│       └── providers/
│
└── shared/
    ├── theme/
    └── widgets/
```

---

## Étapes de Migration

### Phase 1: Créer le layer application/

1. **Créer `lib/application/providers/`**
2. **Déplacer les providers partagés:**
   - `features/unlock/providers/crypto_provider.dart` → `application/providers/crypto_provider.dart`
   - `features/unlock/providers/storage_provider.dart` → `application/providers/storage_provider.dart`
   - `features/unlock/providers/vault_provider.dart` → `application/providers/vault_provider.dart`

3. **Déplacer cleanup_service:**
   - `core/services/cleanup_service.dart` → `application/services/cleanup_service.dart`

### Phase 2: Créer le domain partagé

1. **Créer `lib/domain/models/`**
2. **Déplacer VaultEntry:**
   - `features/exchange/domain/vault_entry.dart` → `domain/models/vault_entry.dart`
3. **Garder RetentionPeriod dans exchange** (spécifique à cette feature)

### Phase 3: Mettre à jour les imports

1. **Mettre à jour tous les fichiers qui importent les providers déplacés**
2. **Mettre à jour les imports de VaultEntry**
3. **Vérifier qu'aucun import ne viole la règle de dépendance:**
   - `core/` ne doit pas importer depuis `features/` ou `application/`
   - `domain/` ne doit pas importer depuis `features/`, `application/`, ou `core/`
   - `features/` peut importer depuis `domain/`, `application/`, et `core/`

### Phase 4: Nettoyer

1. **Supprimer les fichiers vides/obsolètes**
2. **Ajouter des barrel files si nécessaire:**
   - `application/providers/providers.dart`
   - `domain/models/models.dart`

---

## Fichiers à Modifier

### Providers à déplacer

| Source | Destination |
|--------|-------------|
| `lib/features/unlock/providers/crypto_provider.dart` | `lib/application/providers/crypto_provider.dart` |
| `lib/features/unlock/providers/storage_provider.dart` | `lib/application/providers/storage_provider.dart` |
| `lib/features/unlock/providers/vault_provider.dart` | `lib/application/providers/vault_provider.dart` |

### Services à déplacer

| Source | Destination |
|--------|-------------|
| `lib/core/services/cleanup_service.dart` | `lib/application/services/cleanup_service.dart` |

### Modèles à déplacer

| Source | Destination |
|--------|-------------|
| `lib/features/exchange/domain/vault_entry.dart` | `lib/domain/models/vault_entry.dart` |

### Fichiers avec imports à mettre à jour (~15 fichiers)

- `lib/features/exchange/presentation/exchange_screen.dart`
- `lib/features/exchange/presentation/widgets/new_share_card.dart`
- `lib/features/exchange/presentation/widgets/vault_list.dart`
- `lib/features/exchange/presentation/widgets/vault_entry_details.dart`
- `lib/features/exchange/providers/exchange_notifier.dart`
- `lib/features/unlock/presentation/unlock_screen.dart`
- `lib/features/setup/presentation/setup_screen.dart`
- `lib/core/github/vault_repository.dart`
- Tests associés

---

## Règles de Dépendance

```
┌─────────────────────────────────────────────┐
│                  features/                   │
│     (UI, presentation, feature-specific)     │
└──────────────────┬──────────────────────────┘
                   │ peut importer
                   ▼
┌─────────────────────────────────────────────┐
│               application/                   │
│        (providers partagés, services)        │
└──────────────────┬──────────────────────────┘
                   │ peut importer
                   ▼
┌─────────────────────────────────────────────┐
│            domain/ + core/                   │
│    (modèles purs, infrastructure pure)       │
└─────────────────────────────────────────────┘
```

**Règles:**
- `domain/` = modèles Dart purs, aucune dépendance externe
- `core/` = infrastructure (crypto, HTTP, storage), pas de business logic
- `application/` = orchestration, peut utiliser domain/ et core/
- `features/` = UI et logique spécifique, peut tout utiliser sauf d'autres features

---

## Validation

Après refactoring, vérifier:

```bash
# 1. Aucune erreur de compilation
flutter analyze

# 2. Tests passent
flutter test

# 3. Vérifier les imports (grep)
# core/ ne doit pas importer features/ ou application/
grep -r "import.*features/" lib/core/
grep -r "import.*application/" lib/core/

# domain/ ne doit pas importer features/, application/, ou core/
grep -r "import.*features/" lib/domain/
grep -r "import.*application/" lib/domain/
grep -r "import.*core/" lib/domain/
```

---

## Estimation

- **Complexité:** Moyenne
- **Risque:** Faible (refactoring structurel, pas de changement de logique)
- **Impact:** Améliore maintenabilité et testabilité

---

## Notes

- La migration peut se faire progressivement feature par feature
- Garder les tests fonctionnels à chaque étape
- Les barrel files (`providers.dart`, `models.dart`) facilitent les imports
