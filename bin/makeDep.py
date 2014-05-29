#!/usr/bin/env python
# vim: ts=4 expandtab sw=4

"""Consruct a dependency database."""


# run this from the build directory
# creates $MRB_BUILDDIR/.dependency_database
# To use a temporary database as a base database, 
# copy it to $MRB_INSTALL/.base_dependency_database

import optparse
import os
import re
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
        """Constructor."""
        #print >>sys.stderr, "DEBUG: Globals initializing."
        #self.indent = " " * 2
        # Results of parsing the command line.
        self.opts = None
        self.args = None
        self.mrb_source = os.environ.get("MRB_SOURCE", "")
        if self.mrb_source and (self.mrb_source[-1] == os.sep):
            del self.mrb_source[-1]
        self.mrb_build = os.environ.get("MRB_BUILDDIR", "")
        self.mrb_install = os.environ.get("MRB_INSTALL", "")
        self.products = os.environ.get("PRODUCTS", "")
        tmp = self.products.split(":")
        self.product_dirs = []
        for dir in self.products.split(":"):
            if dir and (dir[-1] == os.sep):
                del dir[-1]
            self.product_dirs.append(dir)
        self.pat_mrb_source = re.compile(self.mrb_source + os.sep)
        self.pat_pkg_names = re.compile(r"([^/]+)/(.*): " + \
            self.mrb_source + r"/([^/]+)/(.*[.](?:h|hh|hpp|i|icc|tcc))$")
        self.dep_file_name = os.path.join(self.mrb_build, \
            ".dependency_database")
        self.project_dep_file_name = os.path.join(self.mrb_install, \
            ".base_dependency_database")
        #print >>sys.stderr, "DEBUG: opts:", self.opts
        #print >>sys.stderr, "DEBUG: args:", self.args
        #print >>sys.stderr, "DEBUG: MRB_SOURCE:", globals.mrb_source
        #print >>sys.stderr, "DEBUG: MRB_BUILD:", globals.mrb_build
        #print >>sys.stderr, "DEBUG: MRB_INSTALL:", globals.mrb_install
        #print >>sys.stderr, "DEBUG: products:", self.products
        #print >>sys.stderr, "DEBUG: product_dirs:", self.product_dirs
        #print >>sys.stderr, "DEBUG: dep_file_name:", self.dep_file_name
        #print >>sys.stderr, "DEBUG: project_dep_file_name:", \
        #    self.project_dep_file_name

    def parse_options(self):
        """Parse the command line."""
        descrip="Create the local dependency database by loading " + \
                "information from the cmake dependency files created in " + \
                "the build area during a build."
        p = optparse.OptionParser(description=descrip)
        p.set_defaults(do_nothing=False)
        p.add_option("-n", dest="do_nothing", action="store_true",
            help="do nothing")
        (self.opts, self.args) = p.parse_args()
        #print >>sys.stderr, "DEBUG: do_nothing:", self.opts.do_nothing

# Create an object to contain global variables.
globals = GLOBALS()

class SYSTEM:
    """Master Controller."""

    def __init__(self):
        """Constructor."""
        #print >>sys.stderr, "DEBUG: System initializing."
        # Project dependency database.
        self.project_deps = {}
        # Local dependency database.
        self.local_deps = {}
        # Combined project and local dependency database.
        self.deps = {}
        # Local package information.
        self.local_pkgs = {}
        # Patterns for matching base pkgs.
        self.pat_base_pkgs = []

    def run(self):
        """Entry Point."""
        #print >>sys.stderr, "DEBUG: System running."
        globals.parse_options()
        if globals.opts.do_nothing:
            return
        self.load_project_dependency_database()
        #print >>sys.stderr, "DEBUG: project_deps:", self.project_deps
        self.get_list_of_local_pkgs()
        #print >>sys.stderr, "DEBUG: local_pkgs:", self.local_pkgs
        self.make_base_pkgs_pats()
        #print >>sys.stderr, "DEBUG: pat_base_pkgs:", self.pat_base_pkgs
        self.scan_local_dependencies()
        #print >>sys.stderr, "DEBUG: deps:", self.deps
        self.deps = self.project_deps
        # Combine the project and local dependency databases.
        self.deps.update(self.local_deps)
        #print >>sys.stderr, "DEBUG: deps:", self.deps
        self.write_local_dependency_database()

    def load_project_dependency_database(self):
        """Get the base dependency database."""
        self.project_deps = {}
        if not os.path.exists(globals.project_dep_file_name):
            # Note: This is not an error because we get here
            #       when we are creating the project dependency
            #       database itself.
            return
        inf = open(globals.project_dep_file_name, "r")
        for line in inf:
            #print >>sys.stderr, "DEBUG:", line,
            (pkg, dep, dep_file) = line.split(":")
            pkg = pkg.strip()
            dep = dep.strip()
            dep_file = dep_file.strip()
            #print >>sys.stderr, "DEBUG: '%s' : '%s' : '%s'" % \
            #    (pkg, dep, dep_file)
            if not self.project_deps.has_key(pkg):
                self.project_deps[pkg] = { dep : { dep_file : 1 } }
            else:
                if not self.project_deps[pkg].has_key(dep):
                    self.project_deps[pkg][dep] = { dep_file : 1 }
                else:
                    self.project_deps[pkg][dep][dep_file] = 1
        inf.close()

    def get_list_of_local_pkgs(self):
        """Make a list of local pkgs."""
        curdir = os.getcwd()
        os.chdir(globals.mrb_source)
        for nm in sorted(os.listdir(".")):
            if not os.path.isdir(nm):
                # Skip ordinary files.
                continue;
            # This is a package source directory.
            self.local_pkgs[nm] = 1
        os.chdir(curdir)

    def make_base_pkgs_pats(self):
        """Create regex patterns for matching base pkgs."""
        local_pkgs = self.local_pkgs.keys()
        local_pkgs.sort()
        self.pat_base_pkgs = {}
        for prod_dir in globals.product_dirs:
            for pkg in sorted(self.project_deps.keys()):
                if pkg in local_pkgs:
                    # Skip local packages.
                    continue
                pkg_dir = os.path.join(prod_dir, pkg)
                if not os.path.exists(pkg_dir):
                    # Nope, this pkg is not in that product dir.
                    continue
                self.pat_base_pkgs[pkg] = [
                    re.compile(pkg_dir + os.sep),
                    re.compile(r"([^/]+)/(.*): " + prod_dir + \
                    r"/([^/]+)/v[^/]+/include/(.*[.](?:h|hh|hpp|i|icc|tcc))$") ]

    def scan_local_dependencies(self):
        """Scan the mrb build directory for dependency info."""
        curdir = os.getcwd()
        os.chdir(globals.mrb_build)
        for nm in sorted(os.listdir(".")):
            if not os.path.isdir(nm):
                # Skip ordinary files.
                continue;
            if nm == "CMakeFiles":
                # Top level CMakeFiles dir is not interesting.
                continue;
            # This is a package build directory.
            self.handle_package_build_dir(nm)
        os.chdir(curdir)

    def handle_package_build_dir(self, pkg):
        """Scan a package build directory for dependency info."""
        #print >>sys.stderr, "DEBUG:", pkg
        pkgdepends = {}
        os.chdir(pkg)
        for nm in sorted(os.listdir(".")):
            if not os.path.isdir(nm):
                # We are looking for cmake info dirs,
                # skip ordinary files.
                continue;
            self.scan_dir_for_depends(nm, 1, pkgdepends)
        self.local_deps[pkg] = pkgdepends
        os.chdir("..")

    def scan_dir_for_depends(self, dirname, level, pkgdepends):
        """Recursively scan a directory for dependency files."""
        #indent = globals.indent * level
        #print >>sys.stderr, "DEBUG: %s%s" % (indent, dirname)
        os.chdir(dirname)
        for nm in sorted(os.listdir(".")):
            if os.path.isdir(nm):
                # Recursively scan subdirectories.
                self.scan_dir_for_depends(nm, level + 1, pkgdepends)
            if nm == "depend.make":
                # Found a cmake dependency info file, scan it.
                self.collect_deps_from_a_file(os.path.abspath(nm), \
                    level + 1, pkgdepends)
        os.chdir("..")
        
    def collect_deps_from_a_file(self, filename, level, pkgdepends):
        """Collect dependency info from a make format dependency file."""
        #indent = globals.indent * level
        #print >>sys.stderr, "DEBUG: %s%s" % (indent, filename)
        inf = open(filename, "r")
        for line in inf:
            if "#" == line[0]:
                # Skip comment lines.
                continue
            res = None
            if globals.pat_mrb_source.search(line):
                # Found a dependency on a local pkg.
                # Get the package names out of the dependency line.
                res = globals.pat_pkg_names.match(line)
                #if res:
                #    print >>sys.stderr, "DEBUG:", \
                #        "res.group(1):", res.group(1), \
                #        "res.group(2):", res.group(2), \
                #        "res.group(3):", res.group(3), \
                #        "res.group(4):", res.group(4)
            else:
                # Not a dependency on a local pkg, check for a base pkg.
                found = False
                for base_pkg in sorted(self.pat_base_pkgs.keys()):
                    if self.pat_base_pkgs[base_pkg][0].search(line):
                        # Found use of a file from a base pkg.
                        res = self.pat_base_pkgs[base_pkg][1].match(line)
                        #if res:
                        #    print >>sys.stderr, \
                        #        "DEBUG: base pkg:", \
                        #        "res.group(1):", res.group(1), \
                        #        "res.group(2):", res.group(2), \
                        #        "res.group(3):", res.group(3), \
                        #        "res.group(4):", res.group(4)
                        found = True
                        break
                if not found:
                    # Did not match a local pkg or a base pkg, skip it.
                    continue
            if not res:
                # Note: Match failures are expected.  We are only matching
                #       header files, source files are excluded.
                continue
            # Got dependency info, now record it.
            dep = res.group(3)
            if not pkgdepends.has_key(dep):
                pkgdepends[dep] = {}
                pkgdepends[dep][res.group(4)] = 1
            else:
                if not pkgdepends[dep].has_key(res.group(4)):
                    pkgdepends[dep][res.group(4)] = 1
        inf.close()

    def write_local_dependency_database(self):
        """Dump the combined project and local dependency database to disk
           as the new local dependency database."""
        outf = open(globals.dep_file_name, "w")
        for pkg in sorted(self.deps.keys()):
            for dep in sorted(self.deps[pkg].keys()):
                for dep_file in sorted(self.deps[pkg][dep].keys()):
                    print >>outf, "%s : %s : %s" % (pkg, dep, dep_file)
        outf.close()

if __name__ == "__main__":
    # We are being run as a script.
    system = SYSTEM()
    system.run()
else:
    # We are being loaded as a module.
    pass

