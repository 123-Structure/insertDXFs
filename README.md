# 🔄 InsertDXFs - Script AutoLISP pour l'insertion automatique de DXF

## 📋 Description

InsertDXFs est un script AutoLISP avancé qui automatise l'insertion de fichiers DXF dans un plan AutoCAD contenant plusieurs cartouches. Le script offre une interface interactive permettant de sélectionner les points de positionnement, de définir l'espacement entre les cartouches, et d'insérer les fichiers DXF avec un centrage précis.

## 🛠️ Prérequis

- AutoCAD (version standard, pas LT)
- Fichiers DXF à insérer
- Un gabarit AutoCAD avec des cartouches vides

## 🚀 Installation

1. Téléchargez le fichier `InsertDXFs.lsp`
2. Placez-le dans un dossier accessible depuis AutoCAD
3. Chargez le script avec la commande `APPLOAD` dans AutoCAD
4. Sélectionnez le fichier `InsertDXFs.lsp` et cliquez sur "Charger"

## ⚙️ Fonctionnalités principales

- **Sélection interactive du dossier** : Interface de sélection de dossier via boîte de dialogue
- **Mémorisation du dernier dossier** : Le script se souvient du dernier dossier utilisé
- **Sélection des points de positionnement** : Définition interactive des points de départ, diagonal et d'espacement
- **Calcul automatique de l'espacement** : Basé sur les points sélectionnés par l'utilisateur
- **Facteur d'échelle personnalisable** : Possibilité de définir un facteur d'échelle pour l'insertion
- **Modes d'insertion flexibles** : Insertion de tous les fichiers DXF ou sélection manuelle
- **Centrage automatique** : Les DXF sont automatiquement centrés dans les cartouches

## 🎮 Utilisation

### Étape 1 : Lancement du script

1. Ouvrez votre gabarit AutoCAD contenant les cartouches vides
2. Exécutez la commande `InsertDXFs` dans la ligne de commande d'AutoCAD

### Étape 2 : Sélection du dossier

1. Sélectionnez un fichier DXF dans le dossier souhaité via la boîte de dialogue
2. Le script extraira automatiquement le chemin du dossier
3. Vous pouvez également utiliser le dernier dossier utilisé si proposé

### Étape 3 : Définition des points de positionnement

1. **Point de départ** : Sélectionnez le coin inférieur gauche du premier cartouche
2. **Point diagonal** : Sélectionnez le coin supérieur droit du premier cartouche
3. **Point d'espacement** : Sélectionnez un point pour définir l'espacement entre les cartouches

### Étape 4 : Configuration de l'insertion

1. **Facteur d'échelle** : Entrez le facteur d'échelle souhaité (par défaut : 20)
2. **Mode d'insertion** : Choisissez entre insérer tous les fichiers DXF ou faire une sélection manuelle
3. Si vous choisissez la sélection manuelle, sélectionnez les fichiers un par un

### Étape 5 : Insertion automatique

Le script insère automatiquement les fichiers DXF sélectionnés en les centrant dans les cartouches avec l'espacement défini.

## 📐 Fonctionnement technique

### Calcul des positions

1. **Centre du cartouche** : Calculé à partir des points de départ et diagonal
2. **Espacement horizontal** : Calcul de la distance entre le point de départ et le point d'espacement
3. **Position d'insertion** : Ajustée pour centrer chaque DXF dans son cartouche

### Analyse des dimensions

Le script insère temporairement chaque DXF pour déterminer ses dimensions réelles via :
1. Insertion temporaire hors écran
2. Explosion du bloc
3. Analyse de la boîte englobante
4. Calcul des dimensions réelles

## 🔧 Personnalisation

### Facteur d'échelle

Le facteur d'échelle par défaut est 20 (correspondant à une échelle de 1:20). Vous pouvez le modifier lors de l'exécution du script.

### Espacement

L'espacement entre les cartouches est calculé automatiquement à partir des points sélectionnés, mais vous pouvez utiliser la valeur par défaut (420) si aucun point d'espacement n'est spécifié.

## 🚨 Dépannage

- **Aucun fichier DXF trouvé** : Vérifiez que le dossier sélectionné contient des fichiers .dxf
- **Erreur lors de l'insertion** : Vérifiez que les fichiers DXF sont valides et compatibles avec AutoCAD
- **Dimensions incorrectes** : Si le script ne peut pas déterminer les dimensions d'un DXF, il utilisera les dimensions du cartouche
- **Espacement trop petit** : Si l'espacement calculé est inférieur à 10 unités, le script utilisera la valeur par défaut

## 📝 Historique des mises à jour

### Version 2025-07-01
- Ajout de la sélection de dossier via boîte de dialogue (getfiled)
- Gestion des espaces dans les chemins de fichiers
- Chargement automatique des bibliothèques Visual LISP
- Mémorisation du dernier dossier utilisé
- Option pour utiliser un dossier par défaut
- Amélioration de la robustesse avec vérifications d'erreurs
- Gestion des valeurs nil et des chaînes invalides
- Ajout d'un facteur d'échelle personnalisable
- Sélection interactive du point de départ pour l'insertion
- Calcul automatique de l'espacement horizontal
- Option pour insérer tous les fichiers DXF ou faire une sélection manuelle
- Centrage des DXF dans les cartouches
- Version initiale du script

---

📝 Créé par Baptiste LECHAT
