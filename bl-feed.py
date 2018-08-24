#!/usr/bin/env python2.7
# -*- coding: utf-8 -*-
##
## bl-feed.py

import sys,os
import datetime
import subprocess
import argparse

try:
    from lxml import etree
except ImportError:
    import xml.etree.ElementTree as etree

bl_fpath1 = os.environ["HOME"] + "/tmp/feed.txt"
bl_fpath2 = os.environ["HOME"] + "/tmp/feed-all.txt"

arrID_users=[]
arrID_mods=[]

listPOSTS = []
arrENTRIES = []

##### Functions ##############

def parse_feed(bl_fpath,arr):
    tree = etree.parse(bl_fpath)
    root = tree.getroot()
    end=len(root)

    for i in range (6,end):
        title = root[i][0].text
        postid = root[i][5].text
        arr.append(postid)

        id_number = int(filter(str.isdigit, postid))
        id_number = str(id_number)

        i += 1

def load_listMODS(diffs):
    tree = etree.parse(bl_fpath2)
    root = tree.getroot()
    end = len(arrID_mods)
    i = 6
    for n in range(end):
        arrENTRIES = []
        color = 'color'
        title = root[i][0].text
        postid = root[i][5].text
        id_number = int(filter(str.isdigit, postid))

        id_nums = set(diffs)
        if id_number in id_nums:
            color = 'red'

        arrENTRIES = [title,postid,id_number,color]

        i += 1

        listPOSTS.append(arrENTRIES)

###### end functions ############

parse_feed(bl_fpath1,arrID_users)
parse_feed(bl_fpath2,arrID_mods)

#print(len(arrID_users),': ', len(arrID_mods))

s = set(arrID_users)
arrDIFF = [x for x in arrID_mods if x not in s]

arrIDS = []
for diff in arrDIFF:
    id_num = int(filter(str.isdigit, diff))
    arrIDS.append(id_num)

load_listMODS(arrIDS)

print listPOSTS

