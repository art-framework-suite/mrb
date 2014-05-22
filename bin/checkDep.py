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
        self.indent = " " * 2
        self.mrb_source = os.environ.get("MRB_SOURCE", "")
        self.mrb_build = os.environ.get("MRB_BUILDDIR", "")
        self.mrb_top = os.environ.get("MRB_TOP", "")
        self.base_dep_file_name = os.path.join(self.mrb_top, \
            ".base_dependency_database")
        self.dep_file_name = os.path.join(self.mrb_build, \
            ".dependency_database")
        self.opts = None
        self.args = None
        #print >>sys.stderr, "DEBUG: MRB_SOURCE:", self.mrb_source
        #print >>sys.stderr, "DEBUG: MRB_BUILD:", self.mrb_build
        #print >>sys.stderr, "DEBUG: MRB_TOP:", self.mrb_top
        #print >>sys.stderr, "DEBUG: base_dep_file_name:", self.base_dep_file_name
        #print >>sys.stderr, "DEBUG: dep_file_name:", self.dep_file_name

    def parse_options(self):
        usage = "Usage: %prog [options]"
        p = optparse.OptionParser(usage)
        p.set_defaults(do_autocheckout=True)
        p.add_option("-n", dest="do_autocheckout", action="store_false",
            help="automatically checkout missing packages needed for a consistent build")
        (self.opts, self.args) = p.parse_args()
        #print >>sys.stderr, "DEBUG: do_autocheckout:", self.opts.do_autocheckout

# Create an object to contain global variables.
globals = GLOBALS()

class SYSTEM:
    """Master Controller."""

    def __init__(self):
        """Constructor."""
        #print >>sys.stderr, "DEBUG: System initializing."
        self.opts = None
        self.args = None
        self.deps = {}
        self.local_pkgs = {}

    def run(self):
        """Entry Point."""
        #print >>sys.stderr, "DEBUG: System running."
        globals.parse_options()
        self.load_project_dependency_database()
        self.load_dependency_database()
        self.do_transitive_reduction()
        #print >>sys.stderr, "DEBUG: deps:", self.deps
        self.get_list_of_local_pkgs()
        #print >>sys.stderr, "DEBUG: local_pkgs:", self.local_pkgs
        pkgs_to_scan = self.local_pkgs.keys()
        pkgs_to_scan.sort()
        for pkg in pkgs_to_scan:
            self.scan_package_for_checkouts(pkg)

    def load_project_dependency_database(self):
        self.deps = {}
        if not os.path.exists(globals.base_dep_file_name):
            return
        inf = open(globals.base_dep_file_name, "r")
        line = inf.readline()
        while len(line):
            #print >>sys.stderr, "DEBUG:", line,
            (pkg, tmp) = line.split(":")
            pkg = pkg.strip()
            vals = tmp.split()
            self.deps[pkg] = vals
            #print >>sys.stderr, "DEBUG: %s%s:" % (globals.indent, pkg), vals
            line = inf.readline()
        inf.close()

    def load_dependency_database(self):
        if not os.path.exists(globals.dep_file_name):
            # No dependency database to load, not an error.
            return
        inf = open(globals.dep_file_name, "r")
        line = inf.readline()
        while len(line):
            #print >>sys.stderr, "DEBUG:", line,
            (pkg, tmp) = line.split(":")
            pkg = pkg.strip()
            vals = tmp.split()
            self.deps[pkg] = vals
            #print >>sys.stderr, "DEBUG: %s%s:" % (globals.indent, pkg), vals
            line = inf.readline()
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

    def do_transitive_reduction(self):
        reduced_deps = {}
        for pkg in sorted(self.deps.keys()):
            reduced_pkg_deps = self.deps[pkg]
            path = [ pkg ]
            for dep in sorted(self.deps[pkg]):
                path.append(dep)
                self.visit_for_transitive_reduction(dep, path, reduced_pkg_deps)
                path.pop()
            reduced_deps[pkg] = reduced_pkg_deps
        self.deps = reduced_deps

    def visit_for_transitive_reduction(self, pkg, path, reduced_pkg_deps):
        #print >>sys.stderr, "DEBUG: Visiting:", pkg, "Path:", path
        if not self.deps.has_key(pkg):
            print >>sys.stderr, \
                "INFO: No dependency information in database for:", pkg
            return
        for dep in sorted(self.deps[pkg]):
            if dep in path:
                print >>sys.stderr, "ERROR: Circular dependency detected!"
                print >>sys.stderr, "ERROR: ",
                found = False
                for nm in path:
                    if nm == dep:
                        found = True
                    if not found:
                        continue
                    print >>sys.stderr, nm, "->",
                print >>sys.stderr, dep
                return
            if dep in reduced_pkg_deps:
                # Remove a package reachable by transitive closure.
                reduced_pkg_deps.remove(dep)
            path.append(dep)
            self.visit_for_transitive_reduction(dep, path, reduced_pkg_deps)
            path.pop()

    def scan_package_for_checkouts(self, pkg):
        """Scan a package looking for dependencies that are not checked
        out which have dependencies that are checked out."""
        #print >>sys.stderr, "DEBUG: Package:", pkg
        if not self.deps.has_key(pkg):
            # Note: This is not really an error, might be a new package.
            print >>sys.stderr, "INFO: Package not in base release:", pkg
            return
        path = [ pkg ]
        for dep in sorted(self.deps[pkg]):
            if self.local_pkgs.has_key(dep):
                # Already checked out, next.
                continue
            path.append(dep)
            saw_other_end = False
            saw_other_end = self.visit_for_checkout_test(dep, path, saw_other_end)
            #print >>sys.stderr, "DEBUG: saw_other_end:", saw_other_end
            if saw_other_end:
                self.handle_auto_checkout(dep)
            #print >>sys.stderr, "DEBUG: Popping:", path[-1]
            path.pop()

    def visit_for_checkout_test(self, pkg, path, saw_other_end):
        #print >>sys.stderr, "DEBUG: vist_for_checkout: Package:", pkg, "Path:", path
        if not self.deps.has_key(pkg):
            # Note: This is not really an error, might be a new package.
            print >>sys.stderr, "INFO: Package not in base release:", pkg
            return saw_other_end
        if self.local_pkgs.has_key(pkg):
            # Reached a checked out pkg, no need to scan further.
            #print >>sys.stderr, "DEBUG: Scan terminates at pkg:", pkg
            saw_other_end = True
            return saw_other_end
        for dep in sorted(self.deps[pkg]):
            # Check for circularity.
            if dep in path:
                print >>sys.stderr, "ERROR: Circular dependency detected!"
                print >>sys.stderr, "ERROR: ",
                found = False
                for nm in path:
                    if nm == dep:
                        found = True
                    if not found:
                        continue
                    print >>sys.stderr, nm, "->",
                print >>sys.stderr, dep
                return saw_other_end
            # Scan down the dependency graph.
            path.append(dep)
            saw_other_end = False
            saw_other_end = self.visit_for_checkout_test(dep, path, saw_other_end)
            #print >>sys.stderr, "DEBUG: saw_other_end:", saw_other_end
            if saw_other_end and (not self.local_pkgs.has_key(dep)):
                self.handle_auto_checkout(dep)
            #print >>sys.stderr, "DEBUG: Popping:", path[-1]
            path.pop()
        return saw_other_end

    def handle_auto_checkout(self, pkg):
        # Record that we have done this pkg, so that
        # we do not do it again.
        self.local_pkgs[pkg] = 1
        if not globals.opts.do_autocheckout:
            print >>sys.stderr, "INFO: Need to checkout package:", pkg
            return
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

    def scan_for_depends(self, dirname, level, pkgdepends):
        """Recursively scan a directory for dependency files."""
        indent = globals.indent * level
        #print >>sys.stderr, "DEBUG: %s%s" % (indent, dirname)
        os.chdir(dirname)
        tmp = os.listdir(".")
        tmp.sort()
        for nm in tmp:
            if os.path.isdir(nm):
                self.scan_for_depends(nm, level + 1, pkgdepends)
            if nm == "depend.make":
                self.collect_deps(os.path.abspath(nm), level + 1, pkgdepends)
        os.chdir("..")
        
    def collect_deps(self, filename, level, pkgdepends):
        """Collect dependency information from a dependency file."""
        indent = globals.indent * level
        #print >>sys.stderr, "DEBUG: %s%s" % (indent, filename)
        inf = open(filename, "r")
        line = inf.readline()
        while len(line):
            if "#" == line[0]:
                # Skip comment lines.
                line = inf.readline()
                continue
            if not globals.pat_mrb_source.search(line):
                # No MRB_SOURCE path in line.  Must be
                # an external product, skip it.
                line = inf.readline()
                continue
            # Get the package names out of the dependency line.
            res = globals.pat_pkg_names.match(line)
            if not res:
                # Hmm, this line should not be here.
                print >>sys.stderr, "ERROR: Match failed!"
                print >>sys.stderr, "ERROR:", line,
                line = inf.readline()
                continue
            if res.group(1) == res.group(2):
                # Ignore self-dependency.
                line = inf.readline()
                continue
            #print >>sys.stderr, "DEBUG: %s%s%s : %s" % \
            #     (indent, globals.indent, res.group(1), res.group(2))
            dep = res.group(2)
            if dep not in pkgdepends:
                pkgdepends.append(dep)
            line = inf.readline()
        inf.close()

if __name__ == "__main__":
    # We are being run as a script.
    system = SYSTEM()
    system.run()
else:
    # We are being loaded as a module.
    pass

