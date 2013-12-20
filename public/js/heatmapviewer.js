/* 
    v 20131219 2048
    wotreplays.org heatmap viewer
    requires heatmap.js from github.com/pa7/heatmap.js
    requires wotreplays mapgrid
*/

HeatmapViewer = function(options) {
    this.container      =   options.container; 
    this.ident          =   options.ident;
    this.caching        =   (options.caching == null) ? true : options.caching;
    this.api_url        =   (options.api_url == null) ? 'http://api.wotreplays.org/v1' : options.api_url;
    this.handlers       =   [];
    this.heatmapConfig  =   {
        "radius"    : 32,
        "visible"   : true,
        "opacity"   : 50,
        "gradient"  : { 0.1: "rgb(0,0,255)", 0.3: "rgb(0,128,128)", 0.6: "rgb(0,255,255)", 0.8: "rgb(0,255,0)", 0.9: "rgb(255,255,0)", 0.91: "#ffbf00", 0.92: "#ff7f00", 0.93: "#ff3f00", 0.94: "#ff0000", 0.95: "#ff2a2a", 0.96: "#ff5555", 0.97: "#ff7f7f", 0.98: "#ffaaaa", 0.99: "#ffd4d4", 1.00: "#ffffff" }
    };
    this.config         =   {
        types: [
            { id: 'location', name: 'Locations' },
            { id: 'deaths', name: 'Deaths' },
            { id: 'damage', name: 'Damage Received' },
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
        $.getJSON(this.api_url + '/map/' + this.ident + '.json', { _: new Date().getTime() }, function(d) {
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
        var mmap = { 'ctf': 0, 'assault': 2, 'domination': 1, 'encounter': 1 };
        return mmap[this._mode];
    },
    setRadius: function(newRadius) {
        this.getHeatmap().set('radius', newRadius);
        this.getHeatmap().store.setDataSet(this._currentSet);
    },
    loadHeatmapData: function() {
        var prefixMap = {
            'location': '',
            'deaths': 'd_',
            'damage': 'dmg_',
            'damage_d': 'dd_'
        };
        var url = 'http://packets.wotreplays.org/heatmaps/' + prefixMap[this.getType()] + this.config.map_id + '_' + this.getMode() + '.json';
        var cachekey = this.getType() + this.config.map_id + this.getMode();
        this.trigger('loadstart');

        if(this.caching) {
            if(this._cache[cachekey]) {
                this._setDataSet(this._cache[cachekey]);
                return;
            }
        }

        if(this.rendered) this.getMapGrid().showLoader() 

        var me  = this;
        $.getJSON(url, { _: new Date().getTime() }, function(d) {
            // here's the kicker, if we use onDataProcess, it should take care of using _setDataSet instead
            // of us.
            if(me.handlers['process'] && me.handlers['process'].length > 0) {
                // we're doing onProcess bits, so so so 
                me.trigger('process', d);
            } else {
                var max = 0;
                var hmd = [];
                d.forEach(function(data) {
                    if(data.count > max) max = data.count;
                    var gc = me.getMapGrid().game_to_map_coord([ data.x, 0, data.y ]);
                    hmd.push({ x: gc.x, y: gc.y, count: data.count });
                });
                var dataset = { max: max, data: hmd };
                me._setDataSet(dataset, cachekey);
                if(me.rendered) me.getMapGrid().hideLoader();
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
