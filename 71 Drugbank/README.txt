Mappings from UNII to DrugBank created using scripts/parseDBIdBySynsInchiName.py 

INCHI OR Name OR Synonym:
- script output: Name_Syns_UNII_DbId_0_09162014.txt
- converted to unique list of mappings using:
$ cat Name_Syns_UNII_DbId_0_09162014.txt | cut -f1,3,4,5 | sort | uniq  > INCHI-OR-Syns-OR-Name-09162014.txt
- 2367 mappings 
- format: FDA preferred term, UNII, DrugBank name (uppercase), DrugBank ID

INCHI AND (Name OR Synonym):
- script output: Name_Syns_UNII_DbId_1_09162014.txt
- converted to unique list of mappings using:
$ cat Name_Syns_UNII_DbId_1_09162014.txt | cut -f1,3,4,5 | sort | uniq > INCHI-AND-Syns-OR-Name-09162014.txt
- 1218 mappings regarded as high quality 
- format: FDA preferred term, UNII, DrugBank name (uppercase), DrugBank ID
