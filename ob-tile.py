#!/usr/bin/env python3.5
# -*- coding: utf-8 -*-


import gi, os, re, tempfile, pickle
gi.require_version('Gdk', '3.0')
gi.require_version('Gtk', '3.0')
gi.require_version('Wnck', '3.0')
from gi.repository import  Gtk, Wnck
from screeninfo import get_monitors


screen = Wnck.Screen.get_default()
screen.force_update()
w = screen.get_width()
h = screen.get_height()


def dict_load_KBINDS():
    """ Dictionaries to hold keybinds previously set in rc.xml """
    GRID = {'TL':'super+alt+7','TR':'super+alt+9','BR':'super+alt+3','BL':'super+alt+1','C':'super+alt+5'}    # TL,TR,BR,BL,center
    VERT = {'L':'super+alt+4','R':'super+alt+6'}                                                              # Left half,Right half
    HORIZ = {'T':'super+alt+8','B':'super+alt+2'}                                                             # Top half, Bottom half
    VERT_3 = {'LV':'ctrl+super+alt+4','MV':'ctrl+super+alt+5','RV':'ctrl+super+alt+6','C':'super+alt+5'}      # L,M,R vert,center
    HORIZ_3 = {'LH':'ctrl+super+alt+1','MH':'ctrl+super+alt+2','RH':'ctrl+super+alt+3','C':'super+alt+5'}     # L,M,R horiz,center

    KB = (GRID,VERT,HORIZ,VERT_3,HORIZ_3)   # tuple with all keybinds

    return KB

def set_filepaths():
    f_TMP_WIN_LIST = tempfile.NamedTemporaryFile(mode='w+b',prefix='tmp')   # stores window ID's
    f_TMP_WIN_DIMS = os.environ['HOME'] + 'temp-windims.tmp'           # stores geometry for restoring windows
    f_STORE_ARG = os.environ['HOME'] + 'ob_tiling.tmp'
    f_STORE_WIN_CMDS = os.environ['HOME'] + 'win_ids.tmp'

def get_desktop_geometry():

    workspaces = screen.get_workspaces()

    desktop = Wnck.Screen.get_active_workspace(screen)
    print('ActiveDesktop: ', desktop)
    win_list = screen.get_windows()

    mon_LIST=[]
    #mon_LIST.sort(key=int)

    #for m in mon_LIST:
        #print(m)

    for m in get_monitors():
        edge = re.findall('\+([^]]*)\+',str(m))
        if int(edge[0]) > 0:
            screen_edge = edge[0]
            mon_LIST.append(edge[0])
        print('m= ',str(m))
    print ('Number of Monitors= ', str(len(mon_LIST)+1))
    print('Right Monitor starts at ', str(screen_edge))

    return float(screen_edge)

def get_open_windows():
    win_LIST = []
    win_LIST_xid=[]
    win_list = screen.get_windows()
    win_active = screen.get_active_window()

    for win in win_list:
        if win.is_on_workspace(screen.get_active_workspace()):
            if win.get_class_group_name() != 'Tint2' and win.get_class_group_name() != 'conky':
                win_LIST.append(win)
                win_LIST_xid.append( win.get_xid())

        geom=[]
    for win in win_LIST:
        geom.append(win.get_geometry())
    print(geom)

    return win_LIST,geom



def is_on_workspace(win):
    if win.get_pid() == os.getpid():
        return win.get_workspace() == screen.get_active_workspace()

def write_f_pickle(fname,argsLIST):
    with open(fname,'wb') as f:
        pickle.dump(argsLIST,f)
    f.close()

def read_f_pickle(fname):
    f = open(fname,'rb')
    data = pickle.load(f)
    return data
    f.close()
    os.remove(f)

def get_win_geometry():
    geom=[]
    windows,wingeom = get_open_windows()

    for win in windows:
        geom.append(win.get_geometry())

    #for g in geom:
        #print('Window geometry: ',g[0], g[1], g[2], g[3])

    return geom

def get_monitor_pos():
    edge = get_desktop_geometry()
    windows = get_win_geometry()
    for w in windows:
        win_centre = (w[0] + (w[2]/2))
        print('screen edge= ',edge,' Centre= ',win_centre)
        if win_centre > edge:
            monitor = 2
        else:
            monitor = 1

        print('Window geometry: ',w[0], w[1], w[2], w[3],' on Monitor ',monitor)


    # see if window is mainly on left or right monitor
    # is half-width > edge?

if __name__ == "__main__":

    #print('edge= ',get_desktop_geometry())
    #windows,wingeom = get_open_windows()

    #win_data = []
    #i = 0
    #while i < len(windows):
        #g = wingeom[i]
        #print('Win= ',windows[i].get_name(),g[0], g[1], g[2], g[3])
        #win_data.append([windows[i],windows[i].get_name(),g[0], g[1], g[2], g[3]])
        #i += 1

    #fpath = os.path.expanduser('~/tmp')
    #fname = os.path.join(fpath,'windata.txt')
    #write_f_pickle(fname,win_data)

    #print('------------')
    #if os.path.exists(fname):
        #dataLIST = read_f_pickle(fname)
        #for item in dataLIST:
            #print(item[2])
    #else:
        #print('no file found')

    #if os.path.exists(fname):
        #print('file exists')
    #else:
        #print('file has gone')

    #grid,vert,horiz,vert3,horiz3 = dict_load_KBINDS()
    #print('grid: ',grid.keys())
    #print(grid['TL'],vert['L'])

    get_monitor_pos()
