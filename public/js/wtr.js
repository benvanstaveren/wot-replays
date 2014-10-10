window.Wotreplays = function(options) {
    this.pageid     = options.pageid;
    this.channels   = options.channels  || [];
    this.user       = options.user;
    this.prefs      = options.prefs;
    this.apikey     = options.apikey;
    this.thunderkey = options.thunderkey;
    this.indev      = options.indev || false;

    this.catalog    = {};
    this._handlers  = {};

    this._i18n_disabled = false;

    var that = this;
    $(document).ready(function() {
        that.ready();
    });
};

Wotreplays.prototype = {
    disableI18N: function() {
        this._i18n_disabled = true;
    },
    on: function(evt, handler) {
        if(!this._handlers[evt]) this._handlers[evt] = [];
        this._handlers[evt].push(handler);
    },
    emit: function(evt, data) {
        var that = this;
        if(!data) data = {};
        
        if(this._handlers[evt]) {
            this._handlers[evt].forEach(function(h) {
                h.call(that, data);
            });
        }
    },
    dispatchMessage: function(raw) {   
        var message = JSON.parse(raw);
        if(message.evt) this.emit(message.evt, message.data); 
    },
    ready: function() {
        var that = this;
        var chan = [ 'site' ];
        this.channels.forEach(function(c) {
            chan.push(c);
        });
        if(this.pageid != undefined && this.pageid != null) chan.push('page.' + this.pageid);

        this._setDefaultHandlers();

        Thunder.connect('push.wotreplays.org', this.thunderkey, chan, { log: this.indev, user: this.user });
        Thunder.listen(function(message) {
            that.dispatchMessage(message);
        });
        [ '/img/waiting.gif' ].forEach(function(image) {
            var i = new Image();
            i.src = image;
        });
        $('div#pleaseWaitModal').modal({
            backdrop: 'static',
            keyboard: false,
            show: false,
        });
        $('a.please-wait').on('click', function() { 
            $('div#pleaseWaitModal').modal('show');
            return true;
        });
        $('a.btn.btn-save-replay').on('click', function() {
            var go = true;
            if($(this).hasClass('incompatible')) {
                go = confirm(  'This replay is from an older (or newer) version' + "\n" +
                               'of World of Tanks which you might not be able to play back.' + "\n\n" +
                               'Are you sure you want to download it?');
            }
            if($(this).hasClass('disabled')) {
                alert('The file for this replay is missing...');
                go = false;
            }
            if(!go) return false;
            var c = parseInt($(this).find('span.badge').html());
            $(this).find('span.badge').html(c + 1);
            var href = $(this).attr('href');
        });
        $('a.btn.btn-view-replay').on('click', function() {
            if($(this).hasClass('disabled')) return false;
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

        $('div.dnotification .dn-close').on('click', function() {
            var nid = $(this).data('notification');
            var notification = $('div.dnotification[data-notification="' + nid + '"]');
            if($(notification).hasClass('disabled')) return false;

            $(notification).addClass('disabled');
            $.getJSON('/xhr/dn_d', { id: nid }, function() {
                $(notification).fadeOut(2000, function() {
                    $(notification).remove();
                });
            });
            return false;
        });

        if($('.adspace').height() == 0) {
            $('.gat').append("<p><strong>Hello!</strong></p><p>It seems you've enabled AdBlock! While ads can be annoying, they also help support the site. Our monthly bill is upwards of <strong>&euro;75</strong> and advertising revenue covers most of this. If you don't want to make an exception for wotreplays.org, that's fine, but then please consider supporting the site via <a href='/doc/donate'>Patreon</a>.</p><p><strong>Thanks!</strong></p>");
        }

        this.emit('ready');
    },
    growl: function(text, options) {
        if(!options.type) options.type = 'info';
        if(!options.allow_dismiss) options.allow_dismiss = true;
        if(options.delay) options.sticky = false;
        if(options.sticky) options.delay = 60000; 
        options.offset = { from: 'top', amount: 60 };
        $.bootstrapGrowl(text, options);
    },
    _setDefaultHandlers: function() {
        this.on('growl', function(data) {
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
            this.growl(data.text, notifyOpts);
        });
        this.on('replay.processed', function(data) {
            if(this.pageid == 'home') {
                $('#queue-count').html('-');
                $.getJSON('/xhr/qs', {}, function(d) {
                    if(d.ok == 1) {
                        $('#queue-count').html(d.count);
                    } else {
                        $('#queue-count').html('-');
                    }
                });
                $('#frontpage-spinner').removeClass('hide');
                $('#replay-list').load('/', function() {
                    $('#frontpage-spinner').addClass('hide');
                });
            }
        });
        this.on('replay.view', function(data) {
            var panel = $('div[data-replayid="' + data.id + '"]');
            var c = parseInt($(panel).find('a.btn-view-replay span.badge').html());
            $(panel).find('a.btn-view-replay span.badge').html(c + 1);
        });
        this.on('replay.comment', function(data) {
            var panel = $('div[data-replayid="' + data.id + '"]');
            var c = parseInt($(panel).find('a.btn-comment-replay span.badge').html());
            $(panel).find('a.btn-comment-replay span.badge').html(c + 1);
        });
        this.on('replay.like', function(data) {
            var panel = $('div[data-replayid="' + data.id + '"]');
            var c = parseInt($(panel).find('a.btn-like-replay span.badge').html());
            $(panel).find('a.btn-like-replay span.badge').html(c + 1);
        });
        this.on('replay.download', function(data) {
            var panel = $('div[data-replayid="' + data.id + '"]');
            var c = parseInt($(panel).find('a.btn-save-replay span.badge').html());
            $(panel).find('a.btn-save-replay span.badge').html(c + 1);
        });
    },
    _fmt_i18n: function(str, args) {
        return str.replace(/{{(.*?)}}/gi, function(match, name) {
            if(name.match(/:/)) {
                // pluralisation support
                var nm = name.match(/(.*?):(.*)/);
                var n = nm[1];
                var fmt = nm[2].split(/,\s*/);
                if(fmt[2] == undefined) fmt[2] = fmt[1]; 

                var f = (args[n] != null && args[n] != undefined) 
                    ? (args[n] > 1) 
                        ? fmt[1]
                        : fmt[0]
                    : fmt[2];
                return f.replace(/%d/g, f);
            } else {
                return (args[name] != null && args[name] != undefined) 
                    ? args[name]
                    : '';
            }
        });
    },
    i18n: function(key, args) {
        if(this._i18n_disabled) return key;

        try {
            var trimmedkey = key.trim();
        } catch(ex) {
            var trimmedkey = key;
        }

        // do some checks
        var catstr= WR.catalog[trimmedkey];
        if(catstr) {
            var formatted = this._fmt_i18n(catstr, args);
        } else {
            if(trimmedkey.match(/.*_class\d/i) || trimmedkey.match(/.*_mk\d/i)) {
                var formatted = this.i18n(trimmedkey.replace(/_(mk\d|class\d)/i, ''), args);
            } else {
                var formatted = key;
            }
        }
        return formatted;
    },
};

$.fn.extend({
    unselectable: function(v) {
        return this.each(function() {
            if(v) {
                $(this).attr('unselectable', 'on').addClass('unselectable');
            } else {
                $(this).removeAttr('unselectable').removeClass('unselectable');
            }
            $(this).children().unselectable(v);
        });
    },
    i18n: function() {
        return this.each(function() {
            var key      = $(this).text();
            var argsonly = $(this).data('attributes-only');
            if(key != undefined && key != null && !argsonly) {
                var args = $(this).data('i18n') || {};
                var fmt  = $(this).data('i18n-format');

                if(!argsonly) {
                    $(this).data('i18n-orig', key);

                    if(fmt == null || fmt == undefined) {
                        $(this).html(WR.i18n(key, args));
                    } else {
                        $(this).html(fmt.replace('%s', WR.i18n(key, args)));
                    }
                }
            }
            // for things like tooltips, we generally need localized titles as well,
            // we'll find their keys and args in data-i18n-attr
            var attrs = $(this).data('i18n-attr'); 
            if(attrs != null && attrs != undefined) {
                for(attribute in attrs) {
                    var key = attrs[attribute][0];
                    var args = attrs[attribute][1];
                    var val  = WR.i18n(key, args);
                    $(this).attr(attribute, val);
                }
            }
            if($(this).data('title-is-content')) $(this).attr('title', $(this).html());
            if(!argsonly) {
                if($(this).hasClass('transform')) {
                    // transformations only work on entire texts, not attributes
                    var tx = $(this).data('transform');
                    if(tx == 'ucfirst') $(this).css({ 'text-transform': 'capitalize' });
                    if(tx == 'uc') $(this).css({ 'text-transform': 'uppercase' });
                    if(tx == 'lc') $(this).css({ 'text-transform': 'lowercase' });
                }
            }

            // cheesy fix
            if($(this).hasClass('bs-tooltip')) $(this).data('html', true);
        });
    }
});

if(!String.prototype.trim) {
    String.prototype.trim = function() {
        return this.replace(/^\s+|\s+$/g,'');
    }
}
