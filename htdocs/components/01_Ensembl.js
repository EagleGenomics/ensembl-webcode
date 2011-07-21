// $Revision$

var Ensembl = new Base();

Ensembl.extend({
  constructor: null,
  
  initialize: function () {
    var hints       = this.cookie.get('ENSEMBL_HINTS');
    var imagePanels = $('.image_panel');
    
    if (!window.name) {
      window.name = 'ensembl_' + new Date().getTime() + '_' + Math.floor(Math.random() * 10000);
    }
    
    this.hashRegex     = new RegExp(/[\?;&]r=([^;&]+)/);
    this.ajax          = this.cookie.get('ENSEMBL_AJAX') || this.setAjax();
    this.width         = parseInt(this.cookie.get('ENSEMBL_WIDTH'), 10) || this.setWidth(undefined, 1);
    this.dynamicWidth  = !!this.cookie.get('DYNAMIC_WIDTH');
    this.hideHints     = {};
    this.initialPanels = $('.initial_panel');
    this.minWidthEl    = $('#min_width_container');
    this.images        = { // Store image panel details for highlighting
      total: imagePanels.length,
      last:  imagePanels.last()[0]
    };
    
    if (hints) {
      $.each(hints.split(/:/), function () {
        Ensembl.hideHints[this] = 1;
      });
    }
    
    imagePanels = null;
    
    this.setCoreParams();
    
    this.LayoutManager.initialize();
    this.PanelManager.initialize();
  },
  
  cookie: {
    set: function (name, value, expiry, unescaped) {
      var cookie = [
        unescaped === true ? (name + '=' + (value || '')) : (escape(name) + '=' + escape(value || '')),
        '; expires=',
        (expiry === -1 ? 'Thu, 01 Jan 1970' : 'Tue, 19 Jan 2038'),
        ' 00:00:00 GMT; path=/'
      ].join('');
      
      document.cookie = cookie;
      
      return value;
    },
    
    get: function (name, unescaped) {
      var cookie = document.cookie.match(new RegExp('(^|;)\\s*' + (unescaped === true ? name : escape(name)) + '=([^;\\s]*)'));
      return cookie ? unescape(cookie[2]) : '';
    }
  },
  
  setAjax: function () {
    return this.cookie.set('ENSEMBL_AJAX', ($.ajaxSettings.xhr() || false) ? 'enabled' : 'none');
  },
  
  setWidth: function (w, changed) {
    var numeric = !isNaN(w);
    
    w = numeric ? w : Math.floor(($(window).width() - 250) / 100) * 100;
    
    this.width = w < 500 ? 500 : w;
    
    if (changed) {
      this.cookie.set('ENSEMBL_WIDTH', this.width);
      this.cookie.set('DYNAMIC_WIDTH', 1, numeric ? -1 : 1);
      this.dynamicWidth = !numeric;
    }
    
    return this.width;
  },
  
  setCoreParams: function () {
    var regex = '[;&?]%s=(.+?)[;&]';
    var url   = window.location.search + ';';
    var hash  = window.location.hash.replace(/^#/, '?') + ';';
    var lastR = this.coreParams ? this.coreParams.r : '';
    var match, m, i, r;
    
    this.hash          = hash;
    this.coreParams    = {};
    this.initialR      = $('input[name=r]', '#core_params').val();
    this.location      = { length: 100000 };
    this.speciesPath   = $('#species_path').val() || '';
    this.speciesCommon = $('#species_common_name').val() || '';
    this.species       = this.speciesPath.split('/').pop();
    this.multiSpecies  = {};
    
    $('input', '#core_params').each(function () {
      var hashMatch = hash.match(regex.replace('%s', this.name));
      Ensembl.coreParams[this.name] = hashMatch ? unescape(hashMatch[1]) : this.value;
    });
    
    this.lastR = lastR || (hash ? this.coreParams.r : this.initialR);
    
    match = this.coreParams.r ? this.coreParams.r.match(/(.+):(\d+)-(\d+)/) : false;
    
    if (match) {
      this.location = { name: match[1], start: parseInt(match[2], 10), end: parseInt(match[3], 10) };
      this.location.length = this.location.end - this.location.start + 1;
      
      if (this.location.length > 1000000) {
        this.location.length = 1000000;
      }
    }
    
    match = url.match(/s\d+=.+?[;&]/g);
    
    if (match) {
      $.each(match, function () {
        m = this.split('=');
        i = m[0].substr(1);
        
        Ensembl.multiSpecies[i] = {};
        
        $.each(['r', 'g', 's'], function (j, param) {
          Ensembl.multiSpecies[i][param] = url.match(regex.replace('%s', param + i));
          
          if (Ensembl.multiSpecies[i][param]) {
            Ensembl.multiSpecies[i][param] = unescape(Ensembl.multiSpecies[i][param][1]);
          }
          
          if (param === 'r' && Ensembl.multiSpecies[i].r) {
            r = Ensembl.multiSpecies[i].r.match(/(.+):(\d+)-(\d+)/);
            
            Ensembl.multiSpecies[i].location = { name: r[1], start: parseInt(r[2], 10), end: parseInt(r[3], 10) };
          }
        });
      });
    }
  },
  
  cleanURL: function (url) {
    return unescape(url.replace(/&/g, ';').replace(/#.*$/g, '').replace(/([\?;])time=[^;]+;?/g, '$1').replace(/[\?;]$/g, ''));
  },
  
  // Remove the old time stamp from a URL and replace with a new one
  replaceTimestamp: function (url) {
    var d    = new Date();
    var time = d.getTime() + d.getMilliseconds() / 1000;
    
    url  = this.cleanURL(url);
    url += (url.match(/\?/) ? ';' : '?') + 'time=' + time;
    
    return url;
  },
  
  redirect: function (url) {
    for (var p in this.PanelManager.panels) {
      this.PanelManager.panels[p].destructor('cleanup');
    }
    
    url = url || this.replaceTimestamp(window.location.href);
    
    if (window.location.hash) {
      url = this.urlFromHash(url);
    }
    
    window.location = url;
  },
  
  urlFromHash: function (url, paramOnly) {
    var hash  = window.location.hash.replace(/^#/, '?') + ';';
    var match = hash.match(this.hashRegex);
    var r     = match ? match[1] : this.initialR || '';
    
    return paramOnly ? r : url.match(this.hashRegex) ? url.replace(/([\?;]r=)[^;]+(;?)/, '$1' + r + '$2') : r ? url + (url.match(/\?/) ? ';r=' : '?r=') + r : url;
  },
  
  thousandify: function (str) {
    str += '';
    
    var rgx = /(\d+)(\d{3})/;
    var x   = str.split('.');
    var x1  = x[0];
    var x2  = x.length > 1 ? '.' + x[1] : '';
    
    while (rgx.test(x1)) {
      x1 = x1.replace(rgx, '$1' + ',' + '$2');
    }
    
    return x1 + x2;
  }
});

window.Ensembl = Ensembl; // Make Ensembl namespace available on window - needed for upload iframes because the minifier will compress the variable name Ensembl
