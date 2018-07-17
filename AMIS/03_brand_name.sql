-- UPDATE SOURCE_TABLE SET BRAND_NAME = regexp_replace(AM, '\s\(*\d+[,.]*\d*\s*(mg|ml|g|%|I.E.|microg|mcg|Mikrogramm|mmol|ug).*','','g');
UPDATE SOURCE_TABLE
SET BRAND_NAME = regexp_replace(AM, '\s*\(*\d+[,./]*\d*[,./]*\d*[,./]*\d*\s*(UA|IR|Anti-Xa|Heparin-Antidot I\.E\.|Millionen IE|IE|Mio.? I.E.|Mega I.E.|SU|dpp|GBq|SQ-E|SE|ppm|mg|ml|g|%|I.E.|microg|mcg|Mikrogramm|mmol|ug|u).*', '', 'gi');
UPDATE source_table
SET brand_name = regexp_replace(brand_name, ' - .*$', '', 'g')
WHERE brand_name LIKE '% - %'
	AND NOT BRAND_NAME ~ ' - (1[ \-]{0,3}A[ \-]{0,3}Pharma|Q|JENAPHARM|Actavis|Pharma|Berlin-Chemie|Braun|Baxter|Rotexmedica|Eu Rho Pharma|Ratiopharm|Hexal|medica M|ANTEMET-EBS)';

UPDATE source_table
SET brand_name = regexp_replace(brand_name, ' \(.*$', '', 'g')
WHERE brand_name LIKE '% (%';

UPDATE source_table
SET brand_name = regexp_replace(brand_name, '[ ,]+(Dermatophago|Retardtabletten|Injekt|FilmTablette|Pulver|Suspension|Creme|Suppositorien|Kapseln).*$', '', 'gi')
WHERE brand_name ~* '[ ,]+(Dermatophago|Retardtabletten|Injekt|FilmTablette|Pulver|Suspension|Creme|Suppositorien|Kapseln).*$'
	AND NOT brand_name ~* '[ ,]+(Dermatophago|Retardtabletten|Injekt|FilmTablette|Pulver|Suspension|Creme|Suppositorien|Kapseln).*(1[ \-]{0,3}A[ \-]{0,3}Pharma|Q|JENAPHARM|Actavis|Pharma|Berlin-Chemie|Braun|Baxter|Rotexmedica|Eu Rho Pharma|Ratiopharm|Hexal|medica M|ANTEMET-EBS).*$';

-- remove all loesung-s (except for branded)
UPDATE source_table
SET brand_name = 'Rivanol'
WHERE brand_name = 'Rivanolloesung';

UPDATE source_table
SET brand_name = regexp_replace(brand_name, '[ ,-]+[A-Z]*loesung.*$', '', 'gi')
WHERE brand_name ~* '[ ,-]+[A-Z]*loesung.*$'
	AND NOT brand_name ~* '[ ,-]+[A-Z]*loesung.*(1[ \-]{0,3}A[ \-]{0,3}Pharma|Q|JENAPHARM|Actavis|Pharma|Berlin-Chemie|Braun|Baxter|Rotexmedica|Eu Rho Pharma|Ratiopharm|Hexal|medica M|ANTEMET-EBS).*$';

UPDATE source_table
SET brand_name = regexp_replace(brand_name, '[A-Z]*loesung.*$', '', 'gi')
WHERE brand_name ~* '[A-Z]*loesung.*$'
	AND NOT brand_name ~* '[A-Z]*loesung.*(1[ \-]{0,3}A[ \-]{0,3}Pharma|Q|JENAPHARM|Actavis|Pharma|Berlin-Chemie|Braun|Baxter|Rotexmedica|Eu Rho Pharma|Ratiopharm|Hexal|medica M|ANTEMET-EBS).*$';

UPDATE source_table
SET brand_name = regexp_replace(brand_name, ' gegen .*$', '', 'g')
WHERE brand_name LIKE '% gegen %';

UPDATE source_table
SET brand_name = regexp_replace(brand_name, ' mit .*$', '', 'g')
WHERE brand_name LIKE '% mit %';

UPDATE source_table
SET brand_name = TRIM(trailing ',' FROM brand_name)
WHERE brand_name LIKE '%,';

UPDATE source_table
SET brand_name = TRIM(trailing '/' FROM brand_name)
WHERE brand_name LIKE '%/';

UPDATE source_table
SET brand_name = TRIM(trailing '-' FROM brand_name)
WHERE brand_name LIKE '%-';

UPDATE source_table
SET brand_name = TRIM(trailing '.' FROM brand_name)
WHERE brand_name LIKE '%.';

UPDATE source_table
SET brand_name = TRIM(brand_name)
WHERE brand_name LIKE '% ';


/*
SELECT COUNT(BRAND_NAME) FROM SOURCE_TABLE WHERE BRAND_NAME ~ '.*\d.*';
SELECT ENR, AM, BRAND_NAME FROM SOURCE_TABLE WHERE BRAND_NAME ~ '.*\d.*';

SELECT COUNT(BRAND_NAME) FROM SOURCE_TABLE WHERE BRAND_NAME = AM;
SELECT ENR, AM, BRAND_NAME FROM SOURCE_TABLE WHERE BRAND_NAME = AM;
*/
