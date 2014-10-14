#!/bin/env python

# Update a product's version

import os
import sys
import string

def incrementVersion(old, whichNumber, text):

    words = old[1:].split("_")

    oldText = '--none--'
    if len(words) > 3:
        oldText = words[3]
    
    numbers = [ int(x) for x in words[:3] ]

    if whichNumber == "--last--":
        numbers[2] += 1
    elif whichNumber == "--middle--":
        numbers[1] += 1
        numbers[2] = 0
    elif whichNumber == "--first--":
        numbers[0] += 1
        numbers[1] = 0
        numbers[2] = 0

    # Put this back together
    newVersion = 'v{}_{:=02}_{:=02}'.format(numbers[0], numbers[1], numbers[2])

    # Add text if necessary
    if text != '--none--' and text != '--blank--':
        newVersion = newVersion + "_" + text
    elif oldText != '--none--' and text != '--blank--':
        newVersion = newVersion + "_" + oldText
    
    return newVersion
      

def bumpVersion(pkg, pdfile, whichNumber, text, newQual):
    out = ''

    inPV = False
    inPQ = False
    quals = []
    oldQual = ""
    products = []
    sepspace = 8

    # Read the lines of the file
    for line in open(pdfile):

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
            newVersion = incrementVersion(words[2], whichNumber, text)
            print 'Updating product %s from version %s to %s' % \
                (words[1], words[2], newVersion)
            line = 'parent %s %s\n' % (words[1], newVersion)
            out += line

        # Look for defaultqual
        elif words[0] == 'defaultqual':
            oldQual = words[1]
            if newQual != '--none--':
                print 'Updating default qualifier from %s to %s' % (words[1], newQual)
                line = 'defaultqual %s\n' % (newQual)
            out += line

        # Look for the product version table
        elif words[0] == 'product' and words[1] == 'version':
            inPV = True
            out += line

        # Look for only_for_build
        elif words[0] == 'only_for_build':
            out += line

        # Look for the qualifier table
        elif words[0] == 'qualifier':
            inPQ = True

            # Get the list of products
            products = words

            # Determine the qualifiers
            for aProduct in products:
                if aProduct == 'qualifier':
                    if newQual != '--none--':
                        quals.append(newQual)
                    else:
                        quals.append(oldQual)
                    continue
                if aProduct == 'notes':
                    continue

                # Try _FQ_DIR
                fq = os.environ.get("%s_FQ_DIR" % aProduct.upper())
                if fq:
                    fq = fq.split('/')[-1]
                else:
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

            print 'Products: ' + string.join(products, ', ')
            print 'New Qual: ' + string.join(quals, ', ')

            out += string.join(products, ' ' * sepspace) + '\n'

        else:
            out += line

    return out


if __name__ == '__main__':

    blah, pkg, pdfile, whichNumber, text, qual = sys.argv

    out = bumpVersion(pkg, pdfile, whichNumber, text, qual)
    open(pdfile, 'w').write(out)
