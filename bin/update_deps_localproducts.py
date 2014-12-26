#!/bin/env python

import sys, os
import subprocess


def whatIsInLocalProducts(prodArea):

  # Detrmine our flavor - special if Darwin
  flavorArg = ''
  if subprocess.check_output('uname') == 'Darwin\n':
    flavorArg = '-2'
  
  myFlavor = subprocess.check_output('ups flavor %s' % flavorArg, shell=True)
  myFlavor = myFlavor.strip()

  print '== My Flavbor is %s' % myFlavor

  # Get list of products
  allProducts = subprocess.check_output('ups list -z %s -f %s -aK product:version' % (prodArea, myFlavor), shell=True)

  # Make dictionary of products
  products = {}
  for aProduct in allProducts.split("\n"):
    if aProduct == '': continue
    aProduct = aProduct.strip()
    aProduct = aProduct.replace('"', '')
    words = aProduct.split(' ')
    products[ words[0] ] = words[1]

  return products

def whatIsInSrcs():

  cmd = "grep '^ADD' %s/.cmake_add_subdir | cut -d'(' -f 2 | cut -d')' -f 1" % os.environ['MRB_SOURCE']
  allSrcs = subprocess.check_output(cmd, shell=True)

  srcs = []
  for src in allSrcs.split("\n"):
    if src == '': continue
    src = src.strip()
    srcs.append(src)

  return srcs

def updateProductDeps(src, localProducts):

  # We need to open the product_deps file
  pdFile = os.environ['MRB_SOURCE']+'/'+src+"/ups/product_deps"
  subprocess.call('cp %s %s.bak' % (pdFile, pdFile), shell=True)

  # Construct the replacement clauses for awk
  awkCom = "'{ "
  for prod,ver in localProducts.items() :
    awkCom += 'sub(/^%s.+/,"%s            %s"); ' % (prod, prod, ver)
  awkCom += " print }'"
  com = 'awk %s %s > /tmp/awkout' % (awkCom, pdFile)

  subprocess.call(com, shell=True)
  subprocess.call("mv /tmp/awkout %s" % pdFile, shell=True)


if __name__ == '__main__':
  
  blah, prodArea = sys.argv

  print '== Will update for products found in %s' % prodArea
  
  # figure out what is in localproducts
  localProducts = whatIsInLocalProducts(prodArea)
  
  print localProducts.items()

  # figure out the sources
  srcs = whatIsInSrcs()
  
  print '== 'Updating these sources'
  print srcs
  
  # For each src
  for src in srcs:
    updateProductDeps(src, localProducts)

