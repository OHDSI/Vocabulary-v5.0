-- UPDATE SOURCE_TABLE SET BRAND_NAME = regexp_replace(AM, '\s\(*\d+[,.]*\d*\s*(mg|ml|g|%|I.E.|microg|mcg|Mikrogramm|mmol|ug).*');
UPDATE SOURCE_TABLE SET BRAND_NAME = regexp_replace(AM, '\s*\(*\d+[,./]*\d*[,./]*\d*[,./]*\d*\s*(UA|IR|Anti-Xa|Heparin-Antidot I\.E\.|Millionen IE|IE|Mio.? I.E.|Mega I.E.|SU|dpp|GBq|SQ-E|SE|ppm|mg|ml|g|%|I.E.|microg|mcg|Mikrogramm|mmol|ug|u).*','',1,0,'i');


UPDATE source_table SET brand_name = regexp_replace(brand_name, ' - .*$') WHERE brand_name like '% - %' AND NOT regexp_like(BRAND_NAME, ' - (1[ \-]{0,3}A[ \-]{0,3}Pharma|Q|JENAPHARM|Actavis|Pharma|Berlin-Chemie|Braun|Baxter|Rotexmedica|Eu Rho Pharma|Ratiopharm|Hexal|medica M|ANTEMET-EBS)');

UPDATE source_table SET brand_name = regexp_replace(brand_name, ' \(.*$') WHERE brand_name like '% (%';



UPDATE source_table SET brand_name = regexp_replace(brand_name, '[ ,]+(Dermatophago|Retardtabletten|Injekt|FilmTablette|Pulver|Suspension|Creme|Suppositorien|Kapseln).*$', '', 1,0, 'i') WHERE 
  regexp_like(brand_name, '[ ,]+(Dermatophago|Retardtabletten|Injekt|FilmTablette|Pulver|Suspension|Creme|Suppositorien|Kapseln).*$','i')
  AND NOT regexp_like(brand_name, '[ ,]+(Dermatophago|Retardtabletten|Injekt|FilmTablette|Pulver|Suspension|Creme|Suppositorien|Kapseln).*(1[ \-]{0,3}A[ \-]{0,3}Pharma|Q|JENAPHARM|Actavis|Pharma|Berlin-Chemie|Braun|Baxter|Rotexmedica|Eu Rho Pharma|Ratiopharm|Hexal|medica M|ANTEMET-EBS).*$', 'i');

-- remove all loesung-s (except for branded)
update source_table SET brand_name = 'Rivanol' WHERE brand_name = 'Rivanolloesung';

UPDATE source_table SET brand_name = regexp_replace(brand_name, '[ ,-]+[A-Z]*loesung.*$', '', 1,0, 'i') WHERE 
  regexp_like(brand_name, '[ ,-]+[A-Z]*loesung.*$','i')
  AND NOT regexp_like(brand_name, '[ ,-]+[A-Z]*loesung.*(1[ \-]{0,3}A[ \-]{0,3}Pharma|Q|JENAPHARM|Actavis|Pharma|Berlin-Chemie|Braun|Baxter|Rotexmedica|Eu Rho Pharma|Ratiopharm|Hexal|medica M|ANTEMET-EBS).*$', 'i');
  
UPDATE source_table SET brand_name = regexp_replace(brand_name, '[A-Z]*loesung.*$', '', 1,0, 'i') WHERE 
  regexp_like(brand_name, '[A-Z]*loesung.*$','i')
  AND NOT regexp_like(brand_name, '[A-Z]*loesung.*(1[ \-]{0,3}A[ \-]{0,3}Pharma|Q|JENAPHARM|Actavis|Pharma|Berlin-Chemie|Braun|Baxter|Rotexmedica|Eu Rho Pharma|Ratiopharm|Hexal|medica M|ANTEMET-EBS).*$', 'i');
  
  
UPDATE source_table SET brand_name = regexp_replace(brand_name, ' gegen .*$') WHERE brand_name like '% gegen %';  
UPDATE source_table SET brand_name = regexp_replace(brand_name, ' mit .*$') WHERE brand_name like '% mit %';  
  
UPDATE source_table SET brand_name = TRIM(trailing ',' FROM brand_name) WHERE brand_name like '%,';
UPDATE source_table SET brand_name = TRIM(trailing '/' FROM brand_name) WHERE brand_name like '%/';
UPDATE source_table SET brand_name = TRIM(trailing '-' FROM brand_name) WHERE brand_name like '%-';
UPDATE source_table SET brand_name = TRIM(trailing '.' FROM brand_name) WHERE brand_name like '%.';
UPDATE source_table SET brand_name = TRIM(brand_name) WHERE brand_name like '% ';

/*
SELECT COUNT(BRAND_NAME) FROM SOURCE_TABLE WHERE regexp_like(BRAND_NAME, '.*\d.*');
SELECT ENR, AM, BRAND_NAME FROM SOURCE_TABLE WHERE regexp_like(BRAND_NAME, '.*\d.*');

SELECT COUNT(BRAND_NAME) FROM SOURCE_TABLE WHERE BRAND_NAME = AM;
SELECT ENR, AM, BRAND_NAME FROM SOURCE_TABLE WHERE BRAND_NAME = AM;
*/
