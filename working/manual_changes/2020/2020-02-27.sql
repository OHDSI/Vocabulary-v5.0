--fix ICD10CM and ICD10PCS wrong latest update [AVOF-2219]
update sources.icd10cm set vocabulary_date=vocabulary_date+interval '1 year';
update sources.icd10pcs set vocabulary_date=vocabulary_date+interval '1 year';
update vocabulary_conversion set latest_update=latest_update+interval '1 year' where vocabulary_id_v5 in ('ICD10CM','ICD10PCS');

update concept set valid_end_date=valid_end_date+interval '1 year' where vocabulary_id in ('ICD10CM','ICD10PCS') and valid_end_date in (to_date('20181231','yyyymmdd'),to_date('20171231','yyyymmdd'));
update concept set valid_start_date=valid_start_date+interval '1 year' where vocabulary_id in ('ICD10CM','ICD10PCS') and valid_start_date in (to_date('20190101','yyyymmdd'),to_date('20180101','yyyymmdd'));
update concept set valid_start_date=to_date('20170101','yyyymmdd') where vocabulary_id in ('ICD10CM','ICD10PCS') and valid_start_date=to_date('20170428','yyyymmdd');
update concept set valid_end_date=to_date('20161231','yyyymmdd') where vocabulary_id in ('ICD10CM','ICD10PCS') and valid_end_date=to_date('20170427','yyyymmdd');
update concept set valid_start_date=to_date('20180101','yyyymmdd') where vocabulary_id in ('ICD10CM','ICD10PCS') and valid_start_date=to_date('20171001','yyyymmdd');
update concept set valid_end_date=to_date('20171231','yyyymmdd') where vocabulary_id in ('ICD10CM','ICD10PCS') and valid_end_date=to_date('20170930','yyyymmdd');