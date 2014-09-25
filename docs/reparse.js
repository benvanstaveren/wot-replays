db.replays.find({ 'game.version_numeric': 90300 }).forEach(function(replay) {
    db.jobs.update({ _id: replay.digest }, {
        '$set': {
            locked: false,
            complete: false,
            locked_at: null,
            locked_by: null,
        },
    });
    db.replays.remove({ _id: replay._id });
});
