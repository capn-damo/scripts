#!/usr/bin/env python3
# -*- coding: utf-8 -*-
##
## bl-feed.py

import sys,os
import argparse
import requests
import textwrap

import argparse

try:
    from lxml import etree
except ImportError:
    import xml.etree.ElementTree as etree

bullet = '»'

""" get command args """
#color_basic  = sys.argv[1]
#color_alert = sys.argv[2]
#lines = sys.argv[3]
#wrapping = sys.argv[4]

#if len(sys.argv) < 6:
    #linelength = ''
#else:
    #linelength = sys.argv[5]

""" set forum atom data """
user = ''
pwd = ''
auth=(user,pwd)
url = 'https://forums.bunsenlabs.org/extern.php?action=feed&type=atom'

""" initialise lists """
listID_users=[]
listID_mods=[]
listIDS = []
listPOSTS = []
listENTRIES = []

##### Functions ##############

def cmd_args():

    ap = argparse.ArgumentParser()

    ap.add_argument('-col1',required=True)
    ap.add_argument('-col2',required=True)
    ap.add_argument('-lines',type=int,required=False)
    ap.add_argument('-wrap',default=False,required=False)
    ap.add_argument('-linelength',type=int,required=False)
    ap.add_argument('-bullet',required=False)

    return ap.parse_args()

def parse_feed(r,arr):
    """ Extract post title and post id from atom feed """
    root = etree.fromstring(r.text)
    end=len(root)

    for i in range (6,end):
        title = root[i][0].text
        postid = root[i][5].text
        arr.append(postid)

def load_listMODS(diffs):
    """ Find moderator-only posts, and set conky colors accordingly """
    root = etree.fromstring(f_all.text)
    end = len(listID_mods)
    i = 6
    for n in range(end):
        listENTRIES = []
        color = color_basic
        linestart = bullet+' '
        title = root[i][0].text
        postid = root[i][5].text
        id_number = str(postid)

        id_nums = set(diffs)
        if id_number in id_nums:
            linestart = '${'+color_alert+'}'+bullet+' ${'+color_basic+'}'

        listENTRIES = [title,postid,id_number,linestart]
        listPOSTS.append(listENTRIES)

        i += 1

def format_output(arr):
    """ Format the output for conky """
    outputPOSTS = arr
    n = 1
    for x in outputPOSTS:
        if n > lines:
            break
        if wrapping == 'wrap':
            print (textwrap.fill(x[3]+x[0],linelength))
        else:
            print(x[3]+x[0])
        n += 1

###### end functions ############

args = cmd_args()


color_basic  = args.col1
color_alert = args.col2
lines = args.lines
wrapping = args.wrap
linelength = args.linelength
bullet = args.bullet



f_all = requests.get(url, auth=auth)    # atom feed including moderator-only posts
f_users = requests.get(url)             # atom feed for general users

parse_feed(f_users,listID_users)
parse_feed(f_all,listID_mods)

s = set(listID_users)                               # Collect moderator-only post ids
listDIFF = [x for x in listID_mods if x not in s]

for diff in listDIFF:
    id_num = str(diff)
    listIDS.append(id_num)

load_listMODS(listIDS)

format_output(listPOSTS)

