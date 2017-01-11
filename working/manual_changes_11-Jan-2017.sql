--fix some wrong 'Maps to' and 'Mapped from' relationships
update concept_relationship set invalid_reason='D', valid_end_date=trunc(sysdate) where rowid in
(
    SELECT  r.rowid
    FROM concept_relationship r, relationship rel
    WHERE r.invalid_reason IS NULL
    AND r.relationship_id = rel.relationship_id
    AND r.concept_id_1 <> r.concept_id_2
    AND r.relationship_id='Mapped from'
    AND NOT EXISTS
    (
        SELECT 1 FROM concept_relationship r_int WHERE r_int.relationship_id = rel.reverse_relationship_id AND r_int.invalid_reason IS NULL AND r_int.concept_id_1 = r.concept_id_2 AND r_int.concept_id_2 = r.concept_id_1
    )
);
update concept_relationship set invalid_reason=NULL, valid_end_date=TO_DATE ('20991231', 'YYYYMMDD') where concept_id_1=261325 and concept_id_2=45576950;
insert into concept_relationship values (44806793,45571826,'Mapped from',TO_DATE ('19700101', 'YYYYMMDD'),TO_DATE ('20991231', 'YYYYMMDD'),NULL);
update concept_relationship set invalid_reason=NULL, valid_end_date=TO_DATE ('20991231', 'YYYYMMDD') where concept_id_1=437834 and concept_id_2=45566704;
update concept_relationship set invalid_reason=NULL, valid_end_date=TO_DATE ('20991231', 'YYYYMMDD') where concept_id_1=4006963 and concept_id_2=45601691;
insert into concept_relationship values (77360,42617095,'Mapped from',TO_DATE ('20161201', 'YYYYMMDD'),TO_DATE ('20991231', 'YYYYMMDD'),NULL);
insert into concept_relationship values (4218100,45566704,'Mapped from',TO_DATE ('20161201', 'YYYYMMDD'),TO_DATE ('20991231', 'YYYYMMDD'),NULL);
insert into concept_relationship values (4327944,45557115,'Mapped from',TO_DATE ('20161201', 'YYYYMMDD'),TO_DATE ('20991231', 'YYYYMMDD'),NULL);
insert into concept_relationship values (4327944,45755356,'Mapped from',TO_DATE ('20161201', 'YYYYMMDD'),TO_DATE ('20991231', 'YYYYMMDD'),NULL);
commit;

--fix some wrong 'Brand name of' and 'Has brand name' relationships
--deprecate relationships that already have proper relationship_id
update concept_relationship set invalid_reason='D', valid_end_date=trunc(sysdate) where rowid in
(
    select r.rowid from concept a
    join concept_relationship r on a.concept_id = r.concept_id_1
    join concept b on b.concept_id = r.concept_id_2
    where a.concept_class_id like '%Branded%'
    and r.relationship_id = 'Brand name of'
    and r.invalid_reason is null
    and exists (
        select 1 from concept_relationship r_int
        where r_int.concept_id_1=r.concept_id_1
        and r_int.concept_id_2=r.concept_id_2
        and r_int.relationship_id = 'Has brand name'
        and r_int.invalid_reason is null
    )
);
--rename 'Brand name of' to 'Has brand name'
update concept_relationship set relationship_id='Has brand name' where rowid in
(
    select r.rowid from concept a
    join concept_relationship r on a.concept_id = r.concept_id_1
    join concept b on b.concept_id = r.concept_id_2
    where a.concept_class_id like '%Branded%'
    and r.relationship_id = 'Brand name of'
    and r.invalid_reason is null
    and not exists (
        select 1 from concept_relationship r_int
        where r_int.concept_id_1=r.concept_id_1
        and r_int.concept_id_2=r.concept_id_2
        and r_int.relationship_id = 'Has brand name'
        and r_int.invalid_reason is null
    )
);
--and reverse:
--deprecate relationships that already have proper relationship_id
update concept_relationship set invalid_reason='D', valid_end_date=trunc(sysdate) where rowid in
(
    select r.rowid from concept a
    join concept_relationship r on a.concept_id = r.concept_id_1
    join concept b on b.concept_id = r.concept_id_2
    where a.concept_class_id = 'Brand Name'
    and r.relationship_id = 'Has brand name'
    and r.invalid_reason is null
    and exists (
        select 1 from concept_relationship r_int
        where r_int.concept_id_1=r.concept_id_1
        and r_int.concept_id_2=r.concept_id_2
        and r_int.relationship_id = 'Brand name of'
        and r_int.invalid_reason is null
    )
);
--rename 'Has brand name' to 'Brand name of' 
update concept_relationship set relationship_id='Brand name of' where rowid in
(
    select r.rowid from concept a
    join concept_relationship r on a.concept_id = r.concept_id_1
    join concept b on b.concept_id = r.concept_id_2
    where a.concept_class_id = 'Brand Name'
    and r.relationship_id = 'Has brand name'
    and r.invalid_reason is null
    and not exists (
        select 1 from concept_relationship r_int
        where r_int.concept_id_1=r.concept_id_1
        and r_int.concept_id_2=r.concept_id_2
        and r_int.relationship_id = 'Brand name of'
        and r_int.invalid_reason is null
    )
);
commit;

--after all we need to run Vocabulary-v5.0\RxNorm_E\RxNorm_cleanup.sql to fix name duplicates