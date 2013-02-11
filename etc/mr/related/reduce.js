function(k, v) {
    var related = { count: 0, ids: [] };

    v.forEach(function(val) {
        related.count += val.count;
        val.ids.forEach(function(id) {
            related.ids.push(id);
        });
    });
    return related;
}
