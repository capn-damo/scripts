#!/usr/bin/env python3
# -*- coding: utf-8 -*-

## apt-get install pip3 gir1.2-wnck-3.0
## pip3 install:   pynput screeninfo

import gi, os, sys, re, tempfile, pickle
gi.require_version('Gdk', '3.0')
gi.require_version('Gtk', '3.0')
gi.require_version('Wnck', '3.0')
from gi.repository import  Wnck
from screeninfo import get_monitors

USAGE=('    ob-tile.py [arg]\n\n'+
    '   -G |--grid      Tile up to 4 quartered windows; a fifth window will be centered;\
                    Any others will be left alone.\n\n'+
    '   -V |--vert      Tile up to 3 windows side by side; a 4th window will be centered;\n\
                    Any others will be left alone.\n\n'+
    '   -H |--horiz     Tile up to 3 windows above and below; a 4th window will be centered;\n\
                    Any others will be left alone.\n\n'+
    '   -M | --max      Toggle maximize all windows on desktop.\n\n'+
    '       *           This USAGE.\n\n'+
    '   With no script arguments the windows will be grid tiled, and original positions are not stored.'
)


def cmd_args():
    print('Num args= ',len(sys.argv))
    if len(sys.argv) == 1:
        return 0
    else:
        arg = sys.argv[1]
        tiling = {
                '-G':0,
                '--grid':0,
                '-V':1,
                '--vert':1,
                '-H':2,
                '--horiz':2,
                '-V3':3,
                '--vert3':3,
                '-H3':4,
                '--horiz3':4,
                }
        return tiling.get(arg,'ERROR')

def dict_load_KBINDS():
    """ Dictionaries to hold keybinds previously set in rc.xml """
    GRID = {'TL':'super+alt+7','TR':'super+alt+9','BR':'super+alt+3','BL':'super+alt+1','C':'super+alt+5'}    # TL,TR,BR,BL,center
    VERT = {'L':'super+alt+4','R':'super+alt+6'}                                                              # Left half,Right half
    HORIZ = {'T':'super+alt+8','B':'super+alt+2'}                                                             # Top half, Bottom half
    VERT_3 = {'LV':'ctrl+super+alt+4','MV':'ctrl+super+alt+5','RV':'ctrl+super+alt+6','C':'super+alt+5'}      # L,M,R vert,center
    HORIZ_3 = {'LH':'ctrl+super+alt+1','MH':'ctrl+super+alt+2','RH':'ctrl+super+alt+3','C':'super+alt+5'}     # L,M,R horiz,center

    KB = (GRID,VERT,HORIZ,VERT_3,HORIZ_3)   # tuple with all keybinds

    return KB

def set_filepaths(arg):
    # f_TMP_WIN_LIST = tempfile.NamedTemporaryFile(mode='w+b',prefix='tmp')   # stores window ID's
    # f_TMP_WIN_DIMS = os.environ['HOME'] + '/temp-windims.tmp'           # stores geometry for restoring windows
    # f_STORE_ARG = os.environ['HOME'] + '/ob_tiling.tmp'
    # f_STORE_WIN_CMDS = os.environ['HOME'] + '/win_ids.tmp'
    #return f_TMP_WIN_DIMS

    file_case = {
                'store':os.environ['HOME'] + '/temp-windims.tmp',
                'args':os.environ['HOME'] + '/ob_tiling.tmp',
                'commands':os.environ['HOME'] + '/win_ids.tmp',
                }
    return file_case.get(arg,'Error')


def get_desktop_geometry():

    workspaces = screen.get_workspaces()

    desktop = Wnck.Screen.get_active_workspace(screen)
    #print('ActiveDesktop: ', desktop)
    window_list = screen.get_windows()

    #print(get_monitors())
    mon_LIST=[]
    for m in get_monitors():
        edge_left = re.findall('\+([^]]*)\+',str(m))
        #print('edge_left= ',edge_left)
        if int(edge_left[0]) == 0:
            screen_edge = 0
        else:
            screen_edge = edge_left[0]
        mon_LIST.append(int(screen_edge))

        #print('m= ',str(m))
        monitors = len(mon_LIST)
    #print ('Number of Monitors= ', str(monitors))
    #print('Right Monitor starts at ', str(screen_edge))
    mon_LIST.sort(key=int)
    #print('mon_LIST',mon_LIST)
    return int(monitors),mon_LIST

def get_open_windows():
    win_LIST = []
    win_LIST_xid=[]
    window_list = screen.get_windows()

    for win in window_list:
        if win.is_on_workspace(screen.get_active_workspace()):
            if win.get_class_group_name() != 'Tint2' and win.get_class_group_name() != 'conky':
                win_LIST.append(win)
                win_LIST_xid.append( win.get_xid())

    WINDOWS = []
    i = 0
    for w in win_LIST:
        geom = w.get_geometry()
        # get monitor the window is on
        MONITOR, MONITOR_FOCUS = get_monitor_pos(geom)
        #print('Monitor= ',MONITOR,' MONITOR_FOCUS= ',MONITOR_FOCUS,'\n-----------')
        # only store windows on monitor that has the mouse
        if MONITOR_FOCUS == MONITOR:
            WINDOW = {
                    'id':win_LIST_xid[i],
                    'xp':geom[0],
                    'yp':geom[1],
                    'widthp':geom[2],
                    'heightp':geom[3]
                    }
            WINDOWS.append(WINDOW)
        i += 1

    return(WINDOWS)

def get_monitor_pos(w):
    #print('monitors:',monitors,';Window: ',w)
    monitor = 1
    if monitors > 1:
        # see if window is mainly on left or right monitor
        # Openbox uses 33%?
        win_right = (w[0]+w[2])
        win_left = w[0]
        win_width = w[2]
        overlap = ((screen_edge[1] - win_left)/win_width)*100
        #print('screen edge_left=',screen_edge[0],';right edge_left=',screen_edge[1],';win_left=',w[0],';win_width=',w[2])

        if win_left >= screen_edge[1]:
            monitor = 2
        if win_left < screen_edge[1] and win_right > screen_edge[1]:
            #print('overlapping:',overlap,'%')
            if overlap < 33:
                monitor = 2
            else:
                monitor = 1
    else:
        monitor = 1

    active_monitor = get_mouse_on_monitor()
    if active_monitor < screen_edge[1]:
        active_monitor = 1
    else:
        active_monitor = 2
    #print('edge_left ',screen_edge,'active_monitor ',active_monitor)

    return monitor, active_monitor

def is_on_workspace(win):
    if win.get_pid() == os.getpid():
        return win.get_workspace() == screen.get_active_workspace()

def write_f_pickle(fname,argsLIST):
    with open(fname,'wb') as f:
        pickle.dump(argsLIST,f)
    f.close()

def write_data(fname,data):
    f = open(fname,'w')
    f.write(str(data))
    f.close


def read_f_pickle(fname):
    f = open(fname,'rb')
    data = pickle.load(f)
    f.close()
    #os.remove(f)
    return data

def read_data(fname):
    f = open(fname,'r')
    data = f.read()
    f.close()
    return data

# def get_win_geometry():
    # geom=[]
    # windows,wingeom = get_open_windows()

    # for win in windows:
        # geom.append(win.get_geometry())

    # for g in geom:
        # print('Window geometry: ',g[0], g[1], g[2], g[3])

    # return geom


def get_mouse_on_monitor():
    # xdotool getmouselocation
    from pynput.mouse import Controller
    mouse = Controller()
    #print('Mouse x position= ',mouse.position[0])

    return mouse.position[0]

def store_window_data(fname):
    """ get window positions on monitor(s), and write to file """
    windows,wingeom = get_open_windows()
    print('File= ',fname)
    win_data = []
    i = 0
    while i < len(windows):
        g = wingeom[i]
        print('Win= ',windows[i].get_name(),g[0], g[1], g[2], g[3])
        win_data.append([str(windows[i]),str(windows[i].get_name()),g[0], g[1], g[2], g[3]])
        i += 1
    #print(win_data)
    write_f_pickle(fname,win_data)

def get_window_data(fname):
    if os.path.exists(fname):
        dataLIST = read_f_pickle(fname)
        print(dataLIST)
    else:
        print('no file found')

def load_monitor_dicts():
    monitors, monitor_edge = get_desktop_geometry()

if __name__ == "__main__":

    screen = Wnck.Screen.get_default()
    screen.force_update()
    w = screen.get_width()
    h = screen.get_height()
    monitors,screen_edge = get_desktop_geometry()

    open_windows = get_open_windows()

#---------------------------------------

    # command = cmd_args()
    # if command == 'ERROR':
        # print(USAGE)
        # sys.exit()
    # else:
        # print('Command= ',command)
        # keybinds = dict_load_KBINDS()
        # print(keybinds[command])        # use list index from cmd_args

    # #print('edge_left= ',get_desktop_geometry())
    # # windows,wingeom = get_open_windows()

    # # win_data = []
    # # i = 0
    # # while i < len(windows):
        # # g = wingeom[i]
        # # print('Win= ',windows[i].get_name(),g[0], g[1], g[2], g[3])
        # # win_data.append([str(windows[i]),str(windows[i].get_name()),g[0], g[1], g[2], g[3]])
        # # i += 1
    # #print(win_data)
    # #fname = set_filepaths()

    # # fname = set_filepaths('store')      # options are 'store','args','commands'
    # # if fname == 'Error':
        # # print('Filename not set properly\nExiting...')
        # # sys.exit()
    # # else:
        # # print('Filename= ',fname)
        # # store_window_data(fname)
        # # print('------------')
        # # get_window_data(fname)


    # #grid,vert,horiz,vert3,horiz3 = dict_load_KBINDS()
    # #print('grid: ',grid.keys())
    # #print(grid['TL'],vert['L'])

    # #get_monitor_pos()
    # #get_mouse_on_monitor()
