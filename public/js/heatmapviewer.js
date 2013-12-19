/* 
    wotreplays.org heatmap viewer
    requires heatmap.js from github.com/pa7/heatmap.js
    requires wotreplays mapgrid
*/

HeatmapViewer = function(options) {
    this.container      =   options.container; 
    this.ident          =   options.ident;
    this.api_url        =   'http://api.wotreplays.org/v1';
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
            { id: 'damage', name: 'Damage Taken' },
        ],
        modes: null,
    };
    this.gridConfig     =   {
        container: $(this.container).attr('id'),
        ident    : this.ident,
        map      : {
            width: 768,
            height: 768,
        }
    };

    this._mapGrid = null;
    this._heatmap = null;

    this._type    = 'location';
    this._mode    = 'ctf';
    this.rendered = false;
};

HeatmapViewer.prototype = {
    onInit: function(handler) {
        this._handle('init', handler);
    },
    onError: function(handler) {
        this._handle('error', handler);
    },
    onDataLoaded: function(handler) {
        this._handle('dataloaded', handler);
    },
    _handle: function(evtn, handler) {
        if(!this.handlers[evtn]) this.handlers[evtn] = new Array();
        this.handlers[evtn].push(handler);
    },
    trigger: function(evtn, evtdata) {
        if(!this.handlers[evtn]) return;
        this.handlers[evtn].forEach(function(handler) {
            handler.call(this, evtdata);
        });
    },
    init: function() {
        // make an API call to find the map boundaries and valid game modes for the given map ident
        var me = this;
        $.getJSON(this.api_url + '/map/' + this.ident + '.json', { _: new Date().getTime() }, function(d) {
            if(d.ok == 1) {
                me.gridConfig.bounds = [ d.data.attributes.geometry.bottom_left, d.data.attributes.geometry.upper_right ];
                me.gridConfig.positions = null;

                var modes = [];
                for(k in d.data.attributes.positions) {
                    modes.push(k);
                }
                me.config.modes = modes;
                me.config.map_id = d.data.numerical_id;
                me._mapGrid = new MapGrid(this.gridConfig);
                me.heatmapConfig.element = document.getElementById($(me.container).attr('id')); // yeah, strange
                me.heatmap  = heatmapFactory.create(me.heatmapConfig);
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
        $(select).change(function() {
            me.setType($(this).val());
        });
    },
    bindModeSelect: function(select) {
        $(select).empty();
        this.config.modes.forEach(function(mode) {
            $(select).append(
                $('<option/>').attr('value', mode.id).html(mode.name)
            );
        });
        var me = this;
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
        };
        var url = 'http://packets.wotreplays.org/heatmaps/' + prefixMap[this.getType()] + this.config.map_id + '_' + this.getMode() + '.json';
        if(this.rendered) this.getMapGrid().showLoader() 

        if(this.caching) {
            if(this._cache[url]) {
                this._setDataSet(this._cache[url]);
                return;
            }
        }
        var me  = this;
        $.getJSON(url, { _: new Date().getTime() }, function(d) {
            var max = 0;
            d.forEach(function(data) {
                if(data.count > max) max = data.count;
                var gc = me.getMapGrid.game_to_map_coord([ data.x, 0, data.y ]);
                data.x = gc.x;
                data.y = gc.y
            });
            var dataset = { max: max, data: d };
            if(me.caching) me._cache[url] = dataset;
            me._setDataSet(dataset);
            if(me.rendered) me.getMapGrid().hideLoader() 
            me.trigger('dataloaded');
        });
    },
    _setDataSet: function(dataset) {
        this._currentSet = dataset;
        this.getHeatmap().store.setDataSet(this._currentSet);
    },
    render: function() {
        this.rendered = true;
        this.getMapGrid().render();
        this.loadHeatmapData();
    },
};
