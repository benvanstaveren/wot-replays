function() {
    for(k in this.players) {
        if(this.players[k].clanDBID > 0) {
            emit(this.players[k].clanAbbrev, { server: this.player.server, clanDBID: this.players[k].clanDBID });
        }
    }
}
