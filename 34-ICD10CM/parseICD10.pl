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
"Organic, including symptomatic, mental disorders"=>"Metnal Disease", # old name in ICD-10
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

# 4. Read existing ones, so if it crashes we can continue where we left off

%icd10=(); # create hash with all codes and deescriptions
$icd10codes="ICD10-Codes.txt";
if (-e $icd10codes) {
	open icd10codes or ferror("Can't open $icd10codes: $!");
	<icd10codes>; # skip header row
	$count=0;
	while (<icd10codes>) {
		chomp;
		@fields=split(/\t/);
		$code=shift(@fields); $description=shift(@fields);
		$icd10{$code}=$description;
	}
	# print "$_ $atc{$_}\n" for (keys %atc);
	close icd10codes;
}

# read TOC page
$home="http:\/\/apps.who.int\/classifications\/apps\/icd\/icd10online2003\/";
warn "Reading TOC from $url";
my $body=geturl($home."navi.htm") or ferror("Unable to get page: $!");
my %page=(); # hash with all blocks
while ($body =~ /<a href="(\w+)\.htm">/ig) {
	$page{$1} = 1;
}
# my %page=("ga15"=>1);

# 5. Open all result files
# replace with read from page
# replace open with reading from downloaded file

open CONCEPT, ">concept.txt" or ferror("Writing concept.txt: $!"); 
print CONCEPT "concept_id,concept_name,vocabulary_code,class_code,concept_code\n";
open EXCLUDES, ">excludes.txt" or ferror("Writing excludes.txt: $!"); print EXCLUDES "concept_code,note\n";
open INCLUDES, ">includes.txt" or ferror("Writing includes.txt: $!"); print INCLUDES "concept_code,note\n";
open INCLUSIONTERM, ">inclusionterm.txt" or ferror("Writing inclusionterm.txt: $!"); print INCLUSIONTERM "concept_code,note\n";

$concepts=0; # the counter for concepts found and written
$relationships=0; # the counter for concept_relationships written
$chapter=""; # global variable since redefined in every page

# 6. Get home page and start diving and parsing iteratively
$tempfile="temp.htm";
foreach $page (sort(keys %page)) {
# pull page
	$url=$home.$page.".htm";
	my $body=geturl($url) or ferror("Unable to get page: $!");

	warn "Reading block $page";
	open ICD10, ">".$tempfile or ferror("Unable to open tempfile for writing: $!"); 
	print ICD10 $body or ferror("Unable to write temp file: $!");
	close ICD10;
	
	undef $code;
	open ICD10, $tempfile or ferror("Unable to open temp file: $!");
	while (<ICD10>) { # find chapter
		last if $_=~/<H1>Chapter/i;
	}
	while (<ICD10>) {
		next unless $_=~/<HR>(.+)/i;
		$chapter=$1; chomp($chapter);
		last;
	}
	while (<ICD10>) { # jump over lines till sections (H2) are done with
		last if $_=~/<\/H2>/i;
	}
	# collect codes, descriptions and all other notes
	while (<ICD10>) {
		if ($_=~/<A NAME=".+?"/i) {
			<ICD10>=~/<\/A>([\w\.]+)[\+\*]?/i; # the concept_code
			$code=$1; chomp($code); 
			$keytotable="inclusionterm";
			while (<ICD10>) {
				if ($_=~/<STRONG>(.+)/i) { # the concept_name
					$desc=$1; chomp($desc);
					$concepts++;
					printf CONCEPT "1,\"$desc\",ICD10CM,$concept_class{$chapter},$code,1970-01-01,2099-12-31,\n" or ferror("Writing concept.txt: $!");
					$keytotable="inclusionterm";
					last;
				}
				next;
			}
			next;
		}
		# None-standard ones
		$keytotable="includes" if ($_=~/<STRONG>Includes:/i && $code);
		$keytotable="excludes" if ($_=~/<STRONG>Excludes:/i && $code);
		if ($_=~/<TD VALIGN="TOP" ALIGN="LEFT" COLSPAN="\d">(.+)/) {
			$base=$1; $lastrecord=$1; 
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
					printrecord($code, $lastrecord) if $printlast; # print the previous, unless ends in colon
					if ($_=~/<BR>&middot;\s+(.+)/i) { # print previous first
						$lastrecord=$base.$1;
					}
					elsif ($_=~/<BR>(.+)/i) { # the next one that is not a bullet (belongs to one above)
						$lastrecord=$base=$1; 
					}
				}
				elsif ($_=~/<\/TR>/i) {
					# printrecord($code, $lastrecord) if $printlast;
					last;
				}
			}
		}
		last if ($_=~/<HR>/i);
	}
	close ICD10;
}
logmessage("Wrote $concepts concepts, $relationships relationships");

close CONCEPT;
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
	printf INCLUSIONTERM "$code,\"$text\"\n" or ferror("Writing inclusionterm.txt: $!") if $keytotable eq "inclusionterm";
	printf INCLUDES "$code,\"$text\"\n" or ferror("Writing includes.txt: $!") if $keytotable eq "includes";
	printf EXCLUDES "$code,\"$text\"\n" or ferror("Writing excludes.txt: $!") if $keytotable eq "excludes";
}				
