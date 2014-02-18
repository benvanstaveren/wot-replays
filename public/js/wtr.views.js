window.WTR.Base.View = Backbone.View.extend({
    i18n: function() {
        this.$('.i18n').i18n(); 
    },
});
window.WTR.View.Panel = WTR.Base.View.extend({});
