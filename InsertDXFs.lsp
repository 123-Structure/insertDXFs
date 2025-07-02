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
(defun c:InsertDXFs (/ dxfFolder dxfFiles pasX nbCartouches lastUsedFolder selectedDxfFiles cartoucheWidth cartoucheHeight defaultDxfFolder startPoint startX startY diagonalPoint diagonalX diagonalY centerX centerY spacingPoint spacingX spacingY displayScale scale selectionMode fullPath currentCenterX currentCenterY tempInsertPoint tempEnt dxfWidth dxfHeight ss minPoint maxPoint i ent obj minPt maxPt posX posY dxfFile scaleMultiplier)
  
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
  (setq selectionMode (getkword "\nInsérer [Tous] les fichiers DXF ou faire une [Selection] ? <Tous>: "))
  
  ;; Si l'utilisateur a choisi d'insérer tous les fichiers ou n'a rien entré
  (if (or (null selectionMode) (= selectionMode "Tous") (= selectionMode "T"))
    ;; Utiliser tous les fichiers DXF
    (progn
      (setq selectedDxfFiles dxfFiles)
      (princ (strcat "\nTous les fichiers DXF du dossier seront insérés (" (itoa (length dxfFiles)) " fichiers)."))
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
  (alert (strcat "Insertion terminée ! \n\n" 
                (itoa nbCartouches) " fichier(s) DXF inséré(s) avec : \n" 
                "- Facteur d'échelle : 20 (fixe - échelle 1:20)\n"
                "- Centre du premier cartouche : (" (rtos centerX 2 2) "," (rtos centerY 2 2) ")\n"
                "- Dimensions du cartouche : " (rtos cartoucheWidth 2 0) " x " (rtos cartoucheHeight 2 0) "\n"
                (if (null spacingPoint)
                  (strcat "- Espacement horizontal : " (rtos pasX 2 0) " (valeur par défaut)")
                  (strcat "- Espacement horizontal : " (rtos pasX 2 0) " (calculé automatiquement)")
                )
                "\n\nMode : " (if (or (null selectionMode) (= selectionMode "Tous") (= selectionMode "T"))
                            "Tous les fichiers DXF du dossier"
                            "Sélection manuelle des fichiers")
                "\nCentrage : DXF centrés dans les cartouches"
         ))
  
  (princ)
)

;; Charge automatiquement la fonction lors du chargement du fichier
(princ "\nCommande InsertDXFs chargée. Tapez InsertDXFs pour exécuter.\n")
(princ)