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

---------------------------------------------------------------------------------------------
-- 
---------------------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION cde_merge_group(pgroup_code character varying [])
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