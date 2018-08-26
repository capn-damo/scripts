#!/usr/bin/env python3
# -*- coding: utf-8 -*-
##
## BL-atomfeed.py: script to be used by conky to display the latest posts from the Bunsenlabs Forums
#
#    Copyright (C) 2018 damo    <damo@bunsenlabs.org>
#
#    This program is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program.  If not, see <http://www.gnu.org/licenses/>.

"""
BL-atomfeed.py  --help

usage: bl-feed.py [-h] [-col1 COL1] [-col2 COL2] [-lines LINES] [-wrap WRAP]
                  [-bullet BULLET]

optional arguments:
  -h, --help      show this help message and exit
  -col1 COL1      General text color, if bullet is colored. Colors can be
                  literal, eg:red; Hex format, eg #123456 (in which case use
                  quotes); or conky variable eg: color1
  -col2 COL2      Bullet highlight color. Color format as above
  -lines LINES    Number of lines to display (max=15). eg: lines 10
  -wrap WRAP      Wrap lines at this column width, breaking on spaces if
                  possible. Eg: -wrap 40
  -bullet BULLET  Char(s) to use at start of each line
------------------------------------------------------------------------
Example usage in conky.text:

    ${execpi 360 .config/conky/scripts/BL-atomfeed.py -col1 color0 -col2 red -bullet » -wrap 40 -lines 10}
    
------------------------------------------------------------------------
"""

import sys,os,argparse,requests,textwrap

try:
    from lxml import etree
except ImportError:
    import xml.etree.ElementTree as etree

# set forum atom data
url = 'https://forums.bunsenlabs.org/extern.php?action=feed&type=atom'

# initialise lists
listPOSTS = []
listENTRIES = []
listDATA = []

##### Functions ##############

def cmd_args():
    """ parse command args """
    ap = argparse.ArgumentParser()
    
    ap.add_argument('-col1',required=False,help='General text color, if bullet is colored. \
    Colors can be literal, eg:red; Hex format, eg #123456 (in which case use quotes); \
    or conky variable eg: color1')
    ap.add_argument('-col2',required=False,help='Bullet highlight color. Color format as above')
    ap.add_argument('-lines',type=int,required=False,help='Number of lines to display (max=15). \
    eg: lines 10')
    ap.add_argument('-wrap',type=int,required=False,help='Wrap lines at this column width, \
    breaking on spaces if possible. Eg: -wrap 40')
    ap.add_argument('-bullet',required=False,help='Char(s) to use at start of each line')

    return ap.parse_args()

def parse_feed(r,arr):
    """ Extract post titles from atomfeed """
    root = etree.fromstring(r.text)
    end=len(root)

    for i in range (6,end):
        title = root[i][0].text
        arr.append(title)
        

def load_listDATA(posts):
    """ format each line, and add to list """
    root = etree.fromstring(feed.text)
    end = len(posts)
    i = 6
    for n in range(end):
        listENTRIES = []
        
        title = root[i][0].text
        if bullet != None:
            if color_basic == None or color_alert == None:
                linestart = bullet
            else:
                if color_basic != color_alert:
                    linestart = '${'+color_alert+'}'+bullet+'${'+color_basic+'}'
                else:
                    linestart = bullet
        else:
            linestart = None

        listENTRIES = [linestart,title]
        listDATA.append(listENTRIES)

        i += 1

def arrange_output(arr):
    """ Format the output for conky """
    outputPOSTS = arr
    n = 0
    for x in arr:
        if n >= lines:
            break
        if x[0] != None:
            if wrapping == 'wrap':
                print (textwrap.fill(x[0]+' '+x[1],width))
            else:
                print(x[0],x[1])
        else:
            if wrapping == 'wrap':
                print (textwrap.fill(x[1],width))
            else:
                print(x[1])
                
        n += 1

def format_color(col):
    """ format color strings, depending whether literal or hex color, or conky variable """
    if 'color' not in col:
        col = 'color='+col
    else:
        col = col
    return col
    
###### end functions ############

### script parameters ###
args = cmd_args()         # get commandline args, and set output vars

if args.col1:
    color_basic  = format_color(args.col1)  # text color
else:
    color_basic = None
if args.col2:
    color_alert = format_color(args.col2)   # bullet char(s) color
else:
    color_alert = None

if args.lines is None:
    lines = 15          # max titles provided by atomfeed
else:
    lines = args.lines  # num titles required by user
    
if args.wrap is None or args.wrap == 0: # no wrapping
    wrapping = None
    width = 0
else:
    wrapping = 'wrap'       # wrapping width
    width = args.wrap

bullet = args.bullet        # bulletpoint or char(s) to start each line
### end script parameters ###

feed = requests.get(url)             # get atomfeed

parse_feed(feed,listPOSTS)
load_listDATA(listPOSTS)
arrange_output(listDATA)
