-- CDE grouping
TRUNCATE TABLE cde_manual_group;
CREATE UNLOGGED TABLE cde_manual_group(
	sorce_code character varying(10),
	sorce_code_description character varying(255),
	sorce_vocabulary_id character varying(20),
	group_id integer,
	group_name character varying(255),
	group_code character varying []
	);

CREATE SEQUENCE seq_cde_manual_group_id INCREMENT 1 START 1 NO CYCLE;

SELECT * FROM cde_manual_group;

---------------------------------------------------------------------------------------------
-- Merge group function
---------------------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION cde_merge_group(pgroup_id int, pgroup_code character varying [])
RETURNS void
LANGUAGE plpgsql
AS $function$

/*
 * Example:
 * 		select * from cde_merge_group(2, ARRAY['{A15.5:ICD10}','Q12.0:KCD7'])
 */

BEGIN
	IF pgroup_id IS NULL OR NOT EXISTS(SELECT 1 FROM cde_manual_group WHERE group_id = pgroup_id)THEN
			RAISE EXCEPTION 'The supplied group_id parameter does not exist!';
	END IF;

	IF pgroup_code  IS NULL OR array_length(pgroup_code, 1) IS NULL THEN
		RAISE EXCEPTION 'The group code parameter is required!';
	END IF;


	UPDATE cde_manual_group
	SET group_code = ARRAY_CAT(pgroup_code, group_code)
	WHERE group_id = pgroup_id;
END
$function$;

select * from cde_merge_group (2, ARRAY['A18.027:ICD10CN','A18.025:ICD10CN']); -- Case 2 suppose to merge group 1 and 2. Group_id supposed to be '2' for both, group_code should be updated (two group_codes a supposed to be merged)

SELECT * FROM cde_manual_group;

---------------------------------------------------------------------------------------------
--
---------------------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION cde_merge_group(pgroup_id integer[])
RETURNS void
LANGUAGE plpgsql
AS $function$
	/*
	 * Example:
	 * 	select * from cde_merge_group(ARRAY[1,2,3,20])
	 */

BEGIN

	IF pgroup_id IS NULL OR array_length(pgroup_id, 1) IS NULL OR array_length(pgroup_id, 1) < 2 THEN
		RAISE EXCEPTION 'The group id parameter cannot be null, empty or contain less than one id!';
	END IF;

	UPDATE cde_manual_group t
	SET group_id = pgroup_id[1]
	WHERE t.group_id=ANY(pgroup_id)
	AND t.group_id <> pgroup_id[1];

END
$function$;

select * from cde_merge_group(ARRAY[1,2]); -- Case 2a works
SELECT * FROM cde_manual_group;

---------------------------------------------------------------------------------------------
--
---------------------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION cde_merge_group(pgroup_code character varying []) -- Case 2b works
RETURNS void
LANGUAGE plpgsql
AS $function$
	/*
	 * Example:
	 * 	select * from  cde_merge_group(ARRAY['A15.0:ICD10', 'A15.0:ICD10CM','A15:ICD10'])
	 */

DECLARE

BEGIN
	IF pgroup_code IS NULL OR array_length(pgroup_code, 1) IS NULL THEN
		RAISE EXCEPTION 'The group code parameter cannot be null or empty!';
	END IF;

	INSERT INTO  cde_manual_group (group_id,group_code)
	SELECT nextval('seq_cde_manual_group_id'), pgroup_code;

END
$function$;


---------------------------------------------------------------------------------------------
-- Split group function
---------------------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION cde_split_group(pgroup_id int, pgroup_code character varying [] DEFAULT NULL)
RETURNS void
LANGUAGE plpgsql
AS $function$
/*
 * Split the group into separate concepts
 * Example:
 * 	--Split group into a new group
 * 		select * from cde_split_group(15);
 *
 *  --Detach selected group code values into a new group
 *		select * from cde_split_group(15, ARRAY['A15.5:ICD10CM','A15.5:ICD10','A15.6:ICD10CM','A15.6:ICD10','A15.7:ICD10CM','A15.7:ICD10']);
 */

BEGIN

	IF NOT EXISTS(SELECT 1 FROM cde_manual_group WHERE group_id = pgroup_id)
	THEN
			RAISE EXCEPTION 'The supplied group_id does not exist!';
	END IF;

	IF pgroup_code IS NOT NULL AND ARRAY_LENGTH(pgroup_code, 1) > 1
		AND NOT EXISTS (SELECT 1 FROM cde_manual_group WHERE group_id = pgroup_id AND group_code @> pgroup_code)
	THEN
			RAISE EXCEPTION 'One or more of the elements sent in the group_code parameter does not match the content of group code for group id=%!',pgroup_id;
	END IF ;

	WITH cte_group_code AS (
		SELECT 	group_id,
				unnest (group_code) as group_code
		FROM cde_manual_group
		WHERE group_id = pgroup_id )
		INSERT INTO cde_manual_group (sorce_code,sorce_code_description,sorce_vocabulary_id,group_name,group_id,group_code)
		SELECT grm.sorce_code,
				grm.sorce_code_description,
				grm.sorce_vocabulary_id,
				grm.group_name,
				CASE
					WHEN pgroup_code IS NULL THEN NULL --split
					ELSE nextval('seq_cde_manual_group_id') -- detach
				END AS group_id,
				array_agg(cgc.group_code) AS group_code
		FROM cde_manual_group AS grm
		JOIN cte_group_code cgc ON grm.group_id  = cgc.group_id
		WHERE (pgroup_code IS NULL OR cgc.group_code = ANY (pgroup_code))
		GROUP BY grm.sorce_code,grm.sorce_code_description,grm.sorce_vocabulary_id,grm.group_name;


END;
$function$;

select * from cde_split_group(1); -- Case 1. Not working. Separate concept is also a group and should get new group_id, group_name (source_code_description) and group_code (source_code:vocabulary_id). The splited group shouldn't exist in the table
SELECT * FROM cde_manual_group;

select * from cde_split_group(3, ARRAY['Z96.7:ICD10CN','Z96.7:ICD10GM']); -- not working. the group is just splited


