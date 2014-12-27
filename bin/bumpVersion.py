#!/bin/env python

# Update a product's version

import os
import sys
import string

from alterProductDeps import *

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


class BumpVersionPlugin(BasePlugin):
  def __init__(self, whichNumber, text, newQual ):
    BasePlugin.__init__(self)
    self.whichNumber = whichNumber
    self.text = text
    self.newQual = newQual

  def handleParent(self, line, words):
    newVersion = incrementVersion(words[2], self.whichNumber, self.text)
    print 'Updating product %s from version %s to %s' % \
            (words[1], words[2], newVersion)
    line = 'parent %s %s\n' % (words[1], newVersion)
    return line

  def handleDefaultqual(self, line, words):
    if self.newQual != '--none--':
      print 'Updating default qualifier from %s to %s' % (words[1], self.newQual)
      line = 'defaultqual %s\n' % (self.newQual)
    return line

  def handleQualifier(self, oldQual):
    if self.newQual != '--none--':
      return self.newQual
    else:
      return oldQual

if __name__ == '__main__':

  blah, pkg, pdfile, whichNumber, text, qual = sys.argv

  p = BumpVersionPlugin(whichNumber, text, newQual)
  out = alterProductDeps(pdfile, p)

  open(pdfile, 'w').write(out)
