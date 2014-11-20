# Crawler for getting ICD-10 codes from the WHO Collaboration Center
# Version 1.0, 10-Oct-2014
#######################################

$version="1.0";

$|=1;             # flush immediately

use LWP::RobotUA; # Loads LWP robot classes
$mailrecipient='reich@ohdsi.org';

# 1. Open logs

$Logfile=">>robot.log";
$Errorfile=">robot.bad";
unless (open Errorfile) {
    die("Can't open error log $Errorfile: $!"); # can't ferror() this
}
open Logfile or ferror("Can't open logfile $Logfile: $!");

die;

# 2. Prepare robot

$browser = LWP::RobotUA->new("ICD-10 Robot $version", $mailrecipient);
$browser->delay(.1/20); # 5 ms delay
# geturl("http://apps.who.int/classifications/apps/icd") or ferror("Unable to get page: $!"); # test robot

$maxerrors=20; # countdown $maxerors, at 0 we pull the plug

# 3. Prepare classes

# temporary translation table between class_codes and ICD-10 chapters
# should be select concept_name, concept_code from concept where vocabulary_oode='Domain' and class_code='ICD10CM';
%concept_class=(
"Certain infectious and parasitic diseases"=>"Infectious Disease",
"Neoplasms"=>"Neoplasm",
"Diseases of the blood and blood-forming organs and certain disorders involving the immune mechanism"=>"Blood/Immune Disease",
"Endocrine, nutritional and metabolic diseases"=>"Endocrine Disease",
"Mental, Behavioral and Neurodevelopmental disorders"=>"Mental Disease",
"Organic, including symptomatic, mental disorders"=>"Mental Disease", # old name in ICD-10
"Mental and behavioural disorders"=>"Mental Disease", # old name in ICD-10 2003
"Diseases of the nervous system"=>"Nervous Disease",
"Diseases of the eye and adnexa"=>"Eye Disease",
"Diseases of the ear and mastoid process"=>"Ear Disease",
"Diseases of the circulatory system"=>"Circulatory Disease",
"Diseases of the respiratory system"=>"Respiratory Disease",
"Diseases of the digestive system"=>"Digestive Disease",
"Diseases of the skin and subcutaneous tissue"=>"Skin Disease",
"Diseases of the musculoskeletal system and connective tissue"=>"Soft Tissue Disease",
"Diseases of the genitourinary system"=>"Genitourinary Dis",
"Pregnancy, childbirth and the puerperium"=>"Pregnancy",
"Certain conditions originating in the perinatal period"=>"Perinatal Disease",
"Congenital malformations, deformations and chromosomal abnormalities"=>"Congenital Disease",
"Symptoms, signs and abnormal clinical and laboratory findings, not elsewhere classified"=>"Symptom",
"Injury, poisoning and certain other consequences of external causes"=>"Injury",
"External causes of morbidity and mortality"=>"Injury", # old name in ICD-10
"External causes of morbidity"=>"External Cause",
"Factors influencing health status and contact with health services"=>"Health Service",
"Codes for special purposes"=>"Special Code" # in ICD-10 only
);

# 5. Read TOC page
################################################################################
# Change the year in the following. Years supported by this script are 2003-2007
################################################################################

$home="http:\/\/apps.who.int\/classifications\/icd10\/browse\/2008\/en\/GetConcept?ConceptId=";

my @chapters=("I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X", "XI", "XII", "XIII", "XIV", "XV", "XVI", "XVII", "XVIII", "XIX", "XX", "XXI", "XXII");
my %page=(); # hash with all blocks
while (0) {#foreach $chapter (@chapters) {
	warn "Reading TOC from chapter $chapter";
	my $body=geturl($home.$chapter) or ferror("Unable to get page: $!");
	while ($body =~ /<a href=.+?title=.+?class="code[^>]+>(\w\d\d\-[^<]+[^\*])<\/a>/ig) {
		$page{$1} = 1;
	}
}

my %page=("A00-A09"=>1);
warn %page;

# 5. Open all result files
# replace with read from page
# replace open with reading from downloaded file

open CONCEPT, ">concept_stage.txt" or ferror("Writing concept_stage.txt: $!"); 
print CONCEPT "concept_id,concept_name,domain_id,vocabulary_id,concept_class_id,standard_concept,concept_code,valid_start_date,valid_end_date,invalid_reason\n";
open CONCEPT_SYNONYM, ">concept_synonym.txt" or ferror("Writing concept_stage.txt: $!"); 
print CONCEPT_SYNONYM "concept_code,concept_synonym_name,language_concept_id\n";
open EXCLUDES, ">excludes.txt" or ferror("Writing excludes.txt: $!"); print EXCLUDES "concept_code,note\n";
open INCLUDES, ">includes.txt" or ferror("Writing includes.txt: $!"); print INCLUDES "concept_code,note\n";
open INCLUSIONTERM, ">inclusionterm.txt" or ferror("Writing inclusionterm.txt: $!"); print INCLUSIONTERM "concept_code,note\n";

my $concepts=0; # the counter for concepts found and written
my $chapter=""; # global variable since redefined in every page

# 6. Get home page and start diving and parsing iteratively
$tempfile="temp.htm";
foreach $page (sort(keys %page)) {
# pull page
	my $body=geturl($home.$page) or ferror("Unable to get page: $!");
	warn "Reading block $page";
	open ICD10, ">".$tempfile or ferror("Unable to open tempfile for writing: $!"); 
	print ICD10 $body or ferror("Unable to write temp file: $!");
	close ICD10;
	
	undef $code;
	open ICD10, $tempfile or ferror("Unable to open temp file: $!");
	# get chapter
	while (<ICD10>) {
		next unless $_=~/<h2>Chapter [^<]+<br \/>([^<]+)<br \/>/i;
		$chapter=$1; 
		last;
	}
	while (<ICD10>) { # jump over lines till sections are done with
		last if $_=~/<div class="Category/i;
	}
	# collect codes, descriptions and all other notes
	while (<ICD10>) {
		if ($_=~/<h[45]/i) { # new code
			<ICD10>=~/name="([^"]+)"/i; # the concept_code
			$code=$1; 
			<ICD10>=~/<span class="label">([^<]+)<\/span>/i; # the concept_name
			$desc=$1;
			$desc=~s/\(<a href="[^"]+">([^<]+)<\/a>\)\s*/$1/g; # remove hyperlinks
			$concepts++;
			
			print CONCEPT ",\"$desc\",,ICD10,$concept_class{$chapter},,$code,1-Jan-1970,31-Dec-2099,\n" or ferror("Writing concept.txt: $!");
			print CONCEPT_SYNONYM "$code,\"$desc\",4093769\n" or ferror("Writing concept_synonym.txt: $!");
			for (; $_=~/<\/h[45]>/i; <ICD10>) {;} # find end of block
		}
		elsif ($_=~/<dt title="(\w\w)clusivum">\w\wcl\.:<\/dt>/i) { # get includes or excludes statement
			$printtable="includes" if $1=~/in/i;
			$printtable="excludes" if $1=~/ex/i;
			while (<ICD10>) { # grab list and dissect
				last if ($_=~/<\/dl>/i); # end of block
				next if ($_=~/^\s*<\/?dd>\s*$/i); # empty line
				$_=~s/<dd>//i; # remove tags
				if ($_=~/\s*(.*?)<\/dd>/i) { # get next line if content not after <dd>
					$term=$1;
					$term=~s/\(?<a href="[^"]+">([^<]+)<\/a>\)?\s*/$1/g; # remove hyperlinks
					if ($term=~/([^<]+)<ul class="Rubric-Label-Fragment-list1">/i) { # if list of bullets
						$base=$1;
						if ($base=~/(.+):$/) { # if bullet has colon at the end strip and combine only 
							$base=$1;
						}
						else { # otherwise print out alone
							printrecord($code, $base);
							$base=~s/\s*\w\d\d[\.\d]*//gi; # and remove links from subsequent combinations
						}
						while ($term=~/<li class="Rubric-Label-Fragment-listitem1">(.+?)<\/li>/gi) {
							$addon=$1;
							$addon=" ".$addon if ($addon=~/^\S/);
							printrecord($code, $base.$addon);
						}
					}
					else {
						printrecord($code, $term);
					}
				}
				elsif ($_=~/<table class="Rubric-Fragment-TwoColumnTable">/) { # fragment table
					$term="";
					while (<ICD10>) {
					if ($_=~/<td class="Rubric-Fragment-TwoColumnTable/i) { # starting a column
							@fragment=();
							while (<ICD10>) {
								push @fragment, $1 if ($_=~/<li>([^<]+)<\/li>/i); # collect a bullet
								last if ($_=~/<\/td>/i);
							}
							$term.=join("/", @fragment)." ";
						}
						last if ($_=~/<\/table>/i);
					}
					$term=~s/(.*) /$1/; # trim space at the end
					printrecord($code, $term);
				}
			} # while running through lines within block
		} # includes/excludes block
	}
	close ICD10;
}
logmessage("Wrote $concepts concepts, 0 relationships");

close CONCEPT;
close CONCEPT_SYNONYM;
close EXCLUDES;
close INCLUDES;
close INCLUSIONTERM;

sub ferror { # ("error message to log"), die at the end
    $message=shift;
    print Errorfile timestamp(), $message, "\n";
    die $message;
}

sub logmessage { # ("message to log")
    $message=shift;
    print Logfile timestamp(), $message, "\n";
    return;
}

sub logerror { # ("error message to log")
    $message=shift;
    unless (--$maxerrors) { # too many soft errors
        ferror("Maxerrors exhaustet: ".$message);
    }
    print Errorfile timestamp(), $message, "\n";
    return;
}

sub timestamp { # ()
    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst)=localtime(time);
    $year+=1900; $mon++;
    return "$mday.$mon.$year, $hour:$min:$sec: ";
}

sub geturl { # ($url);
    $url=shift;
    my $response=$browser->get($url);
    ferror("URL $url returns ".$response->status_line) unless ($response->is_success);
    ferror("Content type not HTML in URL $url") unless $response->content_type eq 'text/html';
    return($response->decoded_content);
}

sub printrecord { # ($code, $text)
	my $code=shift; my $text=shift;
print "$printtable $code: $text\n";
	print CONCEPT ",\"$desc\",,ICD10,$concept_class{$chapter},,$code,1-Jan-1970,31-Dec-2099,\n" or ferror("Writing concept.txt: $!") if $printtable eq "concept";
	print INCLUSIONTERM "$code,\"$text\"\n" or ferror("Writing inclusionterm.txt: $!") if $printtable eq "inclusionterm";
	print INCLUDES "$code,\"$text\"\n" or ferror("Writing includes.txt: $!") if $printtable eq "includes";
	print CONCEPT_SYNONYM "$code,\"$text\",4093769\n" or ferror("Writing concept_synonym.txt: $!") if $printtable eq "inclusionterm";
	print CONCEPT_SYNONYM "$code,\"$text\",4093769\n" or ferror("Writing concept_synonym.txt: $!") if $printtable eq "concept";
	print EXCLUDES "$code,\"$text\"\n" or ferror("Writing excludes.txt: $!") if $printtable eq "excludes";
}				
