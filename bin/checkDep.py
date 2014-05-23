#!/usr/bin/env python
# vim: ts=4 expandtab sw=4

"""Consruct a dependency database."""

import optparse
import os
import re
import string
import subprocess
import sys

# Force the python version to be at least 2.4.x, which is
# the version available in SLF5.x distributions (actually
# they all ship with 2.4.3, and just for reference, all
# of the SLF6.x distributions ship with 2.6.6).
if (sys.version_info[0] < 2) or ((sys.version_info[0] == 2) and \
        (sys.version_info[1] < 4)):
    print >>sys.stderr, "ERROR: Python version must be at least 2.4!"
    sys.exit(1)

class GLOBALS:
    """Global variables container."""

    def __init__(self):
        """Constructor"""
        # Results of parsing the command line.
        self.opts = None
        self.args = None
        # Time difference in seconds for considering a local file
        # to have been modified.
        self.stat_fudge = 5.0
        self.mrb_source = os.environ.get("MRB_SOURCE", "")
        self.mrb_build = os.environ.get("MRB_BUILDDIR", "")
        self.mrb_top = os.environ.get("MRB_TOP", "")
        #self.products = os.environ.get("PRODUCTS", "")
        #tmp = self.products.split(":")
        #self.product_dirs = []
        #for dir in self.products.split(":"):
        #    if dir and (dir[-1] == os.sep):
        #        del dir[-1]
        #    self.product_dirs.append(dir)
        self.project_dep_file_name = os.path.join(self.mrb_top, \
            ".base_dependency_database")
        self.dep_file_name = os.path.join(self.mrb_build, \
            ".dependency_database")
        #print >>sys.stderr, "DEBUG: opts:", self.opts
        #print >>sys.stderr, "DEBUG: args:", self.args
        #print >>sys.stderr, "DEBUG: MRB_SOURCE:", self.mrb_source
        #print >>sys.stderr, "DEBUG: MRB_BUILD:", self.mrb_build
        #print >>sys.stderr, "DEBUG: MRB_TOP:", self.mrb_top
        #print >>sys.stderr, "DEBUG: PRODUCTS:", self.products
        #print >>sys.stderr, "DEBUG: product_dirs:", self.product_dirs
        #print >>sys.stderr, "DEBUG: project_dep_file_name:", self.project_dep_file_name
        #print >>sys.stderr, "DEBUG: dep_file_name:", self.dep_file_name

    def parse_options(self):
        """Parse the command line."""
        descrip="Scan the dependency database looking for packages " + \
                "which #include files which have been modified in the " + \
                "working area.  Normal behavior is to checkout any such " + \
                "package if it has not already been checked out, but " + \
                "this behavior can be prevented with the -n option."
        p = optparse.OptionParser(description=descrip)
        p.set_defaults(do_autocheckout=True)
        p.add_option("-n", dest="do_autocheckout", action="store_false",
            help="no autocheckout")
        (self.opts, self.args) = p.parse_args()
        #print >>sys.stderr, "DEBUG: do_autocheckout:", self.opts.do_autocheckout

# Create an object to contain global variables.
globals = GLOBALS()

class SYSTEM:
    """Master Controller."""

    def __init__(self):
        """Constructor."""
        #print >>sys.stderr, "DEBUG: System initializing."
        # Checked out pkgs in the local developer area.
        self.local_pkgs = {}
        # Project dependency database.
        self.project_deps = {}
        # Local package information.
        self.local_pkgs = {}
        # Patterns for matching base pkgs.
        self.pat_base_pkgs = []
        # Local dependency database.
        self.local_deps = {}
        # Combined project and local dependency database.
        self.deps = {}
        # Cache of modified files in local pkgs.
        self.file_mod_cache = {}
        # Packages we have tried to checkout at least once.
        self.notified_pkgs = {}

    def run(self):
        """Entry Point."""
        #print >>sys.stderr, "DEBUG: System running."
        globals.parse_options()
        self.load_project_dependency_database()
        self.load_local_dependency_database()
        self.deps = self.project_deps
        self.deps.update(self.local_deps)
        #print >>sys.stderr, "DEBUG: deps:", self.deps
        self.get_list_of_local_pkgs()
        #print >>sys.stderr, "DEBUG: local_pkgs:", self.local_pkgs
        for pkg in sorted(self.deps.keys()):
            if self.local_pkgs.has_key(pkg):
                # Skip already checked out pkgs.
                continue
            for dep in sorted(self.deps[pkg]):
                if dep == pkg:
                    # Ignore self-dependencies.
                    continue
                if self.local_pkgs.has_key(dep):
                    # We have a not-checked out pkg that depends
                    # on a checked out pkg, check to see if we
                    # should check it out.
                    self.test_pkg_for_auto_checkout(pkg, dep)

    def load_project_dependency_database(self):
        """Read in the project-level dependency database."""
        self.deps = {}
        if not os.path.exists(globals.project_dep_file_name):
            return
        inf = open(globals.project_dep_file_name, "r")
        for line in inf:
            #print >>sys.stderr, "DEBUG:", line,
            (pkg, dep, dep_file) = line.split(":")
            pkg = pkg.strip()
            dep = dep.strip()
            dep_file = dep_file.strip()
            #print >>sys.stderr, "DEBUG: '%s' : '%s' : '%s'" % (pkg, dep, dep_file)
            if not self.project_deps.has_key(pkg):
                self.project_deps[pkg] = { dep : { dep_file : 1 } }
            else:
                if not self.project_deps[pkg].has_key(dep):
                    self.project_deps[pkg][dep] = { dep_file : 1 }
                else:
                    self.project_deps[pkg][dep][dep_file] = 1
        inf.close()

    def load_local_dependency_database(self):
        """Read in development area dependency datatbase."""
        if not os.path.exists(globals.dep_file_name):
            # No dependency database to load, not an error.
            return
        inf = open(globals.dep_file_name, "r")
        for line in inf:
            #print >>sys.stderr, "DEBUG:", line,
            (pkg, dep, dep_file) = line.split(":")
            pkg = pkg.strip()
            dep = dep.strip()
            dep_file = dep_file.strip()
            #print >>sys.stderr, "DEBUG: '%s' : '%s' : '%s'" % (pkg, dep, dep_file)
            if not self.local_deps.has_key(pkg):
                self.local_deps[pkg] = { dep : { dep_file : 1 } }
            else:
                if not self.local_deps[pkg].has_key(dep):
                    self.local_deps[pkg][dep] = { dep_file : 1 }
                else:
                    self.local_deps[pkg][dep][dep_file] = 1
        inf.close()

    def get_list_of_local_pkgs(self):
        """Make a list of local pkgs."""
        curdir = os.getcwd()
        os.chdir(globals.mrb_source)
        tmp = os.listdir(".")
        tmp.sort()
        for nm in tmp:
            if not os.path.isdir(nm):
                # Skip ordinary files.
                continue;
            # This is a package source directory.
            self.local_pkgs[nm] = 1
        os.chdir(curdir)

    def test_pkg_for_auto_checkout(self, pkg, other_end):
        """Check pkg to see if it depends on a modified
           file in pkg other_end, and if so, check it out."""
        #print >>sys.stderr, "DEBUG: test_pkg_for_auto_checkout: Package:", \
        #    pkg, "Other End:", other_end
        if not self.deps[pkg].has_key(other_end):
            # This pkg has no dependencies on the other end,
            # so we do not need to check it out.
            return
        needs_checkout = False
        for dep_file in sorted(self.deps[pkg][other_end].keys()):
            if not self.file_mod_cache.has_key(other_end):
                self.file_mod_cache[other_end] = {
                    dep_file :
                    self.check_if_file_modified(other_end, dep_file) }
            if not self.file_mod_cache[other_end].has_key(dep_file):
                self.file_mod_cache[other_end][dep_file] = \
                    self.check_if_file_modified(other_end, dep_file)
            if self.file_mod_cache[other_end][dep_file]:
                needs_checkout = True
                break
        if needs_checkout:
            self.handle_auto_checkout(pkg, other_end, dep_file)

    def check_if_file_modified(self, pkg, filenm):
        """Check if a file in pkg has been modified by comparing
           its modification date to the modification date of the
           package directory."""
        dir = os.path.join(globals.mrb_source, pkg)
        fullnm = os.path.join(dir, filenm)
        if (os.stat(fullnm).st_mtime - os.stat(dir).st_mtime) > \
                globals.stat_fudge:
            # File has been modified.
            return True
        # Nope, the file is unchanged.
        return False

    def handle_auto_checkout(self, pkg, other_end, dep_file):
        """Perform an autocheckout of pkg, if enabled, because
           it makes use of dep_file ing package other_end which
           has been modified."""
        # Record that we have done this pkg, so that
        # we do not do it again.
        #self.local_pkgs[pkg] = 1
        if self.notified_pkgs.has_key(pkg):
            # Already tried this at least once before.
            return
        self.notified_pkgs[pkg] = 1
        if not globals.opts.do_autocheckout:
            print >>sys.stderr, "INFO: Please checkout package", pkg,
            print >>sys.stderr, "due to modified file %s/%s/%s" % \
                (globals.mrb_source, other_end, dep_file)
            return
        print >>sys.stderr, "INFO: Checking out package", pkg,
        print >>sys.stderr, "due to modified file %s/%s" % \
                (other_end, dep_file)
        curdir = os.getcwd()
        os.chdir(globals.mrb_source)
        proc = subprocess.Popen(["mrb",  "gitCheckout",  pkg], \
            stdout=subprocess.PIPE, stderr=subprocess.STDOUT, \
            universal_newlines=True)
        msgs = proc.communicate()[0]
        print >>sys.stderr, msgs,
        if proc.returncode != 0:
            if proc.returncode < 0:
                print >>sys.stderr, \
                    "ERROR: Checkout terminated by signal %d!" % \
                    (-proc.returncode,)
            else:
                print >>sys.stderr, "ERROR: Checkout failed!"
        os.chdir(curdir)

if __name__ == "__main__":
    # We are being run as a script.
    system = SYSTEM()
    system.run()
else:
    # We are being loaded as a module.
    pass

