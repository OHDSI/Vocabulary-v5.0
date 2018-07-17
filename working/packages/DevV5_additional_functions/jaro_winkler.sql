--From http://alga42.blogspot.ru/2016/05/jaro-winkler-in-plpgsql.html
CREATE OR REPLACE FUNCTION devv5.jaro_winkler(ying TEXT, yang TEXT)
    RETURNS float8 AS $$
DECLARE
    ying_len integer := LENGTH(ying);
    yang_len integer := LENGTH(yang);
    min_len integer := GREATEST(ying_len, yang_len);
    search_range integer;
    ying_flags bool[];
    yang_flags bool[];
    common_chars float8 := 0;
    ying_ch TEXT;
    hi integer;
    low integer;
    trans_count integer := 0;
    weight float8;
    i integer;
    j integer;
    jj integer;
    k integer;
BEGIN

    IF ying_len = 0 OR yang_len = 0 THEN
        RETURN 0;
    END IF;

    search_range := (GREATEST(ying_len, yang_len) / 2) - 1;
    IF search_range < 0 THEN
        search_range := 0;
    END IF;
    FOR i IN 1 .. ying_len LOOP
        ying_flags[i] := false;
    END LOOP;
    FOR i IN 1 .. yang_len LOOP
        yang_flags[i] := false;
    END LOOP;

    -- looking only within search range, count & flag matched pairs
    FOR i in 1 .. ying_len LOOP
        ying_ch := SUBSTRING(ying FROM i for 1);
        IF i > search_range THEN
            low := i - search_range;
        ELSE
            low := 1;
        END IF;
        IF i + search_range <= yang_len THEN
            hi := i + search_range;
        ELSE
            hi := yang_len;
        END IF;
        <<inner>>
        FOR j IN low .. hi LOOP
            IF NOT yang_flags[j] AND
                 SUBSTRING(yang FROM j FOR 1) = ying_ch THEN
               ying_flags[i] := true;
               yang_flags[j] := true;
               common_chars := common_chars + 1;
               EXIT inner;
            END IF;
        END LOOP inner;
    END LOOP;
    -- short circuit if no characters match
    IF common_chars = 0 THEN
        RETURN 0;
    END IF;

    -- count transpositions
    k := 1;
    FOR i IN 1 .. ying_len LOOP
        IF ying_flags[i] THEN
            <<inner2>>
            FOR j IN k .. yang_len LOOP
                jj := j;
                IF yang_flags[j] THEN
                    k := j + 1;
                    EXIT inner2;
                END IF;
            END LOOP;
            IF SUBSTRING(ying FROM i FOR 1) <>
                    SUBSTRING(yang FROM jj FOR 1) THEN
                trans_count := trans_count + 1;
            END IF;
        END IF;
    END LOOP;
    trans_count := trans_count / 2;

    -- adjust for similarities in nonmatched characters
    weight := ((common_chars/ying_len + common_chars/yang_len +
               (common_chars-trans_count) / common_chars)) / 3;

    -- winkler modification: continue to boost if strings are similar
    IF weight > 0.7 AND ying_len > 3 AND yang_len > 3 THEN
       -- adjust for up to first 4 chars in common
       j := LEAST(min_len, 4);
       i := 1;
       WHILE i - 1 < j AND
             SUBSTRING(ying FROM i FOR 1) = SUBSTRING(yang FROM i FOR 1) LOOP
           i := i + 1;
       END LOOP;
       weight := weight + (i - 1) * 0.1 * (1.0 - weight);
    END IF;

    RETURN weight;

END;
$$
LANGUAGE plpgsql;