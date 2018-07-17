drop table if exists supplier;
create table supplier as
select distinct initcap(substring (concept_name,'\((.*)\)')) as supplier,concept_code
from concept_stage_sn
where concept_class_id in ('Trade Product Unit','Trade Product Pack','Containered Pack')
and substring (concept_name,'\((.*)\)') is not null
and not substring (concept_name,'\((.*)\)') ~ '[0-9]'
and not substring (concept_name,'\((.*)\)') ~ 'blood|virus|inert|D|accidental|CSL|paraffin|once|extemporaneous|long chain|perindopril|triglycerides|Night Tablet'
and length(substring (concept_name,'\(.*\)'))>5
and substring (lower(concept_name),'\((.*)\)')!='night'
and substring (lower(concept_name),'\((.*)\)')!='capsule';

update supplier
set supplier=regexp_replace(supplier,'Night\s','','g') where supplier like '%Night%';
update supplier
set supplier=regexp_replace(supplier,'Night\s','','g') where supplier like '%Night%';
UPDATE SUPPLIER   SET SUPPLIER = 'Pfizer' WHERE SUPPLIER = 'Pfizer Perth';

--add suppliers with abbreviations
drop table if exists supplier_2;
create table supplier_2 as
select distinct supplier from supplier;
INSERT INTO SUPPLIER_2 (SUPPLIER) VALUES('Apo');
INSERT INTO SUPPLIER_2 (SUPPLIER) VALUES('Sun');
INSERT INTO SUPPLIER_2 (SUPPLIER) VALUES('David Craig');
INSERT INTO SUPPLIER_2 (SUPPLIER) VALUES ('Parke Davis');
INSERT INTO SUPPLIER_2 (SUPPLIER ) VALUES ('Bioceuticals');
INSERT INTO SUPPLIER_2 (SUPPLIER ) VALUES ('Ipc');
INSERT INTO SUPPLIER_2 (SUPPLIER ) VALUES ('Rbx');
INSERT INTO SUPPLIER_2 (SUPPLIER ) VALUES ('Dakota');
INSERT INTO SUPPLIER_2 (SUPPLIER ) VALUES ('Dbl');
INSERT INTO SUPPLIER_2 (SUPPLIER ) VALUES ('Scp');
INSERT INTO SUPPLIER_2 (SUPPLIER ) VALUES ('Myx');
INSERT INTO SUPPLIER_2 (SUPPLIER ) VALUES ('Aft');
INSERT INTO SUPPLIER_2 (SUPPLIER ) VALUES ('Douglas');
INSERT INTO SUPPLIER_2 (SUPPLIER ) VALUES ('Omega');
INSERT INTO SUPPLIER_2 (SUPPLIER ) VALUES ('Bnm');
INSERT INTO SUPPLIER_2 (SUPPLIER ) VALUES ('Qv');
INSERT INTO SUPPLIER_2 (SUPPLIER ) VALUES ('Gxp');
INSERT INTO SUPPLIER_2 (SUPPLIER ) VALUES ('Fbm');
INSERT INTO SUPPLIER_2 (SUPPLIER ) VALUES ('Drla');
INSERT INTO SUPPLIER_2 (SUPPLIER ) VALUES ('Csl');
INSERT INTO SUPPLIER_2 (SUPPLIER ) VALUES ('Briemar');
INSERT INTO SUPPLIER_2 (SUPPLIER ) VALUES ('Nature''S Way');
INSERT INTO SUPPLIER_2 (SUPPLIER ) VALUES ('Sau');
INSERT INTO SUPPLIER_2 (SUPPLIER ) VALUES ('Drx');

alter table supplier_2
add concept_code varchar(255);

--using old codes from previous runs that have OMOP-codes 
update supplier_2 s2 
set concept_code=i.concept_code
from (select concept_code,concept_name from devv5.concept where concept_class_id='Supplier' and vocabulary_id='AMT') i
where i.concept_name=s2.supplier

update supplier_2
set concept_code=(select distinct concept_code from devv5.concept where concept_class_id='Supplier' and vocabulary_id='AMT' and concept_name='Independent Pharmacy Cooperative'),
supplier='IPC'
where supplier='Ipc';
update supplier_2
set concept_code=(select distinct concept_code from devv5.concept where concept_class_id='Supplier' and vocabulary_id='AMT' and concept_name='Sun Pharmaceutical')
where supplier='Sun';
update supplier_2
set concept_code=(select distinct concept_code from devv5.concept where concept_class_id='Supplier' and vocabulary_id='AMT' and concept_name='Boucher & Muir Pty Ltd'),
supplier='Boucher & Muir'
where supplier='Bnm';
update supplier_2
set concept_code=(select distinct concept_code from devv5.concept where concept_class_id='Supplier' and vocabulary_id='AMT' and concept_name='Pharma GXP'),
supplier='GXP'
where supplier='Gxp';
update supplier_2
set concept_code=(select distinct concept_code from devv5.concept where concept_class_id='Supplier' and vocabulary_id='AMT' and concept_name='FBM-PHARMA'),
supplier='FBM'
where supplier='Fbm';
update supplier_2
set concept_code=(select distinct concept_code from devv5.concept where concept_class_id='Supplier' and vocabulary_id='AMT' and concept_name='Douglas Pharmaceuticals')
where supplier='Douglas';
update supplier_2
set concept_code=(select distinct concept_code from devv5.concept where concept_class_id='Supplier' and vocabulary_id='AMT' and concept_name='DRX Pharmaceutical Consultants'),
supplier='DRX'
where supplier='Drx';
update supplier_2
set concept_code=(select distinct concept_code from devv5.concept where concept_class_id='Supplier' and vocabulary_id='AMT' and concept_name='Saudi pharmaceutical'),
supplier='Saudi'
where supplier='Sau';

/*
drop sequence if exists new_voc;
create sequence new_voc start with 528823;
*/

update supplier_2
set concept_code='OMOP'||nextval('new_voc')
where concept_code is null;

--creating first table for drug_strength
drop table if exists ds_0;
create table ds_0 as
select sourceid,destinationid, UNITID, VALUE from sources.amt_rf2_ss_strength_refset a
join sources.amt_sct2_rela_full_au b on referencedComponentId=b.id
;

-- parse units as they looks like 'mg/ml' etc.
drop table if exists unit;
CREATE TABLE unit AS
SELECT concept_name,
	concept_class_id,
	new_concept_class_id,
	concept_name AS concept_code,
	unitid
FROM (
	SELECT DISTINCT UNNEST(regexp_matches(regexp_replace(b.concept_name, '(/)(unit|each|application|dose)', '', 'g'), '[^/]+', 'g')) concept_name,
		'Unit' AS new_concept_class_id,
		concept_class_id,
		unitid
	FROM ds_0 a
	JOIN concept_stage_sn b ON a.unitid::TEXT = b.concept_code
	) AS s0;

drop table if exists form;
create table form as
select distinct a.CONCEPT_NAME, 'Dose Form' as NEW_CONCEPT_CLASS_ID,a.CONCEPT_CODE,a.CONCEPT_CLASS_ID from
concept_stage_sn a join sources.amt_sct2_rela_full_au b on a.concept_code=b.sourceid::text join concept_stage_sn  c on c.concept_Code=destinationid::text where a.concept_class_id='AU Qualifier' 
and a.concept_code not in 
(select distinct a.concept_code from 
concept_stage_sn a join sources.amt_rf2_full_relationships b on a.concept_code=b.sourceid::text join concept_stage_sn  c on c.concept_Code=destinationid::text where a.concept_class_id='AU Qualifier'
and initcap(c.concept_name) in ('Area Unit Of Measure','Biological Unit Of Measure','Composite Unit Of Measure','Descriptive Unit Of Measure','Mass Unit Of Measure','Microbiological Culture Unit Of Measure',
'Radiation Activity Unit Of Measure','Time Unit Of Measure','Volume Unit Of Measure','Type Of International Unit','Type Of Pharmacopoeial Unit'))
and lower(a.concept_name) not in (select lower(concept_name) from unit);

drop table if exists dcs_bn;
create table dcs_bn as 
select distinct * from concept_stage_sn  where CONCEPT_CLASS_ID='Trade Product';

update dcs_bn 
set concept_name=regexp_replace(concept_name,'\d+(\.\d+)?(\s\w+)?/\d+\s\w+$','','g') where concept_name ~ '\d+(\s\w+)?/\d+\s\w+$';
update dcs_bn 
set concept_name=regexp_replace(concept_name,'\d+(\.\d+)?(\s\w+)?/\d+\s\w+$','','g') where concept_name ~ '\d+(\s\w+)?/\d+\s\w+$';
update dcs_bn 
set concept_name=regexp_replace(concept_name,'(\d+/)?(\d+\.)?\d+/\d+(\.\d+)?$','','g') where concept_name ~ '(\d+/)?(\d+\.)?\d+/\d+(\.\d+)?$' and not concept_name ~ '-(\d+\.)?\d+/\d+$';
update dcs_bn 
set concept_name=regexp_replace(concept_name,'\d+(\.\d+)?/\d+(\.\d+)?(\s)?\w+$','','g') where concept_name ~ '\d+(\.\d+)?/\d+(\.\d+)?(\s)?\w+$';
update dcs_bn 
set concept_name=regexp_replace(concept_name,'\d+(\.\d+)?(\s)?(\w+)?(\s\w+)?/\d+(\.\d+)?(\s)?\w+$','','g') where concept_name ~ '\d+(\.\d+)?(\s)?(\w+)?(\s\w+)?/\d+(\.\d+)?(\s)?\w+$';
update dcs_bn 
set concept_name='Biostate' where concept_name like '%Biostate%';
update dcs_bn 
set concept_name='Feiba-NF' where concept_name like '%Feiba-NF%';
update dcs_bn 
set concept_name='Xylocaine' where concept_name like '%Xylocaine%';
update dcs_bn 
set concept_name='Canesten' where concept_name like '%Canesten%';
update dcs_bn 
set concept_name=rtrim(substring (concept_name,'([^0-9]+)[0-9]?'),'-') where concept_name like '%/%' and concept_name not like '%Neutrogena%';

update  dcs_bn
set concept_name=replace(concept_name,'(Pfizer (Perth))','Pfizer');
update  dcs_bn
set concept_name=regexp_replace(concept_name,' IM$| IV$','','g');

UPDATE DCS_BN
SET CONCEPT_NAME = 'Paracetamol Infant Drops' WHERE CONCEPT_NAME = 'Paracetamol Infant''s Drops';
UPDATE DCS_BN
   SET CONCEPT_NAME = 'Panadol Children''s 5 to 12 Years'
WHERE CONCEPT_NAME = 'Panadol Children''s 5 Years to 12 Years';
UPDATE DCS_BN
   SET CONCEPT_NAME = 'Panadol Children''s 1 to 5 Years'
WHERE CONCEPT_NAME = 'Panadol Children''s Elixir 1 to 5 Years';
UPDATE DCS_BN
   SET CONCEPT_NAME = 'Panadol Children''s 5 to 12 Years'
WHERE CONCEPT_NAME = 'Panadol Children''s Elixir 5 to 12 Years';

update  dcs_bn
set concept_name=regexp_replace(concept_name,'\(Day\)|\(Night\)|(Day and Night)$|(Day$)');

update  dcs_bn
set concept_name=trim(replace(regexp_replace(concept_name,'\d+|\.|%|\smg\s|\smg$|\sIU\s|\sIU$','','g'),'  ',' '))
where not concept_name ~ '-\d+' and length (concept_name)>3 and concept_name not like '%Years%'
;
update dcs_bn
set concept_name=trim(replace(concept_name,'  ',' '));

--the same names
UPDATE DCS_BN
   SET CONCEPT_NAME = 'Friar''s Balsam'
WHERE CONCEPT_CODE in ('696391000168106','688371000168108');


delete from dcs_bn where  CONCEPT_CODE in (select CONCEPT_CODE from non_drug);
delete from dcs_bn where concept_name ~* 'chloride|phosphate|paraffin|water| acid|toxoid|hydrate|sodium|glucose|castor| talc|^iodine|antivenom'
and not concept_name ~ ' APF| CD|Forte|Relief|Adult|Bio |BCP| XR|Plus|SR|Minims|HCTZ| BP|lasma-Lyte| EC|Min-I-Jet';

delete from dcs_bn where concept_name like '% mg%' or concept_name in ('Aciclovir Intravenous','Aciclovir IV','Acidophilus Bifidus','Risperidone','Ropivacaine','Piperacillin And Tazobactam','Perindopril And Indapamide','Paracetamol IV',
'Paracetamol Drops','Ondansetron Tabs','Omeprazole IV','Olanzapine IM',
'Copper', 'Chromium and Manganese','Menthol and Eucalyptus Inhalation','Menthol and Pine Inhalation','Chlorhexidine Hand Lotion','Brilliant Green and Crystal Violet Paint','Chlorhexidine Acetate and Cetrimide','Metoprolol IV','Metformin',
'Methadone Syrup','Levetiracetam IV','Latanoprost-Timolol','Wash','Cream','Oral Rehydration Salts','Gentian Alkaline Mixture','Decongestant','Zinc Compound','Ice','Pentamidine Isethionate','Bath Oil','Ringer"s','Sinus Rinse','Mercurochrome',
'Kaolin Mixture','Sulphadiazine','Pentamidine Isethionate','Zinc Compound','Vitamin B','Multivitamin and Minerals','Mycostatin Oral Drops','Paracetamol Drops','Nystatin Drops');

delete from dcs_bn where ( concept_name like '%artan % HCT%' or concept_name like '%Sodium% HCT%') and concept_name!='Asartan HCT';--delete combination of ingredients
delete from dcs_bn where lower(concept_name) in (select lower(Concept_name) from concept_stage_sn  where CONCEPT_CLASS_ID='AU Substance');
delete from dcs_bn where lower(concept_name) in (select lower(Concept_name) from devv5.concept  where CONCEPT_CLASS_ID='Ingredient');

--all kinds of compounds
DELETE
FROM DCS_BN
WHERE CONCEPT_CODE in ( '654241000168106','770691000168104','51957011000036109','65048011000036101','86596011000036106','43151000168105','60221000168109','734591000168106','59261000168100','3637011000036108','53153011000036106','664311000168109',
'65011011000036100','60481000168107','40851000168105','65135011000036103','53159011000036109','65107011000036104','76000011000036107','846531000168104','45161000168106','45161000168106','7061000168108','38571000168102')
;

DELETE FROM DCS_BN WHERE CONCEPT_NAME = 'Alendronate with Colecalciferol';
DELETE FROM DCS_BN WHERE CONCEPT_NAME = 'Aluminium Acetate BP';
DELETE FROM DCS_BN WHERE CONCEPT_NAME = 'Aluminium Acetate Aqueous APF';
DELETE FROM DCS_BN WHERE CONCEPT_NAME = 'Analgesic Calmative';
DELETE FROM DCS_BN WHERE CONCEPT_NAME = 'Analgesic and Calmative';
DELETE FROM DCS_BN WHERE CONCEPT_NAME = 'Antiseptic';
DELETE FROM DCS_BN WHERE CONCEPT_NAME = 'Betadine Antiseptic';
DELETE FROM DCS_BN WHERE CONCEPT_NAME = 'Calamine Oily';
DELETE FROM DCS_BN WHERE CONCEPT_NAME = 'Calamine Aqueous';
DELETE FROM DCS_BN WHERE CONCEPT_NAME = 'Cepacaine Oral Solution';
DELETE FROM DCS_BN WHERE CONCEPT_NAME = 'Clotrimazole Antifungal';
DELETE FROM DCS_BN WHERE CONCEPT_NAME = 'Clotrimazole Anti-Fungal';
DELETE FROM DCS_BN WHERE CONCEPT_NAME = 'Cocaine Hydrochloride and Adrenaline Acid Tartrate APF';
DELETE FROM DCS_BN WHERE CONCEPT_NAME = 'Codeine Phosphate Linctus APF';
DELETE FROM DCS_BN WHERE CONCEPT_NAME = 'Combantrin-1 with Mebendazole';
DELETE FROM DCS_BN WHERE CONCEPT_NAME = 'Cough Suppressant';
DELETE FROM DCS_BN WHERE CONCEPT_NAME = 'Decongestant Medicine';
DELETE FROM DCS_BN WHERE CONCEPT_NAME = 'Dermatitis and Psoriasis Relief';
DELETE FROM DCS_BN WHERE CONCEPT_NAME = 'Dexamphetamine Sulfate';
DELETE FROM DCS_BN WHERE CONCEPT_NAME = 'Diclofenac Sodium Anti-Inflammatory Pain Relief';
DELETE FROM DCS_BN WHERE CONCEPT_NAME = 'Disinfectant Hand Rub';
DELETE FROM DCS_BN WHERE CONCEPT_NAME = 'Emulsifying Ointment BP';
DELETE FROM DCS_BN WHERE CONCEPT_NAME = 'Epsom Salts';
DELETE FROM DCS_BN WHERE CONCEPT_NAME = 'Esomeprazole Hp';
DELETE FROM DCS_BN WHERE CONCEPT_NAME = 'Gentian Alkaline Mixture BP';
DELETE FROM DCS_BN WHERE CONCEPT_NAME = 'Homatropine Hydrobromide and Cocaine Hydrochloride APF';
DELETE FROM DCS_BN WHERE CONCEPT_NAME = 'Hypurin Isophane';
DELETE FROM DCS_BN WHERE CONCEPT_NAME = 'Ibuprofen and Codeine';
DELETE FROM DCS_BN WHERE CONCEPT_NAME = 'Ipecacuanha Syrup';
DELETE FROM DCS_BN WHERE CONCEPT_NAME = 'Kaolin Mixture BPC';
DELETE FROM DCS_BN WHERE CONCEPT_NAME = 'Kaolin and Opium Mixture APF';
DELETE FROM DCS_BN WHERE CONCEPT_NAME = 'Lamivudine and Zidovudine';
DELETE FROM DCS_BN WHERE CONCEPT_NAME = 'Laxative with Senna';
DELETE FROM DCS_BN WHERE CONCEPT_NAME = 'Magnesium Trisilicate Mixture BPC';
DELETE FROM DCS_BN WHERE CONCEPT_NAME = 'Magnesium Trisilicate and Belladonna Mixture BPC';
DELETE FROM DCS_BN WHERE CONCEPT_NAME = 'Menthol and Eucalyptus BP';
DELETE FROM DCS_BN WHERE CONCEPT_NAME = 'Mentholaire Vaporizer Fluid';
DELETE FROM DCS_BN WHERE CONCEPT_NAME = 'Methylated Spirit Specially';
DELETE FROM DCS_BN WHERE CONCEPT_NAME = 'Nasal Decongestant';
DELETE FROM DCS_BN WHERE CONCEPT_NAME = 'Natural Laxative with Softener';
DELETE FROM DCS_BN WHERE CONCEPT_NAME = 'Paraffin Soft White BP';
DELETE FROM DCS_BN WHERE CONCEPT_NAME = 'Perindopril and Indapamide';
DELETE FROM DCS_BN WHERE CONCEPT_NAME = 'Pholcodine Linctus APF';
DELETE FROM DCS_BN WHERE CONCEPT_NAME = 'Rh(D) Immunoglobulin-VF';
DELETE FROM DCS_BN WHERE CONCEPT_NAME = 'Ringer-Lactate';
DELETE FROM DCS_BN WHERE CONCEPT_NAME = 'Sodium Bicarbonate BP';
DELETE FROM DCS_BN WHERE CONCEPT_NAME = 'Sodium Bicarbonate APF';
DELETE FROM DCS_BN WHERE CONCEPT_NAME = 'Zinc, Starch and Talc Dusting Powder BPC';
DELETE FROM DCS_BN WHERE CONCEPT_NAME = 'Zinc, Starch and Talc Dusting Powder APF';
DELETE FROM DCS_BN WHERE CONCEPT_NAME = 'Zinc Paste APF';
UPDATE DCS_BN   SET CONCEPT_NAME = 'Abbocillin VK' WHERE CONCEPT_NAME = 'Abbocillin VK Filmtab';
UPDATE DCS_BN   SET CONCEPT_NAME = 'Acnederm' WHERE CONCEPT_NAME = 'Acnederm Foaming Wash';
UPDATE DCS_BN   SET CONCEPT_NAME = 'Actacode' WHERE CONCEPT_NAME = 'Actacode Linctus';
UPDATE DCS_BN   SET CONCEPT_NAME = 'Allersoothe' WHERE CONCEPT_NAME = 'Allersoothe Elixir';
UPDATE DCS_BN   SET CONCEPT_NAME = 'Amoxil' WHERE CONCEPT_NAME = 'Amoxil Paediatric Drops';
UPDATE DCS_BN   SET CONCEPT_NAME = 'Avelox' WHERE CONCEPT_NAME = 'Avelox IV';
UPDATE DCS_BN   SET CONCEPT_NAME = 'B-Dose' WHERE CONCEPT_NAME = 'B-Dose IV';
UPDATE DCS_BN   SET CONCEPT_NAME = 'Beconase' WHERE CONCEPT_NAME = 'Beconase Allergy and Hayfever Hour';
UPDATE DCS_BN   SET CONCEPT_NAME = 'Benzac AC' WHERE CONCEPT_NAME = 'Benzac AC Wash';
UPDATE DCS_BN   SET CONCEPT_NAME = 'Bepanthen' WHERE CONCEPT_NAME = 'Bepanthen Antiseptic';
UPDATE DCS_BN   SET CONCEPT_NAME = 'Cepacol' WHERE CONCEPT_NAME = 'Cepacol Antibacterial';
UPDATE DCS_BN   SET CONCEPT_NAME = 'Cepacol' WHERE CONCEPT_NAME = 'Cepacol Antibacterial Menthol and Eucalyptus';
UPDATE DCS_BN   SET CONCEPT_NAME = 'Citanest Dental' WHERE CONCEPT_NAME = 'Citanest with Adrenaline in Dental';
UPDATE DCS_BN   SET CONCEPT_NAME = 'Citanest Dental' WHERE CONCEPT_NAME = 'Citanest with Octapressin Dental';
UPDATE DCS_BN   SET CONCEPT_NAME = 'Colifoam' WHERE CONCEPT_NAME = 'Colifoam Rectal Foam';
UPDATE DCS_BN   SET CONCEPT_NAME = 'Coloxyl' WHERE CONCEPT_NAME = 'Coloxyl Drops';
UPDATE DCS_BN   SET CONCEPT_NAME = 'Coloxyl' WHERE CONCEPT_NAME = 'Coloxyl with Senna';
UPDATE DCS_BN   SET CONCEPT_NAME = 'Cordarone X' WHERE CONCEPT_NAME = 'Cordarone X Intravenous';
UPDATE DCS_BN   SET CONCEPT_NAME = 'Daktarin' WHERE CONCEPT_NAME = 'Daktarin Tincture';
UPDATE DCS_BN   SET CONCEPT_NAME = 'Demazin Cold Relief Paediatric' WHERE CONCEPT_NAME = 'Demazin Cold Relief Paediatric Oral Drops';
UPDATE DCS_BN   SET CONCEPT_NAME = 'Demazin Cold Relief' WHERE CONCEPT_NAME = 'Demazin Cold Relief Syrup';
UPDATE DCS_BN   SET CONCEPT_NAME = 'Demazin Paediatric' WHERE CONCEPT_NAME = 'Demazin Decongestant Paediatric';
UPDATE DCS_BN   SET CONCEPT_NAME = 'Dermaveen' WHERE CONCEPT_NAME = 'Dermaveen Moisturising';
UPDATE DCS_BN   SET CONCEPT_NAME = 'Dermaveen' WHERE CONCEPT_NAME = 'Dermaveen Shower & Bath Oil';
UPDATE DCS_BN   SET CONCEPT_NAME = 'Dermaveen' WHERE CONCEPT_NAME = 'Dermaveen Soap Free Wash';
UPDATE DCS_BN   SET CONCEPT_NAME = 'Dettol' WHERE CONCEPT_NAME = 'Dettol Antiseptic Cream';
UPDATE DCS_BN   SET CONCEPT_NAME = 'Dettol' WHERE CONCEPT_NAME = 'Dettol Antiseptic Liquid';
UPDATE DCS_BN   SET CONCEPT_NAME = 'Dettol' WHERE CONCEPT_NAME = 'Dettol Wound Wash';
UPDATE DCS_BN   SET CONCEPT_NAME = 'Difflam' WHERE CONCEPT_NAME = 'Difflam Anaesthetic, Antibacterial and Anti-Inflammatory';
UPDATE DCS_BN   SET CONCEPT_NAME = 'Difflam' WHERE CONCEPT_NAME = 'Difflam Anti-Inflammatory Lozenge';
UPDATE DCS_BN   SET CONCEPT_NAME = 'Difflam' WHERE CONCEPT_NAME = 'Difflam Anti-Inflammatory Solution';
UPDATE DCS_BN   SET CONCEPT_NAME = 'Difflam' WHERE CONCEPT_NAME = 'Difflam Anti-Inflammatory Throat';
UPDATE DCS_BN   SET CONCEPT_NAME = 'Difflam' WHERE CONCEPT_NAME = 'Difflam Cough Lozenge';
UPDATE DCS_BN   SET CONCEPT_NAME = 'Difflam Exrta Strength' WHERE CONCEPT_NAME = 'Difflam Extra Strength';
UPDATE DCS_BN   SET CONCEPT_NAME = 'Difflam' WHERE CONCEPT_NAME = 'Difflam Lozenge';
UPDATE DCS_BN   SET CONCEPT_NAME = 'Difflam' WHERE CONCEPT_NAME = 'Difflam Mouth';
UPDATE DCS_BN   SET CONCEPT_NAME = 'Difflam' WHERE CONCEPT_NAME = 'Difflam Sore Throat Gargle with Iodine Concentrate';
UPDATE DCS_BN   SET CONCEPT_NAME = 'Difflam-C' WHERE CONCEPT_NAME = 'Difflam-C Anti-Inflammatory Antiseptic';
UPDATE DCS_BN   SET CONCEPT_NAME = 'Dimetapp Chesty Cough' WHERE CONCEPT_NAME = 'Dimetapp Chesty Cough Elixir';
UPDATE DCS_BN   SET CONCEPT_NAME = 'Dimetapp Cold and Allergy' WHERE CONCEPT_NAME = 'Dimetapp Cold and Allergy Elixir';
UPDATE DCS_BN   SET CONCEPT_NAME = 'Dimetapp Cold and Allergy Extra Strength' WHERE CONCEPT_NAME = 'Dimetapp Cold and Allergy Extra Strength Drops';
UPDATE DCS_BN   SET CONCEPT_NAME = 'Dimetapp Cold and Flu Day Relief' WHERE CONCEPT_NAME = 'Dimetapp Cold and Flu Day Relief Liquid Cap';
UPDATE DCS_BN   SET CONCEPT_NAME = 'Dimetapp Cold and Flu Night Relief' WHERE CONCEPT_NAME = 'Dimetapp Cold and Flu Night Relief Liquid Cap';
UPDATE DCS_BN   SET CONCEPT_NAME = 'Dimetapp DM Cough and Cold' WHERE CONCEPT_NAME = 'Dimetapp DM Cough and Cold Drops';
UPDATE DCS_BN   SET CONCEPT_NAME = 'Dimetapp DM Cough and Cold' WHERE CONCEPT_NAME = 'Dimetapp DM Cough and Cold Elixir';
UPDATE DCS_BN   SET CONCEPT_NAME = 'Donnalix Infant' WHERE CONCEPT_NAME = 'Donnalix Infant Drops';
UPDATE DCS_BN   SET CONCEPT_NAME = 'Drixine' WHERE CONCEPT_NAME = 'Drixine Decongestant';
UPDATE DCS_BN   SET CONCEPT_NAME = 'Drixine' WHERE CONCEPT_NAME = 'Drixine Metered Pump Decongestant';
UPDATE DCS_BN   SET CONCEPT_NAME = 'Dry Tickly Cough' WHERE CONCEPT_NAME = 'Dry Tickly Cough Medicine';
UPDATE DCS_BN   SET CONCEPT_NAME = 'Dry Tickly Cough' WHERE CONCEPT_NAME = 'Dry Tickly Cough Mixture';
UPDATE DCS_BN   SET CONCEPT_NAME = 'Dulcolax SP' WHERE CONCEPT_NAME = 'Dulcolax SP Drops';
UPDATE DCS_BN   SET CONCEPT_NAME = 'Duro-Tuss Chesty Cough Forte' WHERE CONCEPT_NAME = 'Duro-Tuss Chesty Cough Liquid Forte';
UPDATE DCS_BN   SET CONCEPT_NAME = 'Duro-Tuss Chesty Cough plus Nasal Decongestant' WHERE CONCEPT_NAME = 'Duro-Tuss Chesty Cough Liquid plus Nasal Decongestant';
UPDATE DCS_BN   SET CONCEPT_NAME = 'Duro-Tuss Chesty Cough' WHERE CONCEPT_NAME = 'Duro-Tuss Chesty Cough Liquid Regular';
UPDATE DCS_BN   SET CONCEPT_NAME = 'Duro-Tuss Chesty Cough' WHERE CONCEPT_NAME = 'Duro-Tuss Chesty Cough Lozenge';
UPDATE DCS_BN   SET CONCEPT_NAME = 'Duro-Tuss Cough' WHERE CONCEPT_NAME = 'Duro-Tuss Cough Liquid Expectorant';
UPDATE DCS_BN   SET CONCEPT_NAME = 'Duro-Tuss Dry Cough plus Nasal Decongestant' WHERE CONCEPT_NAME = 'Duro-Tuss Dry Cough Liquid plus Nasal Decongestant';
UPDATE DCS_BN   SET CONCEPT_NAME = 'Duro-Tuss Dry Cough' WHERE CONCEPT_NAME = 'Duro-Tuss Dry Cough Liquid Regular';
UPDATE DCS_BN   SET CONCEPT_NAME = 'Duro-Tuss Dry Cough' WHERE CONCEPT_NAME = 'Duro-Tuss Dry Cough Lozenge';
UPDATE DCS_BN   SET CONCEPT_NAME = 'Emend' WHERE CONCEPT_NAME = 'Emend IV';
UPDATE DCS_BN   SET CONCEPT_NAME = 'Epilim' WHERE CONCEPT_NAME = 'Epilim Syrup';
UPDATE DCS_BN   SET CONCEPT_NAME = 'Eulactol' WHERE CONCEPT_NAME = 'Eulactol Antifungal';
UPDATE DCS_BN   SET CONCEPT_NAME = 'Febridol Infant' WHERE CONCEPT_NAME = 'Febridol Infant Drops';
UPDATE DCS_BN   SET CONCEPT_NAME = 'Fludara' WHERE CONCEPT_NAME = 'Fludara IV';
UPDATE DCS_BN   SET CONCEPT_NAME = 'Fucidin' WHERE CONCEPT_NAME = 'Fucidin IV';
UPDATE DCS_BN   SET CONCEPT_NAME = 'Idaprex' WHERE CONCEPT_NAME = 'Idaprex Arg';
UPDATE DCS_BN   SET CONCEPT_NAME = 'Imodium' WHERE CONCEPT_NAME = 'Imodium Caplet';
UPDATE DCS_BN   SET CONCEPT_NAME = 'Imogam' WHERE CONCEPT_NAME = 'Imogam Rabies Pasteurised';
UPDATE DCS_BN   SET CONCEPT_NAME = 'Lanoxin Paediatric' WHERE CONCEPT_NAME = 'Lanoxin Paediatric Elixir';
UPDATE DCS_BN   SET CONCEPT_NAME = 'Lemsip Cold and Flu' WHERE CONCEPT_NAME = 'Lemsip Cold and Flu Liquid Capsule';
UPDATE DCS_BN   SET CONCEPT_NAME = 'Lorastyne' WHERE CONCEPT_NAME = 'Lorastyne Syrup';
UPDATE DCS_BN   SET CONCEPT_NAME = 'Lucrin Depot' WHERE CONCEPT_NAME = 'Lucrin Depot -Month';
UPDATE DCS_BN   SET CONCEPT_NAME = 'Marcain Spinal' WHERE CONCEPT_NAME = 'Marcain Spinal Heavy';
UPDATE DCS_BN   SET CONCEPT_NAME = 'Marcain Dental' WHERE CONCEPT_NAME = 'Marcain with Adrenaline in Dental';
UPDATE DCS_BN   SET CONCEPT_NAME = 'Merieux' WHERE CONCEPT_NAME = 'Merieux Inactivated Rabies Vaccine';
UPDATE DCS_BN   SET CONCEPT_NAME = 'Mersyndol' WHERE CONCEPT_NAME = 'Mersyndol Caplet';
UPDATE DCS_BN   SET CONCEPT_NAME = 'MS Contin' WHERE CONCEPT_NAME = 'MS Contin Suspension';
UPDATE DCS_BN   SET CONCEPT_NAME = 'Mycil Healthy Feet Tinea' WHERE CONCEPT_NAME = 'Mycil Healthy Feet Tinea Cream';
UPDATE DCS_BN   SET CONCEPT_NAME = 'Mycil Healthy Feet Tinea' WHERE CONCEPT_NAME = 'Mycil Healthy Feet Tinea Powder';
UPDATE DCS_BN   SET CONCEPT_NAME = 'Nasonex' WHERE CONCEPT_NAME = 'Nasonex Aqueous';
UPDATE DCS_BN   SET CONCEPT_NAME = 'Neutrogena T/Gel Therapeutic Plus' WHERE CONCEPT_NAME = 'Neutrogena T/Gel Therapeutic Plus Shampoo';
UPDATE DCS_BN   SET CONCEPT_NAME = 'Neutrogena T/Gel Therapeutic' WHERE CONCEPT_NAME = 'Neutrogena T/Gel Therapeutic Shampoo';
UPDATE DCS_BN   SET CONCEPT_NAME = 'Nexium HP' WHERE CONCEPT_NAME = 'Nexium Hp';
UPDATE DCS_BN   SET CONCEPT_NAME = 'Nexium' WHERE CONCEPT_NAME = 'Nexium IV';
UPDATE DCS_BN   SET CONCEPT_NAME = 'Nucosef' WHERE CONCEPT_NAME = 'Nucosef Syrup';
UPDATE DCS_BN   SET CONCEPT_NAME = 'Nupentin' WHERE CONCEPT_NAME = 'Nupentin Tab';
UPDATE DCS_BN   SET CONCEPT_NAME = 'Nurocain Dental' WHERE CONCEPT_NAME = 'Nurocain with Adrenaline in Dental';
UPDATE DCS_BN   SET CONCEPT_NAME = 'Nurofen' WHERE CONCEPT_NAME = 'Nurofen Caplet';
UPDATE DCS_BN   SET CONCEPT_NAME = 'Nurofen' WHERE CONCEPT_NAME = 'Nurofen Liquid Capsule';
UPDATE DCS_BN   SET CONCEPT_NAME = 'Nurofen Zavance' WHERE CONCEPT_NAME = 'Nurofen Zavance Liquid Capsule';
UPDATE DCS_BN   SET CONCEPT_NAME = 'Panadol' WHERE CONCEPT_NAME = 'Panadol Caplet';
UPDATE DCS_BN   SET CONCEPT_NAME = 'Panadol Optizorb' WHERE CONCEPT_NAME = 'Panadol Caplet Optizorb';
UPDATE DCS_BN   SET CONCEPT_NAME = 'Panadol Gel' WHERE CONCEPT_NAME = 'Panadol Gel Cap';
UPDATE DCS_BN   SET CONCEPT_NAME = 'Panadol Gel' WHERE CONCEPT_NAME = 'Panadol Gel Tab';
UPDATE DCS_BN   SET CONCEPT_NAME = 'Panadol' WHERE CONCEPT_NAME = 'Panadol Mini Cap';
UPDATE DCS_BN   SET CONCEPT_NAME = 'Panadol Sinus PE Night and Day' WHERE CONCEPT_NAME = 'Panadol Sinus PE Night and Day Caplet';
UPDATE DCS_BN   SET CONCEPT_NAME = 'Panafen IB' WHERE CONCEPT_NAME = 'Panafen IB Mini Cap';
UPDATE DCS_BN   SET CONCEPT_NAME = 'Paracetamol Children''s' WHERE CONCEPT_NAME = 'Paracetamol Children''s Drops';
UPDATE DCS_BN   SET CONCEPT_NAME = 'Paracetamol Children''s 1 Month to 2 Years' WHERE CONCEPT_NAME = 'Paracetamol Children''s Drops 1 Month to 2 Years';
UPDATE DCS_BN   SET CONCEPT_NAME = 'Paracetamol Children''s 1 to 5 Years' WHERE CONCEPT_NAME = 'Paracetamol Children''s Elixir 1 to 5 Years';
UPDATE DCS_BN   SET CONCEPT_NAME = 'Paracetamol Children''s 5 to 12 Years' WHERE CONCEPT_NAME = 'Paracetamol Children''s Elixir 5 to 12 Years';
UPDATE DCS_BN   SET CONCEPT_NAME = 'Paracetamol Children''s 1 Month to 2 Years' WHERE CONCEPT_NAME = 'Paracetamol Children''s Infant Drops 1 Month to 2 Years';
UPDATE DCS_BN   SET CONCEPT_NAME = 'Paracetamol Children''s 1 to 5 Years' WHERE CONCEPT_NAME = 'Paracetamol Children''s Syrup 1 to 5 Years';
UPDATE DCS_BN   SET CONCEPT_NAME = 'Paracetamol Infant and Children 1 Month to 2 Years' WHERE CONCEPT_NAME = 'Paracetamol Drops Infants and Children 1 Month to 2 Years';
UPDATE DCS_BN   SET CONCEPT_NAME = 'Paracetamol Extra' WHERE CONCEPT_NAME = 'Paracetamol Extra Tabsule';
UPDATE DCS_BN   SET CONCEPT_NAME = 'Paracetamol Infant and Children 1 Month to 4 Years' WHERE CONCEPT_NAME = 'Paracetamol Infant and Children''s Drops 1 Month to 4 Years';
UPDATE DCS_BN   SET CONCEPT_NAME = 'Paracetamol Infant' WHERE CONCEPT_NAME = 'Paracetamol Infant Drops';
UPDATE DCS_BN   SET CONCEPT_NAME = 'Paracetamol Pain and Fever 1 Month to 2 Years' WHERE CONCEPT_NAME = 'Paracetamol Pain and Fever Drops 1 Month to 2 Years';
UPDATE DCS_BN   SET CONCEPT_NAME = 'Paralgin' WHERE CONCEPT_NAME = 'Paralgin Tabsule';
UPDATE DCS_BN   SET CONCEPT_NAME = 'Penta-vite' WHERE CONCEPT_NAME = 'Penta-vite Multivitamins with Iron for Kids 1 to 12 Years';
UPDATE DCS_BN   SET CONCEPT_NAME = 'Pholtrate' WHERE CONCEPT_NAME = 'Pholtrate Linctus';
UPDATE DCS_BN   SET CONCEPT_NAME = 'Polaramine' WHERE CONCEPT_NAME = 'Polaramine Syrup';
UPDATE DCS_BN   SET CONCEPT_NAME = 'Prefrin' WHERE CONCEPT_NAME = 'Prefrin Liquifilm';
UPDATE DCS_BN   SET CONCEPT_NAME = 'Proctosedyl' WHERE CONCEPT_NAME = 'Proctosedyl Rectal';
UPDATE DCS_BN   SET CONCEPT_NAME = 'Rhinocort' WHERE CONCEPT_NAME = 'Rhinocort Aqueous';
UPDATE DCS_BN   SET CONCEPT_NAME = 'Rynacrom' WHERE CONCEPT_NAME = 'Rynacrom Metered Dose';
UPDATE DCS_BN   SET CONCEPT_NAME = 'Sandoglobulin NF' WHERE CONCEPT_NAME = 'Sandoglobulin NF Liquid';
UPDATE DCS_BN   SET CONCEPT_NAME = 'Savlon' WHERE CONCEPT_NAME = 'Savlon Antiseptic Powder';
UPDATE DCS_BN   SET CONCEPT_NAME = 'Telfast Children' WHERE CONCEPT_NAME = 'Telfast Children''s Elixir';
UPDATE DCS_BN   SET CONCEPT_NAME = 'Theratears' WHERE CONCEPT_NAME = 'Theratears Liquid';
UPDATE DCS_BN   SET CONCEPT_NAME = 'Tinaderm' WHERE CONCEPT_NAME = 'Tinaderm Powder Spray';
UPDATE DCS_BN   SET CONCEPT_NAME = 'Uniclar' WHERE CONCEPT_NAME = 'Uniclar Aqueous';
UPDATE DCS_BN   SET CONCEPT_NAME = 'Vicks Cough' WHERE CONCEPT_NAME = 'Vicks Cough Syrup';
UPDATE DCS_BN   SET CONCEPT_NAME = 'Vicks Cough' WHERE CONCEPT_NAME = 'Vicks Cough Syrup for Chesty Coughs';
UPDATE DCS_BN   SET CONCEPT_NAME = 'Zarontin' WHERE CONCEPT_NAME = 'Zarontin Syrup';
UPDATE DCS_BN   SET CONCEPT_NAME = 'Zeldox' WHERE CONCEPT_NAME = 'Zeldox IM';
UPDATE DCS_BN   SET CONCEPT_NAME = 'Zithromax' WHERE CONCEPT_NAME = 'Zithromax IV';
UPDATE DCS_BN   SET CONCEPT_NAME = 'Zyprexa' WHERE CONCEPT_NAME = 'Zyprexa IM';

truncate table drug_concept_stage;
insert into drug_concept_stage (CONCEPT_NAME,VOCABULARY_ID,CONCEPT_CLASS_ID,STANDARD_CONCEPT,CONCEPT_CODE,POSSIBLE_EXCIPIENT,domain_id,VALID_START_DATE,VALID_END_DATE,INVALID_REASON, SOURCE_CONCEPT_CLASS_ID)
select CONCEPT_NAME, 'AMT', NEW_CONCEPT_CLASS_ID, null, CONCEPT_CODE, null, 'Drug', TO_DATE('20161101', 'yyyymmdd') as valid_start_date,TO_DATE('20991231', 'yyyymmdd') as valid_end_date, null,CONCEPT_CLASS_ID
from
(
select CONCEPT_NAME,'Ingredient' as NEW_CONCEPT_CLASS_ID,CONCEPT_CODE,CONCEPT_CLASS_ID from concept_stage_sn  where CONCEPT_CLASS_ID='AU Substance' and concept_code not in ('52990011000036102','48158011000036109')-- Aqueous Cream ,Cotton Wool
union 
select CONCEPT_NAME, 'Brand Name' as NEW_CONCEPT_CLASS_ID,CONCEPT_CODE,CONCEPT_CLASS_ID from dcs_bn
union
select CONCEPT_NAME, NEW_CONCEPT_CLASS_ID,CONCEPT_CODE,CONCEPT_CLASS_ID from form
union
select supplier,'Supplier',concept_code,'' from supplier_2
union
select CONCEPT_NAME, NEW_CONCEPT_CLASS_ID,initcap(CONCEPT_NAME),CONCEPT_CLASS_ID from unit
union
select CONCEPT_NAME,'Drug Product',CONCEPT_CODE,CONCEPT_CLASS_ID from concept_stage_sn  where CONCEPT_CLASS_ID in ('Containered Pack','Med Product Pack','Trade Product Pack','Med Product Unit','Trade Product Unit')
and CONCEPT_NAME not like '%(&)%' and (SELECT count(*) FROM regexp_matches(concept_name, '\sx\s', 'g'))<=1
and concept_name not like '%Trisequens, 28%'--exclude packs
union 
select concat(substr(CONCEPT_NAME,1,242),' [Drug Pack]') as concept_name,'Drug Product',CONCEPT_CODE,CONCEPT_CLASS_ID from concept_stage_sn  where 
CONCEPT_CLASS_ID in ('Containered Pack','Med Product Pack','Trade Product Pack','Med Product Unit','Trade Product Unit')
and (CONCEPT_NAME like '%(&)%' or  (SELECT count(*) FROM regexp_matches(concept_name, '\sx\s', 'g'))>1 or concept_name like '%Trisequens, 28%')
 ) as s0;

DELETE from DRUG_CONCEPT_STAGE WHERE CONCEPT_CODE in (select CONCEPT_CODE from non_drug);

insert into drug_concept_stage (CONCEPT_NAME,VOCABULARY_ID,CONCEPT_CLASS_ID,STANDARD_CONCEPT,CONCEPT_CODE,POSSIBLE_EXCIPIENT,domain_id,VALID_START_DATE,VALID_END_DATE,INVALID_REASON, SOURCE_CONCEPT_CLASS_ID)
select distinct CONCEPT_NAME, 'AMT', 'Device', 'S', CONCEPT_CODE, null,'Device', TO_DATE('20161101', 'yyyymmdd') as valid_start_date,TO_DATE('20991231', 'yyyymmdd') as valid_end_date, null,CONCEPT_CLASS_ID
from non_drug where concept_class_id not in ('AU Qualifier','AU Substance','Trade Product');

update drug_concept_stage 
set concept_name=INITCAP(concept_name)
where not (concept_class_id='Supplier' and length(concept_name)<4);--to fix chloride\Chloride

delete from drug_concept_stage --delete containers
where concept_code in (
select destinationid::text from concept_stage_sn  a join sources.amt_sct2_rela_full_au b on destinationid::text=a.concept_code
join concept_stage_sn  c on c.concept_code=sourceid::text
 where  typeid='30465011000036106');

update drug_concept_stage dcs
set standard_concept = 'S'
from (
  select concept_name, MIN(concept_code) m from drug_concept_stage WHERE concept_class_id in ('Ingredient','Dose Form','Brand Name','Unit') --and  source_concept_class_id not in ('Medicinal Product','Trade Product')
  group by concept_name having count(concept_name) >= 1
) d
where d.m=dcs.concept_code;

UPDATE drug_concept_stage
SET POSSIBLE_EXCIPIENT='1'
WHERE concept_name='Aqueous Cream';

delete from drug_concept_stage where lower(concept_name) in ('containered trade product pack','trade product pack','medicinal product unit of use','trade product unit of use','form','medicinal product pack','unit of use', 'unit of measure');

delete from drug_concept_stage where initcap(concept_name) in --delete all unnecessary concepts
('Alternate Strength Followed By Numerator/Denominator Strength','Alternate Strength Only','Australian Qualifier','Numerator/Denominator Strength','Numerator/Denominator Strength Followed By Alternate Strength','Preferred Strength Representation Type','Area Unit Of Measure','Square','Kbq','Dispenser Pack','Diluent','Tube','Tub','Carton','Unit Dose','Vial','Strip',
'Biological Unit Of Measure','Composite Unit Of Measure','Descriptive Unit Of Measure','Medicinal Product','Mass Unit Of Measure','Microbiological Culture Unit Of Measure','Radiation Activity Unit Of Measure','Time Unit Of Measure','Australian Substance','Medicinal Substance','Volume Unit Of Measure',
'Measure','Continuous','Dose','Ampoule','Bag','Bead','Bottle','Ampoule','Type Of International Unit','Type Of Pharmacopoeial Unit');

delete from drug_concept_stage --as RxNorm doesn't have diluents in injectable drugs we will also delete them
where (lower(concept_name) like '%inert%' or lower(concept_name) like '%diluent%') 
and concept_class_id='Drug Product' and lower(concept_name) not like '%tablet%';

analyze drug_concept_stage;

--create relationship from non-standard ingredients to standard ingredients 
drop table if exists non_S_ing_to_S;
create table non_S_ing_to_S as
select distinct b.concept_code,a.concept_code as s_concept_Code
from drug_concept_stage a
join drug_concept_stage b on lower(a.concept_name)=lower(b.concept_name)
where a.STANDARD_CONCEPT='S' and a.CONCEPT_CLASS_ID='Ingredient'
and b.STANDARD_CONCEPT is null and b.CONCEPT_CLASS_ID='Ingredient';
--create relationship from non-standard forms to standard forms
drop table if exists non_S_form_to_S;
create table non_S_form_to_S as
select distinct b.concept_code,a.concept_code as s_concept_Code
from drug_concept_stage a
join drug_concept_stage b on lower(a.concept_name)=lower(b.concept_name)
where a.STANDARD_CONCEPT='S' and a.CONCEPT_CLASS_ID='Dose Form'
and b.STANDARD_CONCEPT is null and b.CONCEPT_CLASS_ID='Dose Form';

--create relationship from non-standard bn to standard bn
drop table if exists non_S_bn_to_S;
create table non_S_bn_to_S as
select distinct b.concept_code,a.concept_code as s_concept_Code
from drug_concept_stage a
join drug_concept_stage b on lower(a.concept_name)=lower(b.concept_name)
where a.STANDARD_CONCEPT='S' and a.CONCEPT_CLASS_ID='Brand Name'
and b.STANDARD_CONCEPT is null and b.CONCEPT_CLASS_ID='Brand Name';
