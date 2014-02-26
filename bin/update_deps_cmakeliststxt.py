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

            if newVersion == version:
                print 'No update for %s %s' % (product, version)
            else:
                print 'For %s replacing version %s with %s' % (product,
                 version, newVersion)
                line = line.replace(version, newVersion)

        out += line

    return out

if __name__ == '__main__':

    f = sys.argv[1]

    out = update_CMakeListsTxt(f)
    open(f, 'w').write(out)
