# parse product_deps

# product_deps format:

#   parent this_product this_version
#   [incdir      product_dir	include]
#   [libdir      fq_dir	lib]
#   [bindir      fq_dir	bin]
#   product		version
#   dependent_product	dependent_product_version [optional]
#   dependent_product	dependent_product_version [optional]
#   qualifier dependent_product       dependent_product notes
#   this_qual dependent_product_qual  dependent_product_qual
#   this_qual dependent_product_qual  dependent_product_qual

# The indir, libdir, and bindir lines are optional
# Use them only if your product does not conform to the defaults
# Format: directory_type directory_path directory_name
# The only recognized values of the first field are incdir, libdir, and bindir
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

sub get_package_list {
  my @params = @_;
  my $srcdir = $params[1];
  my $dfile = $params[2];
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
        print "parse_product_list: ignoring $line\n";
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
        print "parse_qualifier_list: ignoring $line\n";
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
        print "find_optional_products: ignoring $line\n";
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
  my @params = @_;
  $cetpkgfile = $params[6]."/cetpkg_variable_report";
  open(CPG, "> $cetpkgfile") or die "Couldn't open $cetpkgfile";
  print CPG "\n";
  print CPG "CETPKG_NAME     $params[0]\n";
  print CPG "CETPKG_VERSION  $params[1]\n";
  print CPG "CETPKG_DEFAULT_VERSION  $params[2]\n";
  print CPG "CETPKG_QUAL     $params[3]\n";
  print CPG "CETPKG_TYPE     $params[4]\n";
  print CPG "CETPKG_SOURCE   $params[5]\n";
  print CPG "CETPKG_BUILD    $params[6]\n";
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

sub compare_qual {
  my @params = @_;
  my @ql1 = split(/:/,$params[0]);
  my @ql2 = split(/:/,$params[1]);
  my $retval = 0;
  if( $#ql1 != $#ql2 ) { return $retval; }
  my $size = $#ql2 + 1;
  $qmatch = 0;
  foreach $i ( 0 .. $#ql1 ) {
    foreach $j ( 0 .. $#ql2 ) {
      if( $ql1[$i] eq $ql2[$j] )  { $qmatch++; }
    }
  }
  if( $qmatch == $size ) { $retval = 1; }
  return $retval;
}

# can we use a simple database to store this info?
sub get_dependency_list {
  my @params = @_;
  my $depfile = $params[0];
  my $dfl = $params[1];
  my %dhash = ();
  my @dlist;
  # read the dependency list and make a hash file keyed on product name
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

1;
