-- 1 Update latest_update field to new date
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.SetLatestUpdate(
	pVocabularyName			=> 'OSM',
	pVocabularyDate			=> (SELECT MIN(timestamp)::DATE FROM sources.osm),
	pVocabularyVersion		=> 'OSM Release '||(SELECT MIN(timestamp)::DATE FROM sources.osm),
	pVocabularyDevSchema    => 'DEV_OSM'
);
    PERFORM VOCABULARY_PACK.SetLatestUpdate(
	pVocabularyName			=> 'US Census',
	pVocabularyDate			=> TO_DATE('20170101','yyyymmdd'),
	pVocabularyVersion		=> 'US Census 2017 Release',
	pVocabularyDevSchema	=> 'DEV_OSM',
	pAppendVocabulary		=> TRUE
);
END $_$;

-- 2 Truncate all working tables AND remove indices
TRUNCATE TABLE concept_stage;
TRUNCATE TABLE concept_relationship_stage;
TRUNCATE TABLE concept_synonym_stage;
TRUNCATE TABLE pack_content_stage;
TRUNCATE TABLE drug_strength_stage;

-- 3 OSM Preliminary work
-- 3.1 Creation of osm_boundaries_hierarchy temporary table
DROP TABLE IF EXISTS osm_boundaries_hierarchy;
CREATE TABLE osm_boundaries_hierarchy
(	gid integer,
	id integer,
	country varchar(254),
	name varchar(254),
	enname varchar(254),
	locname varchar(254),
	offname varchar(254),
	boundary varchar(254),
	adminlevel integer,
	wikidata varchar(254),
	wikimedia varchar(254),
	timestamp varchar(254),
	note varchar(254),
	rpath varchar(254),
	iso3166_2 varchar(254),
    firts_ancestor_id integer,
    second_ancestor_id integer
);

-- 3.2 Creation of osm_excluded_objects temporary table
DROP TABLE IF EXISTS osm_excluded_objects;
CREATE TABLE osm_excluded_objects (LIKE osm_boundaries_hierarchy);

-- 3.3 Population of osm_boundaries_hierarchy temporary table
-- 3.3.1 id has the 1st position in rpath
INSERT INTO osm_boundaries_hierarchy
SELECT s.gid,
	   s.id,
	   s.country,
	   s.name,
	   s.enname,
	   s.locname,
	   s.offname,
	   s.boundary,
	   s.adminlevel,
	   s.wikidata,
	   s.wikimedia,
	   s.timestamp,
	   s.note,
	   s.rpath,
	   s.iso3166_2,
	   CASE WHEN s.adminlevel > s2.adminlevel THEN (regexp_split_to_array(s.rpath, ','))[2] :: INT
		   	WHEN s.adminlevel = s2.adminlevel AND s2.adminlevel > s3.adminlevel THEN (regexp_split_to_array(s.rpath, ','))[3] :: INT
		   	WHEN s.adminlevel = s2.adminlevel AND s2.adminlevel = s3.adminlevel AND s3.adminlevel > s4.adminlevel THEN (regexp_split_to_array(s.rpath, ','))[4] :: INT
		   	WHEN s.adminlevel = s2.adminlevel AND s2.adminlevel = s3.adminlevel AND s3.adminlevel = s4.adminlevel AND s4.adminlevel > s5.adminlevel THEN (regexp_split_to_array(s.rpath, ','))[5] :: INT
		   	WHEN s.adminlevel = 2 THEN (regexp_split_to_array(s.rpath, ','))[2] :: INT
            ELSE 1
		   	END as first_ancestor_id,
       CASE WHEN s.adminlevel > s2.adminlevel THEN (regexp_split_to_array(s.rpath, ','))[3] :: INT
		   	WHEN s.adminlevel = s2.adminlevel AND s2.adminlevel > s3.adminlevel THEN (regexp_split_to_array(s.rpath, ','))[4] :: INT
		   	WHEN s.adminlevel = s2.adminlevel AND s2.adminlevel = s3.adminlevel AND s3.adminlevel > s4.adminlevel THEN (regexp_split_to_array(s.rpath, ','))[5] :: INT
		   	WHEN s.adminlevel = s2.adminlevel AND s2.adminlevel = s3.adminlevel AND s3.adminlevel = s4.adminlevel AND s4.adminlevel > s5.adminlevel THEN (regexp_split_to_array(s.rpath, ','))[6] :: INT
		   	WHEN s.adminlevel = 2 THEN (regexp_split_to_array(s.rpath, ','))[2] :: INT
            ELSE 1
		   	END as second_ancestor_id

FROM sources.osm s

LEFT JOIN sources.osm s2
	ON	(regexp_split_to_array(s.rpath, ','))[2] :: INT = s2.id

LEFT JOIN sources.osm s3
	ON	(regexp_split_to_array(s.rpath, ','))[3] :: INT = s3.id

LEFT JOIN sources.osm s4
	ON	(regexp_split_to_array(s.rpath, ','))[4] :: INT = s4.id

LEFT JOIN sources.osm s5
	ON	(regexp_split_to_array(s.rpath, ','))[5] :: INT = s5.id

WHERE s.id = (regexp_split_to_array(s.rpath, ','))[1] :: INT;

-- 3.3.2 id has the 2nd position in rpath
INSERT INTO osm_boundaries_hierarchy
SELECT s.gid,
	   s.id,
	   s.country,
	   s.name,
	   s.enname,
	   s.locname,
	   s.offname,
	   s.boundary,
	   s.adminlevel,
	   s.wikidata,
	   s.wikimedia,
	   s.timestamp,
	   s.note,
	   s.rpath,
	   s.iso3166_2,
	   CASE WHEN s.adminlevel = s1.adminlevel AND s.adminlevel > s3.adminlevel THEN (regexp_split_to_array(s.rpath, ','))[3] :: INT
		   	WHEN s.adminlevel = s3.adminlevel AND s3.adminlevel > s4.adminlevel THEN (regexp_split_to_array(s.rpath, ','))[4] :: INT
			ELSE 1
		   	END as first_ancestor_id,
	   CASE WHEN s.adminlevel = s1.adminlevel AND s.adminlevel > s3.adminlevel THEN (regexp_split_to_array(s.rpath, ','))[4] :: INT
		   	WHEN s.adminlevel = s3.adminlevel AND s3.adminlevel > s4.adminlevel THEN (regexp_split_to_array(s.rpath, ','))[5] :: INT
			ELSE 1
		   	END as second_ancestor_id

FROM sources.osm s

LEFT JOIN sources.osm s1
	ON	(regexp_split_to_array(s.rpath, ','))[1] :: INT = s1.id

LEFT JOIN sources.osm s3
	ON	(regexp_split_to_array(s.rpath, ','))[3] :: INT = s3.id

LEFT JOIN sources.osm s4
	ON	(regexp_split_to_array(s.rpath, ','))[4] :: INT = s4.id

WHERE s.id = (regexp_split_to_array(s.rpath, ','))[2] :: INT
    AND s.id != (regexp_split_to_array(s.rpath, ','))[1] :: INT;

-- 3.3.3 id has the 3rd position in rpath
INSERT INTO osm_boundaries_hierarchy
SELECT s.gid,
	   s.id,
	   s.country,
	   s.name,
	   s.enname,
	   s.locname,
	   s.offname,
	   s.boundary,
	   s.adminlevel,
	   s.wikidata,
	   s.wikimedia,
	   s.timestamp,
	   s.note,
	   s.rpath,
	   s.iso3166_2,
	   CASE WHEN s.adminlevel = s1.adminlevel AND s.adminlevel = s2.adminlevel AND s.adminlevel > s4.adminlevel THEN (regexp_split_to_array(s.rpath, ','))[4] :: INT
		   	WHEN s.adminlevel = s1.adminlevel AND s.adminlevel = s2.adminlevel AND s.adminlevel = s4.adminlevel AND s.adminlevel > s5.adminlevel THEN (regexp_split_to_array(s.rpath, ','))[5] :: INT
		   	WHEN s.adminlevel = s1.adminlevel AND s.adminlevel = s2.adminlevel AND s.adminlevel = s4.adminlevel AND s.adminlevel = s5.adminlevel AND s.adminlevel > s10.adminlevel THEN (regexp_split_to_array(s.rpath, ','))[10] :: INT
			ELSE 1
		   	END as first_ancestor_id,
	   CASE WHEN s.adminlevel = s1.adminlevel AND s.adminlevel = s2.adminlevel AND s.adminlevel > s4.adminlevel THEN (regexp_split_to_array(s.rpath, ','))[5] :: INT
		   	WHEN s.adminlevel = s1.adminlevel AND s.adminlevel = s2.adminlevel AND s.adminlevel = s4.adminlevel AND s.adminlevel > s5.adminlevel THEN (regexp_split_to_array(s.rpath, ','))[6] :: INT
		   	WHEN s.adminlevel = s1.adminlevel AND s.adminlevel = s2.adminlevel AND s.adminlevel = s4.adminlevel AND s.adminlevel = s5.adminlevel AND s.adminlevel > s10.adminlevel THEN (regexp_split_to_array(s.rpath, ','))[11] :: INT
			ELSE 1
		   	END as second_ancestor_id

FROM sources.osm s

LEFT JOIN sources.osm s1
	ON	(regexp_split_to_array(s.rpath, ','))[1] :: INT = s1.id

LEFT JOIN sources.osm s2
	ON	(regexp_split_to_array(s.rpath, ','))[2] :: INT = s2.id

LEFT JOIN sources.osm s4
	ON	(regexp_split_to_array(s.rpath, ','))[4] :: INT = s4.id

LEFT JOIN sources.osm s5
	ON	(regexp_split_to_array(s.rpath, ','))[5] :: INT = s5.id

LEFT JOIN sources.osm s10
	ON	(regexp_split_to_array(s.rpath, ','))[10] :: INT = s10.id

WHERE s.id = (regexp_split_to_array(s.rpath, ','))[3] :: INT
    AND s.id != (regexp_split_to_array(s.rpath, ','))[1] :: INT;

-- 3.4 Geo objects clean-up
-- 3.4.1 Excluding the useless & no name objects & >2 count objects
INSERT INTO osm_excluded_objects
SELECT *
FROM osm_boundaries_hierarchy
WHERE (name in ('(Neighborhood)', '平野', '村元')
	OR name ilike '%-banchi'
    OR name ~* '(Bear River|Membertou|Millbrook|Acadia|Pictou|Sipekne''katik)( First Nation)'
    OR name ~* '^\d*$'
 --counterpart objects
	OR id in (8864148, 3960529, 8554903, 6890921, 341752, 341751, 8864429, 9078749, 627469724, 5776358, 7698707, 5815542, 8612543, 5812080, 9069117, 5289198, 7311462, 7311463, 4494994, 6596786, 112818, 4748341, 4755073,
	6824037, 9342059, 9182094)
--wrong objects
	OR id in (8481365, 9103732, 8476276, 6151013, 8283183, 9232301, 1790468, 8209939, 9122618, 3695278, 3185371, 7272976, 8118162, 6769003, 8864042, 3891647, 3883997, 8885026, 6188421, 7297827, 8325776, 5316707, 6190799,
	5317611, 5326982, 6634642, 8461523, 8274922, 5316882, 9256382, 9133146, 7516050, 9245215, 9236300, 7400296, 5668303, 7783258, 2618987, 1614222, 64630, 3807709, 2725328, 8864116, 3879477, 3879474, 8880546, 33117499,
	3881347, 3884282, 3884273, 8552675, 8885351, 8855702, 3011419, 5683043, 1969640, 6933036, 6891043, 7284117, 7311459, 7300811, 7389694, 2743802, 5476350, 112987, 133295, 3545808, 110743, 113000, 112361, 125443, 112421,
	112395, 8249855, 110692, 141058, 110825, 3460806, 110547, 7008694, 5999407, 8539828, 4618535, 4559221, 8277846, 8250162, 8288009, 8246892, 8540079, 8288011, 5543342, 8158336, 8534055, 7311466, 4536855,904177, 7037589, 8250156,
	8250158, 4603713, 4103691, 9107923, 6164994, 4002153, 8201989, 8199182, 6932977, 9215366, 4142039, 4142040, 9252171, 9302983, 6893574, 4079756, 9266970, 6164118, 3959632, 9182093, 8238110)
--wrong objects from different adminlevels, but equal geography
   OR id in (5808786, 3884168, 6210876, 6992297, 6355818, 5231035, 8402981, 6242282, 6992286, 4587947, 6891534, 8388202, 3856703, 7182975, 7159794, 5758866, 5758865, 7783254, 7815256, 7763854, 3565868, 7972501, 8101735, 5190251))
AND id <> 5012169;

--Delete from osm_boundaries_hierarchy
DELETE FROM osm_boundaries_hierarchy
WHERE id in (SELECT id FROM osm_excluded_objects);

-- 3.4.2 Delete counterpart objects with same geography but without wikidata
INSERT INTO osm_excluded_objects
SELECT *
FROM osm_boundaries_hierarchy
WHERE id in (
	SELECT MIN (a2.id)
	FROM osm_boundaries_hierarchy a1
	JOIN osm_boundaries_hierarchy a2
		ON a1.country = a2.country  AND a1.id != a2.id AND a1.name = a2.name AND a1.firts_ancestor_id = a2.firts_ancestor_id AND a1.adminlevel = a2.adminlevel
	JOIN sources.osm osm1
        ON a1.id = osm1.id
	JOIN sources.osm osm2
        ON a2.id = osm2.id
	WHERE osm1.geom :: devv5.geography = osm2.geom :: devv5.geography
		AND (a1.wikidata IS NOT NULL OR a1.wikimedia IS NOT NULL)
	GROUP BY a1.name
	HAVING COUNT (*) = 1
	)
AND id not in (SELECT id FROM osm_excluded_objects);

--Delete from osm_boundaries_hierarchy
DELETE FROM osm_boundaries_hierarchy
WHERE id in (SELECT id FROM osm_excluded_objects);

-- 3.4.3 Delete counterpart objects with same geography, but higher id
INSERT INTO osm_excluded_objects
SELECT *
FROM osm_boundaries_hierarchy
WHERE id in (
	SELECT MAX (a2.id)
	FROM osm_boundaries_hierarchy a1
	JOIN osm_boundaries_hierarchy a2
		ON a1.country = a2.country AND a1.id != a2.id AND a1.name = a2.name AND a1.firts_ancestor_id = a2.firts_ancestor_id AND a1.adminlevel = a2.adminlevel
	JOIN sources.osm osm1
        ON a1.id = osm1.id
	JOIN sources.osm osm2
        ON a2.id = osm2.id
	WHERE osm1.geom :: devv5.geography = osm2.geom :: devv5.geography
	GROUP BY a1.name
	HAVING COUNT (*) = 2
	)
AND id not in (SELECT id FROM osm_excluded_objects);

--Delete from osm_boundaries_hierarchy
DELETE FROM osm_boundaries_hierarchy
WHERE id in (SELECT id FROM osm_excluded_objects);

-- 3.4.4 Excluding the useless & no name & counterpart objects in UK
INSERT INTO osm_excluded_objects
SELECT *
FROM osm_boundaries_hierarchy
WHERE name in ('Glebe', 'Mullaghmore', 'Ballykeel', 'Tully', 'Cabragh', 'Tamlaght', 'Dromore', 'Ballymoney', 'Greenan', 'Gorteen')
AND country = 'GBR'
AND adminlevel = 10
AND NOT (id = 4452073 AND firts_ancestor_id not in (156393, 1119534)) --Glebe
AND NOT (id = 5416800 AND firts_ancestor_id not in (156393, 1117773)) --Glebe
AND NOT (id = 5481741 AND firts_ancestor_id not in (156393)) --Glebe
AND NOT (id = 5321265 AND firts_ancestor_id not in (156393, 1117773)) --Mullaghmore
AND NOT (id = 4167260 AND firts_ancestor_id not in (156393, 1119534)) --Ballykeel
AND NOT (id = 3631266 AND firts_ancestor_id not in (156393, 1118085)) --Tully
AND NOT (id = 5476251 AND firts_ancestor_id not in (156393)) --Cabragh
AND NOT (id = 3629081 AND firts_ancestor_id not in (156393)) --Tamlaght
AND NOT (id = 267762718 AND firts_ancestor_id not in (156393)) --Tamlaght
AND NOT (id in (267763207, 267762836) AND firts_ancestor_id not in (156393)) --Dromore
AND NOT (id = 1604307220 AND firts_ancestor_id not in (156393)) --Ballymoney
AND NOT (id = 4519571 AND firts_ancestor_id not in (156393, 1119534)) --Ballymoney
AND id not in (SELECT id FROM osm_excluded_objects);

--Delete from osm_boundaries_hierarchy
DELETE FROM osm_boundaries_hierarchy
WHERE id in (SELECT id FROM osm_excluded_objects);

ANALYSE osm_boundaries_hierarchy;

-- 3.4.5 Excluding the counterpart objects in UK
with counterparts as (
	SELECT a1.id as id_1,
		   a2.id as id_2
	FROM osm_boundaries_hierarchy a1
    JOIN osm_boundaries_hierarchy a2
        ON a1.country = a2.country AND a1.name = a2.name AND a1.firts_ancestor_id = a2.firts_ancestor_id AND a1.adminlevel = a2.adminlevel
	)

INSERT INTO osm_excluded_objects
SELECT *
FROM osm_boundaries_hierarchy bh
WHERE id in (
            SELECT id_2
			FROM counterparts
			WHERE id_1 in (
			              SELECT id_1
			              FROM counterparts c
			              GROUP BY id_1
			              HAVING COUNT(*) > 1
			              )
	)
AND wikidata IS NULL
AND wikimedia IS NULL
AND country = 'GBR'
AND adminlevel = 10
AND id NOT in (4868152, 5218754, 5225378, 2895940, 5160147)
AND id not in (SELECT id FROM osm_excluded_objects);

--Delete from osm_boundaries_hierarchy
DELETE FROM osm_boundaries_hierarchy
WHERE id in (SELECT id FROM osm_excluded_objects);

-- 3.5 Hierarchy fix
-- 3.5.1 Update firts_ancestor_id if parent was deleted
UPDATE osm_boundaries_hierarchy
SET firts_ancestor_id = second_ancestor_id
WHERE id in (
	SELECT a.id
	FROM osm_boundaries_hierarchy a
	JOIN osm_excluded_objects b
	ON a.firts_ancestor_id = b.id
	)
	AND country != 'CAN';

-- 3.5.2 Manual targeted updates
UPDATE osm_boundaries_hierarchy
SET firts_ancestor_id = 9150813
WHERE id = 9150812;

UPDATE osm_boundaries_hierarchy
SET firts_ancestor_id = 5884638
WHERE id = 206873;

-- 3.6 Delete remaining children of excluded objects
INSERT INTO osm_excluded_objects
SELECT *
FROM osm_boundaries_hierarchy
WHERE id in (
	SELECT a.id
	FROM osm_boundaries_hierarchy a
	JOIN osm_excluded_objects b
		ON a.firts_ancestor_id = b.id
	)
AND id not in (SELECT id FROM osm_excluded_objects);

--Delete from osm_boundaries_hierarchy
DELETE FROM osm_boundaries_hierarchy
WHERE id in (SELECT id FROM osm_excluded_objects);

-- 4 OSM Population of stages
-- 4.1 Population of concept_stage
INSERT INTO concept_stage
SELECT NULL AS concept_id,
	   name AS concept_name,
	   'Geography' AS domain_id,
	   'OSM' AS vocabulary_id,
	   CASE adminlevel :: INT
		   WHEN 2 THEN '2nd level'
		   WHEN 3 THEN '3rd level'
		   WHEN 4 THEN '4th level'
		   WHEN 5 THEN '5th level'
		   WHEN 6 THEN '6th level'
		   WHEN 7 THEN '7th level'
		   WHEN 8 THEN '8th level'
		   WHEN 9 THEN '9th level'
		   WHEN 10 THEN '10th level'
		   WHEN 11 THEN '11th level'
		   WHEN 12 THEN '12th level' END as concept_class_id,
	   'S' as standard_concept,
	   id as concept_code,
	   TO_DATE('19700101','yyyymmdd') as valid_start_date,
	   TO_DATE('20991231','yyyymmdd') as valid_end_date,
	   NULL as invalid_reason
FROM osm_boundaries_hierarchy;

-- 4.2 Population of concept_synonym_stage
-- 4.2.1 Using locname
INSERT INTO concept_synonym_stage
SELECT NULL as synonym_concept_id,
	   locname as synonym_name,
	   id as synonym_concept_code,
	   'OSM' as synonym_vocabulary_id,
	   CASE country
		   WHEN 'BEL' THEN 4182503
		   WHEN 'BRA' THEN 4181536
		   WHEN 'CAN' THEN 4180190
		   WHEN 'CHN' THEN 4182948
		   WHEN 'DEU' THEN 4182504
		   WHEN 'DNK' THEN 4180183
		   WHEN 'ESP' THEN 4182511
		   WHEN 'FRA' THEN 4180190
		   WHEN 'GBR' THEN 4180186
		   WHEN 'ISR' THEN CASE WHEN locname ~* 'א‬|ב|ג|ד|ה|ו|ז|ח|ט|י|מ|נ|ם|ן|פ|צ|ף|ץ|ס|ע|ק|ר|ש|ת|ל|כ|ך' THEN 4180047
		                        WHEN locname !~* 'א‬|ב|ג|ד|ה|ו|ז|ח|ט|י|מ|נ|ם|ן|פ|צ|ף|ץ|ס|ע|ק|ר|ש|ת|ל|כ|ך' THEN 4181374 ELSE 0 END
		   WHEN 'ITA' THEN 4182507
		   WHEN 'JPN' THEN 4181524
		   WHEN 'KOR' THEN 4175771
		   WHEN 'NLD' THEN 4182503
		   WHEN 'SAU' THEN 4181374
		   WHEN 'SWE' THEN 4175777
		   WHEN 'USA' THEN 4180186
		   WHEN 'ZAF' THEN 4180186
		   ELSE 0 END as language_concept_id
FROM osm_boundaries_hierarchy
WHERE locname != name;

-- 4.2.2 Using offname
INSERT INTO concept_synonym_stage
SELECT NULL as synonym_concept_id,
	   offname as synonym_name,
	   id as synonym_concept_code,
	   'OSM' as synonym_vocabulary_id,
	   CASE country
		   WHEN 'AUS' THEN 4180186
		   WHEN 'BEL' THEN 4182503
		   WHEN 'BRA' THEN 4181536
		   WHEN 'CAN' THEN 4180186
		   WHEN 'CHN' THEN 4182948
		   WHEN 'DEU' THEN 4182504
		   WHEN 'DNK' THEN 4180183
		   WHEN 'ESP' THEN 4182511
		   WHEN 'FRA' THEN 4180190
		   WHEN 'GBR' THEN 4180186
		   WHEN 'ISR' THEN CASE WHEN offname ~* 'א‬|ב|ג|ד|ה|ו|ז|ח|ט|י|מ|נ|ם|ן|פ|צ|ף|ץ|ס|ע|ק|ר|ש|ת|ל|כ|ך' THEN 4180047
		                        WHEN offname !~* 'א‬|ב|ג|ד|ה|ו|ז|ח|ט|י|מ|נ|ם|ן|פ|צ|ף|ץ|ס|ע|ק|ר|ש|ת|ל|כ|ך' THEN 4181374 ELSE 0 END
		   WHEN 'ITA' THEN 4182507
		   WHEN 'JPN' THEN 4181524
		   WHEN 'KOR' THEN 4175771
		   WHEN 'NLD' THEN 4182503
		   WHEN 'SAU' THEN 4181374
		   WHEN 'SWE' THEN 4175777
		   WHEN 'USA' THEN 4180186
		   WHEN 'ZAF' THEN 4180186
		   ELSE 0 END as language_concept_id
FROM osm_boundaries_hierarchy
WHERE   offname != name
	AND offname != locname;

-- 4.3 Population of concept_relationship_stage
-- 4.3.1 Is a relationship
INSERT INTO concept_relationship_stage
SELECT NULL as concept_id_1,
       NULL as concept_id_2,
       id as concept_code_1,
       firts_ancestor_id as concept_code_2,
       'OSM' as vocabulary_id_1,
       'OSM' as vocabulary_id_2,
       'Is a' as relationship_id,
       TO_DATE ('19700101', 'yyyymmdd') as valid_start_date,
       TO_DATE ('20991231', 'yyyymmdd') as valid_end_date,
       NULL as invalid_reason
FROM osm_boundaries_hierarchy
WHERE firts_ancestor_id != 0;

-- 5 US Census Preliminary work
-- 5.1 Creation of divisions temporary table with link to region
DROP TABLE IF EXISTS us_divisions;
CREATE TABLE us_divisions
(
	gid int,
	divisionce varchar(1),
	affgeoid varchar(10),
	geoid varchar(1),
	name varchar(100),
	lsad varchar(2),
	aland double precision,
	awater double precision,
	region_code varchar(50)
);

-- 5.2 Creation of us_states temporary table with link to division
DROP TABLE IF EXISTS us_states;
CREATE TABLE us_states
(
  state_concept_code varchar(50), --OSM concept_codes
  division_concept_code varchar(50) --US Census concept_code
);

-- 5.3 Population of divisions temporary table with link to region
INSERT INTO us_divisions
SELECT gid,
       divisionce,
       affgeoid,
       geoid,
       name,
       lsad,
       aland,
       awater,
       CASE
           WHEN name in ('New England' ,'Middle Atlantic')
                 THEN '0200000US1' --Region 1: Northeast
           WHEN name in ('East North Central', 'West North Central')
                 THEN '0200000US2' --Region 2: Midwest
           WHEN name in ('East South Central', 'West South Central', 'South Atlantic')
                 THEN '0200000US3' --Region 3: South
           WHEN name in ('Mountain', 'Pacific')
                 THEN '0200000US4' --Region 4: West
           ELSE '0'
           END as region_code
FROM sources.cb_us_division_500k;

-- 5.4 Population of us_states temporary table with link to divisions
INSERT INTO us_states
SELECT id,
       CASE WHEN name in ('Connecticut', 'Maine', 'Massachusetts', 'New Hampshire', 'Rhode Island', 'Vermont')
                 THEN '0300000US1' --Division 1: New England
            WHEN name in ('New Jersey', 'New York', 'Pennsylvania')
                 THEN '0300000US2' --Division 2: Middle Atlantic
            WHEN name in ('Illinois', 'Indiana', 'Michigan', 'Ohio', 'Wisconsin')
                 THEN '0300000US3' --Division 3: East North Central
            WHEN name in ('Iowa', 'Kansas', 'Minnesota', 'Missouri', 'Nebraska', 'North Dakota', 'South Dakota')
                 THEN '0300000US4' --Division 4: West North Central
            WHEN name in ('Delaware', 'District of Columbia', 'Florida', 'Georgia', 'Maryland', 'North Carolina', 'South Carolina', 'Virginia', 'West Virginia')
                 THEN '0300000US5' --Division 5: South Atlantic
            WHEN name in ('Alabama', 'Kentucky', 'Mississippi', 'Tennessee')
                 THEN '0300000US6' --Division 6: East South Central
            WHEN name in ('Arkansas', 'Louisiana', 'Oklahoma', 'Texas')
                 THEN '0300000US7' --Division 7: West South Central
            WHEN name in ('Arizona', 'Colorado', 'Idaho', 'Montana', 'Nevada', 'New Mexico', 'Utah', 'Wyoming')
                 THEN '0300000US8' --Division 8: Mountain
            WHEN name in ('Alaska', 'California', 'Hawaii', 'Oregon', 'Washington')
                 THEN '0300000US9' --Division 9: Pacific
            ELSE '0'
            END as division_concept_code
FROM osm_boundaries_hierarchy
WHERE country = 'USA'
  AND adminlevel = 4;

-- 6 US Census Population of stages
-- 6.1 Population of concept_stage
-- 6.1.1 US Census regions
INSERT INTO concept_stage
SELECT NULL as concept_id,
       name as concept_name,
       'Geography' as domain_id,
       'US Census' as vocabulary_id,
       'US Census Region' as concept_class_id,
       'S' as standard_concept,
       affgeoid as concept_code,
	   TO_DATE('19700101','yyyymmdd') as valid_start_date,
	   TO_DATE('20991231','yyyymmdd') as valid_end_date,
       null as invalid_reason
FROM sources.cb_us_region_500k;

-- 6.1.2 US Census divisions
INSERT INTO concept_stage
SELECT NULL as concept_id,
       name as concept_name,
       'Geography' as domain_id,
       'US Census' as vocabulary_id,
       'US Census Division' as concept_class_id,
       'S' as standard_concept,
       affgeoid as concept_code,
	   TO_DATE('19700101','yyyymmdd') as valid_start_date,
	   TO_DATE('20991231','yyyymmdd') as valid_end_date,
       null as invalid_reason
FROM sources.cb_us_division_500k;

-- 6.2 Population of concept_synonym_stage
-- 6.2.1 US Census regions
INSERT INTO concept_synonym_stage
SELECT NULL as synonym_concept_id,
	   'Region ' || geoid || ': ' || name as synonym_name,
	   affgeoid as synonym_concept_code,
	   'US Census' as synonym_vocabulary_id,
	   4180186 as language_concept_id
FROM sources.cb_us_region_500k;

-- 6.2.2 US Census divisions
INSERT INTO concept_synonym_stage
SELECT NULL as synonym_concept_id,
	   'Division ' || geoid || ': ' || name as synonym_name,
	   affgeoid as synonym_concept_code,
	   'US Census' as synonym_vocabulary_id,
	   4180186 as language_concept_id
FROM sources.cb_us_division_500k;

-- 6.3 Population of concept_relationship_stage
-- 6.3.1 US Census regions
INSERT INTO concept_relationship_stage
SELECT NULL as concept_id_1,
       NULL as concept_id_2,
	   affgeoid as concept_code_1,
       '148838' as concept_code_2, --United States
       'US Census' as vocabulary_id_1,
       'OSM' as vocabulary_id_2,
       'Is a' as relationship_id,
	   TO_DATE('19700101','yyyymmdd') as valid_start_date,
	   TO_DATE('20991231','yyyymmdd') as valid_end_date,
       NULL as invalid_reason
FROM sources.cb_us_region_500k;

-- 6.3.2 US Census divisions
INSERT INTO concept_relationship_stage
SELECT NULL as concept_id_1,
       NULL as concept_id_2,
       affgeoid as concept_code_1,
       region_code as concept_code_2,
       'US Census' as vocabulary_id_1,
       'US Census' as vocabulary_id_2,
       'Is a' as relationship_id,
	   TO_DATE('19700101','yyyymmdd') as valid_start_date,
	   TO_DATE('20991231','yyyymmdd') as valid_end_date,
       NULL as invalid_reason
FROM us_divisions;

-- 6.3.3 US states
INSERT INTO concept_relationship_stage
SELECT NULL as concept_id_1,
       NULL as concept_id_2,
       state_concept_code as concept_code_1,
       division_concept_code as concept_code_2,
       'OSM' as vocabulary_id_1,
       'US Census' as vocabulary_id_2,
       'Is a' as relationship_id,
	   TO_DATE('19700101','yyyymmdd') as valid_start_date,
	   TO_DATE('20991231','yyyymmdd') as valid_end_date,
       NULL as invalid_reason
FROM us_states
WHERE division_concept_code <> '0';

-- 7 Removal of OSM relationships between USA and division-bounded states
DELETE FROM concept_relationship_stage
WHERE concept_code_2 = '148838' --United States
AND concept_code_1 in (
        SELECT state_concept_code
        FROM us_states
        WHERE division_concept_code <> '0'
        );

-- 8 Clean-up
DROP TABLE osm_boundaries_hierarchy;
DROP TABLE osm_excluded_objects;
DROP TABLE us_states;
DROP TABLE us_divisions;