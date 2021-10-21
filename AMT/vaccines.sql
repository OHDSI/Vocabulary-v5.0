--vaccines, antibodies, microorganism preparations
DROP TABLE IF EXISTS vaccines_1;
CREATE TEMP TABLE vaccines_1
AS (
   WITH inclusion AS (
                     SELECT
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

        exclusion AS (
                     SELECT 'Oil|Oxybenzone|Homosalate|Vitamin|collagenase|sal[yi]c|Nitrate|alumin|octocry|pholcodine|Chlorhexidine|methyl|Methoxy|Anthranilate|Ethanol|Action|Allevyn' ||
                            '|' ||
                            'Serapine|Seralin|Olive|Diarrhoea|Antihistamine|Antitussive|Arginaid|Ointment|Persist|Benadryl|Benserazide|Blistex|Liver|Minoxidil|Ablavar|Inhibitor|Sanitiser|Anti(-| |)Bacterial' ||
                            '|' ||
                            'Anti(-| |)microbial|Brivaracetam|Calamine|Gold|Caustic|Varenicline|Vardenafil|Codral|Coldguard|Oestrogen|Crosvar|pad|Cymevene|Cold|Cough|Antiseptic|Elmendos|Emend' ||
                            '|' ||
                            'Fluorescein|Horseradish|Glivec|glucose|Haemorrhoid|Heparin(?! bind)|Hepasol|Hepsera|Imbruvica|Lavender|Levosimendan|Stick|Energy|Mendeleev|Border|Nexavar|Valsartan|Nuvaring|Oruvail' ||
                            '|' ||
                            'Seravit|Pevaryl|Alanine|Magnesium|Autohaler|Inhaler|Rivaroxaban|Simvar|Stivarga|Tamarindus|Tamiflu|Tenderwet|Tevaripiprazole|Truvada|Zyprexa|Meadowsweet|Gripe' ||
                            '|' ||
                            'Sodium|Canakinumab|Codeine|Insulin|Paracetamol|Doxylamine|progesteron|Atectura|Mevadol|estrogen|hydromorphone|bazedoxifene|Indacaterol|Mometasone|Orencia|Insulin|Truvelog'
                     )

select * from (

              SELECT DISTINCT dcs.*
              FROM drug_concept_stage dcs
              WHERE dcs.concept_name ~* (
                                        SELECT *
                                        FROM inclusion
                                        )
                AND dcs.concept_name !~* (
                                         SELECT *
                                         FROM exclusion
                                         )
                AND dcs.concept_class_id NOT IN ('Unit', 'Supplier')

              UNION

              SELECT DISTINCT dcs2.*
              FROM drug_concept_stage dcs1
              JOIN sources.amt_rf2_full_relationships fr
                  ON dcs1.concept_code = fr.sourceid::TEXT
              JOIN drug_concept_stage dcs2
                  ON dcs2.concept_code = fr.destinationid::TEXT
              WHERE dcs1.concept_name ~* (
                                         SELECT *
                                         FROM inclusion
                                         )
                AND dcs1.concept_name !~* (
                                          SELECT *
                                          FROM exclusion
                                          )
                AND dcs1.concept_class_id NOT IN ('Unit', 'Supplier')
                AND dcs2.concept_name !~* (
                                          SELECT *
                                          FROM exclusion
                                          )
              ) a
   WHERE concept_class_id IN (
                              'Ingredient', 'Drug Product', 'Device', 'Brand Name'
       )
   );


--check if there are more vaccines (using irs)
DROP TABLE IF EXISTS vaccines_2_irs;
CREATE TEMP TABLE vaccines_2_irs AS
    (
    SELECT DISTINCT dcs2.*
    FROM drug_concept_stage dcs

    JOIN internal_relationship_stage irs
        ON dcs.concept_code = irs.concept_code_1 OR
           dcs.concept_code = irs.concept_code_2

    JOIN drug_concept_stage dcs2
        ON dcs2.concept_code = irs.concept_code_1 OR
           dcs2.concept_code = irs.concept_code_2

    WHERE dcs.concept_code IN (
                              SELECT concept_code
                              FROM vaccines_1
                              WHERE concept_code IS NOT NULL
                              )
      AND dcs2.concept_class_id IN
          ('Drug Product', 'Ingredient', 'Device', 'Brand Name')
    )
;

-- union vaccines_1 and vaccines_2
DROP TABLE IF EXISTS vaccines;
CREATE TABLE vaccines AS
    (
    SELECT *
    FROM vaccines_2_irs

    UNION

    SELECT DISTINCT *
    FROM vaccines_1
    );


-- additional concepts in vaccines_2_irs
-- check for incorrect concepts and remove them by adding to the EXCLUSION set
-- in vaccines_1 table creation query
-- SELECT DISTINCT *
-- FROM vaccines_2_irs
--     EXCEPT
-- SELECT DISTINCT *
-- FROM vaccines_1
-- ;


--vaccine final mapping table
DROP TABLE IF EXISTS vaccines_to_map;
CREATE TABLE vaccines_to_map AS
    (
    WITH dosage     AS (
                       SELECT ds.drug_concept_code, ds.ingredient_concept_code,
                              concat_ws(': ', dcs.concept_name,
                                        concat_ws('/', amount_value || ' ' || amount_unit,
                                                  numerator_value || ' ' || numerator_unit,
                                                  denominator_value || ' ' ||
                                                  denominator_unit)) AS dosage
                       FROM ds_stage ds
                       JOIN drug_concept_stage dcs
                           ON ds.ingredient_concept_code = dcs.concept_code
                       WHERE drug_concept_code IN (
                                                  SELECT concept_code
                                                  FROM vaccines
                                                  )
                       ),
         dosage_agg AS (
                       SELECT drug_concept_code, string_agg(dosage, '; ' ORDER BY dosage) AS dosage
                       FROM dosage
                       GROUP BY drug_concept_code
                       )
    SELECT DISTINCT v.concept_code AS source_concept_code, v.concept_name AS source_concept_name,
                    v.concept_class_id AS source_concept_class_id, c2.*,
                    CASE WHEN d5c.concept_name IS NULL THEN 'new' END AS new_concept,
                    da.dosage
    FROM vaccines v
    LEFT JOIN concept c1
        ON v.concept_code = c1.concept_code AND c1.vocabulary_id = 'AMT'
    LEFT JOIN concept_relationship cr
        ON c1.concept_id = cr.concept_id_1 AND cr.relationship_id = 'Maps to' AND
           cr.invalid_reason IS NULL
    LEFT JOIN concept c2
        ON cr.concept_id_2 = c2.concept_id
    LEFT JOIN devv5.concept d5c
        ON v.concept_code = d5c.concept_code
            AND d5c.vocabulary_id = 'AMT'
    LEFT JOIN dosage_agg da
        ON v.concept_code = da.drug_concept_code
    WHERE v.concept_class_id <> 'Brand Name'
    ORDER BY v.concept_name
    )
;


-- removal stage

--get all attributes from IRS that are used nowhere else except for vaccines:
DROP TABLE IF EXISTS vaccine_attrs;
CREATE TABLE vaccine_attrs
AS (
   SELECT DISTINCT irs.concept_code_2 AS concept_code, dcs2.concept_name, dcs2.concept_class_id
   FROM vaccines v
   JOIN drug_concept_stage dcs
       ON v.concept_name = dcs.concept_name
   JOIN internal_relationship_stage irs
       ON irs.concept_code_1 = dcs.concept_code
   JOIN drug_concept_stage dcs2
       ON irs.concept_code_2 = dcs2.concept_code
   LEFT JOIN(
            SELECT DISTINCT concept_code_2
            FROM internal_relationship_stage irs
            JOIN drug_concept_stage dcs
                ON irs.concept_code_1 = dcs.concept_code
                    AND dcs.concept_name NOT IN (
                                                SELECT concept_name
                                                FROM vaccines
                                                )
            ) attr
       ON attr.concept_code_2 = irs.concept_code_2
   WHERE attr.concept_code_2 IS NULL
   )
;

-- add vaccine-only units
INSERT INTO vaccine_attrs
WITH vac           AS (
                      SELECT amount_unit, numerator_unit, denominator_unit
                      FROM ds_stage ds
                      JOIN drug_concept_stage dcs
                          ON ds.drug_concept_code = dcs.concept_code
                      JOIN vaccines v
                          ON dcs.concept_name = v.concept_name
                      ),
     non_vac       AS (
                      SELECT amount_unit, numerator_unit, denominator_unit
                      FROM ds_stage ds
                      JOIN drug_concept_stage dcs
                          ON ds.drug_concept_code = dcs.concept_code
                      WHERE ds.drug_concept_code NOT IN (
                                                        SELECT dcs.concept_code
                                                        FROM drug_concept_stage dcs
                                                        JOIN vaccines v
                                                            ON dcs.concept_name = v.concept_name
                                                        )
                      ),
     vac_units     AS (
                      SELECT DISTINCT amount_unit AS unit
                      FROM vac
                      UNION
                      SELECT DISTINCT numerator_unit AS unit
                      FROM vac
                      UNION
                      SELECT DISTINCT denominator_unit AS unit
                      FROM vac
                      ),
     non_vac_units AS (
                      SELECT DISTINCT amount_unit AS unit
                      FROM non_vac
                      UNION
                      SELECT DISTINCT numerator_unit AS unit
                      FROM non_vac
                      UNION
                      SELECT DISTINCT denominator_unit AS unit
                      FROM non_vac
                      )
SELECT v.*, dcs.concept_name, concept_class_id
FROM vac_units v
LEFT JOIN non_vac_units nv
    ON v.unit = nv.unit
JOIN drug_concept_stage dcs
    ON v.unit = dcs.concept_code
WHERE v.unit IS NOT NULL
  AND nv.unit IS NULL
;


--remove from irs
DELETE
FROM internal_relationship_stage
WHERE concept_code_1 IN (
                        SELECT DISTINCT irs.concept_code_1
                        FROM internal_relationship_stage irs
                        JOIN drug_concept_stage dcs
                            ON irs.concept_code_1 = dcs.concept_code
                        JOIN vaccines v
                            ON dcs.concept_name = v.concept_name
                        );


--remove from ds_stage
DELETE
FROM ds_stage
WHERE drug_concept_code IN (
                           SELECT DISTINCT ds.drug_concept_code
                           FROM ds_stage ds
                           JOIN drug_concept_stage dcs
                               ON ds.drug_concept_code = dcs.concept_code
                           JOIN vaccines v
                               ON dcs.concept_name = v.concept_name
                           );


--remove from pc_stage
DELETE
FROM pc_stage
WHERE pack_concept_code IN (
                           SELECT dcs.concept_code
                           FROM drug_concept_stage dcs
                           JOIN vaccines v
                               ON dcs.concept_name = v.concept_name
                           );

DELETE
FROM pc_stage
WHERE drug_concept_code IN (
                           SELECT dcs.concept_code
                           FROM drug_concept_stage dcs
                           JOIN vaccines v
                               ON dcs.concept_name = v.concept_name
                           );


--remove from _to_map tables
DELETE
FROM ingredient_to_map
WHERE name IN (
              SELECT concept_name
              FROM vaccine_attrs
              WHERE concept_class_id = 'Ingredient'
              );

DELETE
FROM brand_name_to_map
WHERE name IN (
              SELECT concept_name
              FROM vaccine_attrs
              WHERE concept_class_id = 'Brand Name'
              );

DELETE
FROM dose_form_to_map
WHERE name IN (
              SELECT concept_name
              FROM vaccine_attrs
              WHERE concept_class_id = 'Dose Form'
              );

DELETE
FROM supplier_to_map
WHERE name IN (
              SELECT concept_name
              FROM vaccine_attrs
              WHERE concept_class_id = 'Supplier'
              );

DELETE
FROM unit_to_map
WHERE name IN (
              SELECT concept_name
              FROM vaccine_attrs
              WHERE concept_class_id = 'Unit'
              );


--remove vaccine attributes from dcs
DELETE
FROM drug_concept_stage
WHERE concept_code IN (
                      SELECT concept_code
                      FROM drug_concept_stage
                      WHERE concept_code IN (
                                            SELECT concept_code
                                            FROM vaccine_attrs
                                            )
                      );



-- remove vaccine-related concepts from rtc
DELETE
FROM relationship_to_concept
WHERE concept_code_1 IN (
                        SELECT concept_code
                        FROM vaccines
                        );

DELETE
FROM relationship_to_concept
WHERE concept_code_1 IN (
                        SELECT concept_code
                        FROM vaccine_attrs
                        );


-- optional. Remove attrs from _mapped tables.
-- DELETE
-- FROM ingredient_mapped
-- WHERE lower(name) IN (
--                      SELECT lower(concept_name)
--                      FROM vaccine_attrs
--                      );
--
-- DELETE
-- FROM brand_name_mapped
-- WHERE lower(name) IN (
--                      SELECT lower(concept_name)
--                      FROM vaccine_attrs
--                      );
--
-- DELETE
-- FROM supplier_mapped
-- WHERE lower(name) IN (
--                      SELECT lower(concept_name)
--                      FROM vaccine_attrs
--                      );
--
-- DELETE
-- FROM dose_form_mapped
-- WHERE lower(name) IN (
--                      SELECT lower(concept_name)
--                      FROM vaccine_attrs
--                      );
--
-- DELETE
-- FROM unit_mapped
-- WHERE lower(name) IN (
--                      SELECT lower(concept_name)
--                      FROM vaccine_attrs
--                      );
