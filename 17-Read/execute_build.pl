#!/usr/bin/perl
# Automatic loader for Read-17 vocabulary 
# Version 1.0, 26-Aug-2014

#/**************************************************************************
#
#  OMOP - Cloud Research Lab
#
#  Observational Medical Outcomes Partnership
#  (c) Foundation for the National Institutes of Health (FNIH)
#
#  Licensed under the Apache License, Version 2.0 (the "License"); you may not
#  use this file except in compliance with the License. You may obtain a copy
#  of the License at http://omop.fnih.org/publiclicense.
#
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
#  WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. Any
#  redistributions of this work or any derivative work or modification based on
#  this work should be accompanied by the following source attribution: "This
#  work is based on work by the Observational Medical Outcomes Partnership
#  (OMOP) and used under license from the FNIH at
#
#  Any scientific publication that is based on this work should include a
#  reference to http://omop.fnih.org.
#
#  Date:           2014/09/01
#
#  Automatic loader for 17-Read vocabulary
# 
#  Usage: 
#  echo "EXIT" |sqlplus READ_20140401/myPass@DEV_VOCAB @execute_build.pl 
#
#******************************************************************************/'

use warnings;
use strict;
use DBI; 
use DBD::Oracle; 
use Data::Dumper; 
use Archive::Zip qw( :ERROR_CODES :CONSTANTS );
use File::Copy;
#use Dir::Create;

#create connections
my $sys = {
    schema => 'SYS',
    pass => '1234qwer',
    host => 'localhost',
    sid => 'OMOP'
};
 
my $sys_conn = sprintf '%s/%s@%s/%s AS SYSDBA',
    $sys->{schema},
    $sys->{pass},
    $sys->{host},
    $sys->{sid}; 
    
my $stage = {
    schema => 'TEST_READ_20141001',
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
my $zip_one='nhs_readv2_18.0.2_20141001000001.zip';
#NHS Data Migration
my $zip_two='nhs_datamigration_18.0.0_20141001000001.zip';

my $dbh_sys = DBI->connect(
    sprintf(
        'dbi:Oracle:host=%s;sid=%s',
        $sys->{host},
        $sys->{sid}
    ),
    $sys->{schema},
    $sys->{pass},
    { ora_session_mode =>DBD::Oracle::ORA_SYSDBA}
) or die 'Couldnt connect to database';

#build database schema
die 'user exists' if [ $dbh_sys->selectrow_array('SELECT COUNT(*) FROM DBA_USERS WHERE USERNAME = ?', undef, $stage->{schema}) ]->[0]; 
my @out = system('sqlplus', $sys_conn, '@17_create_schema.sql', $stage-> {schema}, $stage->{pass});

my $dbh = DBI->connect(
    sprintf(
	'dbi:Oracle:host=%s;sid=%s', 
	$stage->{host}, 
	$stage->{sid}
    ), 
    $stage->{schema}, 
    $stage->{pass}
) or die 'Couldnt connect to database';
 
#raw data load into Oracle tables

#extract files from the zip archive into the current directory

printf "unzip files";

system("unzip -u nhs_readv2_18.0.2_20141001000001.zip\n");
system("unzip -u nhs_datamigration_18.0.0_20141001000001.zip\n");

#copy files from zips to the current directory
my $oldfile1 = "V2/Unified/Keyv2.all";
my $oldfile2 = "Mapping Tables/Updated/Clinically Assured/rcsctmap2_uk_201410010000001.txt";
my $newfile = "./";
copy($oldfile1, $newfile);
copy($oldfile2, $newfile);

#load FDA raw data into Oracle
system('sqlldr', $stage_conn, 'control=17_keyv2.ctl');
system('sqlldr', $stage_conn, 'control=17_rcsctmap2_uk.ctl'); 
#create directory for back_up
#Dir::create('data') unless -e 'data';
if(-e 'data') {
# data exist
} else {
mkdir('data') or die "Couldn't create data directory, $!";
printf "Directory created successfully\n";
}

#copy data and intermediate files to backup area
system("cp -Ru *.zip data ; cp -Ru *.log data ");
printf "back-up created successfully\n";
system('sqlplus', $stage_conn); 
#verify that number of records loaded is equivalent to prior production load
my @row_ary1 = $dbh->selectrow_array('SELECT count(*) FROM KEYV2;');
printf(@row_ary1);
my @row_ary2 = $dbh->selectrow_array('SELECT count(*) FROM RCSCTMAP2_UK;');
printf(@row_ary2);

#loading to staging tables from raw
#convert and store in staging table maps
system('sqlplus', $stage_conn, '@17_transform_row_maps.sql');
printf "transform_row_to_maps created successfully\n";
#verify that number of records loaded is equivalent to prior production load 
my $stat = $dbh->selectall_arrayref('select \'1. Num Rec in stage\' as scr, count(8) as cnt from source_to_concept_map_stage c where c.source_vocabulary_id in (17) union all select \'2. Num Rec in DEV not deleted\' as scr, count(8) as cnt from dev.source_to_concept_map d where d.source_vocabulary_id in (17) and d.target_vocabulary_id in (1) and nvl (d.invalid_reason, \'X\') <> \'D\' union all select \'3. How many records would be new in DEV added\' as scr, count(8) as cnt from source_to_concept_map_stage c where c.source_vocabulary_id in (17) and c.target_vocabulary_id in (1) and not exists ( select 1 from dev.source_to_concept_map d where d.source_vocabulary_id in (17) and c.source_code = d.source_code and d.source_vocabulary_id = c.source_vocabulary_id and d.mapping_type = c.mapping_type and d.target_concept_id = c.target_concept_id and d.target_vocabulary_id = c.target_vocabulary_id ) union all select \'4. How many DEV active will be marked for deletion\' as scr, count(8) as cnt from dev.source_to_concept_map d where d.source_vocabulary_id in (17) and d.target_vocabulary_id in (1) and nvl (d.invalid_reason, \'X\') <> \'D\' and d.valid_start_date < to_date (substr (user, regexp_instr (user, \'_[[:digit:]]\') + 1, 256), \'yyyymmdd\') and not exists ( select 1 from source_to_concept_map_stage c where c.source_vocabulary_id in (17) and c.source_code = d.source_code and d.source_vocabulary_id = c.source_vocabulary_id and d.mapping_type = c.mapping_type and d.target_concept_id = c.target_concept_id and d.target_vocabulary_id = c.target_vocabulary_id ) and exists ( select 1 from source_to_concept_map_stage c where d.source_code = c.source_code and d.source_vocabulary_id = c.source_vocabulary_id and d.mapping_type = c.mapping_type and d.target_vocabulary_id = c.target_vocabulary_id)');
printf "%s\n", join ' ', @$_ for @$stat; 
#load new maps into DEV schema concept table   
system('sqlplus', $stage_conn, '@17_load_maps.sql');