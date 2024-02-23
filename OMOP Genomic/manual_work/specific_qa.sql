-- All checks should return an empty table. If not, it should be presented to the author

--Check input

-- make sure none of the bad concept_codes get picked up
SELECT concept_code 
FROM concept_small 
WHERE concept_code NOT ILIKE 'OMOP%';

-- check for duplicate concept_codes in concept_small
SELECT * 
FROM concept_small 
    JOIN (SELECT concept_code 
          FROM concept_small 
          GROUP BY concept_code 
          HAVING count(*)>1) a 
        USING (concept_code);

-- check for duplicate concept_names in concept_small
SELECT * 
FROM concept_small 
    JOIN (SELECT concept_name 
          FROM concept_small 
          GROUP BY concept_name 
          HAVING count(*)>1) a USING (concept_name);

-- check for duplicate relationships
SELECT * 
FROM relationship_small 
    JOIN (SELECT concept_code_1, concept_code_2 
        FROM relationship_small WHERE concept_code_1 != concept_code_2 GROUP BY concept_code_1, concept_code_2 HAVING count(*) > 1) a USING(concept_code_1, concept_code_2);

-- check for duplicates in synonym
SELECT syns, cs.* 
FROM concept_small cs 
    JOIN (SELECT synonym_concept_code AS concept_code, string_agg(synonym_name, '-' ORDER BY synonym_name) AS syns 
  FROM synonym_small 
  JOIN (SELECT synonym_name 
        FROM synonym_small 
        WHERE synonym_name NOT LIKE 'rsID%' 
        GROUP BY synonym_name 
        HAVING count(*)>1) a 
      USING(synonym_name) 
  GROUP BY synonym_concept_code
) a USING(concept_code);

-- check for duplicate concept_codes in concept_large
SELECT * 
FROM concept_large 
    JOIN (SELECT concept_code 
          FROM concept_large 
          GROUP BY concept_code 
          HAVING count(*) > 1) a USING(concept_code);

-- check for duplicate concept_names in concept_large
SELECT * 
FROM concept_large 
    JOIN (SELECT concept_name 
          FROM concept_large 
          GROUP BY concept_name 
          HAVING count(*) > 1) a 
        USING(concept_name);


--Check KOIOS output for small tables

-- Perform a bunch of checks, each of which should return an empty tables, except those called "no pass/fail test"
with old as ( -- pulls out small variants from current OMOP Genomic. Will need to change next iteration
  select concept_code, concept_name, case concept_class_id -- these can be abolished in the next iteration
    when 'DNA Variant' then 'Gene DNA Variant'
    when 'RNA Variant' then 'Gene RNA Variant'
    when 'Protein Variant' then 'Gene Protein Variant'
    else concept_class_id
  end as concept_class_id
  from concept where vocabulary_id='OMOP Genomic' and concept_class_id!='Genetic Variation' -- this concept_class_id should change in the next iteration
    and (concept_name like '%on genome%' or concept_name like '%transcript:%' or concept_name like '%protein:%')
),
new_gene as ( -- extracts gene symbol from new set
  select concept_code, concept_name, substr(concept_name, 1, position(' ' in concept_name)-1) as gene_name from concept_small
),
old_gene as ( -- extracts gene symbol from old set 
  select concept_code, concept_name, substr(concept_name, 1, position(' ' in concept_name)-1) as gene_name from old
),
syn_gene as ( -- extracts gene symbol from synonym, if listed
  select synonym_concept_code as concept_code, synonym_name, case
    when synonym_name like '%(%' then substr(synonym_name, position('(' in synonym_name)+1, position(')' in synonym_name)-position('(' in synonym_name)-1)
    when synonym_name like '% %' then substr(synonym_name, 1, position(' ' in synonym_name)-1)
    else ''
  end as gene_name from synonym_small where synonym_name like '% %' and synonym_name not like 'rsID%' -- rsIDs should no longer exist in synonyms and the clause can be dropped in future
),
all_gene as ( -- full list of genes, concept_class_id should change in next iteration to "Gene Variant"
  select substr(concept_name, 1, position(' ' in concept_name)-1) as gene_name from concept c where c.vocabulary_id='OMOP Genomic' and c.concept_class_id='Genetic Variation' and standard_concept='S'
),
r as ( -- all relationship in new set
  select c1.concept_code as c1_code, c1.concept_name as c1_name, 
    r.relationship_id as rel,
    c2.concept_code as c2_code, c2.concept_name as c2_name -- c2_domain, c2.concept_class_id as c2_class, c2.invalid_reason as c2_ir
  from concept_small c1
  join relationship_small r on r.concept_code_1=c1.concept_code and c1.vocabulary_id=r.vocabulary_id_1 and concept_code_1!=concept_code_2
  join concept_small c2 on c2.concept_code=r.concept_code_2 and c2.vocabulary_id=r.vocabulary_id_2
  -- and not (c1.concept_class_id='RNA Variant' and c2.concept_class_id='Protein Variant')
),
new_mut as ( -- class of mutation in new set
  select distinct concept_code, concept_name, case
    when concept_name like '%eletion%nsertion%' then 'DelIns'
    when concept_name like '%and Insertion%' then 'Substitution'
    when concept_name like '%rameshift%' then 'Frameshift'
    when concept_name like '%uplication%' then 'Duplication'
    when concept_name like '%eletion in%' then 'Deletion'
    when concept_name like '%ubstitution in%' then 'Substitution'
    when concept_name like '%nsertion in%' then 'Insertion'
    when concept_name like '%xtension%' then 'Extension'
    else 'xyz' -- concept_name
    end as mech
  from concept_small
),
old_mut as ( -- class of mutation in old set
  select distinct concept_code, concept_name, case
    when concept_name like '%eletion%nsertion%' then 'DelIns'
    when concept_name like '%rameshift%' then 'Frameshift'
    when concept_name like '%uplication%' then 'Duplication'
    when concept_name like '%eletion in%' then 'Deletion'
    when concept_name like '%ubstitution in%' then 'Substitution'
    when concept_name like '%nsertion in%' then 'Insertion'
    when concept_name like '%xtension%' then 'Extension'
    else 'xyz' -- concept_name
    end as mech
  from old
),
syn_mut as ( -- class of mutation in synonyms
  select distinct synonym_concept_code as concept_code, synonym_name, case
    when synonym_name like '%dup%' then 'Duplication'
    when synonym_name like '%delins%' then 'DelIns'
    when synonym_name like '%del%' then 'Deletion'
    when synonym_name like '%>%' then 'Substitution'
    when synonym_name like '%ins%' then 'Insertion'
    when synonym_name like '%ext%' then 'Extension'
    when synonym_name like '%_fs_%' then 'Frameshift'
    when synonym_name like '%:p.%' then 'Substitution'
    else 'Substitution' -- concept_name
    end as mech
  from synonym_small where synonym_name not like 'rsID%'
)
-- 1. check if concept_class_id changed between old and new set
-- select * from concept_small new join old using(concept_code) where new.concept_class_id!=old.concept_class_id;
-- 2. check if mutation class changed in old and new set
-- select * from new_mut join old_mut using(concept_code) where new_mut.mech!=old_mut.mech; 
-- 3. check if gene assignment changed in old and new set
-- select * from new_gene as n join old_gene as o using(concept_code) where n.gene_name!=o.gene_name and n.gene_name not in ('INSRR', 'NTRK1')and o.gene_name not in ('INSRR', 'NTRK1');
-- 4. check if all genes exist
-- select distinct new_gene.gene_name from new_gene left join all_gene using(gene_name) where all_gene.gene_name is null;
-- 5. test whether the gene assignment changes from DNA to RNA
-- select r.*, g1.gene_name, g2.gene_name from r join new_gene g1 on c1_code=g1.concept_code join new_gene g2 on c2_code=g2.concept_code where g1.gene_name!=g2.gene_name and rel='Transcribes to' and  g1.gene_name not in ('FANCL', 'VRK2') and g2.gene_name not in ('FANCL', 'VRK2');
-- 6. test whether the mutation class changes from DNA to RNA
-- select r.* from r join new_mut m1 on c1_code=m1.concept_code join new_mut m2 on c2_code=m2.concept_code where m1.mech!=m2.mech and rel='Transcribes to';
-- 7. (not a pass/fail test): Check if there are one-to-many relationships between DNA, RNA and protein both directions
-- select r.* from r join (select c1_code, rel from r group by c1_code, rel having count(*)>1) a using(c1_code, rel) order by 1;
-- 8. Check that there are only unique concept_replaced_bys
-- select r.* from r join (select c1_code from r where rel='Concept replaced by' group by c1_code having count(*)>1) a using(c1_code) order by 1;
-- 9. Check replaced concepts are deprecated
-- select c.* from r join concept_small as c on concept_code=c1_code where rel='Concept replaced by';
-- 10. check for 3 letter amino acids
-- select * from concept_small where concept_name ilike '% Arg %';
-- 12. check source concepts for concept_replaced_by
-- select * from relationship_small left join old on concept_code=concept_code_1 where relationship_id='Concept replaced by' and old.concept_code is null;
-- 13. check target concepts for concept_replaced_by
-- select relationship_small.concept_code_2 from relationship_small left join concept_small on concept_code=concept_code_2 where relationship_id='Concept replaced by' and concept_small.concept_code is null;
-- 14. check for overlapping synonyms;
-- select distinct concept_code, concept_name, synonym_name from synonym_small join concept_small on concept_code=synonym_concept_code join (select synonym_name from synonym_small group by synonym_name having count(*)>1) a using(synonym_name) order by 3;
-- 15. check if gene assignments match in concepts and synonyms
-- select * from new_gene n join syn_gene s using(concept_code) where n.gene_name!=s.gene_name and n.gene_name not in ('FANCL', 'VRK2') and s.gene_name not in ('FANCL', 'VRK2');
-- 16. Not a pass/fail test: check if mutation changes between concepts and synonyms
-- select * from new_mut join syn_mut using(concept_code) where new_mut.mech!=syn_mut.mech; 
;


--Check KOIOS output for large tables
-- check for duplicate relationships
select * from relationship_large join (select concept_code_1, concept_code_2 from relationship_large where concept_code_1!=concept_code_2 group by concept_code_1, concept_code_2 having count(*)>1) a using(concept_code_1, concept_code_2);

-- Perform a bunch of checks, each of which should return an empty tables, except those called "no pass/fail test"
with old as ( -- pulls out small variants from current OMOP Genomic. Will need to change next iteration
  select concept_code, concept_name, case concept_class_id -- these can be abolished in the next iteration
    when 'Genetic Variation' then 'Gene Variant'
    when 'DNA Variant' then 'Gene DNA Variant'
    when 'RNA Variant' then 'Gene RNA Variant'
    when 'Protein Variant' then 'Gene Protein Variant'
    else concept_class_id
  end as concept_class_id
  from concept where vocabulary_id='OMOP Genomic'  --  this concept_class_id should change in the next iteration
    and not (concept_name like '%on genome%' or concept_name like '%transcript:%' or concept_name like '%protein:%')
),
new_gene as ( -- extracts gene symbol from new set
  select concept_code, concept_name, substr(concept_name, 1, position(' ' in concept_name)-1) as gene_name from concept_large where concept_class_id!='Structural Variant' and concept_name not like '%::%' and invalid_reason is null
union
  select concept_code, concept_name, substr(concept_name, 1, position(':' in concept_name)-1) as gene_name from concept_large where concept_name like '%::%' and invalid_reason is null -- first gene in fusions
union
  select concept_code, concept_name, substr(concept_name, position(':' in concept_name)+2, position(' ' in concept_name)-position(':' in concept_name)-2) as gene_name from concept_large 
where concept_name like '%::%' and concept_name not like 'PML::ADAMTS17::RARA%' and invalid_reason is null -- second gene in fusions
),
old_gene as ( -- extracts gene symbol from old set 
  select concept_code, concept_name, substr(concept_name, 1, position(' ' in concept_name)-1) as gene_name from old where concept_name not ilike '%Fusion%*'
),
all_gene as ( -- full list of genes, concept_class_id should change in next iteration to "Gene Variant"
  select substr(concept_name, 1, position(' ' in concept_name)-1) as gene_name from concept where vocabulary_id='OMOP Genomic' and concept_class_id='Genetic Variation' and standard_concept='S'
union
  select substr(concept_name, 1, position(' ' in concept_name)-1) as gene_name from concept_large where concept_class_id='Gene Variant' -- add new genes 
),
r as ( -- all relationship in new set
  select c1.concept_code as c1_code, c1.concept_name as c1_name, 
    r.relationship_id as rel,
    c2.concept_code as c2_code, c2.concept_name as c2_name -- c2_domain, c2.concept_class_id as c2_class, c2.invalid_reason as c2_ir
  from concept_large c1
  join relationship_large r on r.concept_code_1=c1.concept_code and c1.vocabulary_id=r.vocabulary_id_1 and concept_code_1!=concept_code_2
  join concept_large c2 on c2.concept_code=r.concept_code_2 and c2.vocabulary_id=r.vocabulary_id_2
  -- and not (c1.concept_class_id='RNA Variant' and c2.concept_class_id='Protein Variant')
)
-- 1. Not a pass/fail: check if concept_class_id changed between old and new set
-- select * from concept_large new join old using(concept_code) where new.concept_class_id!=old.concept_class_id;
-- 2. check if gene assignment changed in old and new set
-- select * from new_gene as n join old_gene as o using(concept_code) where n.concept_name not ilike '%fusion%' and n.gene_name!=o.gene_name and o.gene_name not in ('ARMC4', 'DUSP27', 'C11orf95', 'TMEM159', 'GBA', 'INSRR', 'NTRK1');
-- 3. check if all genes exist
-- select distinct new_gene.gene_name from new_gene left join all_gene using(gene_name) where all_gene.gene_name is null;
-- 4. Check that there are only unique concept_replaced_bys
-- select r.* from r join (select c1_code from r where rel='Concept replaced by' group by c1_code having count(*)>1) a using(c1_code) order by 1;
-- 5. Check replaced concepts are deprecated
-- select c.* from r join concept_large as c on concept_code=c1_code where rel='Concept replaced by' and c.invalid_reason is null;
-- 6. check for 3 letter amino acids
-- select * from concept_large where concept_name ilike '% Arg %';
-- 7. check source concepts for concept_replaced_by
-- select * from relationship_large left join old on concept_code=concept_code_1 where relationship_id='Concept replaced by' and old.concept_code is null;
-- 8. check target concepts for concept_replaced_by
-- select r.concept_code_2 from relationship_large r left join concept_large l on l.concept_code=concept_code_2 left join old o on o.concept_code=concept_code_2 where relationship_id='Concept replaced by' and coalesce(l.concept_code, o.concept_code) is null;
;
