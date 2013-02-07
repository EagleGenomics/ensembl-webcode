// $Revision$

Ensembl.Panel.ZMenu = Ensembl.Panel.extend({
  constructor: function (id, data) {
    this.base(id);
    
    var area = $(data.area.a);
    var params, n;
    
    this.drag       = area.hasClass('drag') ? 'drag' : area.hasClass('vdrag') ? 'vdrag' : false;
    this.align      = area.hasClass('align'); // TODO: implement alignslice menus
    this.group      = area.hasClass('group') || area.hasClass('pseudogroup');
    this.coloured   = area.hasClass('coloured');
    this.href       = area.attr('href');
    this.title      = area.attr('title') || '';
    this.das        = false;
    this.position   = data.position;
    this.coords     = data.coords;
    this.imageId    = data.imageId;
    this.relatedEl  = data.relatedEl;
    this.areaCoords = $.extend({}, data.area);
    this.maxLength  = 1e6;
    this.location   = 0;
    
    if (area.hasClass('das')) {
      this.das       = area.hasClass('group') ? 'group' : area.hasClass('pseudogroup') ? 'pseudogroup' : 'feature';
      this.logicName = area.attr('class').replace(/das/, '').replace(/(pseudo)?group/, '').replace(/ /g, '');
    }
    
    if (this.drag) {
      params = this.href.split('|');
      n      = parseInt(params[1], 10) - 1;
      
      this.speciesPath = params[3].replace(/-/, '/');
      this.species     = this.speciesPath.split('/').pop();
      this.chr         = params[4];
      this.start       = parseInt(params[5], 10);
      this.end         = parseInt(params[6], 10);
      this.strand      = parseInt(params[7], 10);
      this.multi       = area.hasClass('multi') ? n : false;
      
      if (!this.speciesPath.match(/^\//)) {
        this.speciesPath = '/' + this.speciesPath;
      }
    }
    
    area = null;
    
    delete this.areaCoords.a;
    
    Ensembl.EventManager.register('showExistingZMenu', this, this.showExisting);
    Ensembl.EventManager.register('hideZMenu',         this, this.hide);
  },
  
  init: function () {
    var panel = this;
    var r     = new RegExp('([\\?;]r' + (this.multi || '') + '=)[^;]+;?', 'g'); // The r parameter to remove from the current URL for this.baseURL
    
    this.base();
    
    this.elLk.caption = $('span.title', this.el);
    this.elLk.tbody   = $('tbody:last', this.el);
    this.elLk.loading = $('.loading',   this.el);
    
    this.el.on('mousedown', function () {
      Ensembl.EventManager.trigger('panelToFront', panel.id);
    }).on('click', 'a.location_change', function () {
      var locationMatch = this.href.match(Ensembl.locationMatch);
      
      if (locationMatch && locationMatch[1] !== Ensembl.coreParams.r) {
        Ensembl.updateLocation(locationMatch[1]);
        panel.hide();
        return false;
      }
    });
    
    $('.close', this.el).on('click', function () { 
      panel.hide();
    });
    
    // The location parameter that is due to be changed has its value replaced with %s
    this.baseURL = window.location.href.replace(/&/g, ';').replace(/#.*$/g, '').replace(r, '$1%s;').replace(/[\?;]$/g, '');
    
    // Add r parameter if it doesn't exist already
    if (!this.baseURL.match(/%s/)) {
      this.baseURL += (this.baseURL.match(/\?/) ? ';' : '?') + 'r=%s';
    }
    
    if (this.multi) {
      // Remove align parameter when changing species
      this.baseURL = this.baseURL.replace(/align=\d+;?/, '').replace(/;$/, '') + ';action=primary;id=' + this.multi;
    }
    
    // Clear secondary regions so all species will be realigned - any change in primary species location should result in a new alignment
    if (this.multi === false) {
      this.baseURL = this.baseURL.replace(/r\d+=[^;]+;?/g, '');
    }
    
    if (this.coloured) {
      this.el.addClass('coloured');
    }
    
    this.el.on('click', 'a.expand', function () {
      panel.populateAjax(this.href, $(this).parents('tr'));
      return false;
    });
    
    this.getContent();
  },
  
  getContent: function () {
    var panel = this;
    
    this.populated = false;
    
    clearTimeout(this.timeout);
    
    this.timeout = setTimeout(function () {
      if (panel.populated === false) {
        panel.elLk.caption.html('Loading component');
        panel.elLk.tbody.hide();
        panel.elLk.loading.show();
        panel.show(panel.das);
      }
    }, 300);
  
    if (this.drag === 'drag') {
      this.populateRegion();
    } else if (this.drag === 'vdrag') {
      this.populateVRegion();
    } else if (this.das !== false) {
      this.populateDas();
    } else if (!this.href) {
      this.populate();
    } else if (this.href.match(/#/)) {
      this.populate(true);
    } else {
      this.populateAjax();
    }
  },
  
  populate: function (link, extra) {
    var menu    = this.title.split('; ');
    var caption = menu.shift();
    
    this.buildMenu(menu, caption, link, extra);
  },
  
  populateDas: function () {
    var strandMap = { '+': 1, '-': -1 };
    var start     = this.title.match(/Start: (\d+)/)[1];
    var end       = this.title.match(/End: (\d+)/)[1];
    var strand    = (this.title.match(/Strand: ([-+])/) || [])[1];
    var id        = this.title.match(/; Id: ([^;]+)$/)[1];
    var url       = [
      window.location.pathname.replace(/\/(\w+)\/\w+$/, '/ZMenu/$1/Das'),
      '?logic_name=', this.logicName,
      ';', this.das, '_id=', id,
      ';start=', start, 
      ';end=', end,
      ';strand=', strandMap[strand],
      ';label=', this.title.split('; ')[0]
    ].join('');
      
    for (var p in Ensembl.coreParams) {
      if (Ensembl.coreParams[p]) {
        url += ';' + p + '=' + Ensembl.coreParams[p];
      }
    }
    
    this.populateNoAjax(true); // Always parse the title tag
    this.populateAjax(url);
  },
  
  populateAjax: function (url, expand) {
    var timeout = this.timeout;
    var caption = this.elLk.caption.html();
        url     = url || this.href;
    
    if (this.group) {
      url += ';click_start=' + this.coords.clickStart + ';click_end=' + this.coords.clickEnd;
    }
    
    if (url && url.match(/\/ZMenu\//)) {
      $.ajax({
        url: url,
        dataType: 'json',
        context: this,
        success: function (json) {
          if (timeout === this.timeout) {
            this.populated = true;
            
            if (json.entries.length) {
              var body = '';
              var subheader, row;
              
              for (var i in json.entries) {
                if (json.entries[i].type === 'subheader') {
                  subheader = subheader || json.entries[i].link;
                  
                  if (json.entries[i].link !== caption) {
                    row = '<th class="subheader" colspan="2">' + json.entries[i].link + '</th>';
                  }
                } else if (json.entries[i].type) {
                  row = '<th>' + json.entries[i].type + '</th><td>' + json.entries[i].link + '</td>';
                } else {
                  row = '<td colspan="2">' + json.entries[i].link + '</td>';
                }
                
                body += '<tr>' + row + '</tr>';
              }
              
              if (expand) {
                expand.replaceWith(body);
                expand = null;
              } else {
                this.elLk.tbody.html(function (j, html) { return caption && caption === (subheader || json.caption) ? body : html + body; }).find('a.update_panel').attr('rel', this.imageId);
                this.elLk.caption.html(json.caption);
                
                this.show();
              }
            } else {
              this.populateNoAjax();
            }
          }
        },
        error: function () {
          this.populateNoAjax();
        }
      });
    } else {
      this.populateNoAjax();
    }
  },
  
  populateNoAjax: function (force) {
    if (this.das && force !== true) {
      this.populated = true;
      
      if (this.elLk.caption.html() === 'Loading component') {
        this.elLk.caption.html(this.title.split('; ')[0]);
      }
      
      this.show();
      
      return;
    }
    
    var extra = '';
    var loc   = this.title.match(/Location: (\S+)/);
    var r;
    
    if (loc) {          
      r = loc[1].split(/\W/);
      
      this.location = parseInt(r[1], 10) + (r[2] - r[1]) / 2;
      
      extra += '<tr><th></th><td><a href="' + this.zoomURL(1) + '">Centre on feature</a></td></tr>';
      extra += '<tr><th></th><td><a href="' + this.baseURL.replace(/%s/, loc[1]) + '">Zoom to feature</a></td></tr>';
    }
    
    this.populate(true, extra);
  },
  
  populateRegion: function () {
    var panel        = this;
    var min          = this.start;
    var max          = this.end;
    var locationView = !!window.location.pathname.match('/Location/') && !window.location.pathname.match(/\/(Chromosome|Synteny)/);
    var scale        = (max - min + 1) / (this.areaCoords.r - this.areaCoords.l);
    var url          = this.baseURL;
    var menu, caption, start, end, tmp;
    
    // Gene, transcript views
    function notLocation() {
      var view = end - start + 1 > Ensembl.maxRegionLength ? 'Overview' : 'View';
          url  = url.replace(/.+\?/, '?');
          menu = [ '<a href="' + panel.speciesPath + '/Location/' + view + url + '">Jump to location ' + view.toLowerCase() + '</a>' ];
      
      if (!window.location.pathname.match('/Chromosome')) {
        menu.push('<a href="' + panel.speciesPath + '/Location/Chromosome' + url + '">Chromosome summary</a>');
      }
    }
    
    // Multi species view
    function multi() {
      var label = start ? 'region' : 'location';
          menu  = [ '<a href="' + url.replace(/;action=primary;id=\d+/, '') + '">Realign using this ' + label + '</a>' ];
        
      if (panel.multi) {
        menu.push('<a href="' + url + '">Use ' + label + ' as primary</a>');
      } else {
        menu.push('<a href="' + url.replace(/[rg]\d+=[^;]+;?/g, '') + '">Jump to ' + label + '</a>');
      }
    
      caption = panel.species.replace(/_/g, ' ') + ' ' + panel.chr + ':' + (start ? start + '-' + end : panel.location);
    }
    
    // AlignSlice view
    function align() {
      var label  = start ? 'region' : 'location';
          label += panel.species === Ensembl.species ? '' : ' on ' + Ensembl.species.replace(/_/g, ' ');
      
      menu    = [ '<a href="' + url.replace(/%s/, Ensembl.coreParams.r + ';align_start=' + start + ';align_end=' + end) + '">Jump to best aligned ' + label + '</a>' ];
      caption = 'Alignment: ' + (start ? start + '-' + end : panel.location);
    }
    
    // Region select
    if (this.coords.r) {
      start = Math.floor(min + (this.coords.s - this.areaCoords.l) * scale);
      end   = Math.floor(min + (this.coords.s + this.coords.r - this.areaCoords.l) * scale);
      
      if (start > end) {
        tmp   = start;
        start = end;
        end   = tmp;
      }
      
      start = Math.max(start, min);
      end   = Math.min(end,   max);
      
      if (this.strand === 1) {
        this.location = (start + end) / 2;
      } else {
        this.location = (2 * this.start + 2 * this.end - start - end) / 2;
        
        tmp   = start;
        start = this.end + this.start - end;
        end   = this.end + this.start - tmp;
      }
      
      if (this.align === true) {
        align();
      } else {
        url     = url.replace(/%s/, this.chr + ':' + start + '-' + end);
        caption = 'Region: ' + this.chr + ':' + start + '-' + end;
        
        if (!locationView) {
          notLocation();
        } else if (this.multi !== false) {
          multi();
        } else {
          menu = [
            '<a class="location_change" href="' + url + '">Jump to region (' + (end - start + 1) + ' bp)</a>',
            '<a class="location_change" href="' + this.zoomURL(1) + '">Centre here</a>'
          ];
        }
      }
    } else { // Point select
      this.location = Math.floor(min + (this.coords.x - this.areaCoords.l) * scale);
      
      if (this.align === true) {
        url = this.zoomURL(1/10);
        align();
      } else {
        url     = this.zoomURL(1);
        caption = 'Location: ' + this.chr + ':' + this.location;
        
        if (!locationView) {
          notLocation();
        } else if (this.multi !== false) {
          multi();
        } else {
          menu = [
            '<a class="location_change" href="' + this.zoomURL(10) + '">Zoom out x10</a>',
            '<a class="location_change" href="' + this.zoomURL(5)  + '">Zoom out x5</a>',
            '<a class="location_change" href="' + this.zoomURL(2)  + '">Zoom out x2</a>',
            '<a class="location_change" href="' + url + '">Centre here</a>'
          ];
          
          // Only add zoom in links if there is space to zoom in to.
          $.each([2, 5, 10], function () {
            var href = panel.zoomURL(1 / this);
            
            if (href !== '') {
              menu.push('<a class="location_change" href="' + href + '">Zoom in x' + this + '</a>');
            }
          });
        }
      }
    }
    
    this.buildMenu(menu, caption);
  },
  
  populateVRegion: function () {
    var min    = this.start;
    var max    = this.end;
    var scale  = (max - min + 1) / (this.areaCoords.b - this.areaCoords.t);
    var length = Math.min(Ensembl.location.length, this.maxLength) / 2;
    var start, end, view, menu, caption, tmp, url;
    
    if (scale === max) {
      scale /= 2; // For very small images, halve the scale. This will stop start > end problems
    }
    
    // Region select
    if (this.coords.r) {
      start = Math.floor(min + (this.coords.s - this.areaCoords.t) * scale);
      end   = Math.floor(min + (this.coords.s + this.coords.r - this.areaCoords.t) * scale);
      view  = end - start + 1 > Ensembl.maxRegionLength ? 'Overview' : 'View';
      
      if (start > end) {
        tmp   = start;
        start = end;
        end   = tmp;
      }
      
      start   = Math.max(start, min);
      end     = Math.min(end,   max);
      caption = this.chr + ': ' + start + '-' + end;
      
      this.location = (start + end) / 2;
    } else {
      this.location = Math.floor(min + (this.coords.y - this.areaCoords.t) * scale);
      
      view    = 'View';
      start   = Math.max(Math.floor(this.location - length), 1);
      end     =          Math.floor(this.location + length);
      caption = this.chr + ': ' + this.location;
    }
    
    url  = this.baseURL.replace(/.+\?/, '?').replace(/%s/, this.chr + ':' + start + '-' + end);
    menu = [ '<a href="' + this.speciesPath + '/Location/' + view + url + '">Jump to location ' + view.toLowerCase() + '</a>' ];
    
    if (!window.location.pathname.match('/Chromosome')) {
      menu.push('<a href="' + this.speciesPath + '/Location/Chromosome' + url + '">Chromosome summary</a>');
    }
    
    this.buildMenu(menu, caption);
  },
  
  buildMenu: function (content, caption, link, extra) {
    var body = [];
    var i    = content.length;
    var menu, title, parse, j, row;
    
    caption = caption || 'Menu';
    extra   = extra   || '';
    
    if (link === true && this.href) {
      title = this.title ? this.title.split('; ')[0] : caption;
      extra = '<tr><th>Link</th><td><a href="' + this.href + '">' + title + '</a></td></tr>' + extra;
    }
    
    while (i--) {
      parse = this.coloured ? content[i].match(/\[(.+)\]/) : null;
      
      if (parse) {
        parse = parse[1].split(',');
        
        for (j = 0; j < parse.length; j += 2) {
          parse[j] = parse[j].split(':');
          row      = '<td style="color:#' + parse[j][1] + '">' + parse[j][0] + '</td>';
          
          if (parse[j+1]) {
            parse[j+1] = parse[j+1].split(':');
            row       += '<td style="color:#' + parse[j+1][1] + '">' + parse[j+1][0] + '</td>';
          } else {
            row += '<td></td>';
          }
          
          body.push('<tr>' + row + '</tr>');
        }
      } else {
        menu = content[i].split(': ');  
        body.unshift('<tr>' + (menu.length > 1 ? '<th>' + menu.shift() + '</th><td>' + menu.join(': ') + '</td>' : '<td colspan="2">' + content[i] + '</td>') + '</tr>');
      }
    }
    
    this.elLk.tbody.html(body.join('') + extra);
    this.elLk.caption.html(caption);
    
    if (this.das) {
      this.elLk.tbody.hide();
    } else {
      this.populated = true;
      this.show();
    }
  },
  
  zoomURL: function (scale) {
    var w = Math.min(Ensembl.location.length, this.maxLength) * scale;
    
    if (w < 1) {
      return '';
    }
    
    var start = Math.round(this.location - (w - 1) / 2);
    var end   = Math.round(this.location + (w - 1) / 2); // No constraints on end - can't know how long the chromosome is, and perl will deal with overflow
    
    if (start < 1) {
      start = this.start;
    }
    
    if (this.align === true) {
      return this.baseURL.replace(/%s/, Ensembl.coreParams.r + ';align_start=' + start + ';align_end=' + end);
    } else {
      return this.baseURL.replace(/%s/, (this.chr || Ensembl.location.name) + ':' + start + '-' + end);
    }
  },
  
  show: function (loading) {
    var menuWidth   = parseInt(this.width(), 10);
    var windowWidth = $(window).width() - 10;
    var scrollLeft  = $(window).scrollLeft();
    
    var css = {
      left:     this.position.left, 
      top:      this.position.top,
      position: 'absolute'
    };
    
    if (this.position.left + menuWidth - scrollLeft > windowWidth) {
      css.left = windowWidth + scrollLeft - menuWidth;
    }
    
    if (!loading && this.elLk.tbody.html()) {
      this.elLk.loading.hide();
      this.elLk.tbody.show();
    }
    
    Ensembl.EventManager.trigger('panelToFront', this.id);
    
    this.el.css(css);
    
    this.base();
    
    if (this.relatedEl) {      
      this.relatedEl.addClass('highlight');
    }
  },

  showExisting: function (data) {
    this.position = data.position;
    this.coords   = data.coords;
    
    if (this.group || this.drag) {
      this.elLk.tbody.empty();
      this.elLk.caption.empty();
      this.hide();
      this.getContent();
    } else {
      this.show();
    }
  },
  
  hide: function (imageId) {
    if (this.el && (!imageId || imageId === this.imageId)) {
      this.base();
      
      if (this.relatedEl) {
        this.relatedEl.removeClass('highlight');
      }
    }
  }
});
