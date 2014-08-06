#!/bin/env python

# Udpate products in a product_deps file with the versions and qualifiers
# that are currently set up

import os
import sys
import string
import sys


def getNewVersion(product):
    # Handle git specially
    if product == 'git':
        newVersion = os.environ['GIT_UPS_DIR'].split('/')[-2]
    else:
        # Other products
            newVersion = os.environ.get("%s_VERSION" % product.upper())
            if not newVersion:
                pdir=os.environ.get("%s_DIR" % product.upper())
                if not pdir:
                    print "******ERROR: Product %s is not set up -- Aborting" % product
                    sys.exit(1)
                words = pdir.split("/")
                newVersion = words[-1]
                if newVersion[0] != "v":
                    newVersion = words[-2]

    return newVersion


def updateProductDeps(f):
    out = ''

    inPV = False
    inPQ = False
    quals = []
    oldQual = ""
    products = []
    sepspace = 8

    # Read the lines of the file
    for line in open(f):

        sline = line.strip()

        if sline == "":
            if inPV:  # Blank line ends product version table
                inPV = False
            if inPQ:
                inPQ = False
            out += line
            continue

        if sline[0] == "#":
            out += line
            continue

        # Split line into words
        words = sline.split()

        # Are we in the product version table?
        if inPV:
            product = words[0]
            version = words[1]

            newVersion = getNewVersion(product)

            if version != newVersion:
                print 'product_deps: For %s REPLACING version %s with %s' % (product,
                    version, newVersion)
                out += line.replace(version, newVersion)
            else:
                print 'product_deps: No change for %s %s' % (product, version)
                out += line

            continue

        if inPQ:
            # Find the mode (debug, prof, opt)
            if words[0] == '-nq-':
                mode = ''
            else:
                mode = words[0].split(':')[1]

            # Write out the qualifiers, adding appropriate spaces
            for i in range(len(products)):
                if products[i] == 'notes':
                    if len(words) > i:
                        out += words[-1]
                    continue

                newText = quals[i]
                if quals[i] != '-nq-':
                    newText += ":" + mode
                out += newText
                spaces = max(len(products[i]) - len(newText), 0) + \
                    sepspace - max(0, len(newText) - len(products[i]))
                out += ' ' * spaces
            out += '\n'
            continue

        # Look for the parent line
        if words[0] == "parent":
            out += line

        # Look for defaultqual
        elif words[0] == 'defaultqual':
            oldQual = words[1]
            out += line

        # Look for the product version table
        elif words[0] == 'product' and words[1] == 'version':
            inPV = True
            out += line

        # Look for only_for_build
        elif words[0] == 'only_for_build':
            newVersion = getNewVersion(words[1])
            if words[2] != newVersion:
                print 'product_deps: For %s REPLACING version %s with %s' % (words[1],
                    words[2], newVersion)
                out += line.replace(words[2], newVersion)
            else:
                print 'product_deps: No change for %s %s' % (words[1], words[2])
                out += line

        # Look for the qualifier table
        elif words[0] == 'qualifier':
            inPQ = True

            # Get the list of porducts
            products = words

            # Determine the qualifiers
            for aProduct in products:
                if aProduct == 'qualifier':
                    quals.append(oldQual)
                    continue
                if aProduct == 'notes':
                    continue

                # Try _FQ_DIR
                fq = os.environ.get("%s_FQ_DIR" % aProduct.upper())
                if fq:
                    fq = fq.split('/')[-1]
                else:
                    fq = os.environ.get("%s_FQ" % aProduct.upper())
                    if not fq:
                        quals.append('-nq-')
                        continue

                # We have FQ, try to break it up
                parts = fq.split('.')
                if not parts[-1] in ('debug', 'prof', 'opt'):
                    parts = fq.split("-")

                if parts[-1] in ('debug', 'prof', 'opt'):
                    prodQual = parts[-2]
                else:
                    prodQual = parts[-1]

                quals.append(prodQual)

            print 'product_deps: Products- ' + string.join(products, ', ')
            print 'product_deps: New Qual- ' + string.join(quals, ', ')

            out += string.join(products, ' ' * sepspace) + '\n'

        else:
            out += line

    return out


if __name__ == '__main__':

    blah, pdfile, dryRun = sys.argv
    out = updateProductDeps(pdfile)
    if dryRun != "yes":
        open(pdfile, 'w').write(out)
