function() {
    if(this.game.arena_id && this.file) 
        emit(this.game.arena_id, { count: 1, ids: [ this._id ] });
}
