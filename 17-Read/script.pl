/******************************************************************************
*
*  OMOP - Cloud Research Lab
*
*  Observational Medical Outcomes Partnership
*  (c) Foundation for the National Institutes of Health (FNIH)
*
*  Licensed under the Apache License, Version 2.0 (the "License"); you may not
*  use this file except in compliance with the License. You may obtain a copy
*  of the License at http://omop.fnih.org/publiclicense.
*
*  Unless required by applicable law or agreed to in writing, software
*  distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
*  WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. Any
*  redistributions of this work or any derivative work or modification based on
*  this work should be accompanied by the following source attribution: "This
*  work is based on work by the Observational Medical Outcomes Partnership
*  (OMOP) and used under license from the FNIH at
*  http://omop.fnih.org/publiclicense.
*
*  Any scientific publication that is based on this work should include a
*  reference to http://omop.fnih.org.
*
*  Date:           2014/09/01
*
*  Automatic loader for 17-Read vocabulary
* 
*  Usage: 
*  echo "EXIT" |sqlplus READ_20140401/myPass@DEV_VOCAB @execute_build.pl 
*
******************************************************************************/

#!/usr/bin/perl
# Automatic loader for Read-17 vocabulary 
# Version 1.0, 26-Aug-2014

use warnings;
use strict;
use DBI;
use Data::Dumper;

my $sys = {
    schema => 'SYS',
    pass => '123qwer',
    host => 'localhost',
    sid => 'OMOP'
};
 
my $sys_conn = sprintf '%s/%s@%s/%s AS SYSDBA',
    $sys->{schema},
    $sys->{pass},
    $sys->{host},
    $sys->{sid};
    
my $stage = {
    schema => 'TEST_READ_20140401',
    pass => '123',
    host => 'localhost',
    sid => 'OMOP'
};

my $stage_conn = sprintf '%s/%s@%s/%s',
    $stage->{schema},
    $stage->{pass},
    $stage->{host},
    $stage->{sid};

#latest release files from the Health and Social Care Information Centre TRUD section "UK Read".
#NHS UK Read Codes Version 2
my $zip_one='nhs_readv2_17.0.0_20140401000001.zip';
#NHS Data Migration
my $zip_two='nhs_datamigration_17.0.0_20140401000001.zip';


my $dbh = DBI->connect(
    sprintf(
	'dbi:Oracle:host=%s;sid=%s', 
	$stage->{host}, 
	$stage->{sid}
    ), 
    $stage->{schema}, 
    $stage->{pass}
) or die 'Couldnt connect to database';

system('sqlplus', '$sys_conn', '@17_create_schema.sql', $stage-> {schema}, $stage->{pass});
my $status1 = unzip $zip_one => "."
or die "unzip failed:\n";
my $status2 = unzip $zip_two => "."
or die "unzip failed:\n";
system('sqlldr', $stage_conn, '@control=17_keyv2.ctl');
system('sqlldr', $stage_conn, '@control=17_rcsctmap2_uk');
system("cp -Ru *.zip data ; cp -Ru *.log data "); 
system('sqlplus', $stage_conn);
#@row_ary = $dbh->selectrow_array('SELECT count(*) FROM KEYV2;');
#@row_ary = $dbh->selectrow_array('SELECT count(*) FROM RCSCTMAP2_UK;');


system('sqlplus', $stage_conn, '@17_transform_row_maps.sql');
my $stat = $dbh->selectall_arrayref('select \'1. Num Rec in stage\' as scr, count(8) as cnt from source_to_concept_map_stage c where c.source_vocabulary_id in (17) union all select \'2. Num Rec in DEV not deleted\' as scr, count(8) as cnt from dev.source_to_concept_map d where d.source_vocabulary_id in (17) and d.target_vocabulary_id in (1) and nvl (d.invalid_reason, \'X\') <> \'D\' union all select \'3. How many records would be new in DEV added\' as scr, count(8) as cnt from source_to_concept_map_stage c where c.source_vocabulary_id in (17) and c.target_vocabulary_id in (1) and not exists ( select 1 from dev.source_to_concept_map d where d.source_vocabulary_id in (17) and c.source_code = d.source_code and d.source_vocabulary_id = c.source_vocabulary_id and d.mapping_type = c.mapping_type and d.target_concept_id = c.target_concept_id and d.target_vocabulary_id = c.target_vocabulary_id ) union all select \'4. How many DEV active will be marked for deletion\' as scr, count(8) as cnt from dev.source_to_concept_map d where d.source_vocabulary_id in (17) and d.target_vocabulary_id in (1) and nvl (d.invalid_reason, \'X\') <> \'D\' and d.valid_start_date < to_date (substr (user, regexp_instr (user, \'_[[:digit:]]\') + 1, 256), \'yyyymmdd\') and not exists ( select 1 from source_to_concept_map_stage c where c.source_vocabulary_id in (17) and c.source_code = d.source_code and d.source_vocabulary_id = c.source_vocabulary_id and d.mapping_type = c.mapping_type and d.target_concept_id = c.target_concept_id and d.target_vocabulary_id = c.target_vocabulary_id ) and exists ( select 1 from source_to_concept_map_stage c where d.source_code = c.source_code and d.source_vocabulary_id = c.source_vocabulary_id and d.mapping_type = c.mapping_type and d.target_vocabulary_id = c.target_vocabulary_id)');
printf "%s\n", join ' ', @$_ for @$stat;
system('sqlplus', $stage_conn, '@17_load_maps.sql');