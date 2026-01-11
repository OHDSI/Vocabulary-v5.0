select *
from dev_atc.new_adm_r;

WITH CTE as (
                select
                    class_code,
                    CASE
                    WHEN adm_r = 'Chewing gum' THEN 'chewing gum'
                    WHEN adm_r IN ('Inhal', 'Inhal. powder', 'Inhal.aerosol', 'Inhal.powder', 'Inhal.solution') THEN 'inhalant'
                    WHEN adm_r = 'Instill.solution' THEN 'instillation solution'
                    WHEN adm_r = 'N' THEN 'nasal'
                    WHEN adm_r = 'O' THEN 'oral'
                    WHEN adm_r IN ('O,P', '"O,P"') THEN 'oral, parenteral'
                    WHEN adm_r = 'P' THEN 'parenteral'
                    WHEN adm_r = 'R' THEN 'rectal'
                    WHEN adm_r = 'SL' THEN 'sublingual'
                    WHEN adm_r = 'TD' THEN 'transdermal'
                    WHEN adm_r = 'V' THEN 'vaginal'
                    WHEN adm_r IN ('implant', 's.c. implant', 'urethral') THEN 'implant'
                    WHEN adm_r = 'intravesical' THEN 'intravesical'
                    WHEN adm_r = 'lamella' THEN 'lamella'
                    WHEN adm_r = 'ointment' THEN 'ointment'
                    WHEN adm_r = 'oral aerosol' THEN 'local oral'
                    ELSE adm_r
                END
                from sources.atc_codes
                WHERE adm_r != 'NA'),
                CTE2 as (SELECT *
                FROM sources.atc_codes
                WHERE class_code not in (select class_code from CTE)
                AND length (class_code) = 7)
SELECT *
FROM sources.atc_codes
WHERE class_code in (select left(class_code, 5) FROM CTE2)
ORDER BY
;

select *
from sources.atc_codes
where left(class_code,5) = 'A01AB';