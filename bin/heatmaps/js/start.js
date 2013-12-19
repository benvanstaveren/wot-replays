db.dropDatabase();
db['raw_location'].ensureIndex({ map_id: 1, gameplay_id: 1, bonus_type: 1, is: 1 });
