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
        $(this).find('span.badge.downloads').html(c + 1);
        var href = $(this).attr('href');
    });
    $('a.btn.btn-view-replay').on('click', function() {
        var c = parseInt($(this).find('span.badge').html());
        $(this).find('span.badge').html(c + 1);
    });
    $('a.btn.btn-like-replay').on('click', function() {
        var href = $(this).attr('href');
        var s = this;
        $.getJSON('/replay/' + href + '/up', {}, function(d) {
            $(s).find('span.badge').html(d.c);
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
    }
};
