GRR readme upload / update of GRR

Prerequisites:

Schema DevV5 with copies of tables concept, concept_relationship and concept_synonym from ProdV5, fully indexed.

Working directory dev_grr.

  For upload use following instructions:
1. Run create_source_tables.sql in your DEV-schema (e.g dev_grr)

2. You need to have the access to both GEDA and GRR.
Then run the following query to get grr_new_2:
  select distinct
    fcc,
    pri_ifa_cd as pzn, 
    intl_pack_form_desc,
    intl_pack_strnt_desc,
    intl_pack_size_desc,
    pack_desc,
    pack_substn_cnt,
    pri_synm_nm as molecule,
    wgt_qty,
    wgt_uom_cd,
    pack_addl_strnt_desc,
    pack_wgt_qty,
    pack_wgt_uom_cd,
    pack_vol_qty,
    pack_vol_uom_cd,
    pack_size_cnt,
    grr_pack_composn.abs_strnt_qty,
    grr_pack_composn.abs_strnt_uom_cd,
    rltv_strnt_qty,
    hmo_dilution_cd,
    form_desc,
    generic_prod_lng_nm as brand_name1,
    ims_prod_lng_nm as brand_name
  from grr_pack
  left join grr_pack_composn on grr_pack.grr_pack_cd=grr_pack_composn.grr_pack_cd
  left join grr_mlcl using(mlcl_id) -- get molecule information
  where coalesce(ctrysp_reg_status_cd, 'X') not in ('NOTKNOWN', 'X', 'UNREG'); -- remove non-drugs

You also need to create 'source_data' table and upload GEDA into it.

3. Run load_stage.sql
4. Run Build_RxE.sql and generic_update.sql (from working directory);
5. Run drops.sql to remove all the temporary tables


  For update use following instructions:
Before update use fast_recreate_schema.sql (from working directory);

1. Import source file into 'source_data' table;
2. Run script_for_delta.sql;
3. Map table relationship_to_concept_to_map and import those mappings into relationship_to_concept_manual;
4. Run script_for_delta.sql  without line 1919;
5. Run Build_RxE.sql (from working directory);
6. Fill mapping for vaccines and insulins manually from vacc_ins_manual table 
7. Run concept_relationship_manual_post_proc.sql;
8. Run generic_update.sql (from working directory);
9. Run drops.sql to remove all the temporary tables


  If was created duplicates by concept_name and concept_class, but with different concept_code in vocabulary 'GRR', you can use post_proc_clean_up.sql for fixing this bug.