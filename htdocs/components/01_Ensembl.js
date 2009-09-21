// $Revision$

var Ensembl = new Base();

Ensembl.extend({
  constructor: null,
  
  initialize: function () {
    var myself = this;
    
    var hints = this.cookie.get('ENSEMBL_HINTS');
    
    if (!window.name) {
      window.name = 'ensembl_' + new Date().getTime() + '_' + Math.floor(Math.random() * 10000);
    }
    
    (this.ajax  = this.cookie.get('ENSEMBL_AJAX'))  || this.setAjax();
    (this.width = this.cookie.get('ENSEMBL_WIDTH')) || this.setWidth();
    
    this.hideHints = {};
    
    if (hints) {
      $.each(hints.split(/:/), function () {
        myself.hideHints[this] = 1;
      });
    }
    
    // Store image panel details for highlighting
    this.images = {
      total: $('.image_panel').length,
      last: $('.image_panel:last')[0]
    }
    
    this.setCoreParams();
    
    this.LayoutManager.initialize();
    this.PanelManager.initialize();
  },
   
  cookie: {
    set: function (name, value, expiry) {  
      document.cookie = escape(name) + '=' + escape(value || '') +
      '; expires=' + (expiry == -1 ? 'Thu, 01 Jan 1970' : 'Tue, 19 Jan 2038') +
      ' 00:00:00 GMT; path=/';
    },
    
    get: function (name) {
      var cookie = document.cookie.match(new RegExp('(^|;)\\s*' + escape(name) + '=([^;\\s]*)'));
      return cookie ? unescape(cookie[2]) : '';
    }
  },
  
  setAjax: function () {
    this.ajax = ($.ajaxSettings.xhr() || false) ? 'enabled' : 'none';
    this.cookie.set('ENSEMBL_AJAX', this.ajax);
  },
  
  setWidth: function () {
    var w = Math.floor(($(window).width() - 250) / 100) * 100;
    
    this.width = w < 500 ? 500 : w;
    this.cookie.set('ENSEMBL_WIDTH', this.width);
  },
  
  setCoreParams: function () {
    var myself = this;
    
    var regex = '[;&?]%s=(.+?)[;&]';
    var url = window.location.search + ';';
    
    this.coreParams = {};
    this.location = { width: 100000 };
    this.species = window.location.pathname.split('/')[1];
    this.multiSpecies = {};
    
    $.each(['r', 'g', 't', 'v'], function () {
      myself.coreParams[this] = url.match(regex.replace('%s', this));
      
      if (myself.coreParams[this]) {
        myself.coreParams[this] = unescape(myself.coreParams[this][1]);
      }
    });
    
    var match = (this.coreParams.r ? this.coreParams.r.match(/(.+):(\d+)-(\d+)/) : false) || ($('a', '#tab_location').html() || '').replace(/,/g, '').match(/^Location: (.+):(\d+)-(\d+)$/);
    
    if (match) {
      this.location = { name: match[1], start: parseInt(match[2]), end: parseInt(match[3]) };
      this.location.width = this.location.end - this.location.start + 1;
      
      if (this.location.width > 1000000) {
        this.location.width = 1000000;
      }
    }
    
    match = url.match(/s\d+=.+?[;&]/g);
    
    if (match) {      
      var m, i, r;
      
      $.each(match, function () {
        m = this.split('=');
        i = m[0].substr(1);
        
        myself.multiSpecies[i] = {};
        
        $.each(['r', 'g', 's'], function () {
          myself.multiSpecies[i][this] = url.match(regex.replace('%s', this + i));
          
          if (myself.multiSpecies[i][this]) {
            myself.multiSpecies[i][this] = unescape(myself.multiSpecies[i][this][1]);
          }
          
          if (this == 'r' && myself.multiSpecies[i].r) {
            r = myself.multiSpecies[i].r.match(/(.+):(\d+)-(\d+)/);
            
            myself.multiSpecies[i].location = { name: r[1], start: parseInt(r[2]), end: parseInt(r[3]) };
          }
        });
      });
    }
  },
  
  // Remove the old time stamp from a URL and replace with a new one
  replaceTimestamp: function (url) {
    var d = new Date();
    var time = d.getTime() + d.getMilliseconds() / 1000;
    
    url = url.replace(/&/g, ';').replace(/#.*$/g, '').replace(/\?time=[^;]+;?/g, '?').replace(/;time=[^;]+;?/g, ';').replace(/[\?;]$/g, '');
    url += (url.match(/\?/) ? ';' : '?') + 'time=' + time;
    
    return url;
  }
});
