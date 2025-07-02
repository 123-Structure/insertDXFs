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
;;                     - Ajout d'un facteur d'échelle personnalisable (20 par défaut, converti en 200)
;;                     - Sélection interactive du point de départ pour l'insertion
;;                     - Calcul automatique de l'espacement horizontal à partir de deux points sélectionnés
;;                     - Option pour insérer tous les fichiers DXF du dossier ou faire une sélection manuelle
;;                     - En mode sélection: choix des fichiers DXF un par un via boîte de dialogue
;;                     - Disposition linéaire (sur une seule ligne)
;;                     - Possibilité d'ajouter plusieurs fichiers un par un avec confirmation
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
(defun c:InsertDXFs (/ dxfFolder dxfFiles baseX baseY pasX pasY maxCartouches nbCartouches lastUsedFolder selectedDxfFiles)
  
  ;; ===== CONFIGURATION =====
  ;; Chargement des bibliothèques nécessaires
  (vl-load-com)
  
  ;; Facteur d'échelle par défaut (valeur affichée 20, valeur réelle 200)
  (setq defaultDisplayScale 20.0)  ;; Valeur affichée à l'utilisateur
  (setq scaleMultiplier 10.0)      ;; Multiplicateur pour convertir cm en mm
  
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
  
  ;; Position de départ pour l'insertion - Demander à l'utilisateur
  (princ "\nSélectionnez le point de départ pour l'insertion des DXF : ")
  (setq basePoint (getpoint))
  (if (null basePoint)
    (progn
      (princ "\nPoint de départ non spécifié. Utilisation des coordonnées par défaut (0,0).")
      (setq baseX 0.0)
      (setq baseY 0.0)
    )
    (progn
      (setq baseX (car basePoint))
      (setq baseY (cadr basePoint))
    )
  )
  
  ;; Demander le point pour le deuxième DXF pour calculer l'espacement automatiquement
  (princ "\nSélectionnez le point pour le deuxième DXF (pour calculer l'espacement) : ")
  (setq secondPoint (getpoint))
  
  ;; Calculer l'espacement horizontal automatiquement ou utiliser la valeur par défaut
  (if (null secondPoint)
    (progn
      (princ "\nPoint pour le deuxième DXF non spécifié. Utilisation de l'espacement par défaut (420).")
      (setq pasX 420.0)
    )
    (progn
      ;; Calculer la distance horizontale entre les deux points
      (setq secondX (car secondPoint))
      (setq secondY (cadr secondPoint))
      (setq pasX (distance (list baseX baseY 0) (list secondX secondY 0)))
      
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
  
  ;; Pas de distance verticale nécessaire pour une disposition linéaire
  (setq pasY 0.0)
  
  ;; Nombre maximum de cartouches disponibles dans le gabarit - Toujours insérer tous les fichiers
  (setq maxCartouches 99999)  ;; Valeur très élevée pour insérer tous les fichiers DXF
  
  ;; Disposition toujours linéaire (sur une seule ligne)
  (setq cartouchesParLigne 0)
  
  ;; ===== DEMANDE DU FACTEUR D'ÉCHELLE =====
  ;; Demander à l'utilisateur s'il souhaite utiliser un facteur d'échelle personnalisé
  (setq scaleInput (getstring (strcat "\nFacteur d'échelle [" (rtos defaultDisplayScale 2 1) "] : ")))
  (setq userDisplayScale (if (= scaleInput "") defaultDisplayScale (atof scaleInput)))
  
  ;; Vérifier que le facteur d'échelle est valide et positif
  (if (<= userDisplayScale 0.0)
    (progn
      (alert "Le facteur d'échelle doit être un nombre positif. Utilisation de la valeur par défaut.")
      (setq displayScale defaultDisplayScale)
    )
    (setq displayScale userDisplayScale)
  )
  
  ;; Calculer le facteur d'échelle réel (multiplié par 10 pour conversion cm/mm)
  ;; Note: Cette conversion est nécessaire car l'utilisateur pense en échelle de dessin (1:20)
  ;; mais AutoCAD a besoin d'un facteur réel pour l'insertion (200 pour une échelle de 1:20)
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
  (defun getDxfFilesFromFolder (/ allFiles dxfFiles)
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
      (defun selectSingleFile (/ file fileName fileExt justFileName)
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
    ;; Vérification du nombre maximum de cartouches (toujours insérer tous les fichiers)
    (if (>= nbCartouches maxCartouches)
      (progn
        (alert "Tous les fichiers DXF sélectionnés ont été insérés.")
        (exit)
      )
    )
    
    ;; Calcul de la position d'insertion (disposition linéaire horizontale)
    (setq posX (+ baseX (* pasX nbCartouches)))
    (setq posY baseY)
    
    ;; Chemin complet du fichier DXF
    (setq fullPath nil)
    (if (and dxfFolder (is-string dxfFolder) dxfFile (is-string dxfFile))
      (setq fullPath (strcat dxfFolder dxfFile))
      (princ (strcat "\nErreur: Chemin de dossier ou nom de fichier invalide pour " (if (is-string dxfFile) dxfFile "fichier inconnu")))
    )
    
    ;; Vérification que le chemin n'est pas nil
    (if fullPath
      (progn
        ;; Insertion du DXF - Gestion des espaces dans le chemin
        (if (and (is-string fullPath) (vl-string-search " " fullPath))
          ;; Si le chemin contient des espaces, l'entourer de guillemets
          (command "_.-INSERT" (strcat "\"" fullPath "\"") (list posX posY 0) scale scale 0)
          ;; Sinon, utiliser le chemin tel quel
          (command "_.-INSERT" fullPath (list posX posY 0) scale scale 0)
        )
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
                "- Facteur d'échelle : " (rtos displayScale 2 1) "\n"
                "- Point de départ : (" (rtos baseX 2 2) "," (rtos baseY 2 2) ")\n"
                (if (null secondPoint)
                  (strcat "- Espacement horizontal : " (rtos pasX 2 0) " (valeur par défaut)")
                  (strcat "- Espacement horizontal : " (rtos pasX 2 0) " (calculé automatiquement)")
                )
                "\n\nMode : " (if (or (null selectionMode) (= selectionMode "Tous") (= selectionMode "T"))
                            "Tous les fichiers DXF du dossier"
                            "Sélection manuelle des fichiers")
         ))
  
  (princ)
)

;; Charge automatiquement la fonction lors du chargement du fichier
(princ "\nCommande InsertDXFs chargée. Tapez InsertDXFs pour exécuter.\n")
(princ)