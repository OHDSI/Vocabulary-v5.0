--vaccines, antibodies, microorganism preparations
--DROP TABLE vaccines;
CREATE TABLE vaccines AS (
with inclusion as (SELECT
        --general
        'vaccine|virus|Microb|Micr(o|)org|Bacter|Booster|antigen|serum|sera|antiserum|globin|globulin|strain|antibody|conjugate|split|live|attenuate|Adjuvant|cellular|inactivate|antitoxin|toxoid|Rho|whole( |-|)cell|polysaccharide'
        || '|' ||
        --vaccine abbrevations
        'DTaP|dTpa|tDPP|Tdap|MMR'
        || '|' ||
        -- influenza
        'influenza|Grippe|Gripe|Orthomyxov|flu$|H(a|)emagglutinin|Neuraminidase|(h\d{1,2}n\d{1,2}(?!\d))|IIV|LAIV'
        || '|' ||
        --botulism
        'botul|Clostrid|Klostrid|C\.b|C\. b'
        || '|' ||
        --gas-gangrene
        '(Gas).*(Gangrene)|(Gangrene).*(Gas)|C\. p|C\.p|perfringens|novyi|C\.n|C\. n|septicum|C\. s|C\.s|ramnosum|C\.r|C\. r'
        || '|' ||
        --staphylococcus
        'staphyloc|aureus|S\. a|S\. a|epidermidis|S\.e|S\. e'
        || '|' ||
        --cytomegalovirus
        'cytomegalov|cmv|herpes|HHV'
        || '|' ||
        --Coxiella Burnetii
        'Coxiella|burnetii|C\.b|C\. b|Q( |-|)fever'
        || '|' ||
        --anthrax
        'anthrax|antrax|Bacil|anthracis|B\.a|B\. a'
        || '|' ||
        --brucella
        'brucel|(undulant|Mediterranean|Bang).*(fever|disease)|(fever|disease).*(undulant|Mediterranean|Bang)|melitensis|B\.m|B\. m|abortus|B\.a|B\. a'
        || '|' ||
        --rubella
        'rubella|RuV|Rubiv|Togav|Wistar|(RA).*(27).*(3)'
        || '|' ||
        --mumps
        'mumps|rubulavirus|Jeryl|Lynn'
        || '|' ||
        --measles
        'measles|morbilliv|morbiliv|MeV|Ender|Edmonston'
        || '|' ||
        --poliomyelitis
        'polio|Enterovi|Mahoney|MEF( |-|)1|Saukett|Sabin|IPV|OPV'
        || '|' ||
        --diphtheria
        'dipht|Dipth|Coryne|Corine|C\.d|C\. d'
        || '|' ||
        --tetanus
        'tetan|C\.t|C\. t|Clostrid|Klostrid'
        || '|' ||
        --pertussis
        'pertus|Bord|B\. p|B\.p|Pertactin|Fimbri(a|)e|Filamentous'
        || '|' ||
        --hepatitis B
        'hepat|HBV|Orthohepad|Hepadn|ADW2|HBSAG|CpG|HepB|HBIG|Hepa( |-|)Gam'
        || '|' ||
        --hemophilus influenzae B
        'h(a|)emophilus|influenz|hib|H\.inf|H\. inf|Ross|HbOC|PRP(-| |)OMP|PRP(-| |)T|PRP(-| |)D'
        || '|' ||
        --Neisseria
        'mening|N\.m|N\. m|Neis|CRM197|MenB|MenC(-| |)TT|MenY(-| |)TT|MenD|MenAC|MenCY|PsA(-| |)TT|MenACWY|MPSV|MCV|Adhesin( |-|)A|Factor( |-|)H|Membrane Vesicle'
        || '|' ||
        --rabies
        'rabies|rhabdo|rabdo|lyssav|PM( |-|)1503|1503( |-|)3M'
        || '|' ||
        --papillomavirus
        'papilloma|HPV'
        || '|' ||
        --smallpox
        'smallpox|small-pox|Variola|Poxv|Orthopoxv|Vaccinia|VACV|VV|Cowpox|Monkeypox|Dryvax|Imvamune|ACAM2000|Calf lymph'
        || '|' ||
        --yellow fever
        'Yellow Fever|Yellow-Fever|Flaviv|17D( |-|)204'
        || '|' ||
        --varicella/zoster
        'varicel|zoster|herpes|chickenpox|VZV|HHV|chicken-pox|(Oka).*(Merck)|ZVL|RZV|VAR'
        || '|' ||
        --rota virus
        'rota( |-|)v|Reov|RV1|RV5'
        || '|' ||
        --hepatitis A
        'hepat|HAV|HM175|HepA'
        || '|' ||
        --typhoid
        'typh|Salmone|S\.t|S\. t|S\.e|S\. e|Ty21|ty( |-|)2'
        || '|' ||
        --encephalitis
        'encephalitis|tick|Flaviv|Japanese'
        || '|' ||
        --typhus exanthematicus
        'typhus|exanthematicus|Rickettsia|prowaz|R\.p|R\. p|Orientia|tsutsug|O\.t|O\. t|R\. ty|R\. ty|felis|typhi|R\. f|R\. f'
        || '|' ||
        --tuberculosis
        'tuberc|M\. t|M\.t|M\. b|M\.b|M\. a|M\.a|mycobacterium|bcg|Calmet|Guerin|bovis|africanum|Tice|Connaught|Montreal'
        || '|' ||
        --pneumococcus
        'pneumo|S\.pn|S\. pn|PCV|PPSV'
        || '|' ||
        --plague
        'plague|Yersinia|Y\.p|Y\. p'
        || '|' ||
        --cholera
        'choler|Vibri|V\.c|V\. c|Inaba|Ogawa'
),

exclusion as (SELECT
    'Oil|Oxybenzone|Homosalate|Vitamin|collagenase|sal[yi]c|Nitrate|alumin|octocry|pholcodine|Chlorhexidine|methyl|Methoxy|Anthranilate|Ethanol|Action|Allevyn' || '|' ||
    'Serapine|Seralin|Olive|Diarrhoea|Antihistamine|Antitussive|Arginaid|Ointment|Persist|Benadryl|Benserazide|Blistex|Liver|Minoxidil|Ablavar|Inhibitor|Sanitiser|Anti(-| |)Bacterial' || '|' ||
    'Anti(-| |)microbial|Brivaracetam|Calamine|Gold|Caustic|Varenicline|Vardenafil|Codral|Coldguard|Oestrogen|Crosvar|pad|Cymevene|Cold|Cough|Antiseptic|Elmendos|Emend' || '|' ||
    'Fluorescein|Horseradish|Glivec|glucose|Haemorrhoid|Heparin(?! bind)|Hepasol|Hepsera|Imbruvica|Lavender|Levosimendan|Stick|Energy|Mendeleev|Border|Nexavar|Valsartan|Nuvaring|Oruvail' || '|' ||
    'Seravit|Pevaryl|Alanine|Magnesium|Autohaler|Inhaler|Rivaroxaban|Simvar|Stivarga|Tamarindus|Tamiflu|Tenderwet|Tevaripiprazole|Truvada|Zyprexa|Meadowsweet|Gripe'
    )

select * from (

    SELECT DISTINCT dcs.*
    FROM drug_concept_stage dcs
    WHERE dcs.concept_name ~* (select * from inclusion)
        AND dcs.concept_name !~* (select * from exclusion)
        AND dcs.concept_class_id NOT IN ('Unit', 'Supplier')

    UNION

    SELECT DISTINCT dcs2.*
    FROM drug_concept_stage dcs1
    JOIN sources.amt_rf2_full_relationships fr
        ON dcs1.concept_code = fr.sourceid::text
    JOIN drug_concept_stage dcs2
        ON dcs2.concept_code = fr.destinationid::text
    WHERE dcs1.concept_name ~* (select * from inclusion)
        AND dcs1.concept_name !~* (select * from exclusion)
        AND dcs1.concept_class_id NOT IN ('Unit', 'Supplier')
        AND dcs2.concept_name !~* (select * from exclusion)
) a
WHERE concept_class_id IN (
                           'Ingredient'
                           ,'Drug Product'
                           ,'Device'
                           ,'Brand Name'
                          )
);
;


SELECT *
FROM vaccines;

--check if there are more vaccines (using irs)
--DROP TABLE vaccines_2;
CREATE TABLE vaccines_2 AS (

SELECT * FROM (

    SELECT DISTINCT dcs2.*
    FROM drug_concept_stage dcs

    JOIN internal_relationship_stage irs
        ON dcs.concept_code = irs.concept_code_1 OR dcs.concept_code = irs.concept_code_2

    JOIN drug_concept_stage dcs2
        ON dcs2.concept_code = irs.concept_code_1 OR dcs2.concept_code = irs.concept_code_2

    WHERE dcs.concept_code IN (SELECT concept_code FROM vaccines WHERE concept_code IS NOT NULL)
        AND dcs2.concept_class_id IN ('Drug Product', 'Ingredient', 'Device', 'Brand Name')

    UNION

    SELECT DISTINCT *
    FROM vaccines
    WHERE concept_class_id IN ('Drug Product', 'Ingredient', 'Device', 'Brand Name')
) as a

)
;

--additinal concepts added
SELECT DISTINCT *
FROM vaccines_2

EXCEPT

SELECT DISTINCT *
FROM vaccines
;

SELECT * FROM relationship_to_concept_bckp300817;

--vaccine attributes mapping review
SELECT DISTINCT
       dcs.concept_class_id,
       dcs.concept_name,
       NULL,
       mapping_type,
       precedence,
       concept_id_2,
       c.concept_code,
       c.concept_name,
       c.concept_class_id,
       c.standard_concept,
       c.invalid_reason,
       c.domain_id,
       c.vocabulary_id
FROM "mapping_review_backup_2020-03-31" m
JOIN drug_concept_stage dcs
    ON dcs.concept_code = m.concept_code_1
JOIN concept c
    ON m.concept_id_2 = c.concept_id
WHERE m.concept_code_1 IN (
                          SELECT concept_code
                          FROM vaccines_2
                          WHERE concept_class_id IN ('Ingredient'/*, 'Brand Name'*/)
                          )
;


--vaccine final mapping review
SELECT DISTINCT v.concept_name, v.concept_class_id, c2.*,
                CASE WHEN d5c.concept_name IS NULL THEN 'new' END AS new_concept
FROM vaccines_2 v
LEFT JOIN concept c1
    ON v.concept_code = c1.concept_code AND c1.vocabulary_id = 'AMT'
LEFT JOIN concept_relationship cr
    ON c1.concept_id = cr.concept_id_1 AND cr.relationship_id = 'Maps to' AND cr.invalid_reason IS NULL
LEFT JOIN concept c2
    ON cr.concept_id_2 = c2.concept_id
LEFT JOIN devv5.concept d5c
    ON v.concept_code = d5c.concept_code
        AND d5c.vocabulary_id = 'AMT'
;
