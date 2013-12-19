var mapf = function() {
    emit(this.map_id, 1);
};
var redf = function(k, v) {
    var sum = 0;

    v.forEach(function(e) {
        sum += e;
    });

    return sum;
};

db.raw_location.mapReduce(mapf, redf, {
    out: { 'replace': 'map_list' }
});

