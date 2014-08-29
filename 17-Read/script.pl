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

my $zip_one='nhs_readv2_17.0.0_20140401000001.zip';
my $zip_two='nhs_datamigration_17.0.0_20140401000001.zip';
#open(FILL,"file.txt");
#my $file_name='READ_20140505';


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
system("cp -Ru /data/READ/.zip /data/backup_area ; cp -Ru /data/READ/.log /data/backup_area "); 
system('sqlplus', $stage_conn);
#@row_ary = $dbh->selectrow_array('SELECT count(*) FROM KEYV2;');
#@row_ary = $dbh->selectrow_array('SELECT count(*) FROM RCSCTMAP2_UK;');


system('sqlplus', $stage_conn, '@17_transform_row_maps.sql');
my $stat = $dbh->selectall_arrayref('select \'1. Num Rec in stage\' as scr, count(8) as cnt from source_to_concept_map_stage c where c.source_vocabulary_id in (17) union all select \'2. Num Rec in DEV not deleted\' as scr, count(8) as cnt from dev.source_to_concept_map d where d.source_vocabulary_id in (17) and d.target_vocabulary_id in (1) and nvl (d.invalid_reason, \'X\') <> \'D\' union all select \'3. How many records would be new in DEV added\' as scr, count(8) as cnt from source_to_concept_map_stage c where c.source_vocabulary_id in (17) and c.target_vocabulary_id in (1) and not exists ( select 1 from dev.source_to_concept_map d where d.source_vocabulary_id in (17) and c.source_code = d.source_code and d.source_vocabulary_id = c.source_vocabulary_id and d.mapping_type = c.mapping_type and d.target_concept_id = c.target_concept_id and d.target_vocabulary_id = c.target_vocabulary_id ) union all select \'4. How many DEV active will be marked for deletion\' as scr, count(8) as cnt from dev.source_to_concept_map d where d.source_vocabulary_id in (17) and d.target_vocabulary_id in (1) and nvl (d.invalid_reason, \'X\') <> \'D\' and d.valid_start_date < to_date (substr (user, regexp_instr (user, \'_[[:digit:]]\') + 1, 256), \'yyyymmdd\') and not exists ( select 1 from source_to_concept_map_stage c where c.source_vocabulary_id in (17) and c.source_code = d.source_code and d.source_vocabulary_id = c.source_vocabulary_id and d.mapping_type = c.mapping_type and d.target_concept_id = c.target_concept_id and d.target_vocabulary_id = c.target_vocabulary_id ) and exists ( select 1 from source_to_concept_map_stage c where d.source_code = c.source_code and d.source_vocabulary_id = c.source_vocabulary_id and d.mapping_type = c.mapping_type and d.target_vocabulary_id = c.target_vocabulary_id)');
printf "%s\n", join ' ', @$_ for @$stat;
system('sqlplus', $stage_conn, '@17_load_maps.sql');