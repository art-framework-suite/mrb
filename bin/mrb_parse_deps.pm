use strict;
use warnings;

package mrb_parse_deps;

use List::Util qw(min max);     # Numeric min / max funcions.

use Exporter 'import';
our (@EXPORT, @setup_list);

# Items we expect to get from parse_deps.pm.
my @from_parse_deps =
  qw( annotated_items
      by_version
      cetpkg_info_file
      compiler_for_quals
      diag_print_items
      get_fcl_directory
      get_fw_directory
      get_gdml_directory
      get_perllib
      get_parent_info
      get_product_list
      get_qualifier_list
      get_qualifier_matrix
      get_setfw_list
      match_qual
      offset_annotated_items
      parse_version_string
      print_dep_setup
      print_setup_boilerplate
      prods_for_quals
      setup_error
      sort_qual
      to_string
      $compiler_table
   );

use parse_deps @from_parse_deps;

@EXPORT = qw( compare_qual
              find_cetbuildtools
              get_package_list
              get_only_for_build
              get_product_name
              get_root_path
              latest_version
              product_setup_loop
              setup_only_for_build
           );

# Export the functions we just imported from parse_deps.pm
push @EXPORT, @from_parse_deps;

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
      if ( (uc $words[0]) eq "ADD_SUBDIRECTORY" ) {
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
      if ( $words[0] eq "parent" ) {
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
      if ( $words[0] eq "only_for_build" ) {
        if ( $words[1] eq "cetbuildtools" ) {
          $cver = $words[2];
        }
      } elsif ( $words[0] eq "cetbuildtools" ) {
        $cver = $words[1];
      }
    }
  }
  close(PIN);
  return ($cver);
}

sub latest_version {
  my @result = sort by_version @_;
  return pop @result;
}

sub get_root_path {
  my @params = @_;
  my $incdir = "default";
  my $fq = "true";
  my $line;
  my @words;
  my $rp = "none";
  my $extrapath = "none";
  open(PIN, "< $params[0]") or die "Couldn't open $params[0]";
  while ( $line=<PIN> ) {
    chop $line;
    if ( index($line,"#") == 0 ) {
    } elsif ( $line !~ /\w+/ ) {
    } elsif ( index($line,"ROOT_INCLUDE_PATH") > 0 ) {
      #print "DEBUG: found $line\n";
      my $cind = index($line,",");
      if ( $cind > 0 ) {
        my $pind = index($line,")");
        my $bind = index($line,"\$");
        #print "DEBUG: comma at $cind $bind paren at $pind\n";
        $extrapath = substr($line, $bind, ($pind-$bind));
        #print "DEBUG: extracted --$extrapath--\n";
      }
    } else {
      @words = split(/\s+/,$line);
      if ( $words[0] eq "incdir" ) {
        if ( ! $words[2] ) {
          $words[2] = "include";
        }
        if ( $words[1] eq "product_dir" ) {
          $incdir = $params[1]."/".$words[2];
        } elsif ( $words[1] eq "fq_dir" ) {
          $incdir = $params[1]."/".$words[2];
        } elsif ( $words[1] eq "-" ) {
          $incdir = "none";
        } else {
          print "ERROR: $words[1] is an invalid directory path\n";
          print "ERROR: directory path must be specified as either \"product_dir\" or \"fq_dir\"\n";
          print "ERROR: using the default include directory path\n";
        }
      } elsif ( $words[0] eq "no_fq_dir" ) {
        $fq = "";
      }
    }
  }
  close(PIN);
  if ( $incdir ne "none" ) {
    $incdir = "\${MRB_SOURCE}/".$params[1];
  }
  ##print "defining executable directory $incdir\n";
  if ( $fq ) {
    if ( $extrapath eq "none" ) {
      $rp = $incdir;
    } else {
      $rp = $incdir.":".$extrapath;
    }
  }
  #print "DEBUG: return $rp\n";
  return ($rp);
}

sub get_only_for_build {
  my ($phash, $dbgrpt) = @_;
  # Filter only_for_build version entries for all products in a *resolved*
  # $phash.
  return
    { map { $phash->{$_}->{only_for_build} ? ( $_ => $phash->{$_} ) : (); } keys %{$phash} };
}

sub compare_qual {
  my @params = @_;
  my @ql1 = split(/:/,$params[0]);
  my @ql2 = split(/:/,$params[1]);
  my $retval = 0;
  if ( $#ql1 != $#ql2 ) {
    return $retval;
  }
  my $size = $#ql2 + 1;
  my $qmatch = 0;
  my $ii;
  my $jj;
  foreach $ii ( 0 .. $#ql1 ) {
    foreach $jj ( 0 .. $#ql2 ) {
      if ( $ql1[$ii] eq $ql2[$jj] ) {
        $qmatch++;
      }
    }
  }
  if ( $qmatch == $size ) {
    $retval = 1;
  }
  return $retval;
}

1;
