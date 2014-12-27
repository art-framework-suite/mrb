# A python module to alter the product_deps file.
# Consolidates the functions of bumpVersion and update_deps_productdeps. Avoids cutting and pasting.

# Plugin is a class that has methods that are run at certain times as seen below

import os, sys, string

class BasePlugin:
  def __init__(self):
    pass
  
  def handleInPV(self, line, words):
    return line

  def handleInPQ(self, line, words, products, quals):
    out = ''
    
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
      if quals[i] == 'UNKNOWN':
        # Just use what we had before
        newText = words[i]
      else:
        newText += ":" + mode
      out += newText
      spaces = max(len(products[i]) - len(newText), 0) + \
        sepspace - max(0, len(newText) - len(products[i]))
      out += ' ' * spaces

    out += '\n'
    return out

  def handleParent(self, line, words):
    return line

  def handleDefaultqual(self, line, words):
    return line

  def handleOnlyForBuild(self, line, words):
    return line

  def handleQualifier(self, oldQual):
    return oldQual


def alterProductDeps(f, Plugin):
  
  # The output data
  out = ''

  inPV = False  # In product depedency versions
  inPQ = False  # In product dependency qualifiers
  quals = []    # List of qualifiers
  oldQual = ""  # The old qualifier
  products = []  # List of products
  sepspace = 8   # Spaces for the qualifier table

  # Read the lines of the file
  for line in open(f):

    sline = line.strip()

    if sline == '':
      out += line
      continue

    if sline == "end_product_list" or sline == "end_qualifier_list":
      if inPV:
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
      out += Plugin.handleInPV(line, words)
      continue

    # Are we in qualifier table?
    if inPQ:
      out += Plugin.handleInPQ(line, words, products, quals)
      continue

    # Look for the parent line
    if words[0] == "parent":
      out += Plugin.handleParent(line, words)

    # Look for defaultqual
    elif words[0] == 'defaultqual':
      oldQual = words[1]
      out += Plugin.handleDefaultqual(line, words)

    # Look for the product version table
    elif words[0] == 'product' and words[1] == 'version':
      inPV = True
      out += line

    # Look for only_for_build
    elif words[0] == 'only_for_build':
      out += Plugin.handleOnlyForBuild(line, words)

    # Look for the qualifier table
    elif words[0] == 'qualifier':
      inPQ = True

      # Get the list of products
      products = words

      # Determine the qualifiers
      for aProduct in products:
        
        if aProduct == 'qualifier':
          quals.append( Plugin.handleQualifier(oldQual) )
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
            # We can't find a fully qualified name, mark as unknown
            quals.append('UNKNOWN')
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
