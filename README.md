Ce dépôt contient les sources du projet VHDL (3A SICOM STIC)
Sujet : Implémentation de l'algorithme de détection de contours de Deriche sur une image vidéo

Changelog depuis le dernier commit :
- suppression du RESET du module memoire_ligne car non utilisé ;
- le calcul du gradient fonctionne avec les bonnes opérations sur le bon nombre de bits et les bons types de données ;
- la génération du contour fonctionne avec la fonction gen_contour qui simplifie l'écriture ;
- tous les signaux ont une affectation par défaut pour éviter les états indéterminés et la génération de latch ;
- les variable sont utilisées uniquement pour développer les calculs localement dans un même cycle d'horloge (n'existent pas physiquement !). Les registres sont utilisés pour stocker les valeurs d'un cycle à l'autre ;
- nettoyage du code en général.

Binôme : Fabrice , Victor.
