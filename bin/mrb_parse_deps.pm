# parse product_deps

# product_deps format:

#   parent       this_product   this_version
#   defaultqual  qualifier
#
#   [incdir      product_dir    include]
#   [fcldir      product_dir    fcl]
#   [libdir      fq_dir	        lib]
#   [bindir      fq_dir         bin]
#   [fwdir       -              unspecified]
#   [gdmldir     -              gdml]
#
#   product		version
#   dependent_product	dependent_product_version [optional]
#
#   qualifier dependent_product       dependent_product notes
#   this_qual dependent_product_qual  dependent_product_qual
#   this_qual dependent_product_qual  dependent_product_qual
#
# cetbuildtools v4 and later
#   product		version
#   dependent_product	dependent_product_version [distinguishing qualifier|-] [optional|only_for_build]
#
#   qualifier dependent_product1       dependent_product2	notes
#   qual_set1 dependent_product1_qual  dependent_product2_qual	optional notes about this qualifier set
#   qual_set2 dependent_product1_qual  dependent_product2_qual

# The indir, fcldir, libdir, and bindir lines are optional
# Use them only if your product does not conform to the defaults
# Format: directory_type directory_path directory_name
# The only recognized values of the first field are incdir, fcldir, libdir, and bindir
# The only recognized values of the second field are product_dir and fq_dir
# The third field is not constrained
#
# if dependent_product_version is a dash, the "current" version will be specified
# If a dependent product is optional, then add "optional" to the third field. 

#
# Use as many rows as you need for the qualifiers
# Use a separate column for each dependent product that must be explicitly setup
# Do not list products which will be setup by a dependent_product
#
# special qualifier options
# -	not installed for this parent qualifier
# -nq-	this dependent product has no qualifier
# -b-	this dependent product is only used for the build - it will not be in the table

use List::Util qw(min max); # Numeric min / max funcions.

use strict;
use warnings;

sub get_package_list {
  my @params = @_;
  my $dfile = $params[1];
  my @plist = ();
  my $pdep;
  my $pnames;
  my $pver;
  my $line;
  my $i = 0;
  open(CIN, "< $params[0]") or die "Couldn't open $params[0]";
  while ( $line=<CIN> ) {
    chop $line;
    if ( index($line,"#") == 0 ) {
    } elsif ( $line !~ /\w+/ ) {
    } else {
      my @words = split(/\(+/,$line);
      if( $words[0] eq "ADD_SUBDIRECTORY" ) {
	my @w2 = split(/\)+/,$words[1]);
	$plist[$i] = $w2[0];
	++$i;
      }
    }
  }
  close(CIN);

##  print $dfile "get_package_list: found $i packages\n";
##  for $ii ( 0 .. $#plist ) {
##    print $dfile "get_package_list: product $ii $plist[$ii]\n";
##  }

  return (@plist);
}

sub get_product_name {
  my @params = @_;
  my $dfile = $params[1];
  my $pname;
  my $pver;
  my $line;
  ##print $dfile "now check $params[0]\n";
  open(PIN, "< $params[0]") or die "Couldn't open $params[0]";
  while ( $line=<PIN> ) {
    chop $line;
    if ( index($line,"#") == 0 ) {
    } elsif ( $line !~ /\w+/ ) {
    } else {
      my @words = split(/\s+/,$line);
      if( $words[0] eq "parent" ) {
         ##print $dfile "found parent in $line\n";
	 $pname=$words[1];
	 $pver=$words[2];
      }
    }
  }
  close(PIN);
  return ($pname, $pver);
}

sub find_cetbuildtools {
  my @params = @_;
  my $count = 0;
  my $line;
  my $cver;
  open(PIN, "< $params[0]") or die "Couldn't open $params[0]";
  while ( $line=<PIN> ) {
    chop $line;
    if ( index($line,"#") == 0 ) {
    } elsif ( $line !~ /\w+/ ) {
    } else {
      my @words = split(/\s+/,$line);
      if( $words[0] eq "only_for_build" ) {
       if( $words[1] eq "cetbuildtools" ) {
           $cver = $words[2];
	}
      }
    }
  }
  close(PIN);
  return ($cver);
}

sub compare_versions {
  my $ver1 = $_[0];
  my $ver2 = $_[1];
  my $version = $ver1;
  my @vers1 = ();
  my @vers2 = ();
  @vers1 = split(/_/,$ver1);
  @vers2 = split(/_/,$ver2);
  if ( $vers2[0] gt $vers1[0] ) {
     $version = $ver2;
  } elsif ( ( $vers2[0] eq $vers1[0]) && ($vers2[1] gt $vers1[1] ) ) {
     $version = $ver2;
  } elsif ( ( $vers2[0] eq $vers1[0]) && ($vers2[1] eq $vers1[1] ) && ($vers2[2] gt $vers1[2]) ) {
     $version = $ver2;
  }
  return $version;

}

sub get_parent_info {
  my @params = @_;
  open(PIN, "< $params[0]") or die "Couldn't open $params[0]";
  my $extra="none";
  my $line;
  my @words;
  my $prod;
  my $ver; 
  my $fq = "true";
  my $dq = "-nq-";
  while ( $line=<PIN> ) {
    chop $line;
    if ( index($line,"#") == 0 ) {
    } elsif ( $line !~ /\w+/ ) {
    } else {
      @words = split(/\s+/,$line);
      if( $words[0] eq "parent" ) {
	 $prod=$words[1];
	 $ver=$words[2];
	 if( $words[3] ) { $extra=$words[3]; }
      } elsif( $words[0] eq "defaultqual" ) {
	 $dq=$words[1];
      } elsif( $words[0] eq "no_fq_dir" ) {
          $fq = "";
      } else {
        ##print "get_parent_info: ignoring $line\n";
      }
    }
  }
  close(PIN);
  return ($prod, $ver, $extra, $dq, $fq);
}

sub get_product_list {
  my @params = @_;
  open(PIN, "< $params[0]") or die "Couldn't open $params[0]";
  my $get_phash="";
  my $pv="";
  my $dqiter=-1;
  my $piter=-1;
  my $i;
  my $line;
  my @plist;
  my @words;
  my @dplist;
  while ( $line=<PIN> ) {
    chop $line;
    if ( index($line,"#") == 0 ) {
    } elsif ( $line !~ /\w+/ ) {
    } else {
      my @words = split(/\s+/,$line);
      if( $words[0] eq "product" ) {
	 $get_phash="true";
      } elsif( $words[0] eq "end_product_list" ) {
	 $get_phash="";
      } elsif( $words[0] eq "end_qualifier_list" ) {
         $get_phash="";
      } elsif( $words[0] eq "parent" ) {
         $get_phash="";
      } elsif( $words[0] eq "no_fq_dir" ) {
         $get_phash="";
      } elsif( $words[0] eq "incdir" ) {
         $get_phash="";
      } elsif( $words[0] eq "fcldir" ) {
         $get_phash="";
      } elsif( $words[0] eq "gdmldir" ) {
         $get_phash="";
      } elsif( $words[0] eq "fwdir" ) {
         $get_phash="";
      } elsif( $words[0] eq "libdir" ) {
         $get_phash="";
      } elsif( $words[0] eq "bindir" ) {
         $get_phash="";
      } elsif( $words[0] eq "defaultqual" ) {
         $get_phash="";
      } elsif( $words[0] eq "only_for_build" ) {
         $get_phash="";
      } elsif( $words[0] eq "define_pythonpath" ) {
         $get_phash="";
      } elsif( $words[0] eq "product" ) {
         $get_phash="";
      } elsif( $words[0] eq "table_fragment_begin" ) {
         $get_phash="";
      } elsif( $words[0] eq "table_fragment_end" ) {
         $get_phash="";
      } elsif( $words[0] eq "table_fragment_begin" ) {
         $get_phash="";
      } elsif( $words[0] eq "qualifier" ) {
         $get_phash="";
      } elsif( $get_phash ) {
        if(( $words[2] ) && ($words[2]eq "-" )) { $words[2] = ""; }
	++$piter;
        ##print "get_product_list:  $piter  $words[0] $words[1] $words[2] $words[3]\n";
	for $i ( 0 .. $#words ) {
	  $plist[$piter][$i] = $words[$i];
	}
	if( $words[2] ) {
	  my $have_match="false";
	  for $i ( 0 .. $dqiter ) {
	    if( $dplist[$i] eq $words[2] )  { $have_match="true"; }
	  }
	  if ( $have_match eq "false" ) {
	    ++$dqiter;
	    $dplist[$dqiter]=$words[2];
	  }
	}
      } else {
        ##print "get_product_list: ignoring $line\n";
      }
    }
  }
  close(PIN);
  return ($piter, \@plist, $dqiter, \@dplist);
}

sub get_qualifier_list {
  my @params = @_;
  my $efl = $params[1];
  my $irow=0;
  my $get_quals="false";
  my $line;
  my @words = ();
  my $qlen = -1;
  my @qlist = ();
  open(QIN, "< $params[0]") or die "Couldn't open $params[0]";
  while ( $line=<QIN> ) {
    chop $line;
    if ( index($line,"#") == 0 ) {
    } elsif ( $line !~ /\w+/ ) {
    } else {
      ##print "get_qualifier_list: $line\n";
      @words=split(/\s+/,$line);
      if( $words[0] eq "end_qualifier_list" ) {
         $get_quals="false";
      } elsif( $words[0] eq "end_product_list" ) {
         $get_quals="false";
      } elsif( $words[0] eq "parent" ) {
         $get_quals="false";
      } elsif( $words[0] eq "no_fq_dir" ) {
         $get_quals="false";
      } elsif( $words[0] eq "incdir" ) {
         $get_quals="false";
      } elsif( $words[0] eq "fcldir" ) {
         $get_quals="false";
      } elsif( $words[0] eq "gdmldir" ) {
         $get_quals="false";
      } elsif( $words[0] eq "fwdir" ) {
         $get_quals="false";
      } elsif( $words[0] eq "libdir" ) {
         $get_quals="false";
      } elsif( $words[0] eq "bindir" ) {
         $get_quals="false";
      } elsif( $words[0] eq "defaultqual" ) {
         $get_quals="false";
      } elsif( $words[0] eq "only_for_build" ) {
         $get_quals="false";
      } elsif( $words[0] eq "define_pythonpath" ) {
         $get_quals="false";
      } elsif( $words[0] eq "product" ) {
         $get_quals="false";
      } elsif( $words[0] eq "table_fragment_begin" ) {
         $get_quals="false";
      } elsif( $words[0] eq "table_fragment_end" ) {
         $get_quals="false";
      } elsif( $words[0] eq "table_fragment_begin" ) {
         $get_quals="false";
      } elsif( $words[0] eq "qualifier" ) {
         $get_quals="true";
         ##print "qualifiers: $line\n";
	 $qlen = $#words;
	 for my $i ( 0 .. $#words ) {
	      if( $words[$i] eq "notes" ) {
		 $qlen = $i - 1;
	      }
	 }
	 if( $irow != 0 ) {
            print $efl "echo ERROR: qualifier definition row must come before qualifier list\n";
            print $efl "return 2\n";
	    exit 2;
	 }
	 ##print "there are $qlen product entries out of $#words\n";
	 for my $i ( 0 .. $qlen ) {
	   $qlist[$irow][$i] = $words[$i];
	 }
	 $irow++;
      } elsif( $get_quals eq "true" ) {
	 ##print "$params[0] qualifier $words[0] $#words\n";
	 if( ! $qlen ) {
            print $efl "echo ERROR: qualifier definition row must come before qualifier list\n";
            print $efl "return 3\n";
	    exit 3;
	 }
	 if ( $#words < $qlen ) {
            print $efl "echo ERROR: only $#words qualifiers for $words[0] - expect $qlen\n";
            print $efl "return 4\n";
	    exit 4;
	 }
	 for my $i ( 0 .. $qlen ) {
	   $qlist[$irow][$i] = $words[$i];
	 }
	 $irow++;
      } else {
        ##print "get_qualifier_list: ignoring $line\n";
      }
    }
  }
  close(QIN);
  ##print "found $irow qualifier rows\n";
  return ($qlen, @qlist);
}

# can we use a simple database to store this info?
sub get_dependency_list {
  my @params = @_;
  my $depfile = $params[0];
  my $dfl = $params[1];
  my %dhash = ();
  my @dlist = ();
  my $line;
  # read the dependency list and make a hash file keyed on product name
  ##print $dfl "DIAGNOSTIC: parse dependency list\n";
  open(DIN, "< $depfile") or die "Couldn't open $depfile";
  while ( $line=<DIN> ) {
    chop $line;
    if ( index($line,"#") == 0 ) {
    } elsif ( $line !~ /\w+/ ) {
    } else {
      my @words = split(/\s+/,$line);
      @dlist = ();
      if( $words[1] eq "-" ) {
        $dhash{ $words[0] } = "";
      } else {
	foreach my $i  ( 1 .. $#words ) {
	  $dlist[$i-1] = $words[$i];
	}
        $dhash{ $words[0] } = join( ',', @dlist );
      }
    }
  }
  close(DIN);
  ##my @dkeys = keys %dhash;
  ##foreach my $i ( 0 .. $#dkeys ) {
  ##   print $dfl "get_dependency_list: $dkeys[$i] has $dhash{$dkeys[$i]}\n";
  ##}
  return %dhash;
}

sub find_default_qual {
  my @params = @_;
  my $defq = "";
  my $line;
  open(PIN, "< $params[0]") or die "Couldn't open $params[0]";
  while ( $line=<PIN> ) {
    chop $line;
    if ( index($line,"#") == 0 ) {
    } elsif ( $line !~ /\w+/ ) {
    } else {
      my @words = split(/\s+/,$line);
      if( $words[0] eq "defaultqual" ) {
         $defq = $words[1];
      }
    }
  }
  close(PIN);
  ##print "defining library directory $libdir\n";
  return ($find_default_qual::defq);
}

sub get_fcl_directory {
  my @params = @_;
  my $fcldir = "default";
  my $line;
  my @words;
  open(PIN, "< $params[0]") or die "Couldn't open $params[0]";
  while ( $line=<PIN> ) {
    chop $line;
    if ( index($line,"#") == 0 ) {
    } elsif ( $line !~ /\w+/ ) {
    } else {
      @words = split(/\s+/,$line);
      if( $words[0] eq "fcldir" ) {
         if( ! $words[2] ) { $words[2] = "fcl"; }
         if( $words[1] eq "product_dir" ) {
	    $fcldir = "\${UPS_PROD_DIR}/".$words[2];
         } elsif( $words[1] eq "fq_dir" ) {
	    $fcldir = "\${\${UPS_PROD_NAME_UC}_FQ_DIR}/".$words[2];
         } elsif( $words[1] eq "-" ) {
	    $fcldir = "none";
	 } else {
	    print "ERROR: $words[1] is an invalid directory path\n";
	    print "ERROR: directory path must be specified as either \"product_dir\" or \"fq_dir\"\n";
	    print "ERROR: using the default fcl directory path\n";
	 }
      }
    }
  }
  close(PIN);
  ##print "defining executable directory $fcldir\n";
  return ($fcldir);
}

sub get_gdml_directory {
  my @params = @_;
  my $gdmldir = "none";
  my $line;
  my @words;
  open(PIN, "< $params[0]") or die "Couldn't open $params[0]";
  while ( $line=<PIN> ) {
    chop $line;
    if ( index($line,"#") == 0 ) {
    } elsif ( $line !~ /\w+/ ) {
    } else {
      @words = split(/\s+/,$line);
      if( $words[0] eq "gdmldir" ) {
         if( ! $words[2] ) { $words[2] = "gdml"; }
         if( $words[1] eq "product_dir" ) {
	    $gdmldir = "\${UPS_PROD_DIR}/".$words[2];
         } elsif( $words[1] eq "fq_dir" ) {
	    $gdmldir = "\${\${UPS_PROD_NAME_UC}_FQ_DIR}/".$words[2];
         } elsif( $words[1] eq "-" ) {
	    $gdmldir = "none";
	 } else {
	    print "ERROR: $words[1] is an invalid directory path\n";
	    print "ERROR: directory path must be specified as either \"product_dir\" or \"fq_dir\"\n";
	    print "ERROR: using the default gdml directory path\n";
	    $gdmldir = "\${UPS_PROD_DIR}/".$words[2];
	 }
      }
    }
  }
  close(PIN);
  ##print "defining executable directory $gdmldir\n";
  return ($gdmldir);
}

sub get_fw_directory {
  my @params = @_;
  my $fwdir = "none";
  my $line;
  my @words;
  open(PIN, "< $params[0]") or die "Couldn't open $params[0]";
  while ( $line=<PIN> ) {
    chop $line;
    if ( index($line,"#") == 0 ) {
    } elsif ( $line !~ /\w+/ ) {
    } else {
      @words = split(/\s+/,$line);
      if( $words[0] eq "fwdir" ) {
         if( $words[1] eq "-" ) {
	    $fwdir = "none";
	 } else { 
            if( ! $words[2] ) { 
		  print "ERROR: the fwdir subdirectory must be specified, there is no default\n";
	    } else {
               if( $words[1] eq "product_dir" ) {
		  $fwdir = "\${UPS_PROD_DIR}/".$words[2];
               } elsif( $words[1] eq "fq_dir" ) {
		  $fwdir = "\${\${UPS_PROD_NAME_UC}_FQ_DIR}/".$words[2];
	       } else {
		  print "ERROR: $words[1] is an invalid directory path\n";
		  print "ERROR: directory path must be specified as either \"product_dir\" or \"fq_dir\"\n";
	       }
	    }
	 }
      }
    }
  }
  close(PIN);
  ##print "defining executable directory $fwdir\n";
  return ($fwdir);
}

sub product_setup_loop {
  my @params = @_;
  my $pfile = $params[0];
  my $dop = $params[1];
  my $simple = $params[2];
  my $builddir = $params[3];
  my $dfile = $params[4];
  my $tfile = $params[5];
  my ($product, $version, $default_ver, $default_qual, $have_fq) = get_parent_info( $pfile );
  my ($plen, $plist_ref, $dqlen, $dqlist_ref) = get_product_list( $pfile );
  my @plist=@$plist_ref;
  my @dqlist=@$dqlist_ref;
  my ($ndeps, @qlist) = get_qualifier_list( $pfile, $dfile );

  my $qual;
  if ( $default_qual ) {
    $qual = $default_qual.":";
    $qual = $qual.$dop;
  } elsif ( $simple ) {
    $qual = "-nq-";
  } else {
    my $errfl2 = $builddir."/error-".$product."-".$version;
    open(ERR2, "> $errfl2") or die "Couldn't open $errfl2";
    print ERR2 "\n";
    print ERR2 "unsetenv_ CETPKG_NAME\n";
    print ERR2 "unsetenv_ CETPKG_VERSION\n";
    print ERR2 "unsetenv_ CETPKG_QUAL\n";
    print ERR2 "unsetenv_ CETPKG_TYPE\n";
    print ERR2 "echo \"ERROR: no qualifiers specified\"\n";
    print ERR2 "echo \"ERROR: add a defaultqual line to $pfile\"\n";
    print ERR2 "echo \"ERROR: or specify the qualifier(s) on the command line\"\n";
    print ERR2 "echo \"USAGE: setup_products <input-directory> <-d|-o|-p> <qualifiers>\"\n";
    print ERR2 "return 1\n";
    close(ERR2);
    print "$errfl2\n";
    exit 0;
  }
  print $dfile "product_setup_loop: $product $version $qual\n";

  return ($product, $version);
}

1;
