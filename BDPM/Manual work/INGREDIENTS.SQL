--precise ingredient to ingredient
--FT is a general
--SA is a precise if normal FT present, 
--but SA is OK if there is no FT
drop  table ingred_to_ingred;
create table ingred_to_ingred as 
select distinct a.form_code as concept_code_1, a.ingredient as concept_name_1 , b.form_code as  concept_code_2 , b.ingredient as  concept_name_2 from ingredient a
 join ingredient b on a.drug_code = b.drug_code  and a.COMP_NUMBER = b.COMP_NUMBER and a.INGREDIENT != b.INGREDIENT
and a.INGR_NATURE = 'SA' and  b.INGR_NATURE = 'FT' 


--automatical mapping - name equality
drop table Ingr_map_1;
create table Ingr_map_1 as 
select d.concept_code,d.concept_name, concept_id, c.concept_name as concept_name_2,'1' as precedence  from dcs_ingredient d
join devv5.concept c on lower ( c.concept_name ) = lower (replace (d.concept_name,' Base') )
where c.vocabulary_id = 'RxNorm'
and c.concept_class_id= 'Ingredient' and invalid_reason is null and standard_Concept='S'
;
delete Ingr_map_1 where concept_Code in ( select concept_code from Ingr_map_1 group by concept_Code having count(1)>1) and concept_name like '%Base';

DROP TABLE Ingr_map_2;
create table Ingr_map_2 as
select d.concept_code,d.concept_name, concept_id, c.concept_name as concept_name_2,'1' as precedence  from dcs_ingredient d
join devv5.concept c on UTL_MATCH.EDIT_DISTANCE (lower (c.concept_name), lower (replace (d.concept_name,' Base') )) = 1
where c.vocabulary_id = 'RxNorm'
and c.concept_class_id= 'Ingredient' and invalid_reason is null and standard_Concept='S'
and d.concept_code not in (select concept_code from Ingr_map_1 )
and d.concept_name not in (select CONCEPT_NAME_1 from ingred_to_ingred ) 
;
delete Ingr_map_2 where concept_Code in ( select concept_code from Ingr_map_2 group by concept_Code having count(1)>1) and concept_name like '%Base';
DELETE FROM INGR_MAP_2 WHERE CONCEPT_CODE = 4180 AND   CONCEPT_NAME = 'Boldine' AND   CONCEPT_ID = 19026134 AND   CONCEPT_NAME_2 = 'poldine';
DELETE FROM INGR_MAP_2 WHERE CONCEPT_CODE = 45730 AND   CONCEPT_NAME = 'Sodium ' AND   CONCEPT_ID = 19136048 AND   CONCEPT_NAME_2 = 'Sodium';

DROP TABLE Ingr_map_3;
create table Ingr_map_3 as
select d.concept_code,d.concept_name, concept_id, c.concept_name as concept_name_2,'1' as precedence  from dcs_ingredient d
join devv5.concept c on UTL_MATCH.EDIT_DISTANCE(lower (c.concept_name), lower (replace (d.concept_name,' Base') )) = 2
where c.vocabulary_id = 'RxNorm'
and c.concept_class_id= 'Ingredient' and invalid_reason is null and standard_Concept='S'
and d.concept_code not in (select concept_code from Ingr_map_1 )
and d.concept_code not in (select concept_code from Ingr_map_2 )
and d.concept_name not in (select CONCEPT_NAME_1 from ingred_to_ingred )  ; 

DELETE FROM INGR_MAP_3 WHERE CONCEPT_CODE = 303 AND   CONCEPT_NAME = 'Chloramine';
DELETE FROM INGR_MAP_3 WHERE CONCEPT_CODE = 303  AND   CONCEPT_NAME = 'Chloramine';
DELETE FROM INGR_MAP_3 WHERE CONCEPT_CODE = 477  AND   CONCEPT_NAME = 'Cystéine';
DELETE FROM INGR_MAP_3 WHERE CONCEPT_CODE = 477  AND   CONCEPT_NAME = 'Cystéine';
DELETE FROM INGR_MAP_3 WHERE CONCEPT_CODE = 651  AND   CONCEPT_NAME = 'Terpine';
DELETE FROM INGR_MAP_3 WHERE CONCEPT_CODE = 900  AND   CONCEPT_NAME = 'Borax';
DELETE FROM INGR_MAP_3 WHERE CONCEPT_CODE = 951  AND   CONCEPT_NAME = 'Salol';
DELETE FROM INGR_MAP_3 WHERE CONCEPT_CODE = 960  AND   CONCEPT_NAME = 'Somatropine ';
DELETE FROM INGR_MAP_3 WHERE CONCEPT_CODE = 1023  AND   CONCEPT_NAME = 'Vitamine C';
DELETE FROM INGR_MAP_3 WHERE CONCEPT_CODE = 1023  AND   CONCEPT_NAME = 'Vitamine C';
DELETE FROM INGR_MAP_3 WHERE CONCEPT_CODE = 1023  AND   CONCEPT_NAME = 'Vitamine C';
DELETE FROM INGR_MAP_3 WHERE CONCEPT_CODE = 4557  AND   CONCEPT_NAME = 'Aescine';
DELETE FROM INGR_MAP_3 WHERE CONCEPT_CODE = 9801  AND   CONCEPT_NAME = 'Étomidate';
DELETE FROM INGR_MAP_3 WHERE CONCEPT_CODE = 11144  AND   CONCEPT_NAME = 'Éconazole Base';
DELETE FROM INGR_MAP_3 WHERE CONCEPT_CODE = 8846  AND   CONCEPT_NAME = 'Cyamémazine Base';
DELETE FROM INGR_MAP_3 WHERE CONCEPT_CODE = 18747  AND   CONCEPT_NAME = 'Kétamine Base';
DELETE FROM INGR_MAP_3 WHERE CONCEPT_CODE = 34855  AND   CONCEPT_NAME = 'Fer';
DELETE FROM INGR_MAP_3 WHERE CONCEPT_CODE = 44437  AND   CONCEPT_NAME = 'Ropivacaïne Base';
DELETE FROM INGR_MAP_3 WHERE CONCEPT_CODE = 41553  AND   CONCEPT_NAME = 'Romarin';
DELETE FROM INGR_MAP_3 WHERE CONCEPT_CODE = 67549  AND   CONCEPT_NAME = 'Rabéprazole Base';
DELETE FROM INGR_MAP_3 WHERE CONCEPT_CODE = 72074  AND   CONCEPT_NAME = 'Mémantine Base';
DELETE FROM INGR_MAP_3 WHERE CONCEPT_CODE = 72101  AND   CONCEPT_NAME = 'Duloxétine Base';
DELETE FROM INGR_MAP_3 WHERE CONCEPT_CODE = 76119  AND   CONCEPT_NAME = 'Lopéramide Base';
DELETE FROM INGR_MAP_3 WHERE CONCEPT_CODE = 76541  AND   CONCEPT_NAME = 'Lanthane';
DELETE FROM INGR_MAP_3 WHERE CONCEPT_CODE = 81058  AND   CONCEPT_NAME = 'Somatropine ';
DELETE FROM INGR_MAP_3 WHERE CONCEPT_CODE = 93678  AND   CONCEPT_NAME = 'Raloxifène Base';
DELETE FROM INGR_MAP_3 WHERE CONCEPT_CODE = 94583  AND   CONCEPT_NAME = 'Cystéamine';
UPDATE INGR_MAP_3   SET CONCEPT_ID = 19059707,       CONCEPT_NAME_2 = 'Terpin hydrate' WHERE CONCEPT_CODE = 651  AND   CONCEPT_NAME = 'Terpine';
UPDATE INGR_MAP_3   SET CONCEPT_ID = 937712,       CONCEPT_NAME_2 = 'phenyl salicylate' WHERE CONCEPT_CODE = 951  AND   CONCEPT_NAME = 'Salol';
UPDATE INGR_MAP_3   SET CONCEPT_ID = 19011773,       CONCEPT_NAME_2 = 'Ascorbic Acid' WHERE CONCEPT_CODE = 1023  AND   CONCEPT_NAME = 'Vitamine C';
UPDATE INGR_MAP_3   SET CONCEPT_ID = 1396131,       CONCEPT_NAME_2 = 'ferrous sulfate' WHERE CONCEPT_CODE = 34855  AND   CONCEPT_NAME = 'Fer';
UPDATE INGR_MAP_3   SET CONCEPT_ID = 19082654,       CONCEPT_NAME_2 = 'Rosmarinus Officinalis Preparation' WHERE CONCEPT_CODE = 41553  AND   CONCEPT_NAME = 'Romarin';
UPDATE INGR_MAP_3   SET CONCEPT_ID = 990028,       CONCEPT_NAME_2 = 'lanthanum carbonate' WHERE CONCEPT_CODE = 76541  AND   CONCEPT_NAME = 'Lanthane';

DROP table Ingr_map_4;
create table Ingr_map_4 as
select d.concept_code,d.concept_name, concept_id, c.concept_name as concept_name_2,'1' as precedence  from dcs_ingredient d
join devv5.concept c on UTL_MATCH.EDIT_DISTANCE(lower (c.concept_name), lower (replace (d.concept_name,' Base') )) = 3
where c.vocabulary_id = 'RxNorm'
and c.concept_class_id= 'Ingredient' and invalid_reason is null and standard_Concept='S'
and d.concept_code not in (select concept_code from Ingr_map_1 )
and d.concept_code not in (select concept_code from Ingr_map_2 )
and d.concept_code not in (select concept_code from Ingr_map_3 )
and d.concept_name not in (select CONCEPT_NAME_1 from ingred_to_ingred )  ;

DELETE  FROM INGR_MAP_4 WHERE CONCEPT_CODE = 92701 AND   CONCEPT_NAME = 'Hémine';
DELETE FROM INGR_MAP_4 WHERE CONCEPT_CODE = 73219 AND   CONCEPT_NAME = 'Pixantrone';
DELETE FROM INGR_MAP_4 WHERE CONCEPT_CODE = 72087 AND   CONCEPT_NAME = 'Amifampridine';
DELETE FROM INGR_MAP_4 WHERE CONCEPT_CODE = 67102 AND   CONCEPT_NAME = 'Pipéracilline Base';
DELETE FROM INGR_MAP_4 WHERE CONCEPT_CODE = 62794 AND   CONCEPT_NAME = 'Vinflunine';
DELETE FROM INGR_MAP_4 WHERE CONCEPT_CODE = 51827 AND   CONCEPT_NAME = 'Bilastine';
DELETE FROM INGR_MAP_4 WHERE CONCEPT_CODE = 45730 AND   CONCEPT_NAME = 'Sodium ';
DELETE FROM INGR_MAP_4 WHERE CONCEPT_CODE = 36828 AND   CONCEPT_NAME = 'Guarana';
DELETE FROM INGR_MAP_4 WHERE CONCEPT_CODE = 35166 AND   CONCEPT_NAME = 'Tamoxifène Base';
DELETE FROM INGR_MAP_4 WHERE CONCEPT_CODE = 30451 AND   CONCEPT_NAME = 'Avoine';
DELETE FROM INGR_MAP_4 WHERE CONCEPT_CODE = 27062 AND   CONCEPT_NAME = 'Indigotine';
UPDATE INGR_MAP_4   SET CONCEPT_ID = 42903740,       CONCEPT_NAME_2 = 'Avena sativa whole extract' WHERE CONCEPT_CODE = 30451 AND   CONCEPT_NAME = 'Avoine';
DELETE FROM INGR_MAP_4 WHERE CONCEPT_CODE = 35 AND   CONCEPT_NAME = 'Alcool';
DELETE FROM INGR_MAP_4 WHERE CONCEPT_CODE = 188 AND   CONCEPT_NAME = 'Mauve';
DELETE FROM INGR_MAP_4 WHERE CONCEPT_CODE = 547 AND   CONCEPT_NAME = 'Valpromide';
DELETE FROM INGR_MAP_4 WHERE CONCEPT_CODE = 626 AND   CONCEPT_NAME = 'Salbutamol';
DELETE FROM INGR_MAP_4 WHERE CONCEPT_CODE = 674 AND   CONCEPT_NAME = 'Tryptophane L';
DELETE FROM INGR_MAP_4 WHERE CONCEPT_CODE = 756 AND   CONCEPT_NAME = 'Colophane';
DELETE FROM INGR_MAP_4 WHERE CONCEPT_CODE = 756 AND   CONCEPT_NAME = 'Colophane';
DELETE FROM INGR_MAP_4 WHERE CONCEPT_CODE = 728 AND   CONCEPT_NAME = 'Busserole';
DELETE FROM INGR_MAP_4 WHERE CONCEPT_CODE = 838 AND   CONCEPT_NAME = 'Inosiplex';
DELETE FROM INGR_MAP_4 WHERE CONCEPT_CODE = 1080 AND   CONCEPT_NAME = 'Adrénaline Base';
DELETE FROM INGR_MAP_4 WHERE CONCEPT_CODE = 1785 AND   CONCEPT_NAME = 'Érythromycine Base';
DELETE FROM INGR_MAP_4 WHERE CONCEPT_CODE = 1821 AND   CONCEPT_NAME = 'Thiamazole';
DELETE FROM INGR_MAP_4 WHERE CONCEPT_CODE = 2332 AND   CONCEPT_NAME = 'Rifampicine';
DELETE FROM INGR_MAP_4 WHERE CONCEPT_CODE = 2428 AND   CONCEPT_NAME = 'Triclabendazole';
DELETE FROM INGR_MAP_4 WHERE CONCEPT_CODE = 2441 AND   CONCEPT_NAME = 'Nicéthamide';
DELETE FROM INGR_MAP_4 WHERE CONCEPT_CODE = 2640 AND   CONCEPT_NAME = 'Mésalazine';
DELETE FROM INGR_MAP_4 WHERE CONCEPT_CODE = 2903 AND   CONCEPT_NAME = 'Sulfirame';
DELETE FROM INGR_MAP_4 WHERE CONCEPT_CODE = 2903 AND   CONCEPT_NAME = 'Sulfirame';
DELETE FROM INGR_MAP_4 WHERE CONCEPT_CODE = 3072 AND   CONCEPT_NAME = 'Ibacitabine';
DELETE FROM INGR_MAP_4 WHERE CONCEPT_CODE = 3121 AND   CONCEPT_NAME = 'Tiliquinol';
DELETE FROM INGR_MAP_4 WHERE CONCEPT_CODE = 3354 AND   CONCEPT_NAME = 'Oxitriptan';
DELETE FROM INGR_MAP_4 WHERE CONCEPT_CODE = 3848 AND   CONCEPT_NAME = 'Glucuronamide';
DELETE FROM INGR_MAP_4 WHERE CONCEPT_CODE = 3666 AND   CONCEPT_NAME = 'Cinéole';
DELETE FROM INGR_MAP_4 WHERE CONCEPT_CODE = 4458 AND   CONCEPT_NAME = 'Trinitrine';
DELETE FROM INGR_MAP_4 WHERE CONCEPT_CODE = 4180 AND   CONCEPT_NAME = 'Boldine';
DELETE FROM INGR_MAP_4 WHERE CONCEPT_CODE = 5506 AND   CONCEPT_NAME = 'Énoxolone';
DELETE FROM INGR_MAP_4 WHERE CONCEPT_CODE = 4863 AND   CONCEPT_NAME = 'Éther';
DELETE FROM INGR_MAP_4 WHERE CONCEPT_CODE = 6327 AND   CONCEPT_NAME = 'Prêle';
DELETE FROM INGR_MAP_4 WHERE CONCEPT_CODE = 6209 AND   CONCEPT_NAME = 'Sulprostone';
DELETE FROM INGR_MAP_4 WHERE CONCEPT_CODE = 9414 AND   CONCEPT_NAME = 'Diosmectite';
DELETE FROM INGR_MAP_4 WHERE CONCEPT_CODE = 14743 AND   CONCEPT_NAME = 'Chinosol';
DELETE FROM INGR_MAP_4 WHERE CONCEPT_CODE = 14743 AND   CONCEPT_NAME = 'Chinosol';
DELETE FROM INGR_MAP_4 WHERE CONCEPT_CODE = 15401 AND   CONCEPT_NAME = 'Ketotifène Base';
DELETE FROM INGR_MAP_4 WHERE CONCEPT_CODE = 18310 AND   CONCEPT_NAME = 'Picloxydine Base';
DELETE FROM INGR_MAP_4 WHERE CONCEPT_CODE = 15911 AND   CONCEPT_NAME = 'Cibenzoline';
DELETE FROM INGR_MAP_4 WHERE CONCEPT_CODE = 19558 AND   CONCEPT_NAME = 'Doxépine';
DELETE FROM INGR_MAP_4 WHERE CONCEPT_CODE = 19757 AND   CONCEPT_NAME = 'Céfazoline Base';
DELETE FROM INGR_MAP_4 WHERE CONCEPT_CODE = 22328 AND   CONCEPT_NAME = 'Fucus';
DELETE FROM INGR_MAP_4 WHERE CONCEPT_CODE = 23010 AND   CONCEPT_NAME = 'Rupatadine';
DELETE FROM INGR_MAP_4 WHERE CONCEPT_CODE = 80439 AND   CONCEPT_NAME = 'Moroctocog Alfa ';
UPDATE INGR_MAP_4   SET CONCEPT_ID = 955372,       CONCEPT_NAME_2 = 'Ethanol' WHERE CONCEPT_CODE = 35 AND   CONCEPT_NAME = 'Alcool';
UPDATE INGR_MAP_4   SET CONCEPT_ID = 961145,       CONCEPT_NAME_2 = 'Glycerin' WHERE CONCEPT_CODE = 532 AND   CONCEPT_NAME = 'Glycérol';
UPDATE INGR_MAP_4   SET CONCEPT_ID = 1343916,       CONCEPT_NAME_2 = 'Epinephrine' WHERE CONCEPT_CODE = 1080 AND   CONCEPT_NAME = 'Adrénaline';
UPDATE INGR_MAP_4   SET CONCEPT_ID = 19072130,       CONCEPT_NAME_2 = 'monosulfiram' WHERE CONCEPT_CODE = 2903 AND   CONCEPT_NAME = 'Sulfirame';

create table ingr_translation_all
(concept_code varchar(255),
concept_name varchar(255),
translation varchar(255));
WbImport -file=C:/Users/aostropolets/Desktop/bdpm files/ingredient translation all.txt
         -type=text
         -table=INGR_TRANSLATION_ALL
         -encoding="ISO-8859-15"
         -header=true
         -decode=false
         -dateFormat=dd/m/yyyy
         -timestampFormat=dd/m/yyyy
         -delimiter='\t'
         -decimal=.
         -fileColumns=CONCEPT_CODE,CONCEPT_NAME,TRANSLATION
         -quoteCharEscaping=none
         -ignoreIdentityColumns=false
         -deleteTarget=false
         -continueOnError=false
         -batchSize=1000;

--processing after ingredient translation
create table ing_to_map as(  
select * from ingr_translation_all where concept_code not in (
  Select concept_Code from INGR_MAP_1 union
  Select concept_Code from INGR_MAP_2 union
  Select concept_Code from INGR_MAP_3 union
  Select concept_Code from INGR_MAP_4))
 ;
 
drop table Ingr_map_5;
create table Ingr_map_5 as 
select d.concept_code,d.translation, concept_id, c.concept_name as concept_name_2,'1' as precedence from ing_to_map d
join devv5.concept c on lower ( c.concept_name ) = lower (replace (d.translation,' for homeopathic preparations') )
where c.vocabulary_id = 'RxNorm'
and c.concept_class_id= 'Ingredient' and invalid_reason is null and standard_Concept='S'
;
DELETE FROM INGR_MAP_5 WHERE CONCEPT_CODE = '34855' AND   TRANSLATION = 'Iron' AND   CONCEPT_ID = 1360067 AND   CONCEPT_NAME_2 = 'Iron';
DELETE FROM INGR_MAP_5 WHERE CONCEPT_CODE = '44997' AND   TRANSLATION = 'Sulfur' AND   CONCEPT_ID = 1036525 AND   CONCEPT_NAME_2 = 'Sulfur';

DROP TABLE Ingr_map_6;
create table Ingr_map_6 as
select d.concept_code,d.translation, concept_id, c.concept_name as concept_name_2,'1' as precedence from ing_to_map d
join devv5.concept c on UTL_MATCH.EDIT_DISTANCE (lower (c.concept_name), lower (replace (d.translation,' for homeopathic preparations') )) = 1
where c.vocabulary_id = 'RxNorm'
and c.concept_class_id= 'Ingredient' and invalid_reason is null and standard_Concept='S'
and d.concept_code not in (select concept_code from Ingr_map_5)
and d.concept_name not in (select CONCEPT_NAME_1 from ingred_to_ingred ) 
;
DELETE FROM INGR_MAP_6 WHERE CONCEPT_CODE = '60189' AND   TRANSLATION = 'Epoetin zeta' AND   CONCEPT_ID = 19001311 AND   CONCEPT_NAME_2 = 'epoetin beta';
DELETE FROM INGR_MAP_6 WHERE CONCEPT_CODE = '62942' AND   TRANSLATION = 'Botulinum toxin Type B' AND   CONCEPT_ID = 729855 AND   CONCEPT_NAME_2 = 'Botulinum Toxin Type A';
UPDATE INGR_MAP_6   SET CONCEPT_ID = 911486,       CONCEPT_NAME_2 = 'Glutamate' WHERE CONCEPT_CODE = '1044' AND   TRANSLATION = 'L-Glutamic acid' AND   CONCEPT_ID = 43533055 AND   CONCEPT_NAME_2 = 'D-glutamic acid';
UPDATE INGR_MAP_6   SET CONCEPT_ID = 19054337,       CONCEPT_NAME_2 = '[13C] urea' WHERE CONCEPT_CODE = '98950' AND   TRANSLATION = 'Urea [13c]' AND   CONCEPT_ID = 19065777 AND   CONCEPT_NAME_2 = 'Urea [14C]';
INSERT INTO INGR_MAP_6(  CONCEPT_CODE,  TRANSLATION,  CONCEPT_ID,CONCEPT_NAME_2,  PRECEDENCE)VALUES(  '98950',  'Urea [13c]',906914,  'Urea',  2);


DROP TABLE Ingr_map_7;
create table Ingr_map_7 as
select d.concept_code,d.translation, concept_id, c.concept_name as concept_name_2,'1' as precedence from ing_to_map d
join devv5.concept c on UTL_MATCH.EDIT_DISTANCE(lower (c.concept_name), lower (replace (d.translation,' for homeopathic preparations') )) = 2
where c.vocabulary_id = 'RxNorm'
and c.concept_class_id= 'Ingredient' and invalid_reason is null and standard_Concept='S'
and d.concept_code not in (select concept_code from Ingr_map_5 )
and d.concept_code not in (select concept_code from Ingr_map_6 )
and d.concept_name not in (select CONCEPT_NAME_1 from ingred_to_ingred )  ; 
DELETE FROM INGR_MAP_7 WHERE CONCEPT_CODE = '25222' AND   TRANSLATION = 'Cina for homeopathic preparations' AND   CONCEPT_ID = 19136013 AND   CONCEPT_NAME_2 = 'RNA' AND   PRECEDENCE = '1';
DELETE FROM INGR_MAP_7 WHERE CONCEPT_CODE = '25222' AND   TRANSLATION = 'Cina for homeopathic preparations' AND   CONCEPT_ID = 19008281 AND   CONCEPT_NAME_2 = 'Tin' AND   PRECEDENCE = '1';
DELETE FROM INGR_MAP_7 WHERE CONCEPT_CODE = '25222' AND   TRANSLATION = 'Cina for homeopathic preparations' AND   CONCEPT_ID = 43012239 AND   CONCEPT_NAME_2 = 'Mica' AND   PRECEDENCE = '1';
DELETE FROM INGR_MAP_7 WHERE CONCEPT_CODE = '25222' AND   TRANSLATION = 'Cina for homeopathic preparations' AND   CONCEPT_ID = 19010696 AND   CONCEPT_NAME_2 = 'Zinc' AND   PRECEDENCE = '1';
DELETE FROM INGR_MAP_7 WHERE CONCEPT_CODE = '27287' AND   TRANSLATION = 'Dapoxetine' AND   CONCEPT_ID = 715259 AND   CONCEPT_NAME_2 = 'duloxetine' AND   PRECEDENCE = '1';
DELETE FROM INGR_MAP_7 WHERE CONCEPT_CODE = '303' AND   TRANSLATION = 'Chloramine' AND   CONCEPT_ID = 949453 AND   CONCEPT_NAME_2 = 'chloroxine' AND   PRECEDENCE = '1';
DELETE FROM INGR_MAP_7 WHERE CONCEPT_CODE = '303' AND   TRANSLATION = 'Chloramine' AND   CONCEPT_ID = 42898711 AND   CONCEPT_NAME_2 = 'Chlorine' AND   PRECEDENCE = '1';
DELETE FROM INGR_MAP_7 WHERE CONCEPT_CODE = '45849' AND   TRANSLATION = 'Epoetin theta' AND   CONCEPT_ID = 19001311 AND   CONCEPT_NAME_2 = 'epoetin beta' AND   PRECEDENCE = '1';
DELETE FROM INGR_MAP_7 WHERE CONCEPT_CODE = '477' AND   TRANSLATION = 'L-Cysteine' AND   CONCEPT_ID = 19071999 AND   CONCEPT_NAME_2 = 'mecysteine' AND   PRECEDENCE = '1';
DELETE FROM INGR_MAP_7 WHERE CONCEPT_CODE = '5506' AND   TRANSLATION = 'Enoxolone' AND   CONCEPT_ID = 19063454 AND   CONCEPT_NAME_2 = 'Enoximone' AND   PRECEDENCE = '1';
DELETE FROM INGR_MAP_7 WHERE CONCEPT_CODE = '8637' AND   TRANSLATION = 'Iodum for homeopathic preparations' AND   CONCEPT_ID = 19136048 AND   CONCEPT_NAME_2 = 'Sodium' AND   PRECEDENCE = '1';
DELETE FROM INGR_MAP_7 WHERE CONCEPT_CODE = '89485' AND   TRANSLATION = 'Eseridine' AND   CONCEPT_ID = 1387219 AND   CONCEPT_NAME_2 = 'deserpidine' AND   PRECEDENCE = '1';
DELETE FROM INGR_MAP_7 WHERE CONCEPT_CODE = '900' AND   TRANSLATION = 'Borax' AND   CONCEPT_ID = 1037015 AND   CONCEPT_NAME_2 = 'Bran' AND   PRECEDENCE = '1';
DELETE FROM INGR_MAP_7 WHERE CONCEPT_CODE = '90673' AND   TRANSLATION = 'Folinic acid' AND   CONCEPT_ID = 19129642 AND   CONCEPT_NAME_2 = 'Oxolinic Acid' AND   PRECEDENCE = '1';
DELETE FROM INGR_MAP_7 WHERE CONCEPT_CODE = '9308' AND   TRANSLATION = 'Kidron for homeopathic preparations' AND   CONCEPT_ID = 1360067 AND   CONCEPT_NAME_2 = 'Iron' AND   PRECEDENCE = '1';
DELETE FROM INGR_MAP_7 WHERE CONCEPT_CODE = '951' AND   TRANSLATION = 'Salol' AND   CONCEPT_ID = 1370109 AND   CONCEPT_NAME_2 = 'Sotalol' AND   PRECEDENCE = '1';
UPDATE INGR_MAP_7   SET CONCEPT_ID = 938268,       CONCEPT_NAME_2 = 'sennosides, USP',       PRECEDENCE = '2' WHERE CONCEPT_CODE = '2314' AND   TRANSLATION = 'Senna for homeopathic preparations' AND   CONCEPT_ID = 1354698 AND   CONCEPT_NAME_2 = 'Mesna' AND   PRECEDENCE = '1';
UPDATE INGR_MAP_7   SET CONCEPT_ID = 745466,       CONCEPT_NAME_2 = 'Valproate' WHERE CONCEPT_CODE = '25252' AND   TRANSLATION = 'Valproic acid' AND   CONCEPT_ID = 45775582 AND   CONCEPT_NAME_2 = 'valeric acid' AND   PRECEDENCE = '1';
UPDATE INGR_MAP_7   SET CONCEPT_ID = 1036059,       CONCEPT_NAME_2 = 'Antipyrine' WHERE CONCEPT_CODE = '2811' AND   TRANSLATION = 'Phenazone' AND   CONCEPT_ID = 19132884 AND   CONCEPT_NAME_2 = 'Phenazocine' AND   PRECEDENCE = '1';
UPDATE INGR_MAP_7   SET CONCEPT_ID = 19071838,       CONCEPT_NAME_2 = 'Oats preparation',       PRECEDENCE = '1' WHERE CONCEPT_CODE = '30451' AND   TRANSLATION = 'Oat extract' AND   CONCEPT_ID = 990337 AND   CONCEPT_NAME_2 = 'Malt extract' AND   PRECEDENCE = '1';
UPDATE INGR_MAP_7   SET CONCEPT_ID = 1400498,       CONCEPT_NAME_2 = 'Iron Carbonyl',       PRECEDENCE = '3' WHERE CONCEPT_CODE = '34855' AND   TRANSLATION = 'Iron' AND   CONCEPT_ID = 19016747 AND   CONCEPT_NAME_2 = 'Neon' AND   PRECEDENCE = '1';
UPDATE INGR_MAP_7   SET CONCEPT_ID = 1381661,       CONCEPT_NAME_2 = 'Iron-Dextran Complex',       PRECEDENCE = '2' WHERE CONCEPT_CODE = '34855' AND   TRANSLATION = 'Iron' AND   CONCEPT_ID = 19029824 AND   CONCEPT_NAME_2 = 'Boron' AND   PRECEDENCE = '1';
UPDATE INGR_MAP_7   SET CONCEPT_ID = 1396131,       CONCEPT_NAME_2 = 'ferrous sulfate',       PRECEDENCE = '1' WHERE CONCEPT_CODE = '34855' AND   TRANSLATION = 'Iron' AND   CONCEPT_ID = 43013470 AND   CONCEPT_NAME_2 = 'Argon' AND   PRECEDENCE = '1';
UPDATE INGR_MAP_7   SET CONCEPT_ID = 1595799,       CONCEPT_NAME_2 = 'Ferrous fumarate',       PRECEDENCE = '4' WHERE CONCEPT_CODE = '34855' AND   TRANSLATION = 'Iron' AND   CONCEPT_ID = 1037015 AND   CONCEPT_NAME_2 = 'Bran' AND   PRECEDENCE = '1';
UPDATE INGR_MAP_7   SET CONCEPT_ID = 19050346,       CONCEPT_NAME_2 = 'Eucalyptol' WHERE CONCEPT_CODE = '3666' AND   TRANSLATION = 'Cineole' AND   CONCEPT_ID = 42900471 AND   CONCEPT_NAME_2 = 'indole' AND   PRECEDENCE = '1';
UPDATE INGR_MAP_7   SET CONCEPT_ID = 42899623,       CONCEPT_NAME_2 = 'Peumus boldus leaf extract' WHERE CONCEPT_CODE = '39881' AND   TRANSLATION = 'Boldo extract' AND   CONCEPT_ID = 590768 AND   CONCEPT_NAME_2 = 'Mold Extract' AND   PRECEDENCE = '1';
UPDATE INGR_MAP_7   SET CONCEPT_ID = 42903472,       CONCEPT_NAME_2 = 'diacetyl boldine' WHERE CONCEPT_CODE = '4180' AND   TRANSLATION = 'Boldin' AND   CONCEPT_ID = 19026134 AND   CONCEPT_NAME_2 = 'poldine' AND   PRECEDENCE = '1';
UPDATE INGR_MAP_7   SET CONCEPT_ID = 19036781,       CONCEPT_NAME_2 = 'Calcium Chloride' WHERE CONCEPT_CODE = '430' AND   TRANSLATION = 'Calcium chloride dihydrate' AND   CONCEPT_ID = 45776278 AND   CONCEPT_NAME_2 = 'calcium chlorate dihydrate' AND   PRECEDENCE = '1';
UPDATE INGR_MAP_7   SET CONCEPT_ID = 950933,       CONCEPT_NAME_2 = 'Castor Oil' WHERE CONCEPT_CODE = '4324' AND   TRANSLATION = 'Ricin oil' AND   CONCEPT_ID = 42899800 AND   CONCEPT_NAME_2 = 'Rice Oil' AND   PRECEDENCE = '1';
UPDATE INGR_MAP_7   SET CONCEPT_ID = 19095043,       CONCEPT_NAME_2 = 'Chlortetracycline' WHERE CONCEPT_CODE = '46194' AND   TRANSLATION = 'Aureomycin for homeopathic preparations' AND   CONCEPT_ID = 19026710 AND   CONCEPT_NAME_2 = 'Capreomycin' AND   PRECEDENCE = '1';
UPDATE INGR_MAP_7   SET CONCEPT_ID = 19011035,       CONCEPT_NAME_2 = 'Lactate' WHERE CONCEPT_CODE = '5009' AND   TRANSLATION = 'sodium Lactate' AND   CONCEPT_ID = 19077884 AND   CONCEPT_NAME_2 = 'Sodium Acetate' AND   PRECEDENCE = '1';
UPDATE INGR_MAP_7   SET CONCEPT_ID = 42899194,       CONCEPT_NAME_2 = 'Glycyrrhetinic acid' WHERE CONCEPT_CODE = '5506' AND   TRANSLATION = 'Enoxolone' AND   CONCEPT_ID = 19061392 AND   CONCEPT_NAME_2 = 'fenozolone' AND   PRECEDENCE = '1';
UPDATE INGR_MAP_7   SET CONCEPT_ID = 19071966,       CONCEPT_NAME_2 = 'Adenine' WHERE CONCEPT_CODE = '59' AND   TRANSLATION = 'Adenine triphosphate' AND   CONCEPT_ID = 19015230 AND   CONCEPT_NAME_2 = 'Adenosine Triphosphate' AND   PRECEDENCE = '1';
UPDATE INGR_MAP_7   SET CONCEPT_ID = 19086759,       CONCEPT_NAME_2 = 'Cephalothin' WHERE CONCEPT_CODE = '63303' AND   TRANSLATION = 'Cefalotin' AND   CONCEPT_ID = 1771162 AND   CONCEPT_NAME_2 = 'Cefazolin' AND   PRECEDENCE = '1';
UPDATE INGR_MAP_7   SET CONCEPT_ID = 1396131,       CONCEPT_NAME_2 = 'ferrous sulfate' WHERE CONCEPT_CODE = '64153' AND   TRANSLATION = 'Ferrum' AND   CONCEPT_ID = 43012573 AND   CONCEPT_NAME_2 = 'Cerium' AND   PRECEDENCE = '1';
UPDATE INGR_MAP_7   SET CONCEPT_ID = 19007429,       CONCEPT_NAME_2 = 'Thymus Extracts' WHERE CONCEPT_CODE = '67400' AND   TRANSLATION = 'Thymulin for homeopathic preparations' AND   CONCEPT_ID = 45775549 AND   CONCEPT_NAME_2 = 'tiamulin' AND   PRECEDENCE = '1';
UPDATE INGR_MAP_7   SET CONCEPT_ID = 19011035,       CONCEPT_NAME_2 = 'Lactate' WHERE CONCEPT_CODE = '688' AND   TRANSLATION = 'Lactic acid' AND   CONCEPT_ID = 929549 AND   CONCEPT_NAME_2 = 'Acetic Acid' AND   PRECEDENCE = '1';
UPDATE INGR_MAP_7   SET CONCEPT_ID = 711452,       CONCEPT_NAME_2 = 'Benzoate' WHERE CONCEPT_CODE = '7' AND   TRANSLATION = 'Benzoic acid' AND   CONCEPT_ID = 43533088 AND   CONCEPT_NAME_2 = 'BENZILIC ACID' AND   PRECEDENCE = '1';
UPDATE INGR_MAP_7   SET CONCEPT_ID = 1780601,       CONCEPT_NAME_2 = 'Iodine' WHERE CONCEPT_CODE = '8637' AND   TRANSLATION = 'Iodum for homeopathic preparations' AND   CONCEPT_ID = 43012200 AND   CONCEPT_NAME_2 = 'Indium' AND   PRECEDENCE = '1';
UPDATE INGR_MAP_7   SET PRECEDENCE = '2' WHERE CONCEPT_CODE = '87348' AND   TRANSLATION = 'Phenylenediamine' AND   CONCEPT_ID = 43560189 AND   CONCEPT_NAME_2 = 'M-PHENYLENEDIAMINE' AND   PRECEDENCE = '1';
UPDATE INGR_MAP_7   SET CONCEPT_ID = 1388796,       CONCEPT_NAME_2 = 'Leucovorin' WHERE CONCEPT_CODE = '90673' AND   TRANSLATION = 'Folinic acid' AND   CONCEPT_ID = 19111620 AND   CONCEPT_NAME_2 = 'Folic Acid' AND   PRECEDENCE = '1';
UPDATE INGR_MAP_7   SET CONCEPT_ID = 937712,       CONCEPT_NAME_2 = 'phenyl salicylate' WHERE CONCEPT_CODE = '951' AND   TRANSLATION = 'Salol' AND   CONCEPT_ID = 43012237 AND   CONCEPT_NAME_2 = 'maltol' AND   PRECEDENCE = '1';
UPDATE INGR_MAP_7   SET CONCEPT_ID = 992409,       CONCEPT_NAME_2 = 'Senna Leaves' WHERE CONCEPT_CODE = '97684' AND   TRANSLATION = 'Senna extract' AND   CONCEPT_ID = 19097473 AND   CONCEPT_NAME_2 = 'Sepia extract' AND   PRECEDENCE = '1';
INSERT INTO INGR_MAP_7(  CONCEPT_CODE,  TRANSLATION,  CONCEPT_ID,  CONCEPT_NAME_2,  PRECEDENCE)VALUES(  '2314',  'Senna for homeopathic preparations',  992409,  'Senna Leaves',  '1');
INSERT INTO INGR_MAP_7(  CONCEPT_CODE,  TRANSLATION,  CONCEPT_ID,  CONCEPT_NAME_2,  PRECEDENCE)VALUES(  '30451',  'Oat extract',  42903740,  'Avena sativa whole extract',  '2');
INSERT INTO INGR_MAP_7(  CONCEPT_CODE,  TRANSLATION,  CONCEPT_ID,  CONCEPT_NAME_2,  PRECEDENCE)VALUES(  '34855',  'Iron',  1396012,  'ferrous gluconate',  '5');
INSERT INTO INGR_MAP_7(  CONCEPT_CODE,  TRANSLATION,  CONCEPT_ID,  CONCEPT_NAME_2,  PRECEDENCE)VALUES(  '34855',  'Iron',  19096133,  'ferrous succinate',  '6');
INSERT INTO INGR_MAP_7(  CONCEPT_CODE,  TRANSLATION,  CONCEPT_ID,  CONCEPT_NAME_2,  PRECEDENCE)VALUES(  '34855',  'Iron',  19000753,  'Ferrous glycine sulfate',  '7');
INSERT INTO INGR_MAP_7(  CONCEPT_CODE,  TRANSLATION,  CONCEPT_ID,  CONCEPT_NAME_2,  PRECEDENCE)VALUES(  '64153',  'Ferrum',  1396012,  'ferrous gluconate',  '2');
INSERT INTO INGR_MAP_7(  CONCEPT_CODE,  TRANSLATION,  CONCEPT_ID,  CONCEPT_NAME_2,  PRECEDENCE)VALUES(  '64153',  'Ferrum',  19096133,  'ferrous succinate',  '3');
INSERT INTO INGR_MAP_7(  CONCEPT_CODE,  TRANSLATION,  CONCEPT_ID,  CONCEPT_NAME_2,  PRECEDENCE)VALUES(  '64153',  'Ferrum',  1595799,  'Ferrous fumarate',  '4');
INSERT INTO INGR_MAP_7(  CONCEPT_CODE,  TRANSLATION,  CONCEPT_ID,  CONCEPT_NAME_2,  PRECEDENCE)VALUES(  '64153',  'Ferrum',  1400498,  'Iron Carbonyl',  '5');
INSERT INTO INGR_MAP_7(  CONCEPT_CODE,  TRANSLATION,  CONCEPT_ID,  CONCEPT_NAME_2,  PRECEDENCE)VALUES(  '64153',  'Ferrum',  1381661,  'Iron-Dextran Complex',  '6');
INSERT INTO INGR_MAP_7(  CONCEPT_CODE,  TRANSLATION,  CONCEPT_ID,  CONCEPT_NAME_2,  PRECEDENCE)VALUES(  '97684',  'Senna extract',  938268,  'sennosides, USP',  '2');

delete ing_to_map where concept_code in (select CONCEPT_CODE_1 from ingred_to_ingred);
select * from ing_to_map where concept_Code not in(
select cast(concept_Code  as varchar(255))  as concept_Code from INGR_MAP_1
union
select cast(concept_Code  as varchar(255))  from INGR_MAP_2
union
select cast(concept_Code  as varchar(255)) from INGR_MAP_3
union
select cast(concept_Code as varchar(255)) from INGR_MAP_4
union
select concept_Code from INGR_MAP_5
union
select concept_Code from INGR_MAP_6
union
select concept_Code from INGR_MAP_7
);

CREATE TABLE INGR_MAP_8
(
   CONCEPT_CODE    VARCHAR2(255 Byte),
   TRANSLATION     VARCHAR2(255 Byte),
   CONCEPT_ID      NUMBER            ,
   CONCEPT_NAME_2  VARCHAR2(255 Byte),
   PRECEDENCE      CHAR(1)
)
TABLESPACE USERS;
WbImport -file=C:/Users/aostropolets/Desktop/bdpm files/ing_map_8.txt
         -type=text
         -table=INGR_MAP_8
         -encoding="ISO-8859-15"
         -header=true
         -decode=false
         -dateFormat=dd/m/yyyy
         -timestampFormat=dd/m/yyyy
         -delimiter='\t'
         -decimal=.
         -fileColumns=CONCEPT_CODE,TRANSLATION,CONCEPT_ID,CONCEPT_NAME_2,PRECEDENCE
         -quoteCharEscaping=none
         -ignoreIdentityColumns=false
         -deleteTarget=false
         -continueOnError=false
         -batchSize=100;

       
CREATE TABLE INGR_MAP_9_0
(
   CONCEPT_CODE    VARCHAR2(255 Byte),
   TRANSLATION     VARCHAR2(255 Byte),
   CONCEPT_ID      NUMBER            ,
   CONCEPT_NAME_2  VARCHAR2(255 Byte),
   PRECEDENCE      CHAR(2)
)
TABLESPACE USERS;
WbImport -file=C:/Users/aostropolets/Desktop/bdpm files/ing_map_9_0.txt
         -type=text
         -table=INGR_MAP_9_0
         -encoding="ISO-8859-15"
         -header=true
         -decode=false
         -dateFormat=dd/m/yyyy
         -timestampFormat=dd/m/yyyy
         -delimiter='\t'
         -decimal=.
         -fileColumns=CONCEPT_CODE,TRANSLATION,CONCEPT_ID,CONCEPT_NAME_2,PRECEDENCE
         -quoteCharEscaping=none
         -ignoreIdentityColumns=false
         -deleteTarget=false
         -continueOnError=false
         -batchSize=100;

create table ingr_map_9 as (
select b.concept_code,a.translation, concept_id,concept_name_2,precedence from ingr_map_9_0 a 
left join INGR_TRANSLATION_ALL b on a.translation=b.translation);

create table ing_p_1 as(
select cast(CONCEPT_CODE as varchar(255)) as concept_code,CONCEPT_NAME,CONCEPT_ID,CONCEPT_NAME_2,PRECEDENCE from INGR_MAP_1
union
select cast(CONCEPT_CODE as varchar(255)) as concept_code,CONCEPT_NAME,CONCEPT_ID,CONCEPT_NAME_2,PRECEDENCE from INGR_MAP_2
union
select cast(CONCEPT_CODE as varchar(255)) as concept_code,CONCEPT_NAME,CONCEPT_ID,CONCEPT_NAME_2,PRECEDENCE from INGR_MAP_3
union
select cast(CONCEPT_CODE as varchar(255)) as concept_code,CONCEPT_NAME,CONCEPT_ID,CONCEPT_NAME_2,PRECEDENCE from INGR_MAP_4);
select * from ing_p_1 a
left join INGR_TRANSLATION_ALL b 
on a.concept_code=b.CONCEPT_CODE;


create table ing_p_2 as(
select CONCEPT_CODE,TRANSLATION,CONCEPT_ID,CONCEPT_NAME_2,cast (PRECEDENCE as char(2))  as PRECEDENCE from INGR_MAP_5
union
select CONCEPT_CODE,TRANSLATION,CONCEPT_ID,CONCEPT_NAME_2,cast (PRECEDENCE as char(2)) from INGR_MAP_6
union
select CONCEPT_CODE,TRANSLATION,CONCEPT_ID,CONCEPT_NAME_2,PRECEDENCE from INGR_MAP_7
union
select CONCEPT_CODE,TRANSLATION,CONCEPT_ID,CONCEPT_NAME_2,PRECEDENCE from INGR_MAP_8
union
select CONCEPT_CODE,TRANSLATION,CONCEPT_ID,CONCEPT_NAME_2,PRECEDENCE from INGR_MAP_9);
delete ing_p_2 where concept_id='0';

drop table aut_ingr_mapped_all;
create table aut_ingr_mapped_all as(
select a.CONCEPT_CODE,TRANSLATION as CONCEPT_NAME,CONCEPT_ID,CONCEPT_NAME_2,cast (PRECEDENCE as char(2)) as PRECEDENCE  from ing_p_1 a
left join INGR_TRANSLATION_ALL b 
on a.concept_code=b.CONCEPT_CODE
union
select CONCEPT_CODE,TRANSLATION,CONCEPT_ID,CONCEPT_NAME_2,PRECEDENCE  from ing_p_2)
;
insert into aut_ingr_mapped_all (CONCEPT_CODE,CONCEPT_NAME,CONCEPT_ID,CONCEPT_NAME_2,PRECEDENCE)
select concept_code_1,concept_name_1,CONCEPT_ID,b.CONCEPT_NAME_2,PRECEDENCE from INGRED_TO_INGRED_TRNSL a
join aut_ingr_mapped_all b on concept_code_2=concept_Code
where concept_code_1 not in (select concept_code from aut_ingr_mapped_all);

UPDATE AUT_INGR_MAPPED_ALL   SET CONCEPT_ID = 19037704,       CONCEPT_NAME_2 = 'bismuth carbonate'WHERE CONCEPT_CODE = '55294' AND   CONCEPT_NAME = 'Bismuth' AND   CONCEPT_ID = 19025138 AND   CONCEPT_NAME_2 = 'Bismuth' AND   PRECEDENCE = '1 ';
UPDATE AUT_INGR_MAPPED_ALL   SET CONCEPT_ID = 19037401,       CONCEPT_NAME_2 = 'calcium phosphate' WHERE CONCEPT_CODE = '72723' AND   CONCEPT_NAME = 'Calcium' AND   CONCEPT_ID = 19018544 AND   CONCEPT_NAME_2 = 'Calcium' AND   PRECEDENCE = '1 ';
UPDATE AUT_INGR_MAPPED_ALL   SET CONCEPT_ID = 43532257,       CONCEPT_NAME_2 = 'copper carbonate' WHERE CONCEPT_CODE = '5348' AND   CONCEPT_NAME = 'Copper' AND   CONCEPT_ID = 19071128 AND   CONCEPT_NAME_2 = 'Copper' AND   PRECEDENCE = '1 ';
INSERT INTO AUT_INGR_MAPPED_ALL(  CONCEPT_CODE,  CONCEPT_NAME,  CONCEPT_ID,  CONCEPT_NAME_2,  PRECEDENCE)VALUES(  '55294',  'Bismuth',  19037706,  'bismuth oxide',  '2');
INSERT INTO AUT_INGR_MAPPED_ALL(  CONCEPT_CODE,  CONCEPT_NAME,  CONCEPT_ID,  CONCEPT_NAME_2,  PRECEDENCE)VALUES(  '55294',  'Bismuth',  42900374,  'bismuth oxychloride',  '3');
INSERT INTO AUT_INGR_MAPPED_ALL(  CONCEPT_CODE,  CONCEPT_NAME,  CONCEPT_ID,  CONCEPT_NAME_2,  PRECEDENCE)VALUES(  '55294',  'Bismuth',  19037731,  'bismuth subcarbonate',  '4');
INSERT INTO AUT_INGR_MAPPED_ALL(  CONCEPT_CODE,  CONCEPT_NAME,  CONCEPT_ID,  CONCEPT_NAME_2,  PRECEDENCE)VALUES(  '55294',  'Bismuth',  19037794,  'bismuth subnitrate',  '5');
INSERT INTO AUT_INGR_MAPPED_ALL(  CONCEPT_CODE,  CONCEPT_NAME,  CONCEPT_ID,  CONCEPT_NAME_2,  PRECEDENCE)VALUES(  '55294',  'Bismuth',  19103189,  'bismuth aluminate',  '6');
INSERT INTO AUT_INGR_MAPPED_ALL(  CONCEPT_CODE,  CONCEPT_NAME,  CONCEPT_ID,  CONCEPT_NAME_2,  PRECEDENCE)VALUES(  '55294',  'Bismuth',  937791,  'bismuth subsalicylate',  '7');
INSERT INTO AUT_INGR_MAPPED_ALL(  CONCEPT_CODE,  CONCEPT_NAME,  CONCEPT_ID,  CONCEPT_NAME_2,  PRECEDENCE)VALUES(  '72723',  'Calcium',  19035704,  'Calcium Carbonate',  '2');
INSERT INTO AUT_INGR_MAPPED_ALL(  CONCEPT_CODE,  CONCEPT_NAME,  CONCEPT_ID,  CONCEPT_NAME_2,  PRECEDENCE)VALUES(  '72723',  'Calcium',  19036781,  'Calcium Chloride',  '3');
INSERT INTO AUT_INGR_MAPPED_ALL(  CONCEPT_CODE,  CONCEPT_NAME,  CONCEPT_ID,  CONCEPT_NAME_2,  PRECEDENCE)VALUES(  '72723',  'Calcium',  19037038,  'Calcium Gluconate',  '4');
INSERT INTO AUT_INGR_MAPPED_ALL(  CONCEPT_CODE,  CONCEPT_NAME,  CONCEPT_ID,  CONCEPT_NAME_2,  PRECEDENCE)VALUES(  '72723',  'Calcium',  19037446,  'Calcium Sulfate',  '5');
INSERT INTO AUT_INGR_MAPPED_ALL(  CONCEPT_CODE,  CONCEPT_NAME,  CONCEPT_ID,  CONCEPT_NAME_2,  PRECEDENCE)VALUES(  '72723',  'Calcium',  19058896,  'calcium lactate',  '6');
INSERT INTO AUT_INGR_MAPPED_ALL(  CONCEPT_CODE,  CONCEPT_NAME,  CONCEPT_ID,  CONCEPT_NAME_2,  PRECEDENCE)VALUES(  '72723',  'Calcium',  19007595,  'Calcium oxide',  '7');
INSERT INTO AUT_INGR_MAPPED_ALL(  CONCEPT_CODE,  CONCEPT_NAME,  CONCEPT_ID,  CONCEPT_NAME_2,  PRECEDENCE)VALUES(  '72723',  'Calcium',  1337191,  'calcium hydroxide',  '8');
INSERT INTO AUT_INGR_MAPPED_ALL(  CONCEPT_CODE,  CONCEPT_NAME,  CONCEPT_ID,  CONCEPT_NAME_2,  PRECEDENCE)VALUES(  '5348',  'Copper',  19012224,  'Copper chloride',  '2');
INSERT INTO AUT_INGR_MAPPED_ALL(  CONCEPT_CODE,  CONCEPT_NAME,  CONCEPT_ID,  CONCEPT_NAME_2,  PRECEDENCE)VALUES(  '5348',  'Copper',  19004810,  'Copper Gluconate',  '3');
INSERT INTO AUT_INGR_MAPPED_ALL(  CONCEPT_CODE,  CONCEPT_NAME,  CONCEPT_ID,  CONCEPT_NAME_2,  PRECEDENCE)VALUES(  '5348',  'Copper',  19057346,  'Copper Sulfate',  '4');
INSERT INTO AUT_INGR_MAPPED_ALL(  CONCEPT_CODE,  CONCEPT_NAME,  CONCEPT_ID,  CONCEPT_NAME_2,  PRECEDENCE)VALUES(  '5348',  'Copper',  45774792,  'copper arsenate',  '5');
UPDATE AUT_INGR_MAPPED_ALL   SET CONCEPT_ID = 19113039,       CONCEPT_NAME_2 = 'Lithium acetate' WHERE CONCEPT_CODE = '31554' AND   CONCEPT_NAME = 'Lithium' AND   CONCEPT_ID = 19124477 AND   CONCEPT_NAME_2 = 'Lithium' AND   PRECEDENCE = '1 ';
UPDATE AUT_INGR_MAPPED_ALL   SET CONCEPT_ID = 19013986,       CONCEPT_NAME_2 = 'magnesium acetate' WHERE CONCEPT_CODE = '94881' AND   CONCEPT_NAME = 'Magnesium' AND   CONCEPT_ID = 19124906 AND   CONCEPT_NAME_2 = 'Magnesium' AND   PRECEDENCE = '1 ';
UPDATE AUT_INGR_MAPPED_ALL   SET PRECEDENCE = '10' WHERE CONCEPT_CODE = '64114' AND   CONCEPT_NAME = 'Manganese' AND   CONCEPT_ID = 1394027 AND   CONCEPT_NAME_2 = 'Manganese' AND   PRECEDENCE = '1 ';
UPDATE AUT_INGR_MAPPED_ALL   SET CONCEPT_ID = 979096,       CONCEPT_NAME_2 = 'Zinc Acetate' WHERE CONCEPT_CODE = '1473' AND   CONCEPT_NAME = 'Zinc' AND   CONCEPT_ID = 19010696 AND   CONCEPT_NAME_2 = 'Zinc' AND   PRECEDENCE = '1 ';
INSERT INTO AUT_INGR_MAPPED_ALL(  CONCEPT_CODE,  CONCEPT_NAME,  CONCEPT_ID,  CONCEPT_NAME_2,  PRECEDENCE)VALUES(  '31554',  'Lithium',  19127669,  'Lithium Aspartate',  '2');
INSERT INTO AUT_INGR_MAPPED_ALL(  CONCEPT_CODE,  CONCEPT_NAME,  CONCEPT_ID,  CONCEPT_NAME_2,  PRECEDENCE)VALUES(  '31554',  'Lithium',  751246,  'Lithium Carbonate',  '3');
INSERT INTO AUT_INGR_MAPPED_ALL(  CONCEPT_CODE,  CONCEPT_NAME,  CONCEPT_ID,  CONCEPT_NAME_2,  PRECEDENCE)VALUES(  '31554',  'Lithium',  42899307,  'Lithium Chloride',  '4');
INSERT INTO AUT_INGR_MAPPED_ALL(  CONCEPT_CODE,  CONCEPT_NAME,  CONCEPT_ID,  CONCEPT_NAME_2,  PRECEDENCE)VALUES(  '31554',  'Lithium',  19113040,  'lithium gluconate',  '5');
INSERT INTO AUT_INGR_MAPPED_ALL(  CONCEPT_CODE,  CONCEPT_NAME,  CONCEPT_ID,  CONCEPT_NAME_2,  PRECEDENCE)VALUES(  '31554',  'Lithium',  45775526,  'lithium hydroxide',  '6');
INSERT INTO AUT_INGR_MAPPED_ALL(  CONCEPT_CODE,  CONCEPT_NAME,  CONCEPT_ID,  CONCEPT_NAME_2,  PRECEDENCE)VALUES(  '31554',  'Lithium',  19071905,  'lithium sulfate',  '7');
INSERT INTO AUT_INGR_MAPPED_ALL(  CONCEPT_CODE,  CONCEPT_NAME,  CONCEPT_ID,  CONCEPT_NAME_2,  PRECEDENCE)VALUES(  '94881',  'Magnesium',  42899412,  'nesium Ascorbate',  '2');
INSERT INTO AUT_INGR_MAPPED_ALL(  CONCEPT_CODE,  CONCEPT_NAME,  CONCEPT_ID,  CONCEPT_NAME_2,  PRECEDENCE)VALUES(  '94881',  'Magnesium',  19060896,  'magnesium amino acid chelate',  '4');
INSERT INTO AUT_INGR_MAPPED_ALL(  CONCEPT_CODE,  CONCEPT_NAME,  CONCEPT_ID,  CONCEPT_NAME_2,  PRECEDENCE)VALUES(  '94881',  'Magnesium',  19019131,  'Magnesium Aspartate',  '3');
INSERT INTO AUT_INGR_MAPPED_ALL(  CONCEPT_CODE,  CONCEPT_NAME,  CONCEPT_ID,  CONCEPT_NAME_2,  PRECEDENCE)VALUES(  '94881',  'Magnesium',  908464,  'magnesium carbonate',  '5');
INSERT INTO AUT_INGR_MAPPED_ALL(  CONCEPT_CODE,  CONCEPT_NAME,  CONCEPT_ID,  CONCEPT_NAME_2,  PRECEDENCE)VALUES(  '94881',  'Magnesium',  19092849,  'Magnesium Chloride',  '6');
INSERT INTO AUT_INGR_MAPPED_ALL(  CONCEPT_CODE,  CONCEPT_NAME,  CONCEPT_ID,  CONCEPT_NAME_2,  PRECEDENCE)VALUES(  '94881',  'Magnesium',  19067971,  'MAGNESIUM GLUCONATE',  '7');
INSERT INTO AUT_INGR_MAPPED_ALL(  CONCEPT_CODE,  CONCEPT_NAME,  CONCEPT_ID,  CONCEPT_NAME_2,  PRECEDENCE)VALUES(  '94881',  'Magnesium',  992956,  'Magnesium Hydroxide',  '8');
INSERT INTO AUT_INGR_MAPPED_ALL(  CONCEPT_CODE,  CONCEPT_NAME,  CONCEPT_ID,  CONCEPT_NAME_2,  PRECEDENCE)VALUES(  '94881',  'Magnesium',  19051926,  'Magnesium lactate',  '9');
INSERT INTO AUT_INGR_MAPPED_ALL(  CONCEPT_CODE,  CONCEPT_NAME,  CONCEPT_ID,  CONCEPT_NAME_2,  PRECEDENCE)VALUES(  '94881',  'Magnesium',  43012213,  'magnesium nitrate',  '10');
INSERT INTO AUT_INGR_MAPPED_ALL(  CONCEPT_CODE,  CONCEPT_NAME,  CONCEPT_ID,  CONCEPT_NAME_2,  PRECEDENCE)VALUES(  '94881',  'Magnesium',  993631,  'Magnesium Oxide',  '11');
INSERT INTO AUT_INGR_MAPPED_ALL(  CONCEPT_CODE,  CONCEPT_NAME,  CONCEPT_ID,  CONCEPT_NAME_2,  PRECEDENCE)VALUES(  '94881',  'Magnesium',  19093848,  'Magnesium Sulfate',  '12');
INSERT INTO AUT_INGR_MAPPED_ALL(  CONCEPT_CODE,  CONCEPT_NAME,  CONCEPT_ID,  CONCEPT_NAME_2,  PRECEDENCE)VALUES(  '64114',  'Manganese',  43014114,  'manganese acetate',  '2');
INSERT INTO AUT_INGR_MAPPED_ALL(  CONCEPT_CODE,  CONCEPT_NAME,  CONCEPT_ID,  CONCEPT_NAME_2,  PRECEDENCE)VALUES(  '64114',  'Manganese',  19008893,  'manganese chloride',  '3');
INSERT INTO AUT_INGR_MAPPED_ALL(  CONCEPT_CODE,  CONCEPT_NAME,  CONCEPT_ID,  CONCEPT_NAME_2,  PRECEDENCE)VALUES(  '64114',  'Manganese',  19008897,  'manganese sulfate',  '4');
INSERT INTO AUT_INGR_MAPPED_ALL(  CONCEPT_CODE,  CONCEPT_NAME,  CONCEPT_ID,  CONCEPT_NAME_2,  PRECEDENCE)VALUES(  '64114',  'Manganese',  42903608,  'manganese phosphate',  '5');
INSERT INTO AUT_INGR_MAPPED_ALL(  CONCEPT_CODE,  CONCEPT_NAME,  CONCEPT_ID,  CONCEPT_NAME_2,  PRECEDENCE)VALUES(  '64114',  'Manganese',  19071181,  'MANGANESE CITRATE',  '6');
INSERT INTO AUT_INGR_MAPPED_ALL(  CONCEPT_CODE,  CONCEPT_NAME,  CONCEPT_ID,  CONCEPT_NAME_2,  PRECEDENCE)VALUES(  '64114',  'Manganese',  19097026,  'MANGANESE ASPARTATE',  '7');
INSERT INTO AUT_INGR_MAPPED_ALL(  CONCEPT_CODE,  CONCEPT_NAME,  CONCEPT_ID,  CONCEPT_NAME_2,  PRECEDENCE)VALUES(  '64114',  'Manganese',  19068261,  'MANGANESE GLUCONATE',  '8');
INSERT INTO AUT_INGR_MAPPED_ALL(  CONCEPT_CODE,  CONCEPT_NAME,  CONCEPT_ID,  CONCEPT_NAME_2,  PRECEDENCE)VALUES(  '64114',  'Manganese',  19110125,  'MANGANESE HVP CHELATE',  '9');
INSERT INTO AUT_INGR_MAPPED_ALL(  CONCEPT_CODE,  CONCEPT_NAME,  CONCEPT_ID,  CONCEPT_NAME_2,  PRECEDENCE)VALUES(  '64114',  'Manganese',  42903849,  'manganese carbonate',  '1');
INSERT INTO AUT_INGR_MAPPED_ALL(  CONCEPT_CODE,  CONCEPT_NAME,  CONCEPT_ID,  CONCEPT_NAME_2,  PRECEDENCE)VALUES(  '1473',  'Zinc',  45776475,  'zinc ascorbate',  '2');
INSERT INTO AUT_INGR_MAPPED_ALL(  CONCEPT_CODE,  CONCEPT_NAME,  CONCEPT_ID,  CONCEPT_NAME_2,  PRECEDENCE)VALUES(  '1473',  'Zinc',  19055783,  'ZINC ASPARTATE',  '3');
INSERT INTO AUT_INGR_MAPPED_ALL(  CONCEPT_CODE,  CONCEPT_NAME,  CONCEPT_ID,  CONCEPT_NAME_2,  PRECEDENCE)VALUES(  '1473',  'Zinc',  19079204,  'Zinc Gluconate',  '4');
INSERT INTO AUT_INGR_MAPPED_ALL(  CONCEPT_CODE,  CONCEPT_NAME,  CONCEPT_ID,  CONCEPT_NAME_2,  PRECEDENCE)VALUES(  '1473',  'Zinc',  19044317,  'zinc chloride',  '6');
INSERT INTO AUT_INGR_MAPPED_ALL(  CONCEPT_CODE,  CONCEPT_NAME,  CONCEPT_ID,  CONCEPT_NAME_2,  PRECEDENCE)VALUES(  '1473',  'Zinc',  911064,  'Zinc Oxide',  '5');
INSERT INTO AUT_INGR_MAPPED_ALL(  CONCEPT_CODE,  CONCEPT_NAME,  CONCEPT_ID,  CONCEPT_NAME_2,  PRECEDENCE)VALUES(  '1473',  'Zinc',  19050644,  'zinc hydroxide',  '7');
INSERT INTO AUT_INGR_MAPPED_ALL(  CONCEPT_CODE,  CONCEPT_NAME,  CONCEPT_ID,  CONCEPT_NAME_2,  PRECEDENCE)VALUES(  '1473',  'Zinc',  19044522,  'Zinc Sulfate',  '8');
INSERT INTO AUT_INGR_MAPPED_ALL(  CONCEPT_CODE,  CONCEPT_NAME,  CONCEPT_ID,  CONCEPT_NAME_2,  PRECEDENCE)VALUES(  '1473',  'Zinc',  45892185,  'zinc phosphate',  '9');
INSERT INTO AUT_INGR_MAPPED_ALL(  CONCEPT_CODE,  CONCEPT_NAME,  CONCEPT_ID,  CONCEPT_NAME_2,  PRECEDENCE)VALUES(  '1473',  'Zinc',  43533102,  'Zinc Peroxide',  '10');
INSERT INTO AUT_INGR_MAPPED_ALL(  CONCEPT_CODE,  CONCEPT_NAME,  CONCEPT_ID,  CONCEPT_NAME_2,  PRECEDENCE)VALUES(  '1473',  'Zinc',  19097109,  'ZINC, CHELATED',  '11');
UPDATE AUT_INGR_MAPPED_ALL   SET CONCEPT_ID = 42899738,       CONCEPT_NAME_2 = 'Selenium Dioxide' WHERE CONCEPT_CODE = '5363' AND   CONCEPT_NAME = 'Selenium' AND   CONCEPT_ID = 966282 AND   CONCEPT_NAME_2 = 'Selenium' AND   PRECEDENCE = '1 ';
INSERT INTO AUT_INGR_MAPPED_ALL(  CONCEPT_CODE,  CONCEPT_NAME,  CONCEPT_ID,  CONCEPT_NAME_2,  PRECEDENCE)VALUES(  '5363',  'Selenium',  19112412,  'SELENIUM HVP CHELATE',  '2');
INSERT INTO AUT_INGR_MAPPED_ALL(  CONCEPT_CODE,  CONCEPT_NAME,  CONCEPT_ID,  CONCEPT_NAME_2,  PRECEDENCE)VALUES(  '5363',  'Selenium',  938061,  'selenium sulfide',  '3');
INSERT INTO AUT_INGR_MAPPED_ALL(  CONCEPT_CODE,  CONCEPT_NAME,  CONCEPT_ID,  CONCEPT_NAME_2,  PRECEDENCE)VALUES(  '5363',  'Selenium',  966282,  'Selenium',  '5');
UPDATE AUT_INGR_MAPPED_ALL   SET CONCEPT_ID = 19076414,       CONCEPT_NAME_2 = 'Potassium Acetate' WHERE CONCEPT_CODE = '30272' AND   CONCEPT_NAME = 'Potassium' AND   CONCEPT_ID = 19049024 AND   CONCEPT_NAME_2 = 'Potassium' AND   PRECEDENCE = '1 ';
INSERT INTO AUT_INGR_MAPPED_ALL(  CONCEPT_CODE,  CONCEPT_NAME,  CONCEPT_ID,  CONCEPT_NAME_2,  PRECEDENCE)VALUES(  '30272',  'Potassium',  19049059,  'Potassium Aspartate',  '2');
INSERT INTO AUT_INGR_MAPPED_ALL(  CONCEPT_CODE,  CONCEPT_NAME,  CONCEPT_ID,  CONCEPT_NAME_2,  PRECEDENCE)VALUES(  '30272',  'Potassium',  19027080,  'potassium bicarbonate',  '3');
INSERT INTO AUT_INGR_MAPPED_ALL(  CONCEPT_CODE,  CONCEPT_NAME,  CONCEPT_ID,  CONCEPT_NAME_2,  PRECEDENCE)VALUES(  '30272',  'Potassium',  19095091,  'potassium carbonate',  '4');
INSERT INTO AUT_INGR_MAPPED_ALL(  CONCEPT_CODE,  CONCEPT_NAME,  CONCEPT_ID,  CONCEPT_NAME_2,  PRECEDENCE)VALUES(  '30272',  'Potassium',  19049105,  'Potassium Chloride',  '5');
INSERT INTO AUT_INGR_MAPPED_ALL(  CONCEPT_CODE,  CONCEPT_NAME,  CONCEPT_ID,  CONCEPT_NAME_2,  PRECEDENCE)VALUES(  '30272',  'Potassium',  976545,  'potassium citrate',  '6');
INSERT INTO AUT_INGR_MAPPED_ALL(  CONCEPT_CODE,  CONCEPT_NAME,  CONCEPT_ID,  CONCEPT_NAME_2,  PRECEDENCE)VALUES(  '30272',  'Potassium',  19059547,  'Potassium gluconate',  '8');
INSERT INTO AUT_INGR_MAPPED_ALL(  CONCEPT_CODE,  CONCEPT_NAME,  CONCEPT_ID,  CONCEPT_NAME_2,  PRECEDENCE)VALUES(  '30272',  'Potassium',  19027308,  'Potassium Hydroxide',  '7');
INSERT INTO AUT_INGR_MAPPED_ALL(  CONCEPT_CODE,  CONCEPT_NAME,  CONCEPT_ID,  CONCEPT_NAME_2,  PRECEDENCE)VALUES(  '30272',  'Potassium',  19049909,  'Potassium Iodide',  '9');
INSERT INTO AUT_INGR_MAPPED_ALL(  CONCEPT_CODE,  CONCEPT_NAME,  CONCEPT_ID,  CONCEPT_NAME_2,  PRECEDENCE)VALUES(  '30272',  'Potassium',  927322,  'potassium nitrate',  '10');
INSERT INTO AUT_INGR_MAPPED_ALL(  CONCEPT_CODE,  CONCEPT_NAME,  CONCEPT_ID,  CONCEPT_NAME_2,  PRECEDENCE)VALUES(  '30272',  'Potassium',  45892826,  'potassium oxide',  '11');
INSERT INTO AUT_INGR_MAPPED_ALL(  CONCEPT_CODE,  CONCEPT_NAME,  CONCEPT_ID,  CONCEPT_NAME_2,  PRECEDENCE)VALUES(  '30272',  'Potassium',  19027362,  'potassium phosphate',  '12');
INSERT INTO AUT_INGR_MAPPED_ALL(  CONCEPT_CODE,  CONCEPT_NAME,  CONCEPT_ID,  CONCEPT_NAME_2,  PRECEDENCE)VALUES(  '30272',  'Potassium',  19027475,  'potassium sulfate',  '13');
INSERT INTO AUT_INGR_MAPPED_ALL(  CONCEPT_CODE,  CONCEPT_NAME,  CONCEPT_ID,  CONCEPT_NAME_2,  PRECEDENCE)VALUES(  '30272',  'Potassium',  19014213,  'POTASSIUM LACTATE',  '14');
--fix precise ingredients 
 update AUT_INGR_MAPPED_ALL a
 set concept_id = (select concept_id_2 from concept_relationship r
join concept on concept_id = a.concept_id and concept_class_id = 'Ingredient' and vocabulary_id = 'RxNorm'  and standard_concept is null and concept.invalid_reason is null and r.invalid_reason is null
 where a.concept_id = r.concept_id_1 and r.relationship_id = 'Form of')
 where exists ( select 1 from concept_relationship r
join concept on concept_id = a.concept_id and concept_class_id = 'Ingredient' and vocabulary_id = 'RxNorm'  and standard_concept is null and concept.invalid_reason is null and r.invalid_reason is null
 where a.concept_id = r.concept_id_1 and r.relationship_id = 'Form of') 
;
COMMIT
;