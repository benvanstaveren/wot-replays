# original file: res/scripts/client/account_helpers/battleresultscache.pyc
import BigWorld
import AccountCommands
import ResMgr

import base64
import cPickle
import httplib
import json
import os
import traceback
import zlib

from account_helpers import BattleResultsCache
from battle_results_shared import *
from debug_utils import *
from threading import Thread
from urlparse import urlparse
from gui.shared.utils.requesters import StatsRequester
from messenger.proto.bw import ServiceChannelManager
from functools import partial
from gui import ClientHangarSpace
from PlayerEvents import g_playerEvents

print "[WTR]: wotreplays.org battle result submitter loading";

### WTR specific doohickeys ###
todolist   = []

class BattleResultsSubmitter(object):
    def __init__(self, jsonString, callback):
        self.jsonString = jsonString
        self.callback   = callback
    
    def submit(self): 
        u = urlparse('http://api.wotreplays.org/util/battleresult/submit')
        print('[WTR] [BattleResultsSubmitter.submit] to ' + repr(u))
        try:
            conn = httplib.HTTPConnection(u.netloc, timeout=5)
            conn.request('POST', u.path, self.jsonString, { "Content-Type": "application/json" })
            response = conn.getresponse()
            print(response.status, response.reason)
            print(response.read())
            self.callback(True, self.jsonString)
        except Exception as e:
            traceback.format_exc()
            LOG_CURRENT_EXCEPTION()
            self.callback(False, self.jsonString)

def __onUploadDone(result, jsonString):
    if(result == False):
        pass

def __wtr_upload(battleResults, isRetry=False):
    try:
        print "[WTR]: __wtr_upload"
        if isRetry == False:
            print "- arena_id: " + str(battleResults[0])

            s_obj = (battleResults, BattleResultsCache.convertToFullForm(battleResults))
            j_obj = {
                "arena_id" : str(battleResults[0]),
                "battleResult": base64.b64encode(cPickle.dumps(BattleResultsCache.convertToFullForm(battleResults), 2))
            }
                
            jsonString = json.dumps(j_obj)
        else:
            print "- retry"
            jsonString = battleResults

        submitter = BattleResultsSubmitter(jsonString, __onUploadDone)
        thread = Thread(target=submitter.submit);
        thread.start()
    except Exception as e:
        traceback.format_exc()
        LOG_CURRENT_EXCEPTION()

### this is our own implementation of what BRR does, but simpler
old_msg   = ServiceChannelManager._ServiceChannelManager__addServerMessage
old_setup = ClientHangarSpace._VehicleAppearance._VehicleAppearance__doFinalSetup

def fetchresult(arenaUID):
    if arenaUID:    
        print "[WTR]: fetchresult"
        proxy = partial(__onGetResponse, StatsRequester()._valueResponse)
        BigWorld.player()._doCmdInt3(AccountCommands.CMD_REQ_BATTLE_RESULTS, arenaUID, 0, 0, proxy)
    else:
        return

def __onGetResponse(callback, requestID, resultID, errorStr, ext = {}):
    if resultID != AccountCommands.RES_STREAM:
        if callback is not None:
            try:
                callback(resultID, None)
            except:
                LOG_CURRENT_EXCEPTION()

        return
    else:
        BigWorld.player()._subscribeForStream(requestID, partial(__onStreamComplete, callback))
        return

def __onStreamComplete(callback, isSuccess, data):
    try:
        battleResults = cPickle.loads(zlib.decompress(data))
        print "[WTR]: __onStreamComplete"
        # don't save to disk, go straight for the upload
        __wtr_upload(battleResults)
    except:
        LOG_CURRENT_EXCEPTION()
        if callback is not None:
            callback(AccountCommands.RES_FAILURE, None)
    return

def new_msg(self, message):
    #LOG_NOTE('Message:', message)
    if message.type == 2:
        try:
            print "[WTR]: new_msg, appending item to todolist"
            todolist.append(message.data.get('arenaUniqueID', 0))
        except:
            LOG_CURRENT_EXCEPTION()
    old_msg(self, message)

def new_setup(self, buildIdx, model, delModel):
    if todolist:
        print "[WTR]: new_setup, starting work on todolist"
        while todolist:
            temp = todolist.pop()
            fetchresult(int(temp))

    old_setup(self, buildIdx, model, delModel)


### BATTLERESULTSCACHE REPLACERS ###
# replaces the save method in the battle results cache, thus intercepting
# any and all battle results we actually view; unfortunately BRR implements 
# it's own save method, so see below for that one

__old_save = BattleResultsCache.save

def __BattleResultsCache_new_save(account, battleResults):
    __old_save(account, battleResults)
    try:
        print "[WTR]: __BattleResultsCache_new_save"
        __wtr_upload(battleResults) 
    except:
        LOG_CURRENT_EXCEPTION()

BattleResultsCache.save = __BattleResultsCache_new_save

### BRR REPLACERS ###
# if BRR is in the mod path, assume it'll be loaded (it will...)
# and replace it's save method. Since we can't reliably do this during import,
# we'll do it with a one-off onAccountBecomePlayer callback

def hasBRR():
    res = ResMgr.openSection('../paths.xml')
    sb = res['Paths']
    vals = sb.values()[0:2]
    for vl in vals:
        mp = vl.asString + '/scripts/client/mods/BRR.pyc'
        if(os.path.isfile(mp)):
            return True
    return False

try:
    import mods.BRR
    __brr_save = mods.BRR.save
except:
    pass
    
def __BRR_new_save(account, battleResults):
    print "[WTR]: __BRR_new_save"
    try:
        __brr_save(account, battleResults)
    except:
        LOG_CURRENT_EXCEPTION()

    __wtr_upload(battleResults)

### MAIN INIT ###

if hasBRR():
    print "[WTR]: monkeypatching BRR"
    mods.BRR.save = __BRR_new_save
else:
    print "[WTR]: installing auto result fetcher"
    ServiceChannelManager._ServiceChannelManager__addServerMessage = new_msg
    ClientHangarSpace._VehicleAppearance._VehicleAppearance__doFinalSetup = new_setup

print "[WTR]: wotreplays.org battle result submitter loaded";
