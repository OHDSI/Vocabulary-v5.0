-- CDE grouping
TRUNCATE TABLE cde_manual_group;
CREATE UNLOGGED TABLE cde_manual_group(
	source_code character varying(10),
	source_code_description character varying(255),
	source_vocabulary_id character varying(20),
	group_id integer,
	group_name character varying(255),
	group_code character varying []
	);

CREATE SEQUENCE seq_cde_manual_group_id INCREMENT 1 START 1 NO CYCLE;

SELECT * FROM cde_manual_group;

---------------------------------------------------------------------------------------------
-- Merge group function
---------------------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION cde_merge_group(pinput_table TEXT, pgroup_id int, pgroup_code character varying [])
RETURNS void
LANGUAGE plpgsql
AS $function$

/*
 * Example:
 * 		select * from cde_merge_group('cde_manual_group', 2, ARRAY['A15.5:ICD10','Q12.0:KCD7'])
 */

DECLARE
	z int4;
BEGIN
	
	EXECUTE FORMAT ($$
		SELECT COUNT(*) FROM %1$I WHERE group_id = %2$s;
		$$, pinput_table, pgroup_id) INTO z;
	
	IF pgroup_id IS NULL OR Z <= 0 THEN
			RAISE EXCEPTION 'The supplied group_id parameter does not exist!';
	END IF;


	IF pgroup_code  IS NULL OR array_length(pgroup_code, 1) IS NULL THEN
		RAISE EXCEPTION 'The group code parameter is required!';
	END IF;

	DROP TABLE IF EXISTS group_ids;
	CREATE TEMP TABLE group_ids(ids INT);

	EXECUTE FORMAT ($$
		INSERT INTO group_ids
		SELECT DISTINCT group_id
		FROM(
			SELECT group_id
			FROM %1$I
			WHERE group_id = pgroup_id
			UNION ALL
			SELECT group_id AS	group_id
			FROM %1$I	
			WHERE group_code && pgroup_code
		)AS T;
	$$, pinput_table);

	EXECUTE FORMAT ($$
		WITH cte_dource AS (
			SELECT pgroup_code AS group_id,source_vocabulary_id, group_name  , UNNEST (group_code) AS group_code
			FROM %1$I
			WHERE group_id in(
				SELECT ids
				FROM group_ids
			)
		), cte_meger AS(
			SELECT group_id AS id, group_name AS name, array_agg(group_code)  AS code 
			FROM (
				SELECT DISTINCT pgroup_id AS group_id, 
					FIRST_VALUE (group_name) over(ORDER BY source_vocabulary_id, LENGTH(group_name) DESC) AS group_name, 
					group_code
				FROM cte_dource
				)meger
			GROUP BY group_id, group_name
		)
		UPDATE %1$I
		SET group_id = id,
			group_name = name,
			group_code = code
		FROM cte_meger
		WHERE group_id IN (SELECT ids FROM group_ids);
	$$, pinput_table);

END
$function$;

select * from cde_merge_group (1, ARRAY['Z99.201:ICD10CN']);
select * from cde_merge_group (2, ARRAY['A18.027:ICD10CN','A18.025:ICD10CN']); -- Case 2 suppose to merge group 1 and 2. Group_id supposed to be '2' for both, group_code should be updated (two group_codes a supposed to be merged)

SELECT * FROM cde_manual_group;

---------------------------------------------------------------------------------------------
--
---------------------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION cde_merge_group(pinput_table TEXT, pgroup_id integer[])
RETURNS void
LANGUAGE plpgsql
AS $function$
	/*
	 * Example:
	 * 	select * from cde_merge_group('cde_manual_group',ARRAY[1,2,3,20])
	 */
DECLARE
	z int4;
BEGIN

	IF pgroup_id IS NULL OR array_length(pgroup_id, 1) IS NULL OR array_length(pgroup_id, 1) < 2 THEN
		RAISE EXCEPTION 'The group id parameter cannot be null, empty or contain less than one id!';
	END IF;

	EXECUTE FORMAT ($$
			UPDATE %1$I AS t
			SET group_id = $1[1]
			WHERE t.group_id=ANY($1)
			AND t.group_id <> $1[1];
		$$, pinput_table) USING pgroup_id;


END
$function$;

select * from cde_merge_group(ARRAY[1,2]); -- Case 2a works
SELECT * FROM cde_manual_group;

---------------------------------------------------------------------------------------------
--
---------------------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION cde_merge_group(pinput_table TEXT,pgroup_code character varying []) -- Case 2b works
RETURNS void
LANGUAGE plpgsql
AS $function$
	/*
	 * Example:
	 * 	select * from  cde_merge_group('cde_manual_group',ARRAY['A15.0:ICD10', 'A15.0:ICD10CM','A15:ICD10'])
	 */

DECLARE

BEGIN
	IF pgroup_code IS NULL OR array_length(pgroup_code, 1) IS NULL THEN
		RAISE EXCEPTION 'The group code parameter cannot be null or empty!';
	END IF;

	EXECUTE FORMAT ($$
			INSERT INTO %1$I (group_id,group_code)
			SELECT nextval('seq_cde_manual_group_id'), $1;
		$$, pinput_table) USING pgroup_code;


END
$function$;


---------------------------------------------------------------------------------------------
-- Split group function
---------------------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION cde_split_group(pinput_table TEXT,pgroup_id int, pgroup_code character varying [] DEFAULT NULL)
RETURNS void
LANGUAGE plpgsql
AS $function$
/*
 * Split the group into separate concepts
 * Example:
 * 	--Splits each of the elements that belong to the group_code field into a new groups
 * 		select * from cde_merge_group('cde_manual_group',2);
 *
 *  --Detach selected group code values into a new group
 *		select * from cde_merge_group('cde_manual_group',2, ARRAY['Z96.7:ICD10']);
 */
DECLARE
	V_SEQUENCE_VAL INT;
	z int4;
BEGIN
	
	EXECUTE FORMAT ($$
		SELECT COUNT(*) FROM %1$I WHERE group_id = %2$s;
		$$, pinput_table, pgroup_id) INTO z;
	
	IF pgroup_id IS NULL OR Z <= 0 THEN
			RAISE EXCEPTION 'The supplied group_id parameter does not exist!';
	END IF;

	EXECUTE FORMAT ($$
		SELECT COUNT(*) FROM %1$I WHERE group_id = %2$s AND group_code @> $1;
		$$, pinput_table, pgroup_id) USING pgroup_code INTO z;

	IF pgroup_code IS NOT NULL AND ARRAY_LENGTH(pgroup_code, 1) > 1 AND Z <= 0
	THEN
			RAISE EXCEPTION 'One or more of the elements sent in the group_code parameter does not match the content of group code for group id=%!',pgroup_id;
	END IF ;

	SELECT LAST_VALUE INTO V_SEQUENCE_VAL FROM seq_cde_manual_group_id;

	EXECUTE FORMAT ($$
			WITH cte_touples (group_id,group_code,group_name,tuples)AS(
			SELECT group_id,
					group_code, 
					group_name,
					regexp_split_to_array(group_code, ':') AS tuples
			FROM  (
				SELECT DISTINCT  group_id, group_name,unnest (group_code) as group_code
				FROM %1$I
				WHERE group_id = %2$s
				) AS T
			WHERE ($1 IS NULL OR T.group_code = ANY ($1))
		)
		INSERT INTO cde_manual_group
		SELECT c.source_code, 
				c.source_code_description,
				c.source_vocabulary_id,
				nextval('seq_cde_manual_group_id') AS group_id,
				c.group_name,
				c.group_code 
		FROM cte_touples t
		JOIN cde_manual_group c 
			ON t.tuples[1] = c.source_code
				AND t.tuples[2] = c.source_vocabulary_id 
				AND array_length(c.group_code, 1) <= 1;
		$$, pinput_table, pgroup_id) USING pgroup_code;


		
	IF (SELECT LAST_VALUE FROM seq_cde_manual_group_id) = V_SEQUENCE_VAL THEN
		RAISE EXCEPTION 'The supplied group_id cannot be splitted, verify that each of the group_code values exists individually!';
	END IF;
	
	IF pgroup_code IS NULL THEN
		EXECUTE FORMAT ($$
			DELETE FROM %1$I WHERE group_id = %2$s;
		$$, pinput_table, pgroup_id);
		
	END IF;

END;
$function$;

SELECT * FROM cde_manual_group;
select * from cde_split_group(2);
select * from cde_split_group(2, ARRAY['Z99.201:ICD10CN', 'Z99.2:ICD10']);


