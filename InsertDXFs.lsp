;; ===================================================================
;; SCRIPT : InsertDXFs.lsp
;; DESCRIPTION : Insertion de fichiers DXF sélectionnés dans un gabarit
;; AUTEUR : Baptiste LECHAT (généré par IA)
;; DATE : 2023
;; MISE À JOUR : 2024 - Ajout de la sélection de dossier via boîte de dialogue (getfiled)
;;                     - Gestion des espaces dans les chemins de fichiers
;;                     - Chargement automatique des bibliothèques Visual LISP
;;                     - Mémorisation du dernier dossier utilisé
;;                     - Option pour utiliser un dossier par défaut
;;                     - Amélioration de la robustesse avec vérifications d'erreurs
;;                     - Gestion des valeurs nil et des chaînes invalides
;;                     - Facteur d'échelle fixé à 20 (converti en 200) sans demande utilisateur
;;                     - Sélection interactive du point de départ pour l'insertion
;;                     - Calcul automatique de l'espacement horizontal à partir de deux points sélectionnés
;;                     - Option pour insérer tous les fichiers DXF du dossier ou faire une sélection manuelle
;;                     - En mode sélection: choix des fichiers DXF un par un via boîte de dialogue
;;                     - Disposition linéaire (sur une seule ligne)
;;                     - Possibilité d'ajouter plusieurs fichiers un par un avec confirmation
;;                     - Centrage des DXF dans les cartouches (point de départ, point diagonal, point d'espacement)
;; ===================================================================

;; Fonction pour vérifier si une variable est une chaîne
(defun is-string (val)
  (= (type val) 'STR)
)

;; Fonction pour sauvegarder le dernier dossier utilisé
(defun saveLastUsedFolder (folder / filename outfile)
  (if (and folder (is-string folder))
    (progn
      (setq filename (strcat (getvar "DWGPREFIX") "InsertDXFs_LastFolder.txt"))
      (setq outfile (open filename "w"))
      (if outfile
        (progn
          (write-line folder outfile)
          (close outfile)
        )
        (princ "\nErreur: Impossible d'ouvrir le fichier pour sauvegarder le dossier.")
      )
    )
    (princ "\nErreur: Dossier invalide, impossible de sauvegarder.")
  )
  (princ)
)

;; Fonction pour récupérer le dernier dossier utilisé
(defun getLastUsedFolder (/ filename infile lastfolder)
  (setq filename (strcat (getvar "DWGPREFIX") "InsertDXFs_LastFolder.txt"))
  (if (findfile filename)
    (progn
      (setq infile (open filename "r"))
      (if infile
        (progn
          (setq lastfolder (read-line infile))
          (close infile)
          ;; Vérifier que lastfolder est une chaîne valide et non vide
          (if (and lastfolder (is-string lastfolder) (> (strlen lastfolder) 0))
            lastfolder
            (progn
              (princ "\nAttention: Le fichier de dossier précédent est vide ou invalide.")
              nil
            )
          )
        )
        (progn
          (princ "\nErreur: Impossible d'ouvrir le fichier de dossier précédent.")
          nil
        )
      )
    )
    nil
  )
)

;; Fonction principale - Insertion des DXFs
(defun c:InsertDXFs (/ dxfFolder dxfFiles pasX nbCartouches lastUsedFolder selectedDxfFiles cartoucheWidth cartoucheHeight defaultDxfFolder startPoint startX startY diagonalPoint diagonalX diagonalY centerX centerY spacingPoint spacingX spacingY displayScale scale selectionMode fullPath currentCenterX currentCenterY tempInsertPoint tempEnt dxfWidth dxfHeight ss minPoint maxPoint i ent obj minPt maxPt posX posY dxfFile scaleMultiplier customSortDxfFiles done selectedFile resp getFilePrefix getFileNumber getBaseNumber getPartNumber)
  
  ;; ===== CONFIGURATION =====
  ;; Chargement des bibliothèques nécessaires
  (vl-load-com)
    
  ;; Récupérer le dernier dossier utilisé ou utiliser le dossier par défaut
  (setq lastUsedFolder (getLastUsedFolder))
  (setq defaultDxfFolder (if lastUsedFolder lastUsedFolder "C:/Temp/DXF/"))
  
  ;; Fonction pour sélectionner un dossier via getfiled (plus compatible)
  (defun selectFolder (/ folder initialDir folderDir)
    ;; Utiliser le dernier dossier utilisé comme répertoire initial s'il existe
    (setq initialDir (if lastUsedFolder lastUsedFolder ""))
    (setq folder (getfiled "Sélectionner un fichier DXF dans le dossier souhaité" initialDir "dxf" 8))
    (if (and folder (is-string folder))
      (progn
        ;; Extraire le chemin du dossier à partir du chemin complet du fichier
        (setq folderDir (vl-filename-directory folder))
        ;; Vérifier que le chemin du dossier est valide
        (if (and folderDir (is-string folderDir))
          (progn
            ;; Ajouter un slash à la fin si nécessaire
            (if (and (> (strlen folderDir) 0) (/= (substr folderDir (strlen folderDir)) "/"))
              (setq folderDir (strcat folderDir "/"))
            )
            ;; Convertir les backslashes en forward slashes
             (if (and folderDir (is-string folderDir))
               (setq folderDir (vl-string-translate "\\" "/" folderDir))
             )
            folderDir
          )
          (progn
            (alert "Erreur: Impossible d'obtenir le chemin du dossier.")
            nil
          )
        )
      )
      nil
    )
  )
  
  ;; Chemin du dossier contenant les fichiers DXF
  (setq dxfFolder (selectFolder))
  
  ;; Si aucun dossier n'est sélectionné, proposer d'utiliser un dossier par défaut
  (if (null dxfFolder)
    (progn
      (if (= (getstring "\nAucun dossier sélectionné. Utiliser le dossier par défaut ? (O/N) : ") "O")
        ;; Utiliser le dossier par défaut
        (setq dxfFolder defaultDxfFolder)
        ;; Sinon, annuler l'opération
        (progn
          (alert "Opération annulée.")
          (exit)
        )
      )
    )
  )
  
  ;; Vérifier si le dossier par défaut existe
  (if (and dxfFolder (is-string dxfFolder) (= dxfFolder defaultDxfFolder))
    (if (not (vl-file-directory-p dxfFolder))
      (progn
        (alert (strcat "Le dossier par défaut " dxfFolder " n'existe pas ! Veuillez le créer ou sélectionner un autre dossier."))
        (exit)
      )
    )
  )
  
  ;; Nouveau workflow pour centrer les DXF dans les cartouches
  ;; 1. Point de départ du premier cartouche
  (princ "\nSélectionnez le point de départ du premier cartouche : ")
  (setq startPoint (getpoint))
  (if (null startPoint)
    (progn
      (princ "\nPoint de départ non spécifié. Utilisation des coordonnées par défaut (0,0).")
      (setq startX 0.0)
      (setq startY 0.0)
    )
    (progn
      (setq startX (car startPoint))
      (setq startY (cadr startPoint))
    )
  )
  
  ;; 2. Point diagonal opposé pour calculer le centre du cartouche
  (princ "\nSélectionnez le point diagonal opposé du premier cartouche : ")
  (setq diagonalPoint (getpoint))
  (if (null diagonalPoint)
    (progn
      (alert "Point diagonal opposé requis pour calculer le centre du cartouche. Opération annulée.")
      (exit)
    )
    (progn
      (setq diagonalX (car diagonalPoint))
      (setq diagonalY (cadr diagonalPoint))
      
      ;; Calculer le centre du cartouche
      (setq centerX (/ (+ startX diagonalX) 2.0))
      (setq centerY (/ (+ startY diagonalY) 2.0))
      (princ (strcat "\nCentre du cartouche calculé : (" (rtos centerX 2 2) "," (rtos centerY 2 2) ")"))
    )
  )
  
  ;; 3. Point pour l'espacement des cartouches
  (princ "\nSélectionnez un point pour définir l'espacement des cartouches : ")
  (setq spacingPoint (getpoint))
  (if (null spacingPoint)
    (progn
      (princ "\nPoint d'espacement non spécifié. Utilisation de l'espacement par défaut (420).")
      (setq pasX 420.0)
    )
    (progn
      ;; Calculer la distance entre le centre du premier cartouche et le point d'espacement
      (setq spacingX (car spacingPoint))
      (setq spacingY (cadr spacingPoint))
      
      ;; Calculer l'espacement horizontal (distance entre les centres des cartouches)
      ;; spacingX est la coordonnée X du point d'espacement sélectionné par l'utilisateur
      ;; Ce point représente où l'utilisateur souhaite placer le deuxième cartouche
      ;; L'espacement est calculé comme la distance entre le premier point (startX) et le troisième point (spacingX)
      (setq pasX (- spacingX startX))
      
      ;; Si l'espacement est négatif (point à gauche du point de départ), utiliser la valeur absolue
      (if (< pasX 0.0)
        (setq pasX (abs pasX))
      )
      
      ;; Vérifier que la distance calculée est positive et significative
      (if (< pasX 10.0) ;; Seuil minimal pour éviter des espacements trop petits
        (progn
          (alert "L'espacement calculé est trop petit. Utilisation de la valeur par défaut (420).")
          (setq pasX 420.0)
        )
      )
      (princ (strcat "\nEspacement horizontal calculé : " (rtos pasX 2 2)))
    )
  )
  

  
  ;; Pas de limite au nombre de cartouches - Insérer tous les fichiers DXF sélectionnés
  
  ;; ===== FACTEUR D'ÉCHELLE FIXE =====
  ;; Utilisation d'un facteur d'échelle fixe de 20 (200 après conversion)
  (setq displayScale 20.0)
  (princ (strcat "\nFacteur d'échelle fixé à " (rtos displayScale 2 1) " (échelle 1:" (rtos displayScale 2 0) ")"))

  
  ;; Calculer le facteur d'échelle réel (multiplié par 10 pour conversion cm/mm)
  ;; Note: Cette conversion est nécessaire car l'utilisateur pense en échelle de dessin (1:20)
  ;; mais AutoCAD a besoin d'un facteur réel pour l'insertion (200 pour une échelle de 1:20)
  (setq scaleMultiplier 10.0)      ;; Multiplicateur pour convertir cm en mm
  (setq scale (* displayScale scaleMultiplier))
  
  ;; ===== VÉRIFICATION DU DOSSIER =====
  (if (not (and dxfFolder (is-string dxfFolder)))
    (progn
      (alert "Erreur: Chemin de dossier invalide ou non défini.")
      (exit)
    )
  )
  
  (if (not (vl-file-directory-p dxfFolder))
    (progn
      (alert (strcat "Le dossier " dxfFolder " n'existe pas !"))
      (exit)
    )
  )
  
  ;; ===== SÉLECTION DES FICHIERS DXF =====
  ;; Initialiser la liste des fichiers sélectionnés
  (setq selectedDxfFiles nil)
  
  ;; Fonction pour récupérer tous les fichiers DXF du dossier
  (defun getDxfFilesFromFolder (/ allFiles dxfFiles ext)
    ;; Vérifier que le dossier existe
    (if (not (and dxfFolder (is-string dxfFolder) (vl-file-directory-p dxfFolder)))
      (progn
        (alert (strcat "Erreur: Le dossier " dxfFolder " n'est pas valide ou n'existe pas."))
        (exit)
      )
    )
    
    ;; Récupérer tous les fichiers du dossier
    (setq allFiles nil)
    (setq allFiles (vl-directory-files dxfFolder nil nil))
    
    ;; Vérifier que la liste des fichiers n'est pas nil
    (if (null allFiles)
      (progn
        (alert (strcat "Erreur lors de la lecture du dossier " dxfFolder))
        (exit)
      )
    )
    
    ;; Filtre pour ne garder que les fichiers .dxf
    (setq dxfFiles (vl-remove-if-not
                     (function
                       (lambda (x / ext)
                          (and (is-string x) 
                               (setq ext (vl-filename-extension x))
                               (is-string ext)
                               (= (strcase ext) ".DXF")
                          )
                       )
                     )
                     allFiles
                   )
    )
    
    ;; Vérification qu'il y a des fichiers DXF
    (if (= (length dxfFiles) 0)
      (progn
        (alert "Aucun fichier DXF trouvé dans le dossier spécifié !")
        (exit)
      )
    )
    
    dxfFiles
  )
  
  ;; Récupérer la liste des fichiers DXF disponibles
  (setq dxfFiles (getDxfFilesFromFolder))
  
  ;; Demander à l'utilisateur s'il souhaite insérer tous les fichiers ou faire une sélection
  (initget "Tous Selection T S")
  (setq selectionMode (getkword "\nInsérer [Tous/Selection] les fichiers DXF ? <Tous>: "))
  
  ;; Fonction pour trier les fichiers DXF selon un ordre personnalisé
  (defun customSortDxfFiles (dxfFiles / sortedFiles lgFiles lbFiles otherFiles getFilePrefix getFileNumber getBaseNumber getPartNumber fileNum baseNum partNum i prefix fileGroups groupKey fileGroup)
    ;; Fonction pour extraire le préfixe d'un nom de fichier (LG, LB, etc.)
    (defun getFilePrefix (fileName)
      (if (and fileName (is-string fileName))
        (progn
          ;; Extraire les 2 premiers caractères du nom de fichier
          (if (>= (strlen fileName) 2)
            (strcase (substr fileName 1 2))
            "")
        )
        ""
      )
    )
    
    ;; Fonction pour extraire le numéro d'un nom de fichier
    (defun getFileNumber (fileName / prefix numStr i char foundDigit)
      (if (and fileName (is-string fileName))
        (progn
          ;; Extraire le préfixe (2 premiers caractères)
          (setq prefix (getFilePrefix fileName))
          
          ;; Extraire la partie numérique à la fin du nom de fichier
          (setq numStr "")
          (setq fileName (vl-filename-base fileName)) ;; Nom sans extension
          
          ;; Parcourir le nom de fichier de la fin vers le début pour trouver les chiffres
          (setq i (strlen fileName))
          (setq foundDigit nil)
          (while (> i 0)
            (setq char (substr fileName i 1))
            ;; Si le caractère est un chiffre
            (if (and (>= (ascii char) 48) (<= (ascii char) 57))
              (progn
                (setq numStr (strcat char numStr))
                (setq foundDigit T)
              )
              ;; Si on a déjà trouvé des chiffres et qu'on rencontre un non-chiffre, arrêter
              (if foundDigit (setq i 0))
            )
            (setq i (1- i))
          )
          
          ;; Retourner le numéro sous forme de chaîne pour préserver les zéros initiaux
          ;; pour le tri, mais le convertir en nombre pour les comparaisons
          (if (and numStr (> (strlen numStr) 0))
            (atoi numStr)
            0
          )
        )
        0
      )
    )
    
    ;; Fonction pour extraire le numéro de base (sans le suffixe _1, _2, etc.)
    (defun getBaseNumber (fileName / baseFileName pos dashPos prefix numStr i char foundDigit)
      (setq baseFileName (vl-filename-base fileName))
      
      ;; Chercher la position du dernier underscore (pour les parties _1, _2, etc.)
      (setq pos (vl-string-search "_" baseFileName (- (strlen baseFileName) 3)))
      
      ;; Traiter d'abord le cas des underscores
      (if pos
        ;; Si un underscore est trouvé près de la fin, on travaille sur la partie avant l'underscore
        (setq baseFileName (substr baseFileName 1 pos))
      )
      
      ;; Extraire le préfixe (2 premiers caractères)
      (setq prefix (getFilePrefix baseFileName))
      
      ;; Extraire le premier numéro après le préfixe
      (setq numStr "")
      (setq i (+ (strlen prefix) 1))
      (setq foundDigit nil)
      
      ;; Parcourir le nom de fichier après le préfixe pour trouver le premier groupe de chiffres
      (while (and (<= i (strlen baseFileName)) (not foundDigit))
        (setq char (substr baseFileName i 1))
        ;; Si le caractère est un chiffre
        (if (and (>= (ascii char) 48) (<= (ascii char) 57))
          (progn
            ;; Commencer à collecter les chiffres
            (setq numStr (strcat numStr char))
            (setq foundDigit T)
            (setq i (1+ i))
            
            ;; Continuer à collecter les chiffres consécutifs jusqu'au premier tiret ou autre séparateur
            (while (and (<= i (strlen baseFileName)) 
                        (setq char (substr baseFileName i 1))
                        (and (>= (ascii char) 48) (<= (ascii char) 57)))
              (setq numStr (strcat numStr char))
              (setq i (1+ i))
            )
          )
          ;; Passer au caractère suivant si ce n'est pas un chiffre
          (setq i (1+ i))
        )
      )
      
      ;; Retourner le numéro trouvé ou 0 si aucun
      (if (and numStr (> (strlen numStr) 0))
        (atoi numStr)
        0
      )
    )
    
    ;; Fonction pour extraire le numéro de partie (_1, _2, etc.)
    (defun getPartNumber (fileName / baseFileName pos partStr)
      (setq baseFileName (vl-filename-base fileName))
      ;; Chercher la position du dernier underscore
      (setq pos (vl-string-search "_" baseFileName (- (strlen baseFileName) 3)))
      (if pos
        ;; Si un underscore est trouvé près de la fin, extraire le numéro après l'underscore
        (progn
          (setq partStr (substr baseFileName (+ pos 2)))
          (if (and partStr (> (strlen partStr) 0))
            (atoi partStr)
            1
          )
        )
        ;; Sinon, retourner 1 comme numéro de partie par défaut
        1
      )
    )
    
    ;; Séparer les fichiers en trois catégories: LG, LB et autres
    (setq lgFiles nil)
    (setq lbFiles nil)
    (setq otherFiles nil)
    
    (princ "\n=== Analyse des fichiers pour le tri personnalisé ===")
    (foreach file dxfFiles
      (setq prefix (getFilePrefix (vl-filename-base file)))
      (setq fileNum (getFileNumber (vl-filename-base file)))
      (setq baseNum (getBaseNumber file))
      (setq partNum (getPartNumber file))
      (princ (strcat "\nFichier: " file " - Préfixe: " prefix " - Numéro: " (itoa fileNum) 
                     " - Base: " (itoa baseNum) " - Partie: " (itoa partNum)))
      (cond
        ((= prefix "LG") 
         (setq lgFiles (append lgFiles (list file)))
         (princ " -> Catégorie: LG"))
        ((= prefix "LB") 
         (setq lbFiles (append lbFiles (list file)))
         (princ " -> Catégorie: LB"))
        (T 
         (setq otherFiles (append otherFiles (list file)))
         (princ " -> Catégorie: Autre"))
      )
    )
    
    ;; Regrouper les fichiers par préfixe et numéro de base
    (setq fileGroups (list))
    
    ;; Traiter d'abord les fichiers LG
    (foreach file lgFiles
      (setq baseNum (getBaseNumber file))
      (setq groupKey (strcat "LG" (itoa baseNum)))
      (setq fileGroup (assoc groupKey fileGroups))
      (if fileGroup
        ;; Ajouter à un groupe existant
        (setq fileGroups (subst (cons groupKey (append (cdr fileGroup) (list file))) fileGroup fileGroups))
        ;; Créer un nouveau groupe
        (setq fileGroups (append fileGroups (list (cons groupKey (list file)))))
      )
    )
    
    ;; Traiter ensuite les fichiers LB
    (foreach file lbFiles
      (setq baseNum (getBaseNumber file))
      (setq groupKey (strcat "LB" (itoa baseNum)))
      (setq fileGroup (assoc groupKey fileGroups))
      (if fileGroup
        ;; Ajouter à un groupe existant
        (setq fileGroups (subst (cons groupKey (append (cdr fileGroup) (list file))) fileGroup fileGroups))
        ;; Créer un nouveau groupe
        (setq fileGroups (append fileGroups (list (cons groupKey (list file)))))
      )
    )
    
    ;; Traiter enfin les autres fichiers
    (foreach file otherFiles
      (setq prefix (getFilePrefix (vl-filename-base file)))
      (setq baseNum (getBaseNumber file))
      (setq groupKey (strcat prefix (itoa baseNum)))
      (setq fileGroup (assoc groupKey fileGroups))
      (if fileGroup
        ;; Ajouter à un groupe existant
        (setq fileGroups (subst (cons groupKey (append (cdr fileGroup) (list file))) fileGroup fileGroups))
        ;; Créer un nouveau groupe
        (setq fileGroups (append fileGroups (list (cons groupKey (list file)))))
      )
    )
    
    ;; Trier les groupes par préfixe et numéro
    (setq fileGroups (vl-sort fileGroups (function (lambda (a b / prefixA numA prefixB numB)
      (setq prefixA (substr (car a) 1 2))
      (setq numA (atoi (substr (car a) 3)))
      (setq prefixB (substr (car b) 1 2))
      (setq numB (atoi (substr (car b) 3)))
      (cond
        ;; LG en premier
        ((and (= prefixA "LG") (/= prefixB "LG")) T)
        ;; LB en deuxième
        ((and (= prefixA "LB") (/= prefixB "LG") (/= prefixB "LB")) T)
        ((and (/= prefixA "LB") (= prefixB "LB")) nil)
        ;; Pour les autres préfixes, trier par numéro de base
        ((and (/= prefixA "LG") (/= prefixA "LB") (/= prefixB "LG") (/= prefixB "LB")) (< numA numB))
        ;; Cas par défaut (ne devrait pas arriver)
        (T (< prefixA prefixB))
      )
    ))))
    
    ;; Trier les fichiers dans chaque groupe par numéro de partie
    (foreach group fileGroups
      (setq fileGroup (cdr group))
      (setq fileGroup (vl-sort fileGroup (function (lambda (a b) (< (getPartNumber a) (getPartNumber b))))))
      (setq fileGroups (subst (cons (car group) fileGroup) group fileGroups))
    )
    
    ;; Aplatir les groupes en une seule liste
    (setq sortedFiles nil)
    (foreach group fileGroups
      (setq sortedFiles (append sortedFiles (cdr group)))
    )
    
    ;; Afficher l'ordre final d'insertion
    (princ "\n\n=== Ordre final d'insertion ===")
    (setq i 1)
    (foreach file sortedFiles
      (princ (strcat "\n" (itoa i) ". " file 
                     " (Préfixe: " (getFilePrefix (vl-filename-base file)) 
                     ", Base: " (itoa (getBaseNumber file)) 
                     ", Partie: " (itoa (getPartNumber file)) ")"))
      (setq i (1+ i))
    )
    
    ;; Retourner la liste triée
    sortedFiles
  )
  
  ;; Si l'utilisateur a choisi d'insérer tous les fichiers ou n'a rien entré
  (if (or (null selectionMode) (= selectionMode "Tous") (= selectionMode "T"))
    ;; Utiliser tous les fichiers DXF avec tri personnalisé
    (progn
      (setq selectedDxfFiles (customSortDxfFiles dxfFiles))
      (princ (strcat "\nTous les fichiers DXF du dossier seront insérés (" (itoa (length dxfFiles)) " fichiers) selon l'ordre personnalisé."))
    )
    ;; Sinon, permettre à l'utilisateur de sélectionner les fichiers
    (progn
      ;; Fonction pour sélectionner un fichier DXF spécifique
      (defun selectSingleFile (/ file fileName fileExt)
        (setq file (getfiled "Sélectionner un fichier DXF" dxfFolder "dxf" 0))
        
        ;; Si l'utilisateur a annulé, retourner nil
        (if (null file)
          nil
          ;; Sinon, extraire le nom du fichier
          (progn
            (setq fileName (vl-filename-base file))
            (setq fileExt (vl-filename-extension file))
            (strcat fileName fileExt)
          )
        )
      )
      
      ;; Afficher un message pour indiquer à l'utilisateur de sélectionner les fichiers
      (alert (strcat "Vous allez maintenant sélectionner les fichiers DXF à insérer.\n\n"
                    "Dossier: " dxfFolder))
      
      ;; Initialiser la liste des fichiers sélectionnés
      (setq selectedDxfFiles nil)
      (setq done nil)
      (setq selectedFile nil)
      (setq resp nil)
      
      ;; Boucle pour sélectionner les fichiers
      (while (not done)
        (setq selectedFile (selectSingleFile))
        
        ;; Si l'utilisateur a annulé, sortir de la boucle
        (if (null selectedFile)
          (setq done T)
          ;; Sinon, ajouter le fichier à la liste
          (progn
            ;; Vérifier si le fichier est déjà dans la liste
            (if (member selectedFile selectedDxfFiles)
              (princ (strcat "\nFichier déjà sélectionné: " selectedFile))
              (progn
                ;; Ajouter le fichier à la liste
                (setq selectedDxfFiles (append selectedDxfFiles (list selectedFile)))
                (princ (strcat "\nFichier ajouté: " selectedFile))
              )
            )
            
            ;; Afficher le nombre de fichiers sélectionnés
            (princ (strcat "\nNombre de fichiers sélectionnés: " (itoa (length selectedDxfFiles))))
            
            ;; Demander à l'utilisateur s'il souhaite ajouter d'autres fichiers
            (initget "Oui Non O N")
            (setq resp (getkword "\nAjouter un autre fichier ? [Oui/Non] <Oui>: "))
            (if (or (null resp) (= resp "Oui") (= resp "O"))
              (setq done nil)
              (setq done T)
            )
          )
        )
      )
    )
  )
  
  ;; Vérifier qu'au moins un fichier a été sélectionné
  (if (= (length selectedDxfFiles) 0)
    (progn
      (alert "Aucun fichier DXF sélectionné. Opération annulée.")
      (exit)
    )
    (princ (strcat "\n" (itoa (length selectedDxfFiles)) " fichier(s) DXF sélectionné(s)."))
  )
  
  ;; ===== INSERTION DES FICHIERS DXF =====
  (setq nbCartouches 0)
  

  
  ;; Boucle sur chaque fichier DXF sélectionné
  (foreach dxfFile selectedDxfFiles
    
    ;; Chemin complet du fichier DXF
    (setq fullPath nil)
    (if (and dxfFolder (is-string dxfFolder) dxfFile (is-string dxfFile))
      (setq fullPath (strcat dxfFolder dxfFile))
      (princ (strcat "\nErreur: Chemin de dossier ou nom de fichier invalide pour " (if (is-string dxfFile) dxfFile "fichier inconnu")))
    )
    
    ;; Vérification que le chemin n'est pas nil
    (if fullPath
      (progn
        ;; Calculer le centre du cartouche actuel
        ;; Le premier cartouche (nbCartouches = 0) est à la position centerX
        ;; Pour les cartouches suivants, on ajoute l'espacement pasX pour chaque cartouche
        ;; Cela garantit que l'espacement entre deux cartouches consécutifs est exactement pasX
        (setq currentCenterX (+ centerX (* pasX nbCartouches)))
        (setq currentCenterY centerY)
        
        ;; Dimensions du cartouche
        (setq cartoucheWidth (abs (- diagonalX startX)))
        (setq cartoucheHeight (abs (- diagonalY startY)))
        
        ;; Obtenir les dimensions réelles du DXF en l'insérant temporairement
        (setq tempInsertPoint (list -10000 -10000 0)) ;; Point très éloigné pour l'insertion temporaire
        
        ;; Insertion temporaire du DXF pour obtenir ses dimensions
        (if (and (is-string fullPath) (vl-string-search " " fullPath))
          (command "_INSERT" (strcat "\"" fullPath "\"") tempInsertPoint 1 1 0)
          (command "_INSERT" fullPath tempInsertPoint 1 1 0)
        )
        
        ;; Récupérer l'entité insérée
        (setq tempEnt (entlast))
        
        ;; Variables pour stocker les dimensions du DXF
        (setq dxfWidth 0)
        (setq dxfHeight 0)
        
        ;; Obtenir les dimensions du bloc
        (if tempEnt
          (progn
            ;; Exploser le bloc pour obtenir ses dimensions réelles
            (command "_EXPLODE" tempEnt)
            (command "_SELECTALL")
            (setq ss (ssget "_P"))
            
            (if ss
              (progn
                ;; Obtenir la boîte englobante
                (setq minPoint (list 1e99 1e99 0))
                (setq maxPoint (list -1e99 -1e99 0))
                
                (setq i 0)
                (repeat (sslength ss)
                  (setq ent (ssname ss i))
                  (if (not (null ent))
                    (progn
                      (setq obj (vlax-ename->vla-object ent))
                      (vla-GetBoundingBox obj 'minPt 'maxPt)
                      (setq minPt (vlax-safearray->list minPt))
                      (setq maxPt (vlax-safearray->list maxPt))
                      
                      ;; Mettre à jour les points min et max
                      (setq minPoint (list (min (car minPoint) (car minPt)) (min (cadr minPoint) (cadr minPt)) 0))
                      (setq maxPoint (list (max (car maxPoint) (car maxPt)) (max (cadr maxPoint) (cadr maxPt)) 0))
                    )
                  )
                  (setq i (1+ i))
                )
                
                ;; Calculer les dimensions réelles du DXF
                (setq dxfWidth (* (- (car maxPoint) (car minPoint)) scale))
                (setq dxfHeight (* (- (cadr maxPoint) (cadr minPoint)) scale))
                
                ;; Supprimer les entités explosées
                (command "_ERASE" ss "")
                
                ;; Afficher les dimensions du DXF
                (princ (strcat "\nDimensions du DXF " dxfFile " : " (rtos dxfWidth 2 2) " x " (rtos dxfHeight 2 2)))
              )
              (progn
                ;; Si l'explosion n'a pas fonctionné, utiliser les dimensions du cartouche
                (setq dxfWidth cartoucheWidth)
                (setq dxfHeight cartoucheHeight)
                (princ "\nImpossible de déterminer les dimensions du DXF, utilisation des dimensions du cartouche.")
              )
            )
          )
          (progn
            ;; Si l'insertion temporaire a échoué, utiliser les dimensions du cartouche
            (setq dxfWidth cartoucheWidth)
            (setq dxfHeight cartoucheHeight)
            (princ "\nImpossible d'insérer temporairement le DXF, utilisation des dimensions du cartouche.")
          )
        )
        
        ;; Calculer le point d'insertion pour centrer le DXF dans le cartouche
        ;; Le point d'insertion du DXF est en bas à gauche, donc nous décalons pour centrer
        (setq posX (- currentCenterX (/ dxfWidth 2.0)))
        (setq posY (- currentCenterY (/ dxfHeight 2.0)))
        
        ;; Insertion du DXF final - Gestion des espaces dans le chemin
        (if (and (is-string fullPath) (vl-string-search " " fullPath))
          ;; Si le chemin contient des espaces, l'entourer de guillemets
          (command "_INSERT" (strcat "\"" fullPath "\"") (list posX posY 0) scale scale 0)
          ;; Sinon, utiliser le chemin tel quel
          (command "_INSERT" fullPath (list posX posY 0) scale scale 0)
        )
        
        ;; Afficher des informations sur l'insertion
        (princ (strcat "\nInsertion de " dxfFile " au centre (" (rtos currentCenterX 2 2) "," (rtos currentCenterY 2 2) ")"))
      )
      (progn
        (alert "Erreur: Chemin de fichier invalide.")
        (princ (strcat "\nErreur avec le fichier: " dxfFile))
      )
    )
    
    ;; Incrémentation du compteur de cartouches
    (setq nbCartouches (1+ nbCartouches))
  )
  
  ;; ===== SAUVEGARDE DU DOSSIER UTILISÉ =====
  (saveLastUsedFolder dxfFolder)
  
  ;; ===== MESSAGE DE FIN =====
  ;; Créer la liste des fichiers insérés sans l'extension .DXF
  (setq fileListStr "\n\nFichiers insérés :\n")
  (setq fileIndex 1)
  (foreach file selectedDxfFiles
    (setq fileNameWithoutExt (vl-filename-base file))
    (setq fileListStr (strcat fileListStr (itoa fileIndex) ". " fileNameWithoutExt "\n"))
    (setq fileIndex (1+ fileIndex))
  )
  
  ; (alert (strcat "Insertion terminée ! \n\n" 
  ;               (itoa nbCartouches) " fichier(s) DXF inséré(s) avec : \n" 
  ;               "- Facteur d'échelle : 20 (fixe - échelle 1:20)\n"
  ;               "- Centre du premier cartouche : (" (rtos centerX 2 2) "," (rtos centerY 2 2) ")\n"
  ;               "- Dimensions du cartouche : " (rtos cartoucheWidth 2 0) " x " (rtos cartoucheHeight 2 0) "\n"
  ;               (if (null spacingPoint)
  ;                 (strcat "- Espacement horizontal : " (rtos pasX 2 0) " (valeur par défaut)")
  ;                 (strcat "- Espacement horizontal : " (rtos pasX 2 0) " (calculé automatiquement)")
  ;               )
  ;               "\n\nMode : " (if (or (null selectionMode) (= selectionMode "Tous") (= selectionMode "T"))
  ;                           "Tous les fichiers DXF du dossier"
  ;                           "Sélection manuelle des fichiers")
  ;               "\nCentrage : DXF centrés dans les cartouches"
  ;               fileListStr
  ;        ))
  
  (princ)
)

;; Charge automatiquement la fonction lors du chargement du fichier
(princ "\nCommande InsertDXFs chargée. Tapez InsertDXFs pour exécuter.\n")
(princ)