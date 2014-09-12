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
#  Date:           2014/09/11
#
#  Automatic loader for 17-Read vocabulary
# 
#  Usage: 
#  echo "EXIT" |sqlplus READ_20140401/myPass@DEV_VOCAB @download.pl 
#
#******************************************************************************/'

use warnings;
use strict;
use DBI; 
use DBD::Oracle; 
use Data::Dumper; 
use Archive::Zip qw( :ERROR_CODES :CONSTANTS );
use File::Copy;
use LWP::UserAgent;
use HTTP::Request;

use LWP::Simple;
 
my $NameFile = 'nhs_readv2_17.0.0_20140401000001.zip';
my $NameFile1 = 'nhs_datamigration_17.0.0_20140401000001.zip';
my $host = 'https://isd.hscic.gov.uk/artefact/trud3/1cioqb31xpr9pivth7eup8x5ri/17.0.0/NHS_READV2/';
my $host1 = 'https://isd.hscic.gov.uk/artefact/trud3/b96wcfvlr99jjhpey8opu8gjk/DATAMIGRATION/17.0.0/NHS_DATAMIGRATION/';
my $log = 'reich@omop.org';       
my $passw = 'Late4man';  
 
if (head($host)) {
     print 'Requested document exists, first zip 
';
  }
  
if (head($host1)) {
     print 'Requested document exists, second zip 
';
  }  
 
my $ua = LWP::UserAgent-> new;
my $req = HTTP::Request->new(GET =>$host);
   # $req->authorization_basic('$log', '$passw'); # autorization 
   my $res =  $ua->request($req, $NameFile); 

my $ua1 = LWP::UserAgent-> new;     
my $req1 = HTTP::Request->new(GET =>$host1);
   # $req->authorization_basic('$log', '$passw'); # autorization 
   my $res1 =  $ua1->request($req1, $NameFile1);      
 
if ($res->is_success){
    
    print 'Connect to server, first zip ...........Ok
';
   }
 else{
      die 'Downloading failed, first zip...
';
       die '$res->status_line
';
    }  
    
    
    
if ($res1->is_success){
    
    print 'Connect to server, second zip ...........Ok
';
   }
 else{
      die 'Downloading failed, second zip...
';
       die '$res->status_line
';
    }