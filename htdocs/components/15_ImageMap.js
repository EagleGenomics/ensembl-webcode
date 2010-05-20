// $Revision$

Ensembl.Panel.ImageMap = Ensembl.Panel.Content.extend({
  constructor: function (id, params) {
    this.base(id, params);
    
    this.dragging         = false;
    this.clicking         = true;
    this.dragCoords       = {};
    this.dragRegion       = {};
    this.highlightRegions = {};
    this.areas            = [];
    this.draggables       = [];
    this.speciesCount     = 0;
    
    Ensembl.EventManager.register('highlightImage', this, this.highlightImage);
    Ensembl.EventManager.register('dragStop', this, this.dragStop);
    Ensembl.EventManager.register('hashChange', this, this.hashChange);
    
    Ensembl.EventManager.register('highlightAllImages', this, function () {
      if (!this.align) {
        this.highlightAllImages();
      }
    });
  },
  
  init: function () {
    var myself = this;
    
    this.base();
    
    this.lastImage = $(this.el).parents('.image_panel')[0] == Ensembl.images.last;
    this.params.highlight = (Ensembl.images.total == 1 || !this.lastImage);
    
    this.elLk.map        = $('map', this.el);
    this.elLk.img        = $('img.imagemap', this.el);
    this.elLk.areas      = $('area', this.elLk.map);
    this.elLk.exportMenu = $('.iexport_menu', this.el);
    
    this.vdrag = this.elLk.areas.hasClass('vdrag');
    this.multi = this.elLk.areas.hasClass('multi');
    this.align = this.elLk.areas.hasClass('align');
    
    this.makeImageMap(); 
    
    $('.iexport a', this.el).click(function () {
      myself.elLk.exportMenu.css({ left: $(this).offset().left }).toggle();

      return false;
    });
  },
  
  hashChange: function (r) {
    this.params.updateURL = Ensembl.urlFromHash(this.params.updateURL);
    
    if (Ensembl.images.total == 1) {
      this.highlightAllImages();
    } else if (this.lastImage) {
      this.base();
    } else if (!this.multi) {
      var range = this.highlightRegions[0][0].region.range;
      r = r.split(/\W/);
      
      if (parseInt(r[1], 10) < range.start || parseInt(r[2], 10) > range.end) {
        this.base();
      }
    }
    
    if (this.align) {
      Ensembl.EventManager.trigger('highlightAllImages');
    }
  },
  
  makeImageMap: function () {
    var myself = this;
    
    var highlight = !!(window.location.pathname.match(/\/Location\//) && !this.vdrag);
    var rect = [ 'l', 't', 'r', 'b' ];
    var speciesNumber, c;
    
    this.elLk.areas.each(function () {
      c = { a: this };
      
      if (this.shape && this.shape.toLowerCase() != 'rect') {
        c.c = [];
        $.each(this.coords.split(/[ ,]/), function () { c.c.push(parseInt(this, 10)); });
      } else {
        $.each(this.coords.split(/[ ,]/), function (i) { c[rect[i]] = parseInt(this, 10); });
      }
      
      myself.areas.push(c);
      
      if (this.className.match(/drag/)) {
        // r = [ '#drag', image number, species number, species name, region, start, end, strand ]
        var r     = c.a.href.split('|');
        var start = parseInt(r[5], 10);
        var end   = parseInt(r[6], 10);
        var scale = (end - start + 1) / (c.r - c.l); // bps per pixel on image
        
        c.range = { start: start, end: end, scale: scale };
        
        myself.draggables.push(c);
        
        if (highlight === true) {
          r = this.href.split('|');
          speciesNumber = parseInt(r[1], 10) - 1;
          
          if (myself.multi || !speciesNumber) {
            if (!myself.highlightRegions[speciesNumber]) {
              myself.highlightRegions[speciesNumber] = [];
              myself.speciesCount++;
            }
            
            myself.highlightRegions[speciesNumber].push({ region: c });
            myself.imageNumber = parseInt(r[2], 10);
            
            Ensembl.images[myself.imageNumber] = Ensembl.images[myself.imageNumber] || {};
            Ensembl.images[myself.imageNumber][speciesNumber] = [ myself.imageNumber, speciesNumber, parseInt(r[5], 10), parseInt(r[6], 10) ];
          }
        }
      }
    });
    
    if (Ensembl.images.total) {
      this.highlightAllImages();
    }
    
    this.elLk.img.bind({
      mousedown: function (e) {
        // Only draw the drag box for left clicks.
        // This property exists in all our supported browsers, and browsers without it will draw the box for all clicks
        if (!e.which || e.which == 1) {
          myself.dragStart(e);
        }
        
        return false;
      },
      click: function (e) {
        if (myself.clicking) {
          myself.makeZMenu(e, myself.getMapCoords(e));
        } else {
          myself.clicking = true;
        }
      }
    }).parent().mousemove(function (e) {
      var area = myself.getArea(myself.getMapCoords(e));
      
      if (area && area.a) {
        myself.elLk.img.attr({ title: area.a.alt });
      }
      
      area = null;
    });
  },
  
  dragStart: function (e) {
    var myself = this;
    
    this.dragCoords.map    = this.getMapCoords(e);
    this.dragCoords.page   = { x: e.pageX, y : e.pageY };
    this.dragCoords.offset = { x: e.pageX - this.dragCoords.map.x, y: e.pageY - this.dragCoords.map.y }; // Have to use this instead of the map coords because IE can't cope with offsetX/Y and relative positioned elements
    
    this.dragRegion = this.getArea(this.dragCoords.map, true);
    
    if (this.dragRegion) {
      this.elLk.img.mousemove(function (e2) {
        myself.dragging = e; // store mousedown event
        myself.drag(e2);
        return false;
      });
    }
  },
  
  dragStop: function (e) {
    this.elLk.img.unbind('mousemove');
    
    if (this.dragging !== false) {
      var diff = { 
        x: e.pageX - this.dragCoords.page.x, 
        y: e.pageY - this.dragCoords.page.y
      };
      
      // Set a limit below which we consider the event to be a click rather than a drag
      if (Math.abs(diff.x) < 3 && Math.abs(diff.y) < 3) {
        this.clicking = true; // Chrome fires mousemove even when there has been no movement, so catch clicks here
        this.makeZMenu(this.dragging, this.dragCoords.map); // use the original mousedown (stored in this.dragging) to create the zmenu
      } else {
        var range = this.vdrag ? { r: diff.y, s: this.dragCoords.map.y } : { r: diff.x, s: this.dragCoords.map.x };
        
        this.makeZMenu(e, range);
        
        this.dragging = false;
        this.clicking = false;
      }
    }
  },
  
  drag: function (e) {
    var coords = {};
    var x = e.pageX - this.dragCoords.offset.x;
    var y = e.pageY - this.dragCoords.offset.y;
    
    switch (x < this.dragCoords.map.x) {
      case true:  coords.l = x; coords.r = this.dragCoords.map.x; break;
      case false: coords.r = x; coords.l = this.dragCoords.map.x; break;
    }
    
    switch (y < this.dragCoords.map.y) {
      case true:  coords.t = y; coords.b = this.dragCoords.map.y; break;
      case false: coords.b = y; coords.t = this.dragCoords.map.y; break;
    }
    
    if (x < this.dragRegion.l) {
      coords.l = this.dragRegion.l;
    } else if (x > this.dragRegion.r) {
      coords.r = this.dragRegion.r;
    }
    
    if (y < this.dragRegion.t) {
      coords.t = this.dragRegion.t;
    } else if (y > this.dragRegion.b) {
      coords.b = this.dragRegion.b;
    }
    
    this.highlight(coords, 'rubberband', this.dragRegion.a.href.split('|')[3]);
  },
  
  makeZMenu: function (e, coords) {
    var area = coords.r ? this.dragRegion : this.getArea(coords);
    
    if (!area) {
      return;
    }
    
    if ($(area.a).hasClass('nav')) {
      Ensembl.redirect(area.a.href);
      return;
    }
    
    var id = 'zmenu_' + area.a.coords.replace(/[ ,]/g, '_');
    
    if (($(area.a).hasClass('das') || $(area.a).hasClass('group')) && this.highlightRegions) {
      var speciesNumber = 0;
      
      if (this.speciesCount > 1) {
        var dragArea = this.getArea(coords, true);
        
        if (dragArea) {
          speciesNumber = parseInt(dragArea.a.href.split('|')[1], 10) - 1;
        }
        
        dragArea = null;
      }
      
      var range = this.draggables[speciesNumber] ? this.draggables[speciesNumber].range : undefined;
      
      if (range) {
        var location, fuzziness;
        
        location  = range.start + (range.scale * (coords.x - this.dragRegion.l));
        fuzziness = range.scale * 2; // Increase the size of the click so we can have some measure of certainty for returning the right menu
        
        coords.clickStart = Math.floor(location - fuzziness);
        coords.clickEnd   = Math.ceil(location + fuzziness);
        
        if (coords.clickStart < range.start) {
          coords.clickStart = range.start;
        }
        
        if (coords.clickEnd > range.end) {
          coords.clickEnd = range.end;
        }
      }
    }
    
    Ensembl.EventManager.trigger('makeZMenu', id, { position: { left: e.pageX, top: e.pageY }, coords: coords, area: area, imageId: this.id });
  },
  
  /**
   * Triggers events to highlight all images on the page
   */
  highlightAllImages: function () {
    var image = Ensembl.images[this.imageNumber + 1] || Ensembl.images[this.imageNumber];
    var args, i;
    
    for (i in image) {
      args = image[i];
      this.highlightImage.apply(this, args);
    }
    
    if (!this.align && Ensembl.images[this.imageNumber - 1]) {
      image = Ensembl.images[this.imageNumber];
      
      for (i in image) {
        args = image[i].slice();
        args.unshift('highlightImage');
        
        Ensembl.EventManager.trigger.apply(Ensembl.EventManager, args);
      }
    }
  },
  
  /**
   * Highlights regions of the image.
   * In MultiContigView, each image can have numerous regions to highlight - one per species
   *
   * redbox:  Dotted red line outlining the draggable region of an image. 
   *          Only shown where an image displays a region contained in another region.
   *          In practice this means redbox never appears on the first image on the page.
   *
   * redbox2: Solid red line outlining the region of an image displayed on the next image.
   *          If there is only one image, or the next image has an invalid coordinate system 
   *          (eg AlignSlice or whole chromosome), highlighting is taken from the r parameter in the url.
   */
  highlightImage: function (imageNumber, speciesNumber, start, end) {
    // Make sure each image is highlighted based only on itself or the next image on the page
    if (!this.draggables.length || this.vdrag || imageNumber - this.imageNumber > 1 || imageNumber - this.imageNumber < 0) {
      return;
    }
    
    var highlight;
    var i = this.highlightRegions[speciesNumber].length;
    var link = true; // Defines if the highlighted region has come from another image or the url
    
    while (i--) {
      highlight = this.highlightRegions[speciesNumber][i];
      
      if (!highlight.region.a) {
        break;
      }
      
      // Highlighting base on self. Take start and end from Ensembl core parameters
      if (this.imageNumber == imageNumber) {
        // Don't draw the redbox on the first imagemap on the page
        if (this.imageNumber != 1) {
          this.highlight(highlight.region, 'redbox', speciesNumber, i);
        }
        
        if (speciesNumber && Ensembl.multiSpecies[speciesNumber]) {
          start = Ensembl.multiSpecies[speciesNumber].location.start;
          end   = Ensembl.multiSpecies[speciesNumber].location.end;
        } else {
          start = Ensembl.location.start;
          end   = Ensembl.location.end;
        }
        
        link = false;
      }
      
      var coords = {
        t: highlight.region.t + 2,
        b: highlight.region.b - 2,
        l: ((start - highlight.region.range.start) / highlight.region.range.scale) + highlight.region.l,
        r: ((end   - highlight.region.range.start) / highlight.region.range.scale) + highlight.region.l
      };
      
      // Highlight unless it's the bottom image on the page
      if (this.params.highlight) {
        this.highlight(coords, 'redbox2', speciesNumber, i);
      }
    }
  },
  
  highlight: function (coords, cl, speciesNumber, multi) {
    var w = coords.r - coords.l + 1;
    var h = coords.b - coords.t + 1;
    var originalClass;
    
    var style = {
      l: { left: coords.l, width: 1, top: coords.t, height: h },
      r: { left: coords.r, width: 1, top: coords.t, height: h },
      t: { left: coords.l, width: w, top: coords.t, height: 1, overflow: 'hidden' },
      b: { left: coords.l, width: w, top: coords.b, height: 1, overflow: 'hidden' }
    };
    
    if (typeof speciesNumber != 'undefined') {
      originalClass = cl;
      cl = cl + '_' + speciesNumber + (multi || '');
    }
    
    var els = $('.' + cl, this.el);
    
    if (!els.length) {
      els = $([
        '<div class="', cl, ' l"></div>', 
        '<div class="', cl, ' r"></div>', 
        '<div class="', cl, ' t"></div>', 
        '<div class="', cl, ' b"></div>'
      ].join('')).insertAfter(this.elLk.img);
    }
    
    els.each(function () {
      $(this).css(style[this.className.split(' ')[1]]);
    });
    
    if (typeof speciesNumber != 'undefined') {
      els.addClass(originalClass);
    }
    
    els = null;
  },
  
  getMapCoords: function (e) {
    return {
      x: e.originalEvent.layerX || e.originalEvent.offsetX || 0, 
      y: e.originalEvent.layerY || e.originalEvent.offsetY || 0
    };
  },
  
  getArea: function (coords, draggables) {
    var test = false;
    var areas = draggables ? this.draggables : this.areas;
    var c;
    
    for (var i = 0; i < areas.length; i++) {
      c = areas[i];
      
      switch (c.a.shape.toLowerCase()) {
        case 'circle': test = this.inCircle(c.c, coords); break;
        case 'poly':   test = this.inPoly(c.c, coords); break;
        default:       test = this.inRect(c, coords); break;
      }
      
      if (test === true) {
        return $.extend({}, c);
      }
    }
  },
  
  inRect: function (c, coords) {
    return coords.x >= c.l && coords.x <= c.r && coords.y >= c.t && coords.y <= c.b;
  },
  
  inCircle: function (c, coords) {
    return (coords.x - c[0]) * (coords.x - c[0]) + (coords.y - c[1]) * (coords.y - c[1]) <= c[2] * c[2];
  },

  inPoly: function (c, coords) {
    var n = c.length;
    var t = 0;
    var x1, x2, y1, y2;
    
    for (var i = 0; i < n; i += 2) {
      x1 = c[i % n] - coords.x;
      y1 = c[(i + 1) % n] - coords.y;
      x2 = c[(i + 2) % n] - coords.x;
      y2 = c[(i + 3) % n] - coords.y;
      t += Math.atan2(x1*y2 - y1*x2, x1*x2 + y1*y2);
    }
    
    return Math.abs(t/Math.PI/2) > 0.01;
  }
});
