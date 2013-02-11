function() {
    if(this.game.arena_id && this.file && this.site.visible == true) 
        emit(this.game.arena_id + '', { count: 1, ids: [ this._id ] });
}
