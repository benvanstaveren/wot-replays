/* 
    v 20131221 0655
    wotreplays.org heatmap viewer
    requires heatmap.js from github.com/pa7/heatmap.js
    requires wotreplays mapgrid
*/

HeatmapViewer = function(options) {
    this.container      =   options.container; 
    this.apitoken       =   options.apitoken;
    this.ident          =   options.ident;
    this.caching        =   (options.caching == null) ? true : options.caching;
    this.api_url        =   (options.api_url == null) ? 'http://api.wotreplays.org/v1' : options.api_url;
    this.handlers       =   [];

    if(!options.heatmap) options.heatmap = {};
    this.heatmapConfig  = {
        "radius"    : 32,
        "visible"   : true,
        "opacity"   : 40,
    };

    for(k in options.heatmap) {
        this.heatmapConfig[k] = options.heatmap[k];
    }

    this.config         =   {
        types: [
            { id: 'location', name: 'Locations' },
            { id: 'deaths', name: 'Deaths' },
            { id: 'damage_r', name: 'Damage Received' },
            { id: 'damage_d', name: 'Damage Done' },
        ],
        modes: null,
    };
    this.gridConfig     =   {
        container: '#' + $(this.container).attr('id'), // because yeah... 
        ident    : this.ident,
        map      : {
            width: 768,
            height: 768,
        }
    };

    this._mapGrid = null;
    this._heatmap = null;
    this._cache   = {};

    this._type    = 'location';
    this._mode    = 'ctf';
    this.rendered = false;
};

HeatmapViewer.prototype = {
    onInit: function(handler) {
        this._handle('init', handler);
    },
    onDataProcess: function(handler) {
        this._handle('process', handler);
    },
    onError: function(handler) {
        this._handle('error', handler);
    },
    onLoadStart: function(handler) {
        this._handle('loadstart', handler);
    },
    onLoadEnd: function(handler) {
        this._handle('loadend', handler);
    },
    onNoData: function(handler) {
        this._handle('nodata', handler);
    },
    _handle: function(evtn, handler) {
        if(!this.handlers[evtn]) this.handlers[evtn] = new Array();
        this.handlers[evtn].push(handler);
    },
    trigger: function(evtn, evtdata) {
        if(!this.handlers[evtn]) return;
        var me = this;
        this.handlers[evtn].forEach(function(handler) {
            handler.call(me, evtdata);
        });
    },
    init: function() {
        // make an API call to find the map boundaries and valid game modes for the given map ident
        var me = this;
        $.getJSON(this.api_url + '/map/' + this.ident + '.json', { 't': this.apitoken, '_': new Date().getTime() }, function(d) {
            if(d.ok == 1) {
                me.gridConfig.map.bounds = [ d.data.attributes.geometry.bottom_left, d.data.attributes.geometry.upper_right ];
                me.gridConfig.map.positions = null;
                var modes = [];
                for(k in d.data.attributes.positions) {
                    modes.push(k);
                }
                me.config.modes = modes;
                me.mapModeCount = modes.length;
                me.config.map_id = d.data.numerical_id;
                me._mapGrid = new MapGrid(me.gridConfig);
                me.getMapGrid().render(); 
                me.rendered = true;
                me.trigger('init');
            } else {
                me.trigger('error', { code: d.error, text: d[d.error] });
                me.getMapGrid().hideLoader();
            }
        });
    },
    getMapGrid: function() {
        return this._mapGrid;
    },
    getHeatmap: function() {
        if(!this._heatmap) {
            this.heatmapConfig.element = document.getElementById($(this.getMapGrid().getOverlay('viewer')).attr('id')); // yeah, strange
            this._heatmap  = heatmapFactory.create(this.heatmapConfig);
        }
        return this._heatmap;
    },
    bindTypeSelect: function(select) {
        $(select).empty();
        this.config.types.forEach(function(type) {
            $(select).append(
                $('<option/>').attr('value', type.id).html(type.name)
            )
        });
        var me = this;
        $(select).val(this._type);
        $(select).change(function() {
            me.setType($(this).val());
        });
    },
    bindModeSelect: function(select) {
        var modeNames = {
            'ctf': 'CTF',
            'assault': 'Assault',
            'domination': 'Encounter',
        };
        $(select).empty();
        this.config.modes.forEach(function(mode) {
            $(select).append(
                $('<option/>').attr('value', mode).html(modeNames[mode])
            );
        });
        var me = this;
        $(select).val(this._mode);
        $(select).change(function() {
            me.setMode($(this).val());
        });
    },
    setMode: function(newMode) {
        this._mode = newMode;
        this.loadHeatmapData();
    },
    setType: function(newType) {
        this._type = newType;
        this.loadHeatmapData();
    },
    getType: function() {
        return this._type;
    },
    getMode: function() {
        return this._mode;
    },
    loadHeatmapData: function() {
        var url = this.api_url + '/map/' + this.ident + '/heatmap/' + this.getType() + '/' + this.getMode() + '/';

        this.trigger('loadstart');

        if(this.caching) {
            if(this._cache[url]) {
                this._setDataSet(this._cache[url]);
                return;
            }
        }

        if(this.rendered) this.getMapGrid().showLoader() 

        var me  = this;
        $.getJSON(url, { 't': this.apitoken, '_': new Date().getTime() }, function(d) {
            if(d.ok == 0) {
                if(me.rendered) me.getMapGrid().hideLoader();
                me.trigger('error', { code: d.error, text: d[d.error] });
            } else {
                if(d.data.count == 0) {
                    me.trigger('nodata');
                    if(me.rendered) me.getMapGrid().hideLoader();
                } else {
                    var max = 0;
                    var hmd = [];
                    d.data.set.forEach(function(data) {
                        data.value = data.value * 10;
                        if(data.value > max) max = data.value;
                        var gc = me.getMapGrid().game_to_map_coord([ data.x, data.y ]);
                        hmd.push({ x: gc.x, y: gc.y, count: data.value });
                    });
                    var dataset = { max: max, data: hmd };
                    me._setDataSet(dataset, url);
                    if(me.rendered) me.getMapGrid().hideLoader();
                }
            }
        });
    },
    _setDataSet: function(dataset, cachekey) {
        if(this.caching && cachekey) this._cache[cachekey] = dataset;
        this._currentSet = dataset;
        this.getHeatmap().store.setDataSet(this._currentSet);
        this.trigger('loadend');
    },
    load: function() {
        this.loadHeatmapData();
    },
};
