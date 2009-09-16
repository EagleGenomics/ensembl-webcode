// $Revision$

Ensembl.Panel.ZMenu = Ensembl.Panel.extend({
  constructor: function (id, data) {
    this.base(id);
    
    var area = $(data.area.a);
    
    this.drag   = area.hasClass('drag') ? 'drag' : area.hasClass('vdrag') ? 'vdrag' : false;
    this.align  = area.hasClass('align'); // TODO: implement alignslice menus
    this.href   = area.attr('href');
    this.title  = area.attr('title');
    this.das    = false;
    this.mutli  = '';
    
    if (area.hasClass('das')) {
      this.das = area.hasClass('group') ? 'group' : area.hasClass('pseudogroup') ? 'pseudogroup' : 'feature';
      this.logicName = area.attr('class').replace(/das/, '').replace(/(pseudo)?group/, '').replace(/ /g, '');
    }
    
    if (this.drag) {
      var params = this.href.split('|');
      
      this.species = params[3];
      this.chr     = params[4];
      this.start   = parseInt(params[5]);
      this.end     = parseInt(params[6]);
      this.strand  = parseInt(params[7]);
      
      var n = parseInt(params[1]) - 1;
      
      this.multi = area.hasClass('multi') ? n : false;
    }
    
    area = null;
    
    this.position = data.position;
    this.coords = data.coords;
    this.areaCoords = $.extend({}, data.area);
    this.location = 0;
    
    delete this.areaCoords.a;
    
    Ensembl.EventManager.register('showExistingZMenu', this, this.showExisting);
  },
  
  init: function () {
    var myself = this;
    
    var r = new RegExp('([\\?;]r' + (this.multi || '') + '=)[^;]+;?', 'g'); // The r parameter to remove from the current URL for this.baseURL
    
    this.base();
    
    this.elLk.caption = $('span.title', this.el);
    this.elLk.tbody = $('tbody', this.el);
    
    $(this.el).mousedown(function () {
      Ensembl.EventManager.trigger('panelToFront', myself.id);
    });
    
    $('.close', this.el).click(function () { 
      myself.hide();
    });
    
    // The location parameter that is due to be changed has its value replaced with %s
    this.baseURL = window.location.href.replace(/&/g, ';').replace(/#.*$/g, '').replace(r, '$1%s;').replace(/[\?;]$/g, '');
    
    // Add r parameter if it doesn't exist already
    if (!this.baseURL.match(/%s/)) {
      this.baseURL += (this.baseURL.match(/\?/) ? ';' : '?') + 'r=%s';
    }
    
    if (this.multi) {
      var s = new RegExp('\/' + Ensembl.species + '\/');
      var paralogue = this.baseURL.match(new RegExp('s(\\d+)=' + Ensembl.species + '\\b'));
     
      // We have the same species as primary and secondary. Remove it as secondary.
      if (paralogue) {
        this.baseURL = this.baseURL
          .replace(new RegExp(paralogue[0] + '[&;]?'), '')
          .replace(new RegExp('r' + paralogue[1] + '=[^&;]*[&;]?'), '')
          .replace(new RegExp('g' + paralogue[1] + '=[^&;]*[&;]?'), '');
      }
      
      this.baseURL = this.baseURL
        .replace(this.species, Ensembl.species).replace(s, '/' + this.species + '/') // Switch species
        .replace(/%s/, Ensembl.coreParams.r).replace(/r=[^&;]*([&;]?)/, 'r=%s$1')    // Switch r for new species' region
        .replace(/align=\d+[&;]?/, '')                                               // Remove align parameter when changing species
        .replace(/;$/, '');
    }
    
    // Clear secondary regions so all species will be realigned
    // Do this always (not just when this.multi is true) because any change in location should result in a new alignment
    this.baseURL = this.baseURL.replace(/r\d+=[^;]+;?/, '');
    
    this.getContent();
  },
  
  getContent: function () {
    var myself = this;
    
    this.populated = false;
    
    setTimeout(function () {
      if (myself.populated === false) {
        myself.elLk.caption.html('<p class="spinner" style="font-weight:normal">Loading component</p>');
        myself.show();
      }
    }, 300);
  
    if (this.drag == 'drag') {
      this.populateRegion();
    } else if (this.drag == 'vdrag') {
      this.populateVRegion();
    } else if (this.das !== false && Ensembl.ajax == 'enabled') {
      this.populateDas();
    } else if (!this.href) {
      this.populate();
    } else if (this.href.match(/#/)) {
      this.populate(true);
    } else if (Ensembl.ajax == 'enabled') {
      this.populateAjax();
    } else {
      this.populateNoAjax();
    }
  },
  
  populate: function (link, extra) {
    var arr = this.title.split('; ');
    var caption = arr.shift();
    
    this.buildMenu(arr, caption, link, extra);
  },
  
  populateDas: function () {
    var strandMap = { '+': 1, '-': -1 };
    
    var start  = this.title.match(/Start: (\d+)/)[1];
    var end    = this.title.match(/End: (\d+)/)[1];
    var strand = this.title.match(/Strand: ([-+])/)[1];
    
    var url = window.location.pathname.replace(/\/(\w+)\/\w+$/, '/Zmenu/$1/Das') +
      '?logic_name=' + this.logicName +
      ';' + this.das + '_id=' + this.title.split('; ')[0] +
      ';start=' + start + 
      ';end=' + end + 
      ';strand=' + strandMap[strand] + 
      ';click_start=' + this.coords.clickStart + 
      ';click_end=' + this.coords.clickEnd;
      
    for (var p in Ensembl.coreParams) {
      if (Ensembl.coreParams[p]) {
        url += ';' + p + '=' + Ensembl.coreParams[p];
      }
    }
    
    this.populateAjax(url);
  },
  
  populateAjax: function (url) {
    var myself = this;
    
    url = url || this.href.replace(/\/(\w+\/\w+)\?/, '/Zmenu/$1?');
    
    if (url) {
      $.ajax({
        url: url,
        dataType: 'json',
        success: function (json) {
          myself.populated = true;
          
          if (json.entries.length) {
            var body = '';
            var row;
            
            for (var i in json.entries) {
              if (json.entries[i].type == 'subheader') {
                row = '<th class="subheader" colspan="2">' + json.entries[i].link + '</th>';
              } else if (json.entries[i].type) {
                row = '<th>' + json.entries[i].type + '</th><td>' + json.entries[i].link + '</td>';
              } else {
                row = '<td colspan="2">' + json.entries[i].link + '</td>';
              }
              
              body += '<tr>' + row + '</tr>';
            }
            
            myself.elLk.tbody.html(body);
            myself.elLk.caption.html(json.caption);
            
            myself.show();
          } else {
            myself.populateNoAjax();
          }
        },
        error: function () {
          myself.populateNoAjax();
        }
      });
    } else {
      this.populateNoAjax();
    }
  },
  
  populateNoAjax: function () {
    var extra = '';
    var loc = this.title.match(/Location: (\S+)/);
    
    if (loc) {          
      var r = loc[1].split(/\W/);
      this.location = parseInt(r[1]) + (r[2] - r[1]) / 2;
      
      extra += '<tr><th></th><td><a href="' + this.zoomURL(1) + '">Centre on feature</a></td></tr>';
      extra += '<tr><th></th><td><a href="' + this.baseURL.replace(/%s/, loc[1]) + '">Zoom to feature</a></td></tr>';
    }
    
    this.populate(true, extra);
  },
  
  populateRegion: function () {
    var myself = this;
    
    var start, end, tmp, href;
    var arr, caption;
    
    var min = this.start;
    var max = this.end;
    
    var scale = (max - min + 1) / (this.areaCoords.r - this.areaCoords.l);
    
    var url = this.baseURL;
    
    // Region select
    if (this.coords.r) {
      start = Math.floor(min + (this.coords.s - this.areaCoords.l) * scale);
      end   = Math.floor(min + (this.coords.s + this.coords.r - this.areaCoords.l) * scale);
      
      if (start > end) {
        tmp = start;
        start = end;
        end = tmp;
      }
      
      if (start < min) {
        start = min;
      }
      
      if (end > max) {
        end = max;
      }
      
      if (this.strand == 1) {
        this.location = (start + end) / 2;
      } else {
        this.location = (2 * this.start + 2 * this.end - start - end) / 2;
        
        var temp = start;
        start = this.end + this.start - end;
        end   = this.end + this.start - temp;
      }
      
      if (this.align) {
        url = url.replace(/r=%s/, 'c=' + Ensembl.location.name + ':' + (this.location + Ensembl.location.start) + ';w=' + (end - start)); // TODO: currently disabled
      } else {
        url = url.replace(/%s/, this.chr + ':' + start + '-' + end);
      }
      
      arr = [
        '<a href="' + url + '">Jump to region (' + (end - start) + ' bp)</a>',
        '<a href="' + this.zoomURL(1) + '">Centre here</a>'
      ];
      
      caption = (this.multi === false ? 'Region: ' : this.species.replace(/_/g, ' ') + ' ' + this.chr + ':') + start + '-' + end;
    } else {
      this.location = Math.floor(min + (this.coords.x - this.areaCoords.l) * scale);
      
      arr = [
        '<a href="' + this.zoomURL(10) + '">Zoom out x10</a>',
        '<a href="' + this.zoomURL(5)  + '">Zoom out x5</a>',
        '<a href="' + this.zoomURL(2)  + '">Zoom out x2</a>',
        '<a href="' + this.zoomURL(1)  + '">Centre here</a>'
      ];
      
      // Only add zoom in links if there is space to zoom in to.
      $.each([2, 5, 10], function () {
        href = myself.zoomURL(1 / this);
        
        if (href !== '') {
          arr.push('<a href="' + href + '">Zoom in x' + this + '</a>');
        }
      });
      
      caption = (this.multi === false ? 'Location: ' : this.species.replace(/_/g, ' ') + ' ' + this.chr + ':') + this.location;
    }
    
    this.buildMenu(arr, caption);
  },
  
  populateVRegion: function () {
    var start, end, view, arr, caption, tmp, url;
    
    var min = this.start;
    var max = this.end;
    
    var scale = (max - min + 1) / (this.areaCoords.b - this.areaCoords.t);
    
    // Region select
    if (this.coords.r) {
      view = 'Overview';
      
      start = Math.floor(min + (this.coords.s - this.areaCoords.t) * scale);
      end   = Math.floor(min + (this.coords.s + this.coords.r - this.areaCoords.t) * scale);
      
      if (start > end) {
        tmp = start;
        start = end;
        end = tmp;
      }
      
      if (start < min) {
        start = min;
      }
      
      if (end > max) {
        end = max;
      }
      
      this.location = (start + end) / 2;
      
      caption = this.chr + ': ' + start + '-' + end;
    } else {
      view = 'View';
      
      this.location = Math.floor(min + (this.coords.y - this.areaCoords.t) * scale);
      
      start = Math.floor(this.location - (Ensembl.location.width / 2));
      end   = Math.floor(this.location + (Ensembl.location.width / 2));
      
      if (start < 1) {
        start = 1;
      }
      
      caption = this.chr + ': ' + this.location;
    }
    
    url = this.baseURL.replace(/.+\?/, '?').replace(/%s/, this.chr + ':' + start + '-' + end);
    
    arr = [
      '<a href="/' + this.species + '/Location/' + view + url + '">Jump to location ' + view + '</a>',
      '<a href="/' + this.species + '/Location/Chromosome' + url + '">Chromosome summary</a>'
    ];
    
    this.buildMenu(arr, caption);
  },
  
  buildMenu: function (content, caption, link, extra) {
    var body = '';
    var arr, title;
    
    caption = caption || 'Menu';
    extra = extra || '';
    
    if (link === true && this.href) {
      title = this.title ? this.title.split('; ')[0] : caption;
      extra = '<tr><th>Link</th><td><a href="' + this.href + '">' + title + '</a></td></tr>' + extra;
    }
    
    $.each(content, function () {
      arr = this.split(': ');
      body += '<tr>' + (arr.length == 2 ? '<th>' + arr[0] + '</th><td>' + arr[1] + '</td>' : '<td colspan="2">' + this + '</td>') + '</tr>';
    });
    
    this.populated = true;
    
    this.elLk.tbody.html(body + extra);
    this.elLk.caption.html(caption);
    
    this.show();
  },
  
  zoomURL: function (scale) {
    var w = Ensembl.location.width * scale;
    
    if (w < 1) {
      return '';
    }
    
    if (this.align === true) {
      return this.baseURL.replace(/r=%s/, 'c=' + Ensembl.location.name + ':' + (Ensembl.location.start + this.location) + ';w=' + Math.round(w)); // TODO: currently disabled
    } else {
      var start = Math.round(this.location - (w - 1) / 2);
      var end   = Math.round(this.location + (w - 1) / 2); // No constraints on end - can't know how long the chromosome is, and perl will deal with overflow
      
      if (start < 1) {
        start = this.start;
      }
      
      return this.baseURL.replace(/%s/, this.chr + ':' + start + '-' + end);
    }
  },
  
  show: function () {
    var menuWidth = parseInt(this.width());
    var windowWidth = $(window).width() - 10;
    
    var css = {
      left: this.position.left, 
      top: this.position.top,
      position: 'absolute'
    };
    
    if (this.position.left + menuWidth > windowWidth) {
      css.left = windowWidth - menuWidth;
    }
    
    Ensembl.EventManager.trigger('panelToFront', this.id);
    
    $(this.el).css(css);
    
    this.base();
  },

  showExisting: function (data) {
    this.position = data.position;
    this.coords = data.coords;
    
    if (this.das == 'group' || this.das == 'pseudogroup' || this.drag) {
      this.elLk.tbody.empty();
      this.elLk.caption.empty();
      this.hide();
      this.getContent();
    } else {
      this.show();
    };
  }
});
