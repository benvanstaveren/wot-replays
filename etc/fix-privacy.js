db.replays.find().forEach(function(replay) {
    if(replay.site.privacy == null || replay.site.privacy == undefined) {
        replay.site.visible = true;
        replay.site.privacy = 0;
    }
    if(replay.site.visible == null || replay.site.visible == undefined) {
        replay.site.visible = true;
        replay.site.privacy = 0;
    }
   
});   
