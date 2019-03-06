-- 1 Update latest_update field to new date
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.SetLatestUpdate(
	pVocabularyName			=> 'OSM',
	pVocabularyDate			=> (SELECT MAX(timestamp)::DATE FROM sources.osm),
	pVocabularyVersion		=> 'OSM Release '||(SELECT MAX(timestamp)::DATE FROM sources.osm),
	pVocabularyDevSchema    => 'DEV_OSM'
);
END $_$;

-- 2 Truncate all working tables AND remove indices
TRUNCATE TABLE concept_stage;
TRUNCATE TABLE concept_relationship_stage;
TRUNCATE TABLE concept_synonym_stage;
TRUNCATE TABLE pack_content_stage;
TRUNCATE TABLE drug_strength_stage;

-- 3 Preliminary work
-- 3.1 Creation of boundaries_hierarchy temporary table
DROP TABLE IF EXISTS boundaries_hierarchy;

CREATE TABLE boundaries_hierarchy
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

-- 3.2 Creation of excluded_objects table
DROP TABLE IF EXISTS excluded_objects;

CREATE TABLE excluded_objects (LIKE boundaries_hierarchy);

-- 3.3 Population of boundaries_hierarchy table
-- 3.3.1 id has the 1st position in rpath
INSERT INTO boundaries_hierarchy
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
INSERT INTO boundaries_hierarchy
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
INSERT INTO boundaries_hierarchy
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
INSERT INTO excluded_objects
SELECT *
FROM boundaries_hierarchy
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

--Delete from boundaries_hierarchy
DELETE FROM boundaries_hierarchy
WHERE id in (SELECT id FROM excluded_objects);

-- 3.4.2 Delete counterpart objects with same geography but without wikidata
INSERT INTO excluded_objects
SELECT *
FROM boundaries_hierarchy
WHERE id in (
	SELECT MIN (a2.id)
	FROM boundaries_hierarchy a1
	JOIN boundaries_hierarchy a2
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
AND id not in (SELECT id FROM excluded_objects);

--Delete from boundaries_hierarchy
DELETE FROM boundaries_hierarchy
WHERE id in (SELECT id FROM excluded_objects);

-- 3.4.3 Delete counterpart objects with same geography, but higher id
INSERT INTO excluded_objects
SELECT *
FROM boundaries_hierarchy
WHERE id in (
	SELECT MAX (a2.id)
	FROM boundaries_hierarchy a1
	JOIN boundaries_hierarchy a2
		ON a1.country = a2.country AND a1.id != a2.id AND a1.name = a2.name AND a1.firts_ancestor_id = a2.firts_ancestor_id AND a1.adminlevel = a2.adminlevel
	JOIN sources.osm osm1
        ON a1.id = osm1.id
	JOIN sources.osm osm2
        ON a2.id = osm2.id
	WHERE osm1.geom :: devv5.geography = osm2.geom :: devv5.geography
	GROUP BY a1.name
	HAVING COUNT (*) = 2
	)
AND id not in (SELECT id FROM excluded_objects);

--Delete from boundaries_hierarchy
DELETE FROM boundaries_hierarchy
WHERE id in (SELECT id FROM excluded_objects);

-- 3.4.4 Excluding the useless & no name & counterpart objects in UK
INSERT INTO excluded_objects
SELECT *
FROM boundaries_hierarchy
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
AND id not in (SELECT id FROM excluded_objects);

--Delete from boundaries_hierarchy
DELETE FROM boundaries_hierarchy
WHERE id in (SELECT id FROM excluded_objects);

-- 3.4.5 Excluding the counterpart objects in UK
with counterparts as (
	SELECT a1.id as id_1,
		   a2.id as id_2
	FROM boundaries_hierarchy a1
    JOIN boundaries_hierarchy a2
        ON a1.country = a2.country AND a1.name = a2.name AND a1.firts_ancestor_id = a2.firts_ancestor_id AND a1.adminlevel = a2.adminlevel
	)

INSERT INTO excluded_objects
SELECT *
FROM boundaries_hierarchy bh
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
AND id not in (SELECT id FROM excluded_objects);

--Delete from boundaries_hierarchy
DELETE FROM boundaries_hierarchy
WHERE id in (SELECT id FROM excluded_objects);

-- 3.5 Hierarchy fix
-- 3.5.1 Update firts_ancestor_id if parent was deleted
UPDATE boundaries_hierarchy
SET firts_ancestor_id = second_ancestor_id
WHERE id in (
	SELECT a.id
	FROM boundaries_hierarchy a
	JOIN excluded_objects b
	ON a.firts_ancestor_id = b.id
	)
	AND country != 'CAN';

-- 3.5.2 Manual target updates
UPDATE boundaries_hierarchy
SET firts_ancestor_id = 9150813
WHERE id = 9150812;

UPDATE boundaries_hierarchy
SET firts_ancestor_id = 5884638
WHERE id = 206873;

-- 3.6 Delete remaining children of excluded objects
INSERT INTO excluded_objects
SELECT *
FROM boundaries_hierarchy
WHERE id in (
	SELECT a.id
	FROM boundaries_hierarchy a
	JOIN excluded_objects b
		ON a.firts_ancestor_id = b.id
	)
AND id not in (SELECT id FROM excluded_objects);

--Delete from boundaries_hierarchy
DELETE FROM boundaries_hierarchy
WHERE id in (SELECT id FROM excluded_objects);

-- 4 Population of stages
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
FROM boundaries_hierarchy;

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
FROM boundaries_hierarchy
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
FROM boundaries_hierarchy
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
FROM boundaries_hierarchy
WHERE firts_ancestor_id != 0;

-- 5 Clean up
DROP TABLE boundaries_hierarchy;
DROP TABLE excluded_objects;
