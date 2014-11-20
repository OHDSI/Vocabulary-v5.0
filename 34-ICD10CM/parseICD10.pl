# Crawler for getting ICD-10 codes from the WHO Collaboration Center
# Version 1.0, 10-Oct-2014
#######################################
use warnings; use strict;
use LWP::RobotUA; # Loads LWP robot classes
my $mailrecipient='reich@ohdsi.org';

my $version="1.0";

$|=1;             # flush immediately

# 1. Open logs

our $Logfile=">>robot.log";
our $Errorfile=">robot.bad";
open Errorfile or die("Can't open error log $Errorfile: $!"); # can't ferror() this
open Logfile or ferror("Can't open logfile $Logfile: $!");

# 2. Prepare robot

my $browser = LWP::RobotUA->new("ICD-10 Robot $version", $mailrecipient);
$browser->delay(.1/20); # 5 ms delay
my $maxerrors=20; # countdown $maxerors, at 0 we pull the plug

# 3. Prepare classes

# temporary translation table between class_codes and ICD-10 chapters
# should be select concept_name, concept_code from concept where vocabulary_oode='Domain' and class_code='ICD10CM';
my %concept_class=(
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
my $home="http:\/\/apps.who.int\/classifications\/apps\/icd\/icd10online2007\/";
my $startdate="19700101";
warn "Reading TOC";
my $body=geturl($home."navi.htm") or ferror("Unable to get page: $!");
my %pages=(); # hash with all blocks
while ($body =~ /<a href="(\w+)\.htm">/ig) {
	$pages{$1} = 1;
}
%pages=("gt08"=>1); # "gk20"=>1

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
my $code; # ICD-10 code
my $desc; # ICD-10 code description
my $page; # collection of codes, less than chapter
my $thiscode; # to know while following instructions are active
my $stopcode; # to know when following instructions are finished
my $following; # whether a following intruction is active
my $codeext; # the extra digit to be aded to the code in an following instruction
my $textext; # the extra text to be added to the code 
my %ext; # array with all extensions per code
my $totable; # indicating what list is being printed (included, excluded, inclusionterm)
my $base; # for list where the same base is repeated 
my $printlast; # if the term ended in colon and therefore needn't be printed, or not
my $lastrecord; # if it turns out the previous term (collected over several html lines) was the last and needs be printed before a new one is started
my $fragment; # for counting the depth of the fragments
my @f_list; # for the columns in the fragment list

# 6. Get home page and start diving and parsing iteratively
my $tempfile="temp.htm";
foreach $page (sort(keys %pages)) {
# pull page
	my $body=geturl($home.$page.".htm") or ferror("Unable to get page: $!");

#	warn "Reading block $page";
	open ICD10, ">".$tempfile or ferror("Unable to open tempfile for writing: $!"); 
	print ICD10 $body or ferror("Unable to write temp file: $!");
	close ICD10;
	
	undef $code;
	open ICD10, $tempfile or ferror("Unable to open temp file: $!");

	$following=""; # whether to expand a code through "following" instructions

	while (<ICD10>) { # find chapter
		last if $_=~/<H1>Chapter/i;
	}
	while (<ICD10>) {
		next unless $_=~/<HR>(.+)/i;
		$chapter=$1; chomp($chapter);
		last;
	}
	while (<ICD10>) { # jump over lines till sections (H2) are done with
		last if $_=~/<span class="(klassitext)?white">/i;
	}
	# collect codes, descriptions and all other notes
	while (<ICD10>) {
		last if ($_=~/<HR>/i);
		if ($_=~/<A NAME="s\d\d[a-z]\d\d/) { # found following instructions
			<ICD10>=~/<\/A>(.+)/i; # the concept_code
			$following=$1;
			$stopcode=$thiscode="";
			$stopcode=$1 if ($following=~/\-([A-Z]\d\d)/); # when to stop expanding. If doesn't exist, when category of code (length) changes
			$thiscode=$code unless ($stopcode); # if no stop code provided, just work on current code
print "$code: This $thiscode, Stop $stopcode\n" if $following;
			while (<ICD10>) { # pick up instructions
				last if ($_=~/<\/TABLE>/i); # some of them close the table
				last if ($_=~/<EM>/i); # .. others not
				last if ($_=~/<TD VALIGN="TOP" ALIGN="LEFT" COLSPAN="[^68]">/i); # when inclusionterm table started unexpectedly
				if ($_=~/<TD VALIGN="TOP" ALIGN="LEFT" WIDTH="8%">(.*)/i) { # collect the expansion code
					$codeext=$1;
					while (<ICD10>) {
						last if ($_=~/<\/TD>/i);
						$codeext.=$1 if ($_=~/<[^>]+>(.*)/i); # collect anything after a tag, can be in subsequent lines
					}
					$codeext='.'.$codeext if (length($code) eq 3 && !$codeext=~/^\./); # add dot for 4th digit unless already there
				}
				elsif ($_=~/<TD VALIGN="TOP" ALIGN="LEFT" COLSPAN="[68]">(.*)/i) { # collect the expansion text
					$textext=$1;
					last if $codeext eq ""; # jump out quickly if it turns out to be an Inclusionterm (never collected a expansion code)
					while (<ICD10>) {
						last if ($_=~/<\/TD>/i);
						$textext.=$1 if ($_=~/<[^>]+>(.*)/i); # collect anything after a tag, can be in subsequent linesЖ
					}
					$textext=~s/^(\w)/, \l$1/; # comma and lowercase
					$ext{$codeext}=$textext; # record 
					$codeext=$textext=""; # and set back
				}
			}
		}
		elsif ($_=~/<A NAME=".+?"/i) {	# found a code	
			<ICD10>=~/<\/A>([\w\.]+)[\+\*]?/i; # the concept_code
			$code=$1; 
			while (<ICD10>) {
				if ($_=~/<STRONG>(.+)/i) { # the concept_name
					$desc=$1;
					$concepts++;
 					printrecord ($code, $desc, "concept"); # write out main record
					if ($thiscode) { # if we have to watch whether still in expansion
						unless ($code=~/$thiscode/) {
							$following=$stopcode=$thiscode=""; %ext=();
						}
					}
					if ($following) { # if codes need expansion
						foreach $codeext (keys(%ext)) { # print all the permutations of the expansion block
  							printrecord ($code.$codeext, $desc.$ext{$codeext}, "concept"); # write out expanded record
						}
						if ($code eq $stopcode) { # switch off expanding	
							$following=""; %ext=(); $stopcode="";
						}
					}
					last;
				}
			}
			$totable="inclusionterm"; # what comes after collecting the code and description are the synonyms (inclusionterms)
			next;
		}
		$totable="includes" if ($_=~/<STRONG>Includes:/i && $code);
		$totable="excludes" if ($_=~/<STRONG>Excludes:/i && $code);
		if ($_=~/<TD VALIGN="[^"]+" ALIGN="LEFT" COLSPAN="\d">(.+)/) { # found a list (inclusionterm, includes, excludes)
			$base=$1; $lastrecord=$1; 
			$fragment=""; # variable to build the description string for fragments
			while (<ICD10>) {
				$printlast=1;
				if ($lastrecord=~/(.+?)\:/) { # if ends in colon
					$base=$1." "; $printlast=0;
				}
				if ($_=~/<NOBR>\(/i) { # collect hyperlinks in parentheses
					$lastrecord.="(";
					while (<ICD10>) { 
						last if ($_=~/<\/NOBR>/i);
						if ($_=~/<A HREF=".+?">(.+)/i) {
							$lastrecord.=$1;
							next;
						}
						if ($_=~/<\/A>\)/i) {
							$lastrecord.=")";
							next;
						}
						if ($_=~/<\/A>\,/i) {
							$lastrecord.=", ";
							next;
						}
					}
				}
				elsif ($_=~/<BR>/) { # truly new line, print the previous (or not)
					push (@f_list, $lastrecord) if $printlast; # print the previous, unless ends in colon
					if ($_=~/<BR>&middot;\s+(.+)/i) { # print previous first
						$lastrecord=$base.$1;
					}
					elsif ($_=~/<BR>(.+)/i) { # the next one that is not a bullet (belongs to one above)
						$lastrecord=$base=$1; 
					}
				}
				elsif ($_=~/<TD VALIGN="[^"]/i) { # same as <BR>.*
					# push (@f_list, $lastrecord) if $printlast; # print the previous, unless ends in colon
					if ($_=~/<TD VALIGN="[^>]+>[\{\}]/i) { # found another fragment
						$fragment.=join('/', @f_list)." "; # build term from fragments
						@f_list=(); # start new list with next fragement column
						while (<ICD10>) {
							last unless ($_=~/<BR>[\{\}]/i); # skip repetitions
						}
					}
					elsif ($_=~/<TD VALIGN="[^>]+>(.+)/i) { # the next one that is not a bullet (belongs to one above)
						$lastrecord=$base=$1; 
					}
				}
				elsif ($_=~/<\/TR>/i) {
					last;
				}
			}
			# printrecord($code, $lastrecord) if $printlast; # print the previous, unless ends in colon
			if ($fragment) {
				$fragment.=join('/', @f_list)." "; # add the remaining fragments
				printrecord($code, $fragment, $totable); # print out fragmented line
			}
			else {
				foreach $fragment (@f_list) {
					printrecord($code, $fragment, $totable); # print out individual line
				}
			}
			$fragment=""; @f_list=();
		}
	}
	close ICD10;
}
logmessage("Wrote $concepts concepts, 0 relationships");

close CONCEPT;
close EXCLUDES;
close INCLUDES;
close INCLUSIONTERM;

sub ferror { # ("error message to log"), die at the end
    my $message=shift;
    print Errorfile timestamp(), $message, "\n";
    die $message;
}

sub logmessage { # ("message to log")
    my $message=shift;
    print Logfile timestamp(), $message, "\n";
    return;
}

sub logerror { # ("error message to log")
    my $message=shift;
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
    my $url=shift;
    my $response=$browser->get($url);
    ferror("URL $url returns ".$response->status_line) unless ($response->is_success);
    ferror("Content type not HTML in URL $url") unless $response->content_type eq 'text/html';
    return($response->decoded_content);
}

sub printrecord { # ($code, $text)
	my $code=shift; my $text=shift; my $totable=shift;
	$text=~s/\s*$//; # trim trailing spaces
print "$totable $code: $text\n" if ($totable eq "concept");
	print CONCEPT ",\"$text\",,ICD10,$concept_class{$chapter},,$code,$startdate,20991231,\n" or ferror("Writing concept.txt: $!") if $totable eq "concept";
	print INCLUSIONTERM "$code,\"$text\"\n" or ferror("Writing inclusionterm.txt: $!") if $totable eq "inclusionterm";
	print INCLUDES "$code,\"$text\"\n" or ferror("Writing includes.txt: $!") if $totable eq "includes";
	print CONCEPT_SYNONYM "$code,\"$text\",4093769\n" or ferror("Writing concept_synonym.txt: $!") if $totable eq "inclusionterm";
	print CONCEPT_SYNONYM "$code,\"$text\",4093769\n" or ferror("Writing concept_synonym.txt: $!") if $totable eq "concept";
	print EXCLUDES "$code,\"$text\"\n" or ferror("Writing excludes.txt: $!") if $totable eq "excludes";
}				
