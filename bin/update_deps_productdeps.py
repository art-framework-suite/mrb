#!/bin/env python

# Udpate products in a product_deps file with the versions and qualifiers
# that are currently set up

import os
import sys
import string
import sys

from alterProductDeps import *


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


class UpdateProductDepsPlugin(BasePlugin):
  def __init__(self):
    BasicPlugin.__init__(self)

  def handleInPV(self, line, words):
    product = words[0]
    version = words[1]

    newVersion = getNewVersion(product)

    if version != newVersion:
        print 'product_deps: For %s REPLACING version %s with %s' % (product,
            version, newVersion)
        out = line.replace(version, newVersion)
    else:
        print 'product_deps: No change for %s %s' % (product, version)
        out = line

    return out

  def handleOnlyForBuild(self, line, words):
    newVersion = getNewVersion(words[1])
    if words[2] != newVersion:
      print 'product_deps: For %s REPLACING version %s with %s' % (words[1],
                                                                   words[2], newVersion)
      return line.replace(words[2], newVersion)
    else:
      print 'product_deps: No change for %s %s' % (words[1], words[2])
      return line


if __name__ == '__main__':

  blah, pdfile, dryRun = sys.argv
  
  p = UpdateProductDepsPlugin()
  out = alterProductDeps(pdfile, p)
  
  if dryRun != "yes":
      open(pdfile, 'w').write(out)
