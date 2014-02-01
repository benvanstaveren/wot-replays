$(document).ready(function() {
    [ '/img/waiting.gif' ].forEach(function(image) {
        var i = new Image();
        i.src = image;
    });
    $('a.btn.btn-save-replay').on('click', function() {
        var go = true;
        if($(this).hasClass('incompatible')) {
            console.log('incompatible version download');
            go = confirm(  'This replay is from an older (or newer) version' + "\n" +
                           'of World of Tanks which you might not be able to play back.' + "\n\n" +
                           'Are you sure you want to download it?');
        }
        if(!go) return false;
        var c = parseInt($(this).find('span.badge').html());
        $(this).find('span.badge').html(c + 1);
        var href = $(this).attr('href');
    });
    $('a.btn.btn-view-replay').on('click', function() {
        var c = parseInt($(this).find('span.badge').html());
        $(this).find('span.badge').html(c + 1);
    });
    $('a.btn.btn-like-replay').on('click', function() {
        if($(this).hasClass('disabled')) return false;
        var href = $(this).attr('href');
        $(this).addClass('disabled');
        var s = this;
        $.getJSON('/replay/' + href + '/up', {}, function(d) {
            $(s).find('span.badge').html(d.c);
            $(s).removeClass('disabled');
        });
        return false;
    });

});

window.WR = {
    defaultChartOptions: {
        well: { 
            backgroundColor: '#151515', 
            fontName: 'Droid Sans',
            legend: { 
                textStyle: { 
                    color: '#888' 
                },
            },
            titleTextStyle: { 
                color: '#fff'
            } 
        }
    },
    messages: {},
    addMessageHandler: function(type, handler) {
        if(!WR.messages[type]) WR.messages[type] = [];
        WR.messages[type].push(handler);
    },
    dispatchMessage: function(message) {
        if(message.evt) {
            if(WR.messages[message.evt]) {
                WR.messages[message.evt].forEach(function(h) {
                    h(message.data);
                });
            }
        }
    },
};

/* default message handling */
WR.addMessageHandler('growl', function(data) {
    var notifyOpts = { 
        type: (data.type) ? data.type : 'info',
        allow_dismiss: (data.allow_dismiss) ? true : false,
        offset: { from: 'top', amount: 60 },
        delay: (data.sticky) 
            ? 60*1000 
            : (data.delay) 
                ? data.delay
                : 4000
    };
    $.bootstrapGrowl(data.text, notifyOpts);
});
