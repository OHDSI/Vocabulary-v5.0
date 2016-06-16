-- drop table stp_1;
-- drop table stp_2;
-- drop table stp_3;
-- drop table stp_tp1;

create table stp_1 as(
SELECT enr, wsstf, '1' as num, TPACK_1 as TPACK from source_table_pack where TPACK_1 is not NULL UNION
SELECT enr, wsstf, '2' as num, TPACK_2 as TPACK from source_table_pack where TPACK_2 is not NULL UNION
SELECT enr, wsstf, '3' as num, TPACK_3 as TPACK from source_table_pack where TPACK_3 is not NULL UNION
SELECT enr, wsstf, '4' as num, TPACK_4 as TPACK from source_table_pack where TPACK_4 is not NULL UNION
SELECT enr, wsstf, '5' as num, TPACK_5 as TPACK from source_table_pack where TPACK_5 is not NULL UNION
SELECT enr, wsstf, '6' as num, TPACK_6 as TPACK from source_table_pack where TPACK_6 is not NULL UNION
SELECT enr, wsstf, '7' as num, TPACK_7 as TPACK from source_table_pack where TPACK_7 is not NULL UNION
SELECT enr, wsstf, '8' as num, TPACK_8 as TPACK from source_table_pack where TPACK_8 is not NULL UNION
SELECT enr, wsstf, '9' as num, TPACK_9 as TPACK from source_table_pack where TPACK_9 is not NULL UNION
SELECT enr, wsstf, '10' as num, TPACK_10 as TPACK from source_table_pack where TPACK_10 is not NULL UNION
SELECT enr, wsstf, '11' as num, TPACK_11 as TPACK from source_table_pack where TPACK_11 is not NULL UNION
SELECT enr, wsstf, '12' as num, TPACK_12 as TPACK from source_table_pack where TPACK_12 is not NULL UNION
SELECT enr, wsstf, '13' as num, TPACK_13 as TPACK from source_table_pack where TPACK_13 is not NULL UNION
SELECT enr, wsstf, '14' as num, TPACK_14 as TPACK from source_table_pack where TPACK_14 is not NULL UNION
SELECT enr, wsstf, '15' as num, TPACK_15 as TPACK from source_table_pack where TPACK_15 is not NULL UNION
SELECT enr, wsstf, '16' as num, TPACK_16 as TPACK from source_table_pack where TPACK_16 is not NULL UNION
SELECT enr, wsstf, '17' as num, TPACK_17 as TPACK from source_table_pack where TPACK_17 is not NULL UNION
SELECT enr, wsstf, '18' as num, TPACK_18 as TPACK from source_table_pack where TPACK_18 is not NULL UNION
SELECT enr, wsstf, '19' as num, TPACK_19 as TPACK from source_table_pack where TPACK_19 is not NULL UNION
SELECT enr, wsstf, '20' as num, TPACK_20 as TPACK from source_table_pack where TPACK_20 is not NULL UNION
SELECT enr, wsstf, '21' as num, TPACK_21 as TPACK from source_table_pack where TPACK_21 is not NULL UNION
SELECT enr, wsstf, '22' as num, TPACK_22 as TPACK from source_table_pack where TPACK_22 is not NULL UNION
SELECT enr, wsstf, '23' as num, TPACK_23 as TPACK from source_table_pack where TPACK_23 is not NULL UNION
SELECT enr, wsstf, '24' as num, TPACK_24 as TPACK from source_table_pack where TPACK_24 is not NULL UNION
SELECT enr, wsstf, '25' as num, TPACK_25 as TPACK from source_table_pack where TPACK_25 is not NULL UNION
SELECT enr, wsstf, '26' as num, TPACK_26 as TPACK from source_table_pack where TPACK_26 is not NULL UNION
SELECT enr, wsstf, '27' as num, TPACK_27 as TPACK from source_table_pack where TPACK_27 is not NULL UNION
SELECT enr, wsstf, '28' as num, TPACK_28 as TPACK from source_table_pack where TPACK_28 is not NULL UNION
SELECT enr, wsstf, '29' as num, TPACK_29 as TPACK from source_table_pack where TPACK_29 is not NULL UNION
SELECT enr, wsstf, '30' as num, TPACK_30 as TPACK from source_table_pack where TPACK_30 is not NULL UNION
SELECT enr, wsstf, '31' as num, TPACK_31 as TPACK from source_table_pack where TPACK_31 is not NULL UNION
SELECT enr, wsstf, '32' as num, TPACK_32 as TPACK from source_table_pack where TPACK_32 is not NULL UNION
SELECT enr, wsstf, '33' as num, TPACK_33 as TPACK from source_table_pack where TPACK_33 is not NULL UNION
SELECT enr, wsstf, '34' as num, TPACK_34 as TPACK from source_table_pack where TPACK_34 is not NULL UNION
SELECT enr, wsstf, '35' as num, TPACK_35 as TPACK from source_table_pack where TPACK_35 is not NULL UNION
SELECT enr, wsstf, '36' as num, TPACK_36 as TPACK from source_table_pack where TPACK_36 is not NULL UNION
SELECT enr, wsstf, '37' as num, TPACK_37 as TPACK from source_table_pack where TPACK_37 is not NULL UNION
SELECT enr, wsstf, '38' as num, TPACK_38 as TPACK from source_table_pack where TPACK_38 is not NULL UNION
SELECT enr, wsstf, '39' as num, TPACK_39 as TPACK from source_table_pack where TPACK_39 is not NULL UNION
SELECT enr, wsstf, '40' as num, TPACK_40 as TPACK from source_table_pack where TPACK_40 is not NULL UNION
SELECT enr, wsstf, '41' as num, TPACK_41 as TPACK from source_table_pack where TPACK_41 is not NULL UNION
SELECT enr, wsstf, '42' as num, TPACK_42 as TPACK from source_table_pack where TPACK_42 is not NULL UNION
SELECT enr, wsstf, '43' as num, TPACK_43 as TPACK from source_table_pack where TPACK_43 is not NULL UNION
SELECT enr, wsstf, '44' as num, TPACK_44 as TPACK from source_table_pack where TPACK_44 is not NULL UNION
SELECT enr, wsstf, '45' as num, TPACK_45 as TPACK from source_table_pack where TPACK_45 is not NULL UNION
SELECT enr, wsstf, '46' as num, TPACK_46 as TPACK from source_table_pack where TPACK_46 is not NULL UNION
SELECT enr, wsstf, '47' as num, TPACK_47 as TPACK from source_table_pack where TPACK_47 is not NULL UNION
SELECT enr, wsstf, '48' as num, TPACK_48 as TPACK from source_table_pack where TPACK_48 is not NULL UNION
SELECT enr, wsstf, '49' as num, TPACK_49 as TPACK from source_table_pack where TPACK_49 is not NULL UNION
SELECT enr, wsstf, '50' as num, TPACK_50 as TPACK from source_table_pack where TPACK_50 is not NULL UNION
SELECT enr, wsstf, '51' as num, TPACK_51 as TPACK from source_table_pack where TPACK_51 is not NULL UNION
SELECT enr, wsstf, '52' as num, TPACK_52 as TPACK from source_table_pack where TPACK_52 is not NULL UNION
SELECT enr, wsstf, '53' as num, TPACK_53 as TPACK from source_table_pack where TPACK_53 is not NULL UNION
SELECT enr, wsstf, '54' as num, TPACK_54 as TPACK from source_table_pack where TPACK_54 is not NULL UNION
SELECT enr, wsstf, '55' as num, TPACK_55 as TPACK from source_table_pack where TPACK_55 is not NULL UNION
SELECT enr, wsstf, '56' as num, TPACK_56 as TPACK from source_table_pack where TPACK_56 is not NULL UNION
SELECT enr, wsstf, '57' as num, TPACK_57 as TPACK from source_table_pack where TPACK_57 is not NULL UNION
SELECT enr, wsstf, '58' as num, TPACK_58 as TPACK from source_table_pack where TPACK_58 is not NULL UNION
SELECT enr, wsstf, '59' as num, TPACK_59 as TPACK from source_table_pack where TPACK_59 is not NULL UNION
SELECT enr, wsstf, '60' as num, TPACK_60 as TPACK from source_table_pack where TPACK_60 is not NULL UNION
SELECT enr, wsstf, '61' as num, TPACK_61 as TPACK from source_table_pack where TPACK_61 is not NULL UNION
SELECT enr, wsstf, '62' as num, TPACK_62 as TPACK from source_table_pack where TPACK_62 is not NULL UNION
SELECT enr, wsstf, '63' as num, TPACK_63 as TPACK from source_table_pack where TPACK_63 is not NULL UNION
SELECT enr, wsstf, '64' as num, TPACK_64 as TPACK from source_table_pack where TPACK_64 is not NULL UNION
SELECT enr, wsstf, '65' as num, TPACK_65 as TPACK from source_table_pack where TPACK_65 is not NULL UNION
SELECT enr, wsstf, '66' as num, TPACK_66 as TPACK from source_table_pack where TPACK_66 is not NULL UNION
SELECT enr, wsstf, '67' as num, TPACK_67 as TPACK from source_table_pack where TPACK_67 is not NULL UNION
SELECT enr, wsstf, '68' as num, TPACK_68 as TPACK from source_table_pack where TPACK_68 is not NULL);

update source_table_pack set tpack_1=regexp_replace( regexp_replace(tpack_1, '\[', '('), '\]', ')');
update source_table_pack set tpack_1=regexp_replace( tpack_1, '\)\+\(', '+');

CREATE table stp_tp1 as
select enr, (select count(*) from source_table_pack where enr=stp.enr) pack_size,  
regexp_substr(tpack_1, '\(((\d+x)?[[:digit:].,]+(g|mg|ml|cm sup2)?[., ]*\+?)+\)') amounts,
wsstf,
drug_code, 
regexp_substr(regexp_substr(tpack_1, '\d+x'), '\d+') as box_size,
regexp_substr(regexp_substr(tpack_1, '\(((\d+x)?[[:digit:].,]+(g|mg|ml|cm sup2)?[., ]*\+?)+\)'), '(\d+x)?[[:digit:].,]+(g|mg|ml|cm sup2)?[., ]*', 1, wsstf) amount,
tpack_1
from source_table_pack stp
ORDER BY enr, wsstf;

update stp_tp1 SET amount=regexp_replace(amount, 'x.*$');
update stp_tp1 SET amount=1 WHERE regexp_like(amount, '(g|mg|ml|cm sup2)') ;
update stp_tp1 SET amount=NULL WHERE not regexp_like(amount, '^\d+$') ;
update stp_tp1 SET amount=NULL, box_size=NULL WHERE regexp_count(amounts, '\+')+1<pack_size;



CREATE table stp_2 as
select 'OMOP'||new_voc.nextval as concept_code, q.*  from (select distinct enr, num from stp_1 WHERE (select max(num) from stp_1 q where q.enr=stp_1.enr) > 1 order by enr, num) q;

update stp_1 set tpack=regexp_replace( regexp_replace(tpack, '\[', '('), '\]', ')');
update stp_1 set tpack=regexp_replace( tpack, '\)\+\(', '+');


CREATE table stp_3 as
select stp_2.concept_code,
stp_1.enr,
(select count(*) from source_table_pack where enr=stp_1.enr) pack_size, 
regexp_substr(stp_1.tpack, '\(((\d+x)?[[:digit:].,]+(g|mg|ml|cm sup2)?[., ]*\+?)+\)') amounts,
stp_1.wsstf,
stp.drug_code, 
regexp_substr(regexp_substr(stp_1.tpack, '\d+x'), '\d+') as box_size,
regexp_substr(regexp_substr(stp_1.tpack, '\(((\d+x)?[[:digit:].,]+(g|mg|ml|cm sup2)?[., ]*\+?)+\)'), '(\d+x)?[[:digit:].,]+(g|mg|ml|cm sup2)?[., ]*', 1, stp_1.wsstf) amount,
stp_1.tpack
from stp_1 
JOIN stp_2 ON stp_1.enr=stp_2.enr AND stp_1.num=stp_2.num 
JOIN source_table_pack stp ON stp.enr=stp_1.enr AND stp.wsstf=stp_1.wsstf
order by stp_1.enr, stp_1.num;

update stp_3 SET amount=regexp_replace(amount, 'x.*$') ;
update stp_3 SET amount=1 WHERE regexp_like(amount, '(g|mg|ml|cm sup2)') ;
update stp_3 SET amount=NULL WHERE not regexp_like(amount, '^\d+$') ;
update stp_3 SET amount=NULL, box_size=NULL WHERE regexp_count(amounts, '\+')+1<pack_size;

-- insert new packs into drug_concept_stage

-- see 08_drug_concept_stage

truncate table pack_content;

-- insert into pack content

insert into pack_content
select enr as PACK_CONCEPT_CODE, drug_code as DRUG_CONCEPT_CODE,  AMOUNT, BOX_SIZE FROM stp_tp1;

insert into pack_content
select concept_code as PACK_CONCEPT_CODE, drug_code as DRUG_CONCEPT_CODE,  AMOUNT, BOX_SIZE FROM stp_3;
