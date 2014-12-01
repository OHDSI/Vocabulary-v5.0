# Crawler for getting ICD-10 codes from the WHO Collaboration Center
# Version 1.0, 10-Oct-2014
#######################################
use warnings; use strict;
use LWP::RobotUA; # Loads LWP robot classes
my $mailrecipient='reich@ohdsi.org';

my $version="1.0";
my $year="2003"; # which year to fetch
my $startdate="19700101"; # for 2003, after that probably the date of release

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

my $home; # URL
my %pages=(); # hash with all blocks
my $chapter=""; # global variable since redefined in every page
# 5. Read TOC page
if ($year<2008) { # old DIMDI version
	$home="http:\/\/apps.who.int\/classifications\/apps\/icd\/icd10online".$year."\/";
	warn "Reading TOC";
	my $body=geturl($home."navi.htm") or ferror("Unable to get page: $!");
	while ($body =~ /<a href="(\w+)\.htm">/ig) {
		$pages{$1} = 1;
	}
	%pages=("ga15"=>1); # gt08 gk20 gs00
}
else { # new WHO version
	$home="http:\/\/apps.who.int\/classifications\/icd10\/browse\/".$year."\/en\/GetConcept?ConceptId=";
	my @chapters=("I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X", "XI", "XII", "XIII", "XIV", "XV", "XVI", "XVII", "XVIII", "XIX", "XX", "XXI", "XXII");
	foreach $chapter (@chapters) {
		warn "Reading TOC from chapter $chapter";
		my $body=geturl($home.$chapter) or ferror("Unable to get page: $!");
		while ($body =~ /<a href=.+?title=.+?class="code[^>]+>(\w\d\d\-[^<]+[^\*])<\/a>/ig) {
			$pages{$1} = 1;
		}
	}
	# my %pages=("A00-A09"=>1);
}


# 5. Open all result files

open CONCEPT, ">concept_stage.txt" or ferror("Writing concept_stage.txt: $!"); 
print CONCEPT "concept_id,concept_name,domain_id,vocabulary_id,concept_class_id,standard_concept,concept_code,valid_start_date,valid_end_date,invalid_reason\n";
open CONCEPT_SYNONYM, ">concept_synonym.txt" or ferror("Writing concept_stage.txt: $!"); 
print CONCEPT_SYNONYM "concept_code,concept_synonym_name,language_concept_id\n";
open EXCLUDES, ">excludes.txt" or ferror("Writing excludes.txt: $!"); print EXCLUDES "concept_code,note\n";
open INCLUDES, ">includes.txt" or ferror("Writing includes.txt: $!"); print INCLUDES "concept_code,note\n";
open INCLUSIONTERM, ">inclusionterm.txt" or ferror("Writing inclusionterm.txt: $!"); print INCLUSIONTERM "concept_code,note\n";

my $concepts=0; # the counter for concepts found and written
my $code; # ICD-10 code
my $desc; # ICD-10 code description
my $page; # collection of codes, less than chapter
my @f_list; # containing the fragments for the new version
my $thiscode; # to know while following instructions are active
my $thisdesc; # to keep the description in case we need to print expansion when already in following code space
my $printthis; # whether we have something to print within $thiscode (S02), or the previous code (T08)
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

# 6. Get home page and start diving and parsing iteratively
my $tempfile="temp.htm";
if ($year<2008) { # old DIMDI version
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
				$thisdesc=$desc; # keep the descripion in case we need to print it when already in next code space
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
						$codeext=~s/^\.?(.*)/$1/; # chop off dot, will add during printing when necessary
					}
					elsif ($_=~/<TD VALIGN="TOP" ALIGN="LEFT" COLSPAN="[68]">(.*)/i) { # collect the expansion text
						$textext=$1;
						last if $codeext eq ""; # jump out quickly if it turns out to be an Inclusionterm (never collected a expansion code)
						while (<ICD10>) {
							last if ($_=~/<\/TD>/i);
							$textext.=$1 if ($_=~/<[^>]+>(.*)/i); # collect anything after a tag, can be in subsequent lines
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
							$printthis=0; # assume we haven't printed anything yet
							if ($code=~/$thiscode/) { # if we have an expansion 
								$printthis=1; # have codes that still fit thiscode (like S02), don't print previous (like T08)
								foreach $codeext (keys(%ext)) { # print all the permutations of the expansion block
									printrecord ($code.".".$codeext, $desc.$ext{$codeext}, "concept") if (length($code) eq 3); # write out expanded record with dot
									printrecord ($code.$codeext, $desc.$ext{$codeext}, "concept") unless (length($code) eq 3); # write out expanded record without dot
								}
							}
							else { # we are outside $thiscode
								unless ($printthis) { # we have codes that are within $thiscode
									foreach $codeext (keys(%ext)) { # print all the permutations of the expansion block
										printrecord ($thiscode.".".$codeext, $thisdesc.$ext{$codeext}, "concept") if (length($thiscode) eq 3); # write out expanded record for the previous code with dot
										printrecord ($thiscode.$codeext, $thisdesc.$ext{$codeext}, "concept") unless (length($thiscode) eq 3); # write out expanded record for the previous code w/o dot
									}
								}
								$following=$stopcode=$thiscode=""; %ext=(); # and switch off expansion
							}
						}
						elsif ($stopcode) { # if codes need expansion
							foreach $codeext (keys(%ext)) { # print all the permutations of the expansion block
								printrecord ($code.".".$codeext, $desc.$ext{$codeext}, "concept") if (length($code) eq 3); # write out expanded record with dot
								printrecord ($code.$codeext, $desc.$ext{$codeext}, "concept") unless (length($code) eq 3); # write out expanded record w/o dot
							}
							if ($code eq $stopcode) { # switch off expanding at the last one	
								$following=$stopcode=$thiscode=""; %ext=(); 
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
					elsif ($_=~/<BR>/i) { # truly new line, print the previous (or not)
						push (@f_list, $lastrecord) if ($printlast && $lastrecord); # print the previous, unless ends in colon
						$lastrecord="";
						if ($_=~/<BR>&middot;\s+(.+)/i) { # print previous first
							$lastrecord=$base.$1;
						}
						elsif ($_=~/<BR>(.+)/i) { # the next one that is not a bullet (belongs to one above)
							$lastrecord=$base=$1; 
						}
					}
					elsif ($_=~/<TD VALIGN="[^"]/i) { # same as <BR>.*
						push (@f_list, $lastrecord) if ($printlast && $lastrecord); # print the previous, unless ends in colon
						$lastrecord="";
						if ($_=~/<TD VALIGN="[^>]+>[\{\}]/i) { # found another fragment
							$fragment.=join('/', @f_list)." "; # build term from fragments
							@f_list=(); # start new list with next fragement column
# 							$frag_count=1; # start wtih one and count to make sure the right most column doesn't run over
							while (<ICD10>) {
# 								$frag_count++;
								last unless ($_=~/<BR>[\{\}]/i); # skip repetitions
							}
						}
						elsif ($_=~/<TD VALIGN=[^>]+>&middot;\s+(.+)/i) { # print previous first
							$lastrecord=$base.$1;
						}
						elsif ($_=~/<TD VALIGN=[^>]+>(.+)/i) { # the next one that is not a bullet (belongs to one above)
							$lastrecord=$base=$1; 
						}
					}
					elsif ($_=~/<STRONG>/i) {
						last;
					}
 					elsif ($_=~/<\/TR>/i) {
print "Last $lastrecord, Base $base, list @f_list\n" if $code eq 16.3;
						last unless @f_list;
					}
				}
				printrecord($code, $lastrecord, $totable) if ($printlast && $lastrecord); # print the previous, unless ends in colon
				if ($fragment) {
					$fragment.=join('/', @f_list); # add the remaining fragments
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
}
else { # new WHO version
	foreach $page (sort(keys %pages)) {
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
				
				printrecord($code, $desc, "concept");
				for (; $_=~/<\/h[45]>/i; <ICD10>) {;} # find end of block
			}
			elsif ($_=~/<dt title="(\w\w)clusivum">\w\wcl\.:<\/dt>/i) { # get includes or excludes statement
				$totable="includes" if $1=~/in/i;
				$totable="excludes" if $1=~/ex/i;
				while (<ICD10>) { # grab list and dissect
					last if ($_=~/<\/dl>/i); # end of block
					next if ($_=~/^\s*<\/?dd>\s*$/i); # empty line
					$_=~s/<dd>//i; # remove tags
					if ($_=~/\s*(.*?)<\/dd>/i) { # get next line if content not after <dd>
						my $term=$1;
						$term=~s/\(?<a href="[^"]+">([^<]+)<\/a>\)?\s*/$1/g; # remove hyperlinks
						if ($term=~/([^<]+)<ul class="Rubric-Label-Fragment-list1">/i) { # if list of bullets
							$base=$1;
							if ($base=~/(.+):$/) { # if bullet has colon at the end strip and combine only 
								$base=$1;
							}
							else { # otherwise print out alone
								printrecord($code, $base, $totable);
								$base=~s/\s*\w\d\d[\.\d]*//gi; # and remove links from subsequent combinations
							}
							while ($term=~/<li class="Rubric-Label-Fragment-listitem1">(.+?)<\/li>/gi) { # print bulleted components
								my $addon=$1;
								$addon=" ".$addon if ($addon=~/^\S/);
								printrecord($code, $base.$addon, $totable);
							}
						}
						else {
							printrecord($code, $term, $totable);
						}
					}
					elsif ($_=~/<table class="Rubric-Fragment-TwoColumnTable">/) { # fragment table
						my $term="";
						while (<ICD10>) {
						if ($_=~/<td class="Rubric-Fragment-TwoColumnTable/i) { # starting a column
								@f_list=();
								while (<ICD10>) {
									push @f_list, $1 if ($_=~/<li>([^<]+)<\/li>/i); # collect a bullet
									last if ($_=~/<\/td>/i);
								}
								$term.=join("/", @f_list)." ";
							}
							last if ($_=~/<\/table>/i);
						}
						$term=~s/(.*) /$1/; # trim space at the end
						printrecord($code, $term, $totable);
					}
				} # while running through lines within block
			} # includes/excludes block
		}
		close ICD10;
	}
}	
	
logmessage("Wrote $concepts concepts, 0 relationships");

close CONCEPT;
close CONCEPT_SYNONYM;
close EXCLUDES;
close INCLUDES;
close INCLUSIONTERM;

sub printrecord { # ($code, $text)
	my $code=shift; my $text=shift; my $totable=shift;
	$text=~s/\s*$//; # trim trailing spaces
# print "$totable $code: $text\n" if ($totable eq "concept");
	print CONCEPT ",\"$text\",,ICD10,$concept_class{$chapter},,$code,$startdate,20991231,\n" or ferror("Writing concept.txt: $!") if $totable eq "concept";
	print INCLUSIONTERM "$code,\"$text\"\n" or ferror("Writing inclusionterm.txt: $!") if $totable eq "inclusionterm";
	print INCLUDES "$code,\"$text\"\n" or ferror("Writing includes.txt: $!") if $totable eq "includes";
	print EXCLUDES "$code,\"$text\"\n" or ferror("Writing excludes.txt: $!") if $totable eq "excludes";
	$text=~s/\+? \([A-Z]\d\d[^\)]*\)//g; # remove things like '+ (M26.0)'
	print CONCEPT_SYNONYM "$code,\"$text\",4093769\n" or ferror("Writing concept_synonym.txt: $!") if $totable eq "inclusionterm";
	print CONCEPT_SYNONYM "$code,\"$text\",4093769\n" or ferror("Writing concept_synonym.txt: $!") if $totable eq "concept";
}				

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
