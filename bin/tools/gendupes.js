var mapf = function() {
    emit(this.digest, 1);
};
var redf = function(k, v) {
    var sum = 0;

    v.forEach(function(e) {
        sum += e;
    });
    
    return sum;
};

db.replays.mapReduce(mapf, redf, {
    out: { 'replace': 'replay_duplicates' },
});


        
