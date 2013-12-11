# wotreplays.org replay uploader mod
#
# based in part on work done by Phalynx and Locastan 
# based in part on the xvmstat mod, as well as some random junk from XVM
#
# based largely on too much caffeine

__author__ = 'Scrambled'

import os
import cPickle
from gui.shared import  g_questsCache
from Account import Account
from adisp import async, process
from debug_utils import *
from PlayerEvents import g_playerEvents
from gui.shared.quests.bonuses import getBonusObj
from gui.shared.quests.conditions import getConditionObj
from json import dumps, loads, JSONEncoder, JSONDecoder
from threading import Thread
from urlparse import urlparse
import httplib

class ReplayFile(file): 
    def __init__(self, *args, **keyws):
        file.__init__(self, *args, **keyws)

    def __len__(self):
        return int(os.fstat(self.fileno())[6])


class ReplayUpload(object):
    def __init__(self, rfile):
        self.rfile = ReplayFile(rfile, 'rb');

   
class WRUploader(object):
    pass
