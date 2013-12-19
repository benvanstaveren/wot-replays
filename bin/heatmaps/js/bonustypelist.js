var mapf = function() {
    emit(this.bonus_type, 1);
};
var redf = function(k, v) {
    var sum = 0;

    v.forEach(function(e) {
        sum += e;
    });

    return sum;
};

db.raw_location.mapReduce(mapf, redf, {
    out: { 'replace': 'bonustype_list' }
});

