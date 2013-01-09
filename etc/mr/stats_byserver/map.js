function() {
    if(this.player && this.player.server) emit(this.player.server, 1);
}
