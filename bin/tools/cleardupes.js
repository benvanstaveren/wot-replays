db.replay_duplicates.find({ value: { '$gt': 1 }).toArray().forEach(function(dupe) {
    print("dupe digest: " + dupe._id + "\n");
    var a = db.replays.find({ digest: dupe._id }).sort({ 'site.views': -1 }).toArray();
    var i;
    for(i = 1; i < a.length; i++) {
        db.replays.remove({ _id: a[i]._id });
        print("remove: " + i + " id: " + a[i]._id);
    }
});
    

