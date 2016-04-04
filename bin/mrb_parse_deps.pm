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
#   [perllib     -              perllib]
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

use strict;
use warnings;

package mrb_parse_deps;

use List::Util qw(min max); # Numeric min / max funcions.

use Exporter 'import';
our (@EXPORT, @setup_list);
@EXPORT = qw( get_package_list 
              get_product_name 
              find_cetbuildtools 
              compare_versions 
              get_parent_info 
              get_product_list 
              get_qualifier_list 
              find_default_qual 
              get_fcl_directory 
              get_gdml_directory 
              get_perl_directory 
              get_fw_directory 
	      get_root_path
              cetpkg_info_file 
              setup_only_for_build 
              print_setup_noqual 
              print_setup_qual 
              compare_qual 
              product_setup_loop 
	      sort_qual
              @setup_list);


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
      } elsif( $words[0] eq "cetbuildtools" ) {
        $cver = $words[1];
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
  my $dbgrpt = $params[1];
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
      } elsif( $words[0] eq "perllib" ) {
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
	#print $dbgrpt "get_product_list debug info:  $piter $line has 0-$#{words} words\n";
	##print $dbgrpt "get_product_list debug info:  $piter words:";
	##for $i ( 0 .. $#words ) {
	##  print $dbgrpt " $words[$i]";
	##}
	##print $dbgrpt "\n";
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
        ###print $dbgrpt "get_product_list debug info: ignoring $line\n";
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
      } elsif( $words[0] eq "perllib" ) {
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
  my $fcldir = $params[1]."/fcl";
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
	    $fcldir = $params[1]."/".$words[2];
         } elsif( $words[1] eq "fq_dir" ) {
	    $fcldir = $params[1]."/".$words[2];
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
	    $gdmldir = $params[1]."/".$words[2];
         } elsif( $words[1] eq "fq_dir" ) {
	    $gdmldir = $params[1]."/".$words[2];
         } elsif( $words[1] eq "-" ) {
	    $gdmldir = "none";
	 } else {
	    print "ERROR: $words[1] is an invalid directory path\n";
	    print "ERROR: directory path must be specified as either \"product_dir\" or \"fq_dir\"\n";
	    print "ERROR: using the default gdml directory path\n";
	    $gdmldir = $params[1]."/".$words[2];
	 }
      }
    }
  }
  close(PIN);
  ##print "defining executable directory $gdmldir\n";
  return ($gdmldir);
}

sub get_perl_directory {
  my @params = @_;
  my $perllib = "none";
  my $line;
  my @words;
  open(PIN, "< $params[0]") or die "Couldn't open $params[0]";
  while ( $line=<PIN> ) {
    chop $line;
    if ( index($line,"#") == 0 ) {
    } elsif ( $line !~ /\w+/ ) {
    } else {
      @words = split(/\s+/,$line);
      if( $words[0] eq "perllib" ) {
         if( ! $words[2] ) { $words[2] = "perllib"; }
         if( $words[1] eq "product_dir" ) {
	    $perllib = $params[1]."/".$words[2];
         } elsif( $words[1] eq "fq_dir" ) {
	    $perllib = $params[1]."/".$words[2];
         } elsif( $words[1] eq "-" ) {
	    $perllib = "none";
	 } else {
	    print "ERROR: $words[1] is an invalid directory path\n";
	    print "ERROR: directory path must be specified as either \"product_dir\" or \"fq_dir\"\n";
	    print "ERROR: using the default perl directory path\n";
	    $perllib = $params[1]."/".$words[2];
	 }
      }
    }
  }
  close(PIN);
  ##print "defining executable directory $perllib\n";
  return ($perllib);
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
		  $fwdir = $params[1]."/".$words[2];
               } elsif( $words[1] eq "fq_dir" ) {
		  $fwdir = $params[1]."/".$words[2];
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

sub get_root_path {
  my @params = @_;
  my $incdir = "default";
  my $fq = "true";
  my $line;
  my @words;
  my $rp = "none";
  open(PIN, "< $params[0]") or die "Couldn't open $params[0]";
  while ( $line=<PIN> ) {
    chop $line;
    if ( index($line,"#") == 0 ) {
    } elsif ( $line !~ /\w+/ ) {
    } else {
      @words = split(/\s+/,$line);
      if( $words[0] eq "incdir" ) {
         if( ! $words[2] ) { $words[2] = "include"; }
         if( $words[1] eq "product_dir" ) {
	    $incdir = $params[1]."/".$words[2];
         } elsif( $words[1] eq "fq_dir" ) {
	    $incdir = $params[1]."/".$words[2];
         } elsif( $words[1] eq "-" ) {
	    $incdir = "none";
	 } else {
	    print "ERROR: $words[1] is an invalid directory path\n";
	    print "ERROR: directory path must be specified as either \"product_dir\" or \"fq_dir\"\n";
	    print "ERROR: using the default include directory path\n";
	 }
      } elsif( $words[0] eq "no_fq_dir" ) {
          $fq = "";
      }
    }
  }
  close(PIN);
  ##print "defining executable directory $incdir\n";
  if ( $fq ) { $rp = $incdir; }
  return ($rp);
}

sub cetpkg_info_file {
  ## write a file to be processed by CetCMakeEnv
  ## add CETPKG_SOURCE and CETPKG_BUILD for ease of reference by the user
  # if there is a cmake cache file, we could check for the install prefix
  # cmake -N -L | grep CMAKE_INSTALL_PREFIX | cut -f2 -d=
  my @param_names =
    qw (name version default_version qual type source build cc cxx fc only_for_build);
  my @param_vals = @_;
  if (scalar @param_vals != scalar @param_names) {
    print STDERR "ERROR: cetpkg_info_file expects the following paramaters in order:\n",
      join(", ", @param_names), ".\n";
    print STDERR "ERROR: cetpkg_info_file found:\n",
      join(", ", @param_vals), ".\n";
    exit(1);
  }
  my $cetpkgfile = "$param_vals[6]/cetpkg_variable_report";
  open(CPG, "> $cetpkgfile") or die "Couldn't open $cetpkgfile";
  print CPG "\n";
  foreach my $index (0 .. $#param_names) {
    my $pval = $param_vals[$index];
    if( $param_vals[$index] eq "simple" ) { $pval = "-"; }
    printf CPG "CETPKG_%s%s%s\n",
      uc $param_names[$index], # Var name.
        " " x (max(map { length() + 2 } @param_names) -
               length($param_names[$index])), # Space padding.
          $pval; # Value.
  }
  print CPG "to check cmake cached variables, use cmake -N -L\n";
  close(CPG);
  return($cetpkgfile);  
}

sub get_only_for_build {
  my @params = @_;
  my $dbgrpt = $params[1];
  # find all only_for_build products
  my $count = 0;
  my @build_products = ();
  my $line;
  ##print $dbgrpt "get_only_for_build debug: $params[0] \n";
  open(PIN, "< $params[0]") or die "Couldn't open $params[0]";
  while ( $line=<PIN> ) {
    chop $line;
    if ( index($line,"#") == 0 ) {
    } elsif ( $line !~ /\w+/ ) {
    } else {
      my @words = split(/\s+/,$line);
      if( $words[0] eq "only_for_build" ) {
        ++$count;
        ##print $dbgrpt "get_only_for_build debug: found $line \n";
	$build_products[$count][0] = $words[1];  
	if( $words[2] eq "-" ) {
	  $build_products[$count][1] = "";
	} else {
          $build_products[$count][1] = $words[2];
	}
      } elsif( ($words[3]) && ($words[3] eq "only_for_build") ) {
        ++$count;
        ##print $dbgrpt "get_only_for_build debug: found $line \n";
	$build_products[$count][0] = $words[0];  
	if( $words[2] eq "-" ) {
	  $build_products[$count][1] = "";
	} else {
          $build_products[$count][1] = $words[1];
	}
      }
    }
  }
  close(PIN);
  ##print $dbgrpt "get_only_for_build debug: count is $count \n";
  return ($count, @build_products);
}

sub setup_only_for_build {
  my @params = @_;
  my $tfile = $params[1];
  # we are looking for products other than cetbuildtools or cetpkgsupport
  my ($count, @build_products) = get_only_for_build( $params[0], $params[2] );
  # setup these products if they have not already been setup
  foreach my $i ( 1 .. $count ) {
    my $print_setup = "true";
    foreach my $j ( 0 .. $#setup_list ) {
      if( $build_products[$i][0] eq $setup_list[$j] ) {
        $print_setup = "false";
      }
    }
    if ( $print_setup eq "true" ) {
      print $tfile "setup -B $build_products[$i][0] $build_products[$i][1]\n";
      print $tfile "test \"\$?\" = 0 || set_ setup_fail=\"true\"\n"; 
    }
  }
}

sub print_setup_noqual {
  my @params = @_;
  my $efl = $params[3];
  my $dfl = $params[4];
  my $thisqual = $params[1];
  if( $params[1] eq "-" ) {  $thisqual = ""; }
  #print $dfl "print_setup_noqual debug info: called with $params[0] $params[1] $params[2]\n";
  if( $params[2] eq "true" ) { 
  print $efl "# setup of $params[0] is optional\n"; 
  print $efl "unset have_prod\n"; 
  print $efl "ups exist $params[0] $thisqual\n"; 
  print $efl "test \"\$?\" = 0 && set_ have_prod=\"true\"\n"; 
  print $efl "test \"\$have_prod\" = \"true\" || echo \"INFO: no optional setup of $params[0] $thisqual\"\n"; 
  print $efl "test \"\$have_prod\" = \"true\" && setup -B $params[0] $thisqual \n";
  print $efl "unset have_prod\n"; 
  } else {
  print $efl "setup -B $params[0] $thisqual \n";
  print $efl "test \"\$?\" = 0 || set_ setup_fail=\"true\"\n"; 
  }
  return 0;
}

sub print_setup_qual {
  my @params = @_;
  my $efl = $params[4];
  my $dfl = $params[5];
  my $thisqual = $params[1];
  if( $params[1] eq "-" ) {  $thisqual = ""; }
  #print $dfl "print_setup_qual debug info: called with $params[0] $params[1] $params[2] $params[3]\n";
  my @qwords = split(/:/,$params[2]);
  my $ql="+".$qwords[0];
  foreach my $j ( 1 .. $#qwords ) {
    $ql = $ql.":+".$qwords[$j];
  }
  if( $params[3] eq "true" ) { 
  print $efl "# setup of $params[0] is optional\n"; 
  print $efl "unset have_prod\n"; 
  print $efl "ups exist $params[0] $thisqual -q $ql\n"; 
  print $efl "test \"\$?\" = 0 && set_ have_prod=\"true\"\n"; 
  print $efl "test \"\$have_prod\" = \"true\" || echo \"INFO: no optional setup of $params[0] $thisqual -q $ql\"\n"; 
  print $efl "test \"\$have_prod\" = \"true\" && setup -B $params[0] $thisqual -q $ql \n";
  print $efl "unset have_prod\n"; 
  } else {
  print $efl "setup -B $params[0] $thisqual -q $ql\n";
  print $efl "test \"\$?\" = 0 || set_ setup_fail=\"true\"\n"; 
  }
  return 0;
}

sub compare_qual {
  my @params = @_;
  my @ql1 = split(/:/,$params[0]);
  my @ql2 = split(/:/,$params[1]);
  my $retval = 0;
  if( $#ql1 != $#ql2 ) { return $retval; }
  my $size = $#ql2 + 1;
  my $qmatch = 0;
  my $ii;
  my $jj;
  foreach $ii ( 0 .. $#ql1 ) {
    foreach $jj ( 0 .. $#ql2 ) {
      if( $ql1[$ii] eq $ql2[$jj] )  { $qmatch++; }
    }
  }
  if( $qmatch == $size ) { $retval = 1; }
  return $retval;
}

sub product_setup_loop {
  my @params = @_;
  my $sourcedir = $params[0];
  my $pkgname = $params[1];
  my $simple = $params[2];
  my $builddir = $params[3];
  my $dfile = $params[4];
  my $tfile = $params[5];

  my $pfile=$sourcedir."/".$pkgname."/ups/product_deps";
  # make the product subdirectory now
  my $pkgdir = $builddir."/".$pkgname;
  unless ( -e $pkgdir or mkdir $pkgdir ) { die "Couldn't create $pkgdir"; }

  my ($product, $version, $default_ver, $default_qual, $have_fq) = get_parent_info( $pfile );
  #print $dfile "product_setup_loop debug info: $product $version $default_ver $default_qual\n";
  #print $dfile "product_setup_loop debug info: mrb_quals is $setup_products::mrb_quals \n";

  my $qual;
  # logic problem here - we might not want the default qualifier
  # use MRB_QUALS if different than the default qualifier AND if present in the qualifier matrix
  my ($ndeps, @qlist) = get_qualifier_list( $pfile, $dfile );
  foreach my $i ( 1 .. $#qlist ) {
    #print $dfile "product_setup_loop debug info: compare $qlist[$i][0] to $setup_products::mrb_quals \n";
    next if ( ! (compare_qual( $qlist[$i][0], $setup_products::mrb_quals ) ) );
    #print $dfile "product_setup_loop debug info: $qlist[$i][0] matches MRB_QUAL $setup_products::mrb_quals \n";
    $qual = $setup_products::mrb_quals;
  }
  if ( $simple eq "true" ) { $qual = "-nq-"; }
  if ( $qual ) { 
    #print $dfile "product_setup_loop debug info: qual is defined as $qual\n"; 
  } else {
    if ( $default_qual ) {
      $qual = $default_qual.":".$setup_products::dop;
    } else {
      my $errfl2 = $builddir."/error-".$product."-".$version;
      open(ERR2, "> $errfl2") or die "Couldn't open $errfl2";
      print ERR2 "\n";
      print ERR2 "unsetenv_ CETPKG_NAME\n";
      print ERR2 "unsetenv_ CETPKG_VERSION\n";
      print ERR2 "unsetenv_ CETPKG_DIR\n";
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
  }
  #print $dfile "product_setup_loop debug info: $product $version $qual\n";

  my $default_fc = ( $^O eq "darwin" ) ? "-" : "gfortran";
  my $compiler;
  my $compiler_table =
    {
     cc => { CC => "cc", CXX => "c++", FC => $default_fc },
     gcc => { CC => "gcc", CXX => "g++", FC => "gfortran" },
     icc => { CC => "icc", CXX => "icpc", FC => "ifort" },
    };

  if (!$compiler) {
    my @quals = split /:/, $qual;
    if (grep /^(e|gcc)\d+$/, @quals) {
      $compiler = "gcc";
    } elsif (grep /^(i|icc)\d+$/, @quals) {
      $compiler = "icc";
    } else {
      $compiler = "cc"; # Native.
    }
  }
  ###print $dfile "product_setup_loop debug info: compiler is $compiler\n";
  ###print $dfile "product_setup_loop debug info: $compiler_table->{$compiler}->{CC} $compiler_table->{$compiler}->{CXX} $compiler_table->{$compiler}->{FC}\n";

  my ($nonly, @build_products) = get_only_for_build( $pfile, $dfile );
  my $onlyForBuild="";
  ##print $dfile "product_setup_loop debug: get_only_for_build returns $nonly\n";
  foreach my $i ( 1 .. $nonly ) {
      $onlyForBuild=$build_products[$i][0].";".$onlyForBuild;
  }
  my $cetfl = cetpkg_info_file( $product, 
                        	$version, 
				$default_ver, 
				$qual, 
				$setup_products::type, 
				$sourcedir, 
				$pkgdir,
                        	$compiler_table->{$compiler}->{CC},
                        	$compiler_table->{$compiler}->{CXX},
                        	$compiler_table->{$compiler}->{FC},
			        $onlyForBuild
			     );

  print $tfile "# Configuring $product\n";
  setup_only_for_build( $pfile, $tfile, $dfile );

  # now deal with regular dependencies and their qualifiers
  my ($plen, $plist_ref, $dqlen, $dqlist_ref) = get_product_list( $pfile, $dfile );
  my @plist=@$plist_ref;
  my @dqlist=@$dqlist_ref;
  # now call setup with the correct version and qualifiers
  foreach my $i ( 1 .. $#qlist ) {
    #print $dfile "product_setup_loop debug info: compare $qlist[$i][0] to $qual \n";
    next if ( ! (compare_qual( $qlist[$i][0], $qual ) ) );
    #print $dfile "product_setup_loop debug info: $qlist[$i][0] matches $qual \n";
    foreach my $j ( 1 .. $ndeps ) {
      next if $qlist[0][$j] eq "compiler";
      my $print_setup = "true";
      # are we building this product?
      foreach my $k ( 0 .. $#product_setup_loop::productnames ) {
	if ( $product_setup_loop::productnames[$k] eq $qlist[0][$j] ) {
	   $print_setup = "false";
	}
      }
      # is this product already in the setup list?
      foreach my $k ( 0 .. $#setup_list ) {
	if( $qlist[0][$j] eq $setup_list[$k] ) {
          $print_setup = "false";
	}
      }
      #print $dfile "product_setup_loop debug info: setup $qlist[0][$j] $qlist[$i][$j]? ${print_setup}\n";
      if ( $print_setup eq "true" ) {
	push( @setup_list, $qlist[0][$j] );
	my $piter = -1;
	foreach my $k ( 0 .. $plen ) {
	  if ( $plist[$k][0] eq $qlist[0][$j] ) {
	    if ( $plist[$k][2] ) {
	      #print $dfile "product_setup_loop debug info: $k $j $plist[$k][0] $plist[$k][2] matches $qlist[0][$j] \n";
	      if( index($qual, $plist[$k][2]) >= 0 ) { $piter = $k; }
	    } else {
	      $piter = $k;
	    }
	  }
	}
	if ( $piter < 0 ) {
	  my $errfl2 = $builddir."/error-".$product."-".$version;
	  open(ERR2, "> $errfl2") or die "Couldn't open $errfl2";
	  print ERR2 "\n";
	  print ERR2 "unsetenv_ CETPKG_NAME\n";
	  print ERR2 "unsetenv_ CETPKG_VERSION\n";
	  print ERR2 "unsetenv_ CETPKG_DIR\n";
	  print ERR2 "unsetenv_ CETPKG_QUAL\n";
	  print ERR2 "unsetenv_ CETPKG_TYPE\n";
	  print ERR2 "echo \"ERROR: no match to qualifier list for $qlist[0][$j]\"\n";
	  print ERR2 "return 1\n";
	  close(ERR2);
	  print "$errfl2\n";
	  exit 0;
	}
	my $is_optional = "false";
	# old and new style
	if (( $plist[$piter][2]) && ( $plist[$piter][2] eq "optional" )) { $is_optional = "true"; }
	if (( $plist[$piter][3]) && ( $plist[$piter][3] eq "optional" )) { $is_optional = "true"; }
	# are we going to build this package?
	my $no_package_setup = "false";
	for my $ip ( 0 .. $#setup_products::package_list ) {
	  if ( $qlist[0][$j] eq $setup_products::package_list[$ip] ) { $no_package_setup = "true"; }
	}
	if ( $qlist[$i][$j] eq "-" ) {
	} elsif ( $no_package_setup eq "true" ) {
	} elsif ( $qlist[$i][$j] eq "-nq-" ) {
          print_setup_noqual( $qlist[0][$j], $plist[$piter][1], $is_optional, $tfile, $dfile );
	} elsif ( $qlist[$i][$j] eq "-b-" ) {
          print_setup_noqual( $qlist[0][$j], $plist[$piter][1], $is_optional, $tfile, $dfile );
	} else {
          print_setup_qual( $qlist[0][$j], $plist[$piter][1], $qlist[$i][$j], $is_optional, $tfile, $dfile );
	}
      }
    }
  }

  return ($product, $version);
}

sub sort_qual {
  my @params = @_;
  my @ql = split(/:/,$params[0]);
  my $retval = 0;
  my @tql = ();
  my @rql = ();
  my $dop="";
  foreach my $ii ( 0 .. $#ql ) {
      if(( $ql[$ii] eq "debug" ) || ( $ql[$ii] eq "opt" )   || ( $ql[$ii] eq "prof" )) {
         $dop=$ql[$ii];
      } else {
         push @tql, $ql[$ii];
      }
  }
  @rql = sort @tql;
  if( $dop ) { push @rql, $dop; }
  my $squal = join ( ":", @rql );
  return $squal;
}

1;
