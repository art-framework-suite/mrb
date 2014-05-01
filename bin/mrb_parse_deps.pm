# parse product_deps and qualifier_deps

# product_deps format:

#   parent       this_product   this_version
#   [incdir      product_dir	include]
#   [fcldir      product_dir    fcl]
#   [libdir      fq_dir	        lib]
#   [bindir      fq_dir         bin]
#
#   product		version
#   dependent_product	dependent_product_version [optional]
#   dependent_product	dependent_product_version [optional]
#
#   qualifier dependent_product       dependent_product notes
#   this_qual dependent_product_qual  dependent_product_qual
#   this_qual dependent_product_qual  dependent_product_qual

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

sub get_package_list {
  my @params = @_;
  my $dfile = $params[1];
  my $plist;
  my $pdep;
  my $pnames;
  my $pver;
  $i = 0;
  open(CIN, "< $params[0]") or die "Couldn't open $params[0]";
  while ( $line=<CIN> ) {
    chop $line;
    if ( index($line,"#") == 0 ) {
    } elsif ( $line !~ /\w+/ ) {
    } else {
      @words = split(/\(+/,$line);
      if( $words[0] eq "ADD_SUBDIRECTORY" ) {
	@w2 = split(/\)+/,$words[1]);
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
  ##print $dfile "now check $params[0]\n";
  open(PIN, "< $params[0]") or die "Couldn't open $params[0]";
  while ( $line=<PIN> ) {
    chop $line;
    if ( index($line,"#") == 0 ) {
    } elsif ( $line !~ /\w+/ ) {
    } else {
      @words = split(/\s+/,$line);
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

sub parse_product_list {
  my @params = @_;
  my $dfile = $params[1];
  my $pdep = $params[0];
  ##print $dfile "parse_product_list: ready to open $pdep\n";
  open(PIN, "< $pdep") or die "Couldn't open $pdep";
  $get_phash="";
  $get_quals="";
  $get_fragment="";
  my $extra="none";
  my %phash = ();
  ##print $dfile "parse_product_list: parsing $pdep\n";
  while ( $line=<PIN> ) {
    chop $line;
    if ( index($line,"#") == 0 ) {
    } elsif ( $line !~ /\w+/ ) {
    } else {
      ##print $dfile "parse_product_list: parsing $line\n";
      @words = split(/\s+/,$line);
      if( $words[0] eq "parent" ) {
	 $prod=$words[1];
	 $ver=$words[2];
	 if( $words[3] ) { $extra=$words[3]; }
	 $get_phash="";
         $get_quals="";
      } elsif( $words[0] eq "no_fq_dir" ) {
	 $get_phash="";
         $get_quals="";
      } elsif( $words[0] eq "incdir" ) {
	 $get_phash="";
         $get_quals="";
      } elsif( $words[0] eq "fcldir" ) {
	 $get_phash="";
         $get_quals="";
      } elsif( $words[0] eq "gdmldir" ) {
	 $get_phash="";
         $get_quals="";
      } elsif( $words[0] eq "fwdir" ) {
	 $get_phash="";
         $get_quals="";
      } elsif( $words[0] eq "libdir" ) {
	 $get_phash="";
         $get_quals="";
      } elsif( $words[0] eq "bindir" ) {
	 $get_phash="";
         $get_quals="";
      } elsif( $words[0] eq "defaultqual" ) {
	 $get_phash="";
         $get_quals="";
	 $dq=$words[1];
      } elsif( $words[0] eq "only_for_build" ) {
	 $get_phash="";
         $get_quals="";
      } elsif( $words[0] eq "product" ) {
	 $get_phash="true";
         $get_quals="";
      } elsif( $words[0] eq "qualifier" ) {
	 $get_phash="";
         $get_quals="true";
      } elsif( $get_phash ) {
	if( $words[1] eq "-" ) {
          $phash{ $words[0] } = "";
	} else {
          $phash{ $words[0] } = $words[1];
	}
      } elsif( $words[0] eq "table_fragment_begin" ) {
         $get_fragment="true";
	 $get_phash="";
         $get_quals="";
      } elsif( $words[0] eq "table_fragment_end" ) {
         $get_fragment="";
	 $get_phash="";
         $get_quals="";
      } elsif( $get_quals ) {
      } elsif( $get_fragment ) {
      } else {
        print $dfile "WARING: unrecognized line in $pdep: $line\n";
      }
    }
  }
  close(PIN);
  return ($prod, $ver, $extra, $dq, %phash);
}

sub parse_qualifier_list {
  my @params = @_;
  ##print "\n";
  ##print "reading $params[0]\n";
  my $efl = $params[1];
  $irow=0;
  $get_phash="";
  $get_quals="";
  $get_fragment="";
  open(QIN, "< $params[0]") or die "Couldn't open $params[0]";
  while ( $line=<QIN> ) {
    chop $line;
    if ( index($line,"#") == 0 ) {
    } elsif ( $line !~ /\w+/ ) {
    } else {
      ##print "$line\n";
      @words=split(/\s+/,$line);
      if( $words[0] eq "parent" ) {
	 $get_phash="";
         $get_quals="";
      } elsif( $words[0] eq "no_fq_dir" ) {
	 $get_phash="";
         $get_quals="";
      } elsif( $words[0] eq "incdir" ) {
	 $get_phash="";
         $get_quals="";
      } elsif( $words[0] eq "fcldir" ) {
	 $get_phash="";
         $get_quals="";
      } elsif( $words[0] eq "gdmldir" ) {
	 $get_phash="";
         $get_quals="";
      } elsif( $words[0] eq "fwdir" ) {
	 $get_phash="";
         $get_quals="";
      } elsif( $words[0] eq "libdir" ) {
	 $get_phash="";
         $get_quals="";
      } elsif( $words[0] eq "bindir" ) {
	 $get_phash="";
         $get_quals="";
      } elsif( $words[0] eq "defaultqual" ) {
	 $get_phash="";
         $get_quals="";
      } elsif( $words[0] eq "only_for_build" ) {
	 $get_phash="";
         $get_quals="";
      } elsif( $words[0] eq "product" ) {
	 $get_phash="true";
         $get_quals="";
      } elsif( $words[0] eq "table_fragment_begin" ) {
         $get_fragment="true";
	 $get_phash="";
         $get_quals="";
      } elsif( $words[0] eq "table_fragment_end" ) {
         $get_fragment="";
	 $get_phash="";
         $get_quals="";
      } elsif( $words[0] eq "qualifier" ) {
	 $qlen = $#words;
	 $get_phash="";
         $get_quals="true";
	 for $i ( 0 .. $#words ) {
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
	 for $i ( 0 .. $qlen ) {
	   $qlist[$irow][$i] = $words[$i];
	 }
	 $irow++;
      } elsif( $get_phash ) {
      } elsif( $get_fragment ) {
      } elsif( $get_quals ) {
	 ##print "$params[0] qualifier $words[0]\n";
	 if( ! $qlen ) {
            print $efl "echo ERROR: qualifier definition row must come before qualifier list\n";
            print $efl "return 3\n";
	    exit 3;
	 }
	 if ( $#words < $qlen ) {
            print $efl "echo ERROR: only $#words qualifiers for $words[0] - need $qlen\n";
            print $efl "return 4\n";
	    exit 4;
	 }
	 for $i ( 0 .. $qlen ) {
	   $qlist[$irow][$i] = $words[$i];
	 }
	 $irow++;
      } elsif( $get_fragment ) {
	 print "$params[0] qualifier $words[0]\n";
      } else {
        ##print "parse_qualifier_list: ignoring $line\n";
      }
    }
  }
  close(QIN);
  ##print "found $irow qualifier rows\n";
  return ($qlen, @qlist);
}

sub find_optional_products {
  my @params = @_;
  open(PIN, "< $params[0]") or die "Couldn't open $params[0]";
  $get_phash="";
  $get_quals="";
  $get_fragment="";
  while ( $line=<PIN> ) {
    chop $line;
    if ( index($line,"#") == 0 ) {
    } elsif ( $line !~ /\w+/ ) {
    } else {
      @words = split(/\s+/,$line);
      if( $words[0] eq "parent" ) {
	 $get_phash="";
         $get_quals="";
      } elsif( $words[0] eq "no_fq_dir" ) {
	 $get_phash="";
         $get_quals="";
      } elsif( $words[0] eq "incdir" ) {
	 $get_phash="";
         $get_quals="";
      } elsif( $words[0] eq "fcldir" ) {
	 $get_phash="";
         $get_quals="";
      } elsif( $words[0] eq "gdmldir" ) {
	 $get_phash="";
         $get_quals="";
      } elsif( $words[0] eq "fwdir" ) {
	 $get_phash="";
         $get_quals="";
      } elsif( $words[0] eq "libdir" ) {
	 $get_phash="";
         $get_quals="";
      } elsif( $words[0] eq "bindir" ) {
	 $get_phash="";
         $get_quals="";
      } elsif( $words[0] eq "defaultqual" ) {
	 $get_phash="";
         $get_quals="";
	 $dq=$words[1];
      } elsif( $words[0] eq "only_for_build" ) {
	 $get_phash="";
         $get_quals="";
      } elsif( $words[0] eq "product" ) {
	 $get_phash="true";
         $get_quals="";
      } elsif( $words[0] eq "table_fragment_begin" ) {
         $get_fragment="true";
	 $get_phash="";
         $get_quals="";
      } elsif( $words[0] eq "table_fragment_end" ) {
         $get_fragment="";
	 $get_phash="";
         $get_quals="";
      } elsif( $words[0] eq "qualifier" ) {
	 $get_phash="";
         $get_quals="true";
      } elsif( $get_phash ) {
	if ( $#words == 2 ) {
	   if(  $words[2] eq "optional" ) {
              $opthash{ $words[0] } = $words[2];
	   } else {
             $opthash{ $words[0] } = "";
	   }
	} else {
          $opthash{ $words[0] } = "";
	}
      } elsif( $get_fragment ) {
      } elsif( $get_quals ) {
      } else {
        ##print "find_optional_products: ignoring $line\n";
      }
    }
  }
  close(PIN);
  return (%opthash);
}

sub find_only_for_build_products {
  my @params = @_;
  my $count = 0;
  open(PIN, "< $params[0]") or die "Couldn't open $params[0]";
  while ( $line=<PIN> ) {
    chop $line;
    if ( index($line,"#") == 0 ) {
    } elsif ( $line !~ /\w+/ ) {
    } else {
      @words = split(/\s+/,$line);
      if( $words[0] eq "only_for_build" ) {
        ++$count;
	$ephash[$count][0] = $words[1];  
	if( $words[2] eq "-" ) {
	  $ephash[$count][1] = "";
	} else {
          $ephash[$count][1] = $words[2];
	}
      }
    }
  }
  close(PIN);
  return ($count,@ephash);
}

sub find_default_qual {
  my @params = @_;
  $defq = "";
  open(PIN, "< $params[0]") or die "Couldn't open $params[0]";
  while ( $line=<PIN> ) {
    chop $line;
    if ( index($line,"#") == 0 ) {
    } elsif ( $line !~ /\w+/ ) {
    } else {
      @words = split(/\s+/,$line);
      if( $words[0] eq "defaultqual" ) {
         $defq = $words[1];
      }
    }
  }
  close(PIN);
  ##print "defining library directory $libdir\n";
  return ($defq);
}

sub cetpkg_info_file {
  ## write a file to be processed by CetCMakeEnv
  ## add CETPKG_SOURCE and CETPKG_BUILD for ease of reference by the user
  # if there is a cmake cache file, we could check for the install prefix
  # cmake -N -L | grep CMAKE_INSTALL_PREFIX | cut -f2 -d=
  my @param_names =
    qw (name version default_version qual type source build cc cxx fc);
  my @param_vals = @_;
  if (scalar @param_vals != scalar @param_names) {
    print STDERR "ERROR: cetpkg_info_file expects the following paramaters in order:\n",
      join(", ", @param_names), ".\n";
    print STDERR "ERROR: cetpkg_info_file found:\n",
      join(", ", @param_vals), ".\n";
    exit(1);
  }
  $cetpkgfile = "$param_vals[6]/cetpkg_variable_report";
  open(CPG, "> $cetpkgfile") or die "Couldn't open $cetpkgfile";
  print CPG "\n";
  foreach my $index (0 .. $#param_names) {
    printf CPG "CETPKG_%s%s%s\n",
      uc $param_names[$index], # Var name.
        " " x (max(map { length() + 2 } @param_names) -
               length($param_names[$index])), # Space padding.
          $param_vals[$index]; # Value.
  }
  print CPG "to check cmake cached variables, use cmake -N -L\n";
  close(CPG);
  return($cetpkgfile);  
}

sub find_cetbuildtools {
  my @params = @_;
  my $count = 0;
  open(PIN, "< $params[0]") or die "Couldn't open $params[0]";
  while ( $line=<PIN> ) {
    chop $line;
    if ( index($line,"#") == 0 ) {
    } elsif ( $line !~ /\w+/ ) {
    } else {
      @words = split(/\s+/,$line);
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

sub print_setup_noqual {
  my @params = @_;
  my $efl = $params[4];
  ##print $efl "# print_setup_noqual called with $params[0] $params[1] $params[2]\n";
  if( $params[2] eq "optional" ) { 
  print $efl "# setup of $params[0] is optional\n"; 
  print $efl "unset have_prod\n"; 
  print $efl "ups exist $params[0] $params[1]\n"; 
  print $efl "test \"\$?\" = 0 && set_ have_prod=\"true\"\n"; 
  print $efl "test \"\$have_prod\" = \"true\" || echo \"will not setup $params[0] $params[1]\"\n"; 
  print $efl "test \"\$have_prod\" = \"true\" && setup -B $params[0] $params[1] \n";
  print $efl "unset have_prod\n"; 
  } else {
  print $efl "setup -B $params[3] $params[0] $params[1] \n";
  print $efl "test \"\$?\" = 0 || set_ setup_fail=\"true\"\n"; 
  }
  return 0;
}

sub print_setup_qual {
  my @params = @_;
  my $efl = $params[5];
  ##print $efl "# print_setup_qual called with $params[0] $params[1] $params[2] $params[3]\n";
  if( $params[3] eq "optional" ) { 
  print $efl "# setup of $params[0] is optional\n"; 
  print $efl "unset have_prod\n"; 
  print $efl "ups exist $params[0] $params[1] -q $params[2]\n"; 
  print $efl "test \"\$?\" = 0 && set_ have_prod=\"true\"\n"; 
  print $efl "test \"\$have_prod\" = \"true\" || echo \"will not setup $params[0] $params[1] -q $params[2]\"\n"; 
  print $efl "test \"\$have_prod\" = \"true\" && setup -B $params[0] $params[1] -q $params[2] \n";
  print $efl "unset have_prod\n"; 
  } else {
  print $efl "setup -B $params[4] $params[0] $params[1] -q $params[2]\n";
  print $efl "test \"\$?\" = 0 || set_ setup_fail=\"true\"\n"; 
  }
  return 0;
}

sub unsetup_product_dependencies {
  my $prd = $_[0];
  my $unsetlist = $_[1];
  my $dfl = $_[2];
  my $efl = $_[3];
  @dwords = split(/,/,$unsetlist);
  foreach $i ( 0 .. $#dwords ) {
    ##print $dfl "unsetup_product_dependencies: unsetup $dwords[$i]\n";
    # call unsetup if the product has been setup
    my $pck = "SETUP_".uc($dwords[$i]);
    my $p_is_setup=$ENV{$pck};
    ##print $dfl "DIAGNOSTICS: $pck is $p_is_setup\n";
    if ( $p_is_setup ) {
      print $efl "unsetup -j $dwords[$i]\n";
    }
  } 
  ##print $dfl "unsetup_product_dependencies: unsetup $prd\n";
  # call unsetup if the product has been setup
  my $pck = "SETUP_".uc($prd);
  my $p_is_setup=$ENV{$pck};
  ##print $dfl "DIAGNOSTICS: $pck is $p_is_setup\n";
  if ( $p_is_setup ) {
    print $efl "unsetup -j $prd\n";
  }
  return 0;
}

# can we use a simple database to store this info?
sub get_dependency_list {
  my @params = @_;
  my $depfile = $params[0];
  my $dfl = $params[1];
  my %dhash = ();
  my @dlist;
  # read the dependency list and make a hash file keyed on product name
  ##print $dfl "DIAGNOSTIC: parse dependency list\n";
  open(DIN, "< $depfile") or die "Couldn't open $depfile";
  while ( $line=<DIN> ) {
    chop $line;
    if ( index($line,"#") == 0 ) {
    } elsif ( $line !~ /\w+/ ) {
    } else {
      @words = split(/\s+/,$line);
      @dlist = ();
      if( $words[1] eq "-" ) {
        $dhash{ $words[0] } = "";
      } else {
	foreach $i  ( 1 .. $#words ) {
	  $dlist[$i-1] = $words[$i];
	}
        $dhash{ $words[0] } = join( ',', @dlist );
      }
    }
  }
  close(DIN);
  ##my @dkeys = keys %dhash;
  ##foreach $i ( 0 .. $#dkeys ) {
  ##   print $dfl "get_dependency_list: $dkeys[$i] has $dhash{$dkeys[$i]}\n";
  ##}
  return %dhash;
}

sub check_product_dependencies {
  my $prd = $_[0];
  my $dhash_ref = $_[1];
  my $plist = $_[2];
  my $dfl = $_[3];
  my $usej = "";
  my $found_match = false;
  ##print $dfl "check_product_dependencies: checking product $prd\n";
  my @dkeys = keys %$dhash_ref;
  ##print $dfl "check_product_dependencies: dhash_ref has $#dkeys keys\n";
  # this is the list of products we are building
  foreach $i ( 0 .. $#plist ) {
     ##print $dfl "check_product_dependencies: param $i $plist[$i]\n";
     @pl = split( /\,/, $dhash_ref->{$plist[$i]} );
     ##print $dfl "check_product_dependencies: $plist[$i] uses @pl\n";
     foreach $j ( 0 .. $#pl ) {
	if ( $prd eq $pl[$j] ) {
           ##print $dfl "check_product_dependencies: $plist[$i] depends on $prd\n";
           ##print $dfl "check_product_dependencies: $prd depends on $dhash_ref->{$prd}\n";
	   $found_match = true;
	   if ( $dhash_ref->{$prd} eq "" ) { $found_match = false; }
	}
     }
  }
  if ( $found_match eq "true" ) { $usej = "-j"; }
  return $usej;
}

sub get_product_depenencies {
  my $prd = $_[0];
  my $dhash_ref = $_[1];
  my $plist = $_[2];
  my $dfl = $_[3];
  my $pdeps = "";
  my $found_match = false;
  ##print $dfl "get_product_depenencies: checking product $prd\n";
  ##print $dfl "get_product_depenencies: $prd depends on $dhash_ref->{$prd}\n";
  if ( $dhash_ref->{$prd} eq "" ) {
    $found_match = false;
  } else {
     $found_match = true;
     $pdeps = $dhash_ref->{$prd};
  }
  ##print $dfl "get_product_depenencies: set pdeps to $pdeps\n";
  return ($found_match, $pdeps);
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

sub get_lib_directory {
  my @params = @_;
  my $libdir = $params[1]."/lib";
  open(PIN, "< $params[0]") or die "Couldn't open $params[0]";
  while ( $line=<PIN> ) {
    chop $line;
    if ( index($line,"#") == 0 ) {
    } elsif ( $line !~ /\w+/ ) {
    } else {
      @words = split(/\s+/,$line);
      if( $words[0] eq "libdir" ) {
         if( ! $words[2] ) { $words[2] = lib; }
         if( $words[1] eq "product_dir" ) {
	    $libdir = $params[1]."/".$words[2];
         } elsif( $words[1] eq "fq_dir" ) {
	    $libdir = $params[1]."/".$words[2];
         } elsif( $words[1] eq "-" ) {
	    $libdir = "none";
	 } else {
	    print "ERROR: $words[1] is an invalid directory path\n";
	    print "ERROR: directory path must be specified as either \"product_dir\" or \"fq_dir\"\n";
	    print "ERROR: using the default lib directory path\n";
	 }
      }
    }
  }
  close(PIN);
  ##print "defining library directory $libdir\n";
  return ($libdir);
}

sub get_fcl_directory {
  my @params = @_;
  $fcldir = $params[1]."/fcl";
  open(PIN, "< $params[0]") or die "Couldn't open $params[0]";
  while ( $line=<PIN> ) {
    chop $line;
    if ( index($line,"#") == 0 ) {
    } elsif ( $line !~ /\w+/ ) {
    } else {
      @words = split(/\s+/,$line);
      if( $words[0] eq "fcldir" ) {
         if( ! $words[2] ) { $words[2] = fcl; }
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
  # default gdml directory (none)
  $gdmldir = "none";
  open(PIN, "< $params[0]") or die "Couldn't open $params[0]";
  while ( $line=<PIN> ) {
    chop $line;
    if ( index($line,"#") == 0 ) {
    } elsif ( $line !~ /\w+/ ) {
    } else {
      @words = split(/\s+/,$line);
      if( $words[0] eq "gdmldir" ) {
         if( ! $words[2] ) { $words[2] = gdml; }
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
  # default fw directory (none)
  $fwdir = "none";
  open(PIN, "< $params[0]") or die "Couldn't open $params[0]";
  while ( $line=<PIN> ) {
    chop $line;
    if ( index($line,"#") == 0 ) {
    } elsif ( $line !~ /\w+/ ) {
    } else {
      @words = split(/\s+/,$line);
      if( $words[0] eq "fwdir" ) {
         if( ! $words[2] ) { 
	    print "ERROR: you must specify the fw subdirectory name, there is no default\n";
	 } else {
            if( $words[1] eq "product_dir" ) {
	       $fwdir = $params[1]."/".$words[2];
            } elsif( $words[1] eq "fq_dir" ) {
	       $fwdir = $params[1]."/".$words[2];
            } elsif( $words[1] eq "-" ) {
	       $fwdir = "none";
	    } else {
	       print "ERROR: $words[1] is an invalid directory path\n";
	       print "ERROR: directory path must be specified as either \"product_dir\" or \"fq_dir\"\n";
	       print "ERROR: using the default fw directory path\n";
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
  my $loopfile = $params[0];
  my $pkgdir = $params[1];
  my $qual = $params[2];
  my $dfile = $params[3];
  my $tfile = $params[4];

  ($product, $version, $default_ver, $default_qual, %phash) = parse_product_list( $pfile, $dfile );
  ##print $dfile "product_setup_loop: found $product $version $default_ver $default_qual\n";
  
  # continue parsing for this package
  ($ndeps, @qlist) = parse_qualifier_list( $loopfile, $tfile );

  ##print $dfile "product_setup_loop: mrb_quals are $mrb_quals\n";
  ##print $dfile "product_setup_loop: $extra_qual - $dop\n";

  $dq = find_default_qual( $pfile );
  if ( $dq ) {
    $qual = $dq.":";
    $qual = $qual.$dop;
  } elsif ( $simple ) {
    $qual = "-nq-";
  } else {
    $errfl2 = $builddir."/error-".$product."-".$version;
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

  ##print $dfile "product_setup_loop: using qualifier $qual for $product\n";
  my $default_fc = ( $^O eq "darwin" ) ? "-" : "gfortran";

  my $compiler_table =
    {
     cc => { CC => "cc", CXX => "c++", FC => $default_fc },
     gcc => { CC => "gcc", CXX => "g++", FC => "gfortran" },
     icc => { CC => "icc", CXX => "icpc", FC => "ifort" },
    };

  if (!$compiler) {
    my @quals = split /:/, $qual;
    if (grep /^(e[245]|gcc4[78])$/, @quals) {
      $compiler = "gcc";
    } else {
      $compiler = "cc"; # Native.
    }
  }
  ##print $dfile "product_setup_loop: compiler is $compiler\n";
  ##print $dfile "product_setup_loop: $compiler_table->{$compiler}->{CC} $compiler_table->{$compiler}->{CXX} $compiler_table->{$compiler}->{FC}\n";
  $cetfl = cetpkg_info_file( $product, 
                             $version, 
			     $default_ver, 
			     $qual, 
			     $type, 
			     $sourcedir, 
			     $pkgdir,
                          $compiler_table->{$compiler}->{CC},
                          $compiler_table->{$compiler}->{CXX},
                          $compiler_table->{$compiler}->{FC}
			     );

  (%ohash) = find_optional_products( $pfile );
  ($ecount, @ehash) = find_only_for_build_products( $pfile );

  @setup_list=( cetbuildtools, cetpkgsupport );
  foreach $i ( 1 .. $ecount ) {
    $print_setup=true;
    foreach $j ( 0 .. $#setup_list ) {
      if( $ehash[$i][0] eq $setup_list[$j] ) {
        $print_setup=false;
      }
    }
    if ( $print_setup eq "true" ) {
      print $tfile "echo Configuring $product\n";
      print $tfile "setup -B $ehash[$i][0] $ehash[$i][1]\n";
      print $tfile "test \"\$?\" = 0 || set_ setup_fail=\"true\"\n"; 
    }
  }

  # are there products without listed qualifiers?
  @pkeys = keys %phash;
  foreach $i ( 1 .. $#pkeys ) {
    ##print $dfile "searching for $pkeys[$i] qualifiers in $product\n";
    $p_has_qual = 0;
    foreach $k ( 0 .. $#setup_list ) {
      if( $pkeys[$i] eq $setup_list[$k] ) {
	     $p_has_qual++;
      } else {
	foreach $j ( 1 .. $ndeps ) {
	  if ( $pkeys[$i] eq $qlist[0][$j] ) {
	     $p_has_qual++;
	  }
	}
      }
    }
    if ( $p_has_qual == 0 ) {
      print_setup_noqual( $pkeys[$i], $phash{$pkeys[$i]}, $ohash{$pkeys[$i]}, "", $tfile );
    }
  }

  my $sort_mrb_quals = join(":", sort { lc($a) cmp lc($b) } split(/:/,$mrb_quals));
  my $sort_ext_quals = join(":", sort { lc($a) cmp lc($b) } split(/:/,$extra_qual.$qual));
  ##print $dfile "product_setup_loop:  sorted set $sort_ext_quals\n";
  ##print $dfile "product_setup_loop:  sorted mrb $sort_mrb_quals\n";
  # first check for a match to the extended qualifer list 
  $match = 0;
  $exmatch = 0;
  foreach $i ( 1 .. $#qlist ) {
    my $sort_pqual = join(":", sort { lc($a) cmp lc($b) } split(/:/,$qlist[$i][0]));
    ##print $dfile "product_setup_loop: compare $sort_pqual to $sort_ext_quals\n";
    if ( $sort_pqual eq $sort_ext_quals ) {
      $exmatch++;
      ##print $dfile "product_setup_loop: $product matched $sort_pqual to $sort_ext_quals\n";
      foreach $j ( 1 .. $ndeps ) {
	$print_setup=true;
	# are we building this product?
	for $k ( 0 .. $#productnames ) {
	  if ( $productnames[$k] eq $qlist[0][$j] ) {
	     $print_setup=false;
	  }
	}
	# is this product already in the setup list?
	foreach $k ( 0 .. $#setup_list ) {
	  if( $setup_list[$k] eq $qlist[0][$j] ) {
	    $print_setup=false;
	  }
	}
	##print $dfile "should I setup $qlist[0][$j]? ${print_setup}\n";
        if ( $print_setup eq "true" ) {
	  push( @setup_list, $qlist[0][$j] );
	  # is this part of my extended package list?
	  # if it is in the middle of the build list, use setup -j
	  # if we are not building anything it depends on, use regular setup
	  ##print $dfile "DIAGNOSTIC: checking product dependencies for $qlist[0][$j]\n";
	  #$usejj = check_product_dependencies( $qlist[0][$j], \%deplist, \@package_list, $dfile );
	  ($has_deps, $pdeplist) = get_product_depenencies( $qlist[0][$j], \%deplist, \@package_list, $dfile );
          my $usej = "";
	  ##print $dfile "get_product_depenencies returned $has_deps, @pdeplist\n";
	  if ( $has_deps eq "true" ) {
	    ##print $dfile "DIAGNOSTIC: calling unsetup_product_dependencies with $pdeplist\n";
	    unsetup_product_dependencies( $qlist[0][$j], $pdeplist, $dfile, $tfile );
	  }
	  if ( $qlist[$i][$j] eq "-" ) {
	  } elsif ( $qlist[$i][$j] eq "-nq-" ) {
            print_setup_noqual( $qlist[0][$j], $phash{$qlist[0][$j]}, $ohash{$qlist[0][$j]}, $usej, $tfile );
	  } elsif ( $qlist[$i][$j] eq "-b-" ) {
            print_setup_noqual( $qlist[0][$j], $phash{$qlist[0][$j]}, $ohash{$qlist[0][$j]}, $usej, $tfile );
	  } else {
	    @qwords = split(/:/,$qlist[$i][$j]);
	    $ql="+".$qwords[0];
	    foreach $j ( 1 .. $#qwords ) {
	      $ql = $ql.":+".$qwords[$j];
	    }
            print_setup_qual( $qlist[0][$j], $phash{$qlist[0][$j]}, $ql, $ohash{$qlist[0][$j]}, $usej, $tfile );
	  }
	}
      }
    }
  }
  if ( $exmatch == 0 ) {
  # didn't find a match to the extended qual, so check against MRB_QUAL
  foreach $i ( 1 .. $#qlist ) {
    my $sort_pqual = join(":", sort { lc($a) cmp lc($b) } split(/:/,$qlist[$i][0]));
    ##print $dfile "product_setup_loop: compare $sort_pqual to $sort_mrb_quals\n";
    if ( $sort_pqual eq $sort_mrb_quals ) {
      $match++;
      ##print $dfile "product_setup_loop: matched $sort_pqual to $sort_mrb_quals\n";
      foreach $j ( 1 .. $ndeps ) {
	$print_setup=true;
	# are we building this product?
	for $k ( 0 .. $#productnames ) {
	  if ( $productnames[$k] eq $qlist[0][$j] ) {
	     $print_setup=false;
	  }
	}
	# is this product already in the setup list?
	foreach $k ( 0 .. $#setup_list ) {
	  if( $setup_list[$k] eq $qlist[0][$j] ) {
	    $print_setup=false;
	  }
	}
	##print $dfile "should I setup $qlist[0][$j]? ${print_setup}\n";
        if ( $print_setup eq "true" ) {
	  push( @setup_list, $qlist[0][$j] );
	  # is this part of my extended package list?
	  # if it is in the middle of the build list, use setup -j
	  # if we are not building anything it depends on, use regular setup
	  ##print $dfile "DIAGNOSTIC: checking product dependencies for $qlist[0][$j]\n";
	  #$usejj = check_product_dependencies( $qlist[0][$j], \%deplist, \@package_list, $dfile );
	  ($has_deps, $pdeplist) = get_product_depenencies( $qlist[0][$j], \%deplist, \@package_list, $dfile );
          my $usej = "";
	  ##print $dfile "get_product_depenencies returned $has_deps, @pdeplist\n";
	  if ( $has_deps eq "true" ) {
	    ##print $dfile "DIAGNOSTIC: calling unsetup_product_dependencies with $pdeplist\n";
	    unsetup_product_dependencies( $qlist[0][$j], $pdeplist, $dfile, $tfile );
	  }
	  if ( $qlist[$i][$j] eq "-" ) {
	  } elsif ( $qlist[$i][$j] eq "-nq-" ) {
            print_setup_noqual( $qlist[0][$j], $phash{$qlist[0][$j]}, $ohash{$qlist[0][$j]}, $usej, $tfile );
	  } elsif ( $qlist[$i][$j] eq "-b-" ) {
            print_setup_noqual( $qlist[0][$j], $phash{$qlist[0][$j]}, $ohash{$qlist[0][$j]}, $usej, $tfile );
	  } else {
	    @qwords = split(/:/,$qlist[$i][$j]);
	    $ql="+".$qwords[0];
	    foreach $j ( 1 .. $#qwords ) {
	      $ql = $ql.":+".$qwords[$j];
	    }
            print_setup_qual( $qlist[0][$j], $phash{$qlist[0][$j]}, $ql, $ohash{$qlist[0][$j]}, $usej, $tfile );
	  }
	}
      }
    }
  }
  }

  # allow for the case where there are no dependencies
  if ( $match == 0 && $exmatch == 0 ) {
     if( $phash{none} eq "none" ) {
       #print "this package has no dependencies\n";
     } else {
       print $tfile "\n";
       print $tfile "echo \"ERROR: failed to find any dependent products for $product $version -q $qual\"\n";
       print $tfile "echo \"       The following qualifier combinations are recognized:\"\n";
       foreach $i ( 1 .. $#qlist ) {
	   print $tfile "echo \"         $qlist[$i][0] \"\n";
       }
       print $tfile "return 1\n";
       print $tfile "\n";
     }
  }

  return ($product, $version);

}

1;
