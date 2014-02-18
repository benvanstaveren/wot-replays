// also happens to set up the window.WTR space
window.WTR = { 
    Base: {},
    Model: {}, 
    View: {}, 
    Collection: {} 
};
window.WTR.Model.Panel = Backbone.Model.extend({});
window.WTR.Collection.Panel = Backbone.Collection.extend({
    model: WTR.Model.Panel,
});
