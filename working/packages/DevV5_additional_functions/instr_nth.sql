CREATE OR REPLACE FUNCTION devv5.instr_nth (
  string text,
  string_to_search text,
  beg_index integer = 1,
  nth_appearance integer = 1
)
RETURNS integer AS
$body$
DECLARE
    pos integer;
    temp_str text;
BEGIN
    IF beg_index >= 0 THEN
    	temp_str := substring(string FROM beg_index);
        pos := COALESCE((array_positions(string_to_array(temp_str,null),string_to_search))[nth_appearance],0);
        IF pos = 0 THEN
        	RETURN 0;
        ELSE
        	RETURN pos + beg_index - 1;
        END IF;
    ELSE
    	temp_str := substring(reverse (string) FROM beg_index);
        pos = length(string) - (instr_nth(temp_str,string_to_search,abs(beg_index),nth_appearance) - 1);
        IF pos > length(string) then 
        	RETURN 0;
        ELSE
            RETURN pos;
        END IF;
    END IF;
END;
$body$
LANGUAGE 'plpgsql'
IMMUTABLE
RETURNS NULL ON NULL INPUT
SECURITY DEFINER
COST 100;