#!/usr/bin/perl
use Getopt::Long;
 

my $homedir=$ENV{'HOME'};
my @improvements;
my $gold="";
my @inventions;
my $inputfile;
my $outputfile = "tmp_freeciv.sav";
my $remove;
my $gzipped = 0;
my $nation;
my $from_unit="";
my $to_unit="";
my $heal=0;
my $sicken=0;
my $verbosity = 2;
my %purge_cities;
my %units_id;
	$units_id{'Workers'} = 1;
	$units_id{'Engineers'} = 1;
	$units_id{'Riflemen'} = 11;
	$units_id{'Cavalry'} = 21;
	$units_id{'Knights'} = 19;
	$units_id{'Alpine Troops'} = 10;
	$units_id{'Destroyer'} = 37;
	$units_id{'Cruiser'} = 38;
	$units_id{'Transport'} = 43;
	$units_id{'Artillery'} = 25;
	$units_id{'Pikemen'} = 6;
	$units_id{'Archers'} = 5;
	$units_id{'Settlers'} = 0;
	$units_id{'Chariot'} = 5;
	$units_id{'Legion'} = 16;
	$units_id{'Musketeers'} = 7;
	$units_id{'Trireme'} =32;
	
sub print_help {
	print "Supported parameters:
	
--nation\t-n\tNation to manipulate
--input\t-i\tInput file (name of the save game)
--inv\t\tInvention to add/remove
--gold\t-g\tAmount of Gold for nation
--imp\t\tImprovement to add/remove to/from all cities
--remove\t-r\tRemove property rather than adding it
--purge-city\t-p\tPurge (delete) a city
";
	exit 0;
}

sub get_parameters {
	$help = 0;
	my @purge_cities_array;
	GetOptions("input|i=s" => \$inputfile,
		"imp=s" => \@improvements,
		"inv=s" => \@inventions,
		"purge-city|p=s" => \@purge_cities_array,
		"nation|n=s" => \$nation,
		"gold|g=s" => \$gold,
		"remove|r+" => \$remove,
		"fromunit|fu=s" => \$from_unit,
		"tounit|tu=s" => \$to_unit,
		"help|h+" => \$help,
		"dry-run|d+" => \$dry_run);
	if ( $help > 0 ) {
		print_help;
	}
	print "Inpupt file name by user: $inputfile\n";
	$inputfile =~ s/~/$homedir/g;
	while(! -e $inputfile) {
	    print "Trying to correct file name...\n";
	    if ( -e "$inputfile.gz" ) {
		$inputfile = $inputfile . ".gz";
		break;
	    }
	    if ( -e "$homedir/.freeciv/saves/$inputfile" ) {
		$inputfile = "$homedir/.freeciv/saves/$inputfile";
		break;
	    }
	    if ( -e "$homedir/.freeciv/saves/$inputfile.sav" ) {
		$inputfile = "$homedir/.freeciv/saves/$inputfile.sav";
		break;
	    }
	    $fn = "$homedir/.freeciv/saves/$inputfile.sav.gz";
	    print "Test $fn\n";
	    if ( -e $fn ) {
		print "Found...\n";
		$inputfile = $fn;
		break;
	    }
	    if ( ! -e $inputfile ) {
		die "$inputfile not found";
	    }
	    if (  -d $inputfile ) {
		die "$inputfile not a game but a folder";
	    }
	}
	print "Corrected Inpupt file name: $inputfile\n";

	foreach $ci (@purge_cities_array) {
	    $city = "\"$ci\"";
		$purge_cities{$city} = 1;
		print "Prepare to purge city <$city>; >" . $purge_cities{$city} . "<\n";
	}
	$city = "Whatnot";
	print "Prepare to purge city <$city>; >" . $purge_cities{$city} . "<\n";
	$units_id{'test'} = 1;
	foreach $key (keys (%units_id) ){
		print "$key = " . $units_id{$key} . "\n";
	}
	if ( length $from_unit > 0 and length $to_unit > 0 ) {
		if ( 0 ==  $units_id{'$from_unit'}  ) {
			logger (0, "Unknown unit type $from_unit, units will not be converted\n");
			$from_unit="";
			$to_unit="";
		}
		if ( 0 ==  $units_id{'$to_unit'} ) {
			logger (0, "Unknown unit type $to_unit, units will not be converted\n");
			$from_unit="";
			$to_unit="";
		}
	} else {
		$from_unit="";
		$to_unit="";
	}
#	$verbosity = $verbosity - $silence;
}

sub logger {
	($loglevel,$text) = @_;
	if ( $verbosity >= $loglevel ) {
		print $text;
	}
}

sub exec_command {
	( $command ) = @_;
	if ( $verbosity > 0 ) {
		logger 2,"Command: $command\n";
	}
	if ( $dry_run == 0 ) {
		$result = `$command`;
		print $result;
	}
}

sub parse_file {
	($ifile, $ofile) = @_;
	if ( $ifile =~ /\.gz$/ ) {
		$gzipped = 1;
		`gunzip $ifile`;
		$ifile=~ s/\.gz$//;
	}
#read input file and rename it	
	open( IFILE, "< $ifile"  ) or die "Cant open file $ifile";
	@file_array = ( <IFILE> ) ;
	close IFILE;

	if ( $gzipped == 1 ) {
		`gzip $ifile`;
		$ifile = "$ifile.gz";
	}
	$ifilebasename = $ifile;
	$ifilebasename =~ s/^.*\/([^\/]*)$/\1/;
	$backupdir = $homedir . "/.freeciv/backup";
	if ( ! -e $backupdir ) {
	    exec_command "mkdir -p \"$backupdir\"";
	}
	$index = 0;
	
	while( -e "$backupdir/$ifilebasename.backup.$index" ) {
		$index++;
	}
	
	exec_command "mv \"$ifile\" \"$backupdir/$ifilebasename.backup.$index\"";
	$ncities = 0;
	$ncities_index = -1;
	$nunits = 0;
	$nunits_index = -1;
	$in_right_nation = 0;
	$in_city_array = 0;
	$in_units_array = 0;
	%improvementindices;
	%inventionindices;
	%city_line_index;
	%unit_line_index;
	$improvements_column = -1;
	$improvements_new_column = -1;
	@city_line;
	@new_file_array;
	$file_index_line=0;
	$purged = 0;
#modify file 	

	foreach $line ( @file_array ) {
		$skip_this_line =0;
		if ( $line =~ /^ncities=(.+)$/ ) {
			$ncities = $1;
			$purged = 0;
			$ncities_index = $file_index_line;
			logger 1, "$ncities Cities found\n";
		}
		if ( $in_city_array > 0 ) {
			if ( $line=~ /}/ ) {
				$in_city_array = 0;
				if ( $purged > 0 ) {
				    print "Change line " . $new_file_array[$ncities_index] . " to ncities=$ncities\n";
				    $new_file_array[$ncities_index] = "ncities=$ncities\n";
				}
			}  else {
				@city_line=split( /,/,$line );
				$name = $city_line[$city_line_index{'name'}]	;
				logger 2, "City: $name\n";
				if ( $purge_cities{$name} == 1 ) {
				    $purged++;
				    logger 1, "Purge city $name\n";
				    $ncities--;
				    $skip_this_line =1;
				}
			}
		} else {
			if ( $line=~ /^c={/ ) {
				$line_copy = $line;
				$line_copy  =~ s/^c={"(.+)"$/\1/;
				$line_copy  =~ s/"\s*,\s*"/,/g;
				@cityfields=split(/,/,$line_copy);
				$column=0;
				foreach $cityfield ( @cityfields ) {
					$city_line_index{$cityfield} = $column ;
					$column++;
				}
				
				logger 1, "improvements_column = " . $city_line_index{'improvements'} . "\n";
				logger 1, "improvements_new_column = " . $city_line_index{'improvements_new'} . "\n";
				$in_city_array = 2;
			}
			if ( $line=~ /^u={/ ) {
				$line_copy = $line;
				$line_copy  =~ s/^u={"(.+)"$/\1/;
				$line_copy  =~ s/"\s*,\s*"/,/g;
				@unitfields=split(/,/,$line_copy);
				$column=0;
				foreach $unitfield ( @unitfields ) {
					$unit_line_index{$unitfield} = $column ;
					$column++;
				}
				
				logger 1, "Unit name collumn = " . $unit_line_index{'type'} . "\n";
				logger 1, "Unit ID collumn = " . $unit_line_index{'type_by_name'} . "\n";
				$in_unit_array = 2;
			}
		}		
		if ( $line =~ /^nation="(.*)"/ ) {
			if ( $1 eq $nation ) {
				$in_right_nation = 1;
				logger 1, "*";
			} else {
				$in_right_nation = 0;
				logger 1," ";
			};
			logger 1, "Nation: $1\n";
		}
		if ( $line =~ /^gold=(.*)/ ) {
			logger 1, "gold: $1\n";
		}
		if ( $in_right_nation > 0 ) {
			if ( length $gold > 0 )  {
				if ( $line=~ /gold=(.+)/ ) {
				    $file_array[$file_index_line]="gold=$gold\n";
				}
			}
			if ( $line=~ /invs_new="(.+)"/ ) {
			    $invs_new = $1;
			    print "invs_new = $invs_new\n";
			    @invs = split('', $1);
			    foreach $invention (@inventions) {
				print "Index $invention: " . $inventionindices{$invention} . "\n";
				if (  $remove == 0 ) {
				    if ( $invs[$inventionindices{$invention}] eq "0" ) {
					$invs[$inventionindices{$invention}] = "1";
					logger 1, "Added invention $invention for $nation\n";
				    } else 	{ 
					if ( $inventionindices{$invention} > 0 ) {
					    logger 1, "$invention already known by $nation; not changed\n";
					} else {
					    logger 1, "Don't know invention $invention; did you spell it correctly?\n";
					}
				    }
				} else  {
				    if ( $invs[$inventionindices{$invention}] eq "1" ) {
					$invs[$inventionindices{$invention}] = "0";
					logger 1, "Removed invention $invention for $nation\n"
				    } else {
					logger 1, "$invention not known by $nation; not changed\n"
				}
				}
			    }
			    $invs_mod = join('',@invs);
			    $file_array[$file_index_line] = "invs_new=\"$invs_mod\"\n";
			}
			if ( $in_unit_array ==1 ) {
				if ( length $from_unit > 0 ) {
					$from_id = $units_id{$from_unit};
					$to_id = $units_id{$to_unit};
					$file_array[$file_index_line]=~ s/$from_id\,\"$to_unit\"/$to_id\,\"$from_unit\"/;
				}
			}
			if ( $in_city_array == 1 ) {
				logger 3,"Before: $file_array[$file_index_line]";
				@prev_improvements = split '',$city_line[$city_line_index{'improvements_new'}];
				foreach $improvement (@improvements) {
					if ( exists $improvementindices{ $improvement } )  {
						if (  $remove == 0 ) {
							if ( $prev_improvements[$improvementindices{$improvement} + 1] eq '0' ) {
								$prev_improvements[$improvementindices{$improvement} + 1] = "1";
								logger 1,"Added $improvement to " . $city_line[$city_line_index{'name'}] . "\n";
							}
						} else {
							if ( $prev_improvements[$improvementindices{$improvement} + 1] eq '1' ) {
								$prev_improvements[$improvementindices{$improvement} + 1] = "0";
								logger 1,"Removed $improvement from " . $city_line[$city_line_index{'name'}] . "\n";
							}
						}
					} else {
						logger 0, "Don't know improvement $improvement\n";
					}
				}
				$new_improvements=join ('',@prev_improvements);
#				$city_line[$city_line_index{'improvements'}] = $new_improvements;	
				$city_line[$city_line_index{'improvements_new'}] = $new_improvements;	
				$file_array[$file_index_line]=join(',',@city_line);
				logger 3,"After: $file_array[$file_index_line]";
			}
			if ( $in_city_array  == 2 ) {
				$in_city_array  = 1;
			}
			if ( $in_unit_array  == 2 ) {
				$in_unit_array  = 1;
			}
		}
		if ( $line=~ /^improvement_order=/ ) {
			logger 1,"Found improvements-order:\n";
			$line_copy = $line;
			$line_copy  =~ s/^improvement_order="(.+)"$/\1/;
			$line_copy  =~ s/"\s*,\s*"/,/g;
			
			@allimprovements = split(/,/,$line_copy);
			$index=0;
			foreach $impr ( @allimprovements) {
				$improvementindices{$impr} = $index;
				logger 1, "$index : $impr\n";
				$index++;
			}
		} 
		if ( $line=~ /^technology_order=/ ) {
			logger 1,"Found technology-order:\n";
			$line_copy = $line;
			$line_copy  =~ s/^technology_order="(.+)"$/\1/;
			$line_copy  =~ s/"\s*,\s*"/,/g;
			
			@allinventions = split(/,/,$line_copy);
			$index=0;
			foreach $inv ( @allinventions ) {
			    chomp $inv;
				$inventionindices{$inv} = $index;
				logger 1, $inventionindices{$inv} . " : <$inv>\n";
				$index++;
			}
		} 
		if ( $skip_this_line  == 0 ) {
			push @new_file_array, $file_array[$file_index_line];
		}
		$file_index_line++;
	}
	$ofile = $ifile;
	$ofile =~ s/\.gz$//;

	open( OFILE, "> $ofile" );
	print OFILE @new_file_array;
	close OFILE;
	if ( $gzipped == 1 ) {
		`gzip $ofile`;
	}
}

sub main {
	get_parameters;
	parse_file( $inputfile,  $outputfile);
}

main
