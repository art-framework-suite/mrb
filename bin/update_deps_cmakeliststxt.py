#!/bin/env python

# Update products in a CMakeLists.txt file with the versions that
# are currently set up

import re
import os
import sys

findUpsRe = re.compile("find_ups_(.+)\((.+)")


def update_CMakeListsTxt(f):
    out = ''
    # Read lines of the file
    for line in open(f):
        sline = line.strip()
        if sline == "":
            out += line
            continue

        if sline[0] == "#":
            out += line
            continue

        r = findUpsRe.match(sline)
        if r:
            kind = r.groups()[0]
            rest = r.groups()[1].replace(")", '').strip()

            restParts = rest.split()

            if kind == 'product':
                product = restParts[0]
                version = restParts[1]

            else:
                product = kind
                version = restParts[0]

            # Find the setup version
            varName = "%s_VERSION" % product.upper()
            newVersion = os.environ[varName]
            
            # March through the new version string and stop copying at anything strange
            # Look for at most two _ and start with v
            newVersionString = newVersion[0]
            nUnderscores = 0
            for i in range(len(newVersion)):
              if i == 0: continue
              if newVersion[i] == '_':
                nUnderscores += 1
                if nUnderscores > 2: break
              else:
                if not newVersion[i].isdigit(): break
              newVersionString += newVersion[i]

            if newVersion == version:
                print 'CMakeLists.txt: No change for %s %s' % (product, version)
            else:
                print 'CMakeLists.txt: For %s REPLACING version %s with %s (full was %s)' % (product,
                 version, newVersionString, newVersion)
                line = line.replace(version, newVersionString)

        out += line

    return out

if __name__ == '__main__':

    blah, f, dryRun = sys.argv

    out = update_CMakeListsTxt(f)

    if not dryRun == "yes":
        open(f, 'w').write(out)
