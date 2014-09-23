/*
 * Copyright [1999-2014] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
 * 
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 * 
 *      http://www.apache.org/licenses/LICENSE-2.0
 * 
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

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
    this.minImageWidth    = 500;
    
    function resetOffset() {
      delete this.imgOffset;
    }
    
    Ensembl.EventManager.register('highlightImage',     this, this.highlightImage);
    Ensembl.EventManager.register('mouseUp',            this, this.dragStop);
    Ensembl.EventManager.register('hashChange',         this, this.hashChange);
    Ensembl.EventManager.register('changeFavourite',    this, this.changeFavourite);
    Ensembl.EventManager.register('imageResize',        this, function () { if (this.xhr) { this.xhr.abort(); } this.getContent(); });
    Ensembl.EventManager.register('windowResize',       this, resetOffset);
    Ensembl.EventManager.register('ajaxLoaded',         this, resetOffset); // Adding content could cause scrollbars to appear, changing the offset, but this does not fire the window resize event
    Ensembl.EventManager.register('changeWidth',        this, function () { this.params.updateURL = Ensembl.updateURL({ image_width: false }, this.params.updateURL); Ensembl.EventManager.trigger('queuePageReload', this.id); });
    Ensembl.EventManager.register('highlightAllImages', this, function () { if (!this.align) { this.highlightAllImages(); } });
  },
  
  init: function () {
    var panel   = this;
    var species = {};
    
    this.base();
    
    this.imageConfig        = $('input.image_config', this.el).val();
    this.lastImage          = Ensembl.images.total > 1 && this.el.parents('.image_panel')[0] === Ensembl.images.last;
    this.hashChangeReload   = this.lastImage || $('.hash_change_reload', this.el).length;
    this.zMenus             = {};
    
    this.params.highlight   = (Ensembl.images.total === 1 || !this.lastImage);
    
    this.elLk.container     = $('.image_container',   this.el);
    this.elLk.drag          = $('.drag_select',       this.elLk.container);
    this.elLk.map           = $('map',                this.elLk.container);
    this.elLk.areas         = $('area',               this.elLk.map);
    this.elLk.exportMenu    = $('.iexport_menu',      this.elLk.container).appendTo('body').css('left', this.el.offset().left);
    this.elLk.resizeMenu    = $('.image_resize_menu', this.elLk.container).appendTo('body').css('left', this.el.offset().left);
    this.elLk.img           = $('img.imagemap',       this.elLk.container);
    this.elLk.hoverLabels   = $('.hover_label',       this.elLk.container);
    this.elLk.boundaries    = $('.boundaries',        this.elLk.container);
    this.elLk.toolbars      = $('.image_toolbar',     this.elLk.container);
    this.elLk.popupLinks    = $('a.popup',            this.elLk.toolbars);
    
    this.vertical = this.elLk.img.hasClass('vertical');
    this.multi    = this.elLk.areas.hasClass('multi');
    this.align    = this.elLk.areas.hasClass('align');
    
    this.makeImageMap();
    this.makeHoverLabels();
    
    if (!this.vertical) {
      this.makeResizable();
    }
    
    species[this.id] = this.getSpecies();
    $.extend(this, Ensembl.Share);
    this.shareInit({ species: species, type: 'image', positionPopup: this.positionToolbarPopup });
    
    if (this.elLk.boundaries.length) {
      Ensembl.EventManager.register('changeTrackOrder', this, this.sortUpdate);
      
      if (this.elLk.img[0].complete) {
        this.makeSortable();
      } else {
        this.elLk.img.on('load', function () { panel.makeSortable(); });
      }
    }
    
    if (typeof FileReader !== 'undefined') {
      this.dropFileUpload();
    }
    
    $('a',         this.elLk.toolbars).helptip({ track: false });
    $('a.iexport', this.elLk.toolbars).data('popup', this.elLk.exportMenu);
    $('a.resize',  this.elLk.toolbars).data('popup', this.elLk.resizeMenu);
    
    this.elLk.popupLinks.on('click', function () {
      var popup = $(this).data('popup');
      
      panel.elLk.popupLinks.map(function () { return ($(this).data('popup') || $()).filter(':visible')[0]; }).not(popup).hide();
      
      if (popup && !popup.hasClass('share_page')) {
        panel.positionToolbarPopup(popup, this).toggle();
      }
      
      popup = null;
      
      return false;
    });

    $('a.image_resize', this.elLk.resizeMenu).on('click', function () {
      if (!$(this).has('.current').length) {
        panel.resize(parseInt($(this).text(), 10) || Ensembl.imageWidth());
      }
      
      return false;
    });
  },
  
  hashChange: function (r) {
    var reload = this.hashChangeReload;
    
    this.params.updateURL = Ensembl.urlFromHash(this.params.updateURL);
    
    if (Ensembl.images.total === 1) {
      this.highlightAllImages();
    } else if (!this.multi && this.highlightRegions[0]) {
      var range = this.highlightRegions[0][0].region.range;
      r = r.split(/\W/);
      
      if (parseInt(r[1], 10) < range.start || parseInt(r[2], 10) > range.end || range.chr !== r[0]) {
        reload = true;
      }
    }
    
    if (reload) {
      this.base();
    }
    
    if (this.align) {
      Ensembl.EventManager.trigger('highlightAllImages');
    }
  },
  
  getContent: function () {
    // If the panel contains an ajax loaded sub-panel, this function will be reached before ImageMap.init has been completed.
    // Make sure that this doesn't cause an error.
    if (this.imageConfig) {
      this.elLk.exportMenu.add(this.elLk.hoverLabels).add(this.elLk.resizeMenu).remove();
    
      for (var id in this.zMenus) {
        Ensembl.EventManager.trigger('destroyPanel', id);
      }
   
      this.removeShare();
    }
    
    this.base.apply(this, arguments);
    
    this.xhr.done(function (html) {
      if (!html) {
        delete Ensembl.images[this.imageNumber];
        Ensembl.EventManager.trigger('highlightAllImages');
      }
    });
  },
  
  makeImageMap: function () {
    var panel = this;
    
    var highlight = !!(window.location.pathname.match(/\/Location\//) && !this.vertical);
    var rect      = [ 'l', 't', 'r', 'b' ];
    var speciesNumber, c, r, start, end, scale;
    
    this.elLk.areas.each(function () {
      c = { a: this };
      
      if (this.shape && this.shape.toLowerCase() !== 'rect') {
        c.c = [];
        $.each(this.coords.split(/[ ,]/), function () { c.c.push(parseInt(this, 10)); });
      } else {
        $.each(this.coords.split(/[ ,]/), function (i) { c[rect[i]] = parseInt(this, 10); });
      }
      
      panel.areas.push(c);
      
      if (this.className.match(/drag/)) {
        // r = [ '#drag', image number, species number, species name, region, start, end, strand ]
        r        = c.a.href.split('|');
        start    = parseInt(r[5], 10);
        end      = parseInt(r[6], 10);
        scale    = (end - start + 1) / (this.vertical ? (c.b - c.t) : (c.r - c.l)); // bps per pixel on image
        
        c.range = { chr: r[4], start: start, end: end, scale: scale, vertical: this.vertical };
        
        panel.draggables.push(c);
        
        if (highlight === true) {
          r = this.href.split('|');
          speciesNumber = parseInt(r[1], 10) - 1;
          
          if (panel.multi || !speciesNumber) {
            if (!panel.highlightRegions[speciesNumber]) {
              panel.highlightRegions[speciesNumber] = [];
              panel.speciesCount++;
            }
            
            panel.highlightRegions[speciesNumber].push({ region: c });
            panel.imageNumber = parseInt(r[2], 10);
            
            Ensembl.images[panel.imageNumber] = Ensembl.images[panel.imageNumber] || {};
            Ensembl.images[panel.imageNumber][speciesNumber] = [ panel.imageNumber, speciesNumber, parseInt(r[5], 10), parseInt(r[6], 10) ];
          }
        }
      }
    });
    
    if (Ensembl.images.total) {
      this.highlightAllImages();
    }
    
    this.elLk.drag.on({
      mousedown: function (e) {
        // Only draw the drag box for left clicks.
        // This property exists in all our supported browsers, and browsers without it will draw the box for all clicks
        if (!e.which || e.which === 1) {
          panel.dragStart(e);
        }
        
        return false;
      },
      mousemove: function(e) {
        var coords  = panel.getMapCoords(e);
        var area    = coords.r ? panel.dragRegion : panel.getArea(coords);

        $(this).toggleClass('drag_select_pointer', !(!area || $(area.a).hasClass('label') || $(area.a).hasClass('drag')));
      },
      click: function (e) {
        if (panel.clicking) {
          panel.makeZMenu(e, panel.getMapCoords(e));
        } else {
          panel.clicking = true;
        }
      }
    });
  },
  
  makeHoverLabels: function () {
    var panel = this;
    var tip   = false;
    
    this.elLk.hoverLabels.detach().appendTo('body'); // IE 6/7 can't do z-index, so move hover labels to body
    
    this.elLk.drag.on({
      mousemove: function (e) {
        if (panel.dragging !== false) {
          return;
        }
        
        var area  = panel.getArea(panel.getMapCoords(e));
        var hover = false;
        
        if (area && area.a && $(area.a).hasClass('nav')) { // Add helptips on navigation controls in multi species view
          if (tip !== area.a.alt) {
            tip = area.a.alt;
            
            if (!panel.elLk.navHelptip) {
              panel.elLk.navHelptip = $('<div class="ui-tooltip helptip-bottom"><div class="ui-tooltip-content"></div></div>');
            }
            
            panel.elLk.navHelptip.children().html(tip).end().appendTo('body').position({
              of: { pageX: panel.imgOffset.left + area.l + 10, pageY: panel.imgOffset.top + area.t - 48, preventDefault: true }, // fake an event
              my: 'center top'
            });
          }
        } else {
          if (tip) {
            tip = false;
            panel.elLk.navHelptip.detach().css({ top: 0, left: 0 });
          }
          
          if (area && area.a && $(area.a).hasClass('label')) {
            var label = panel.elLk.hoverLabels.filter('.' + area.a.className.replace(/label /, ''));
            
            if (!label.hasClass('active')) {
              panel.elLk.hoverLabels.filter('.active').removeClass('active');
              label.addClass('active');
              
              clearTimeout(panel.hoverTimeout);
              
              panel.hoverTimeout = setTimeout(function () {
                var offset = panel.elLk.img.offset();
                
                panel.elLk.hoverLabels.filter(':visible').hide().end().filter('.active').css({
                  left:    area.l + offset.left,
                  top:     area.t + offset.top,
                  display: 'block'
                });
              }, 100);
            }
            
            hover = true;
          }
        }
        
        if (hover === false) {
          clearTimeout(panel.hoverTimeout);
          panel.elLk.hoverLabels.filter('.active').removeClass('active');
        }
      },
      mouseleave: function (e) {
        if (e.relatedTarget) {
          var active = panel.elLk.hoverLabels.filter('.active');
          
          if (!active.has(e.relatedTarget).length) {
            active.removeClass('active').hide();
          }
          
          if (panel.elLk.navHelptip) {
            panel.elLk.navHelptip.detach();
          }
          
          active = null;
        }
      }
    });
    
    this.elLk.hoverLabels.on('mouseleave', function () {
      $(this).hide().children('div').hide();
    });
    
    this.elLk.hoverLabels.children('img').hoverIntent(
      function () {
        var width = $(this).parent().outerWidth();
        
        $(this).siblings('div').hide().filter('.' + this.className.replace(/ /g, '.')).show().width(function (i, value) {
          return value > width && value > 300 ? 300 : value;
        });
      },
      $.noop
    );
    
    $('a.config', this.elLk.hoverLabels).on('click', function () {
      var config = this.rel;
      var update = this.href.split(';').reverse()[0].split('='); // update = [ trackId, renderer ]
      var fav    = '';
      
      if ($(this).hasClass('favourite')) {
        fav = $(this).hasClass('selected') ? 'off' : 'on';
        Ensembl.EventManager.trigger('changeFavourite', update[0], fav === 'on');
      } else {
        $(this).parents('.hover_label').width(function (i, value) {
          return value > 100 ? value : 100;
        }).find('.spinner').show().siblings('div').hide();
      }
      
      $.ajax({
        url: this.href + fav,
        dataType: 'json',
        success: function (json) {
          if (json.updated) {
            panel.elLk.hoverLabels.remove(); // Deletes elements moved to body
            Ensembl.EventManager.trigger('hideHoverLabels'); // Hide labels on other ImageMap panels
            Ensembl.EventManager.triggerSpecific('changeConfiguration', 'modal_config_' + config, update[0], update[1]);
            Ensembl.EventManager.trigger('reloadPage', panel.id);
          }
        }
      });
      
      return false;
    });
    
    Ensembl.EventManager.register('hideHoverLabels', this, function () { this.elLk.hoverLabels.hide(); });
  },
  
  makeResizable: function () {
    var panel = this;
    
    function resizing(e, ui) {
      panel.imageResize = Math.floor(ui.size.width / 100) * 100; // The image_container has a border, which causes ui.size.width to increase by the border width.
      resizeHelptip.apply(this, [ ui.helper ].concat(e.type === 'resizestart' ? [ 'Drag to resize', e.pageY ] : panel.imageResize + 'px'));
    }
    
    function resizeHelptip(el, content, y) {
      if (typeof y === 'number') {
        el.data('y', y);
      } else {
        y = el.data('y');
      }
      
      el.html('<div class="bg"></div><div class="ui-tooltip"><div class="ui-tooltip-content"></div></div>').find('.ui-tooltip-content').html(content).parent().css('top', function () {
        return y - el.offset().top - $(this).outerHeight(true) / 2;
      });
      
      el = null;
    }
    
    this.elLk.container.resizable({
      handles: 'e',
      grid:    [ 100, 0 ],
      minWidth: this.minImageWidth,
      maxWidth: $(window).width() - this.el.offset().left,
      helper:   'image_resize_overlay',
      start:    resizing,
      resize:   resizing,
      stop:     function (e, ui) {
        if (ui.originalSize.width === ui.size.width) {
          $(this).css({ width: panel.imageResize, height: '' });
        } else {
          panel.resize(panel.imageResize);
        }
      }
    });
  },
  
  makeSortable: function () {
    var panel      = this;
    var wrapperTop = $('.boundaries_wrapper', this.el).position().top;
    var ulTop      = this.elLk.boundaries.position().top + wrapperTop - (Ensembl.browser.ie7 ? 3 : 0); // IE7 reports li.position().top as 3 pixels higher than other browsers, so offset that here.
    var lis        = [];
    
    this.dragCursor = Ensembl.browser.mac ? 'move' : 'n-resize';
    
    this.elLk.boundaries.children().each(function (i) {
      var li = $(this);
      var t  = li.position().top + ulTop;
      
      li.data({ areas: [], position: i, order: parseFloat(li.children('i')[0].className, 10), top: li.offset().top });
      
      lis.push({ top: t, bottom: t + li.height(), areas: li.data('areas') });
      
      li = null;
    });
    
    $.each(this.areas, function () {
      var i = lis.length;
      
      while (i--) {
        if (lis[i].top <= this.t && lis[i].bottom >= this.b) {
          lis[i].areas.push(this);
          break;
        }
      }
    });
    
    this.elLk.boundaries.each(function () {
      $(this).data('updateURL', '/' + this.className.split(' ')[0] + '/Ajax/track_order');
    }).sortable({
      axis:   'y',
      handle: 'p.handle',
      helper: 'clone',
      placeholder: 'tmp',
      start: function (e, ui) {
        ui.placeholder.css({
          backgroundImage:     ui.item.css('backgroundImage'),
          backgroundPosition:  ui.item.css('backgroundPosition'),  // Firefox
          backgroundPositionY: ui.item.css('backgroundPositionY'), // IE (Chrome works with either)
          height:              ui.item.height(),
          opacity:             0.8,
          visibility:          'visible'
        }).html(ui.item.html());
        
        ui.helper.hide();
        $(this).find(':not(.tmp) p.handle').addClass('nohover');
        panel.elLk.drag.css('cursor', panel.dragCursor);
        panel.dragging = true;
      },
      stop: function () {
        $(this).find('p.nohover').removeClass('nohover');
        panel.elLk.drag.css('cursor', 'pointer');
        panel.dragging = false;
      },
      update: function (e, ui) {
        var order = panel.sortUpdate(ui.item);
        var track = ui.item[0].className.replace(' ', '.');
        
        $.ajax({
          url: $(this).data('updateURL'),
          type: 'post',
          data: {
            image_config: panel.imageConfig,
            track: track,
            order: order
          }
        });
        
        Ensembl.EventManager.triggerSpecific('changeTrackOrder', 'modal_config_' + panel.id.toLowerCase(), track, order);
      }
    }).css('visibility', 'visible');
  },
  
  sortUpdate: function (track, order) {
    var tracks = this.elLk.boundaries.children();
    var i, p, n, o, move, li, top;
    
    if (typeof track === 'string') {
      i     = tracks.length;
      track = tracks.filter('.' + track).detach();
      
      if (!track.length) {
        return;
      }
      
      while (i--) {
        if ($(tracks[i]).data('order') < order && tracks[i] !== track[0]) {
          track.insertAfter(tracks[i]);
          break;
        }
      }
      
      if (i === -1) {
        track.insertBefore(tracks[0]);
      }
      
      tracks = this.elLk.boundaries.children();
    } else {
      p = track.prev().data('order') || 0;
      n = track.next().data('order') || 0;
      o = p || n;
      
      if (Math.floor(n) === Math.floor(p)) {
        order = p + (n - p) / 2;
      } else {
        order = o + (p ? 1 : -1) * (Math.round(o) - o || 1) / 2;
      }
    }
    
    track.data('order', order);
    
    tracks.each(function (j) {
      li = $(this);
      
      if (j !== li.data('position')) {
        top  = li.offset().top;
        move = top - li.data('top'); // Up is positive, down is negative
        
        $.each(li.data('areas'), function () {
          this.t += move;
          this.b += move;
        });
        
        li.data({ top: top, position: j });
      }
      
      li = null;
    });
    
    tracks = track = null;
    
    this.removeShare();
    Ensembl.EventManager.trigger('removeShare');
    
    return order;
  },
  
  changeFavourite: function (trackId) {
    this.elLk.hoverLabels.filter(function () { return this.className.match(trackId); }).children('a.favourite').toggleClass('selected');
  },
  
  dragStart: function (e) {
    var panel = this;
    
    this.dragCoords.map    = this.getMapCoords(e);
    this.dragCoords.page   = { x: e.pageX, y : e.pageY };
    this.dragCoords.offset = { x: e.pageX - this.dragCoords.map.x, y: e.pageY - this.dragCoords.map.y }; // Have to use this instead of the map coords because IE can't cope with offsetX/Y and relative positioned elements
    
    this.dragRegion = this.getArea(this.dragCoords.map, true);
    
    if (this.dragRegion) {
      this.mousemove = function (e2) {
        panel.dragging = e; // store mousedown even
        panel.drag(e2);
        return false;
      };
      
      this.elLk.drag.on('mousemove', this.mousemove);
    }
  },
  
  dragStop: function (e) {
    var diff, range;
    
    if (this.mousemove) {
      this.elLk.drag.off('mousemove', this.mousemove);
      this.mousemove = false;
    }
    
    if (this.dragging !== false) {
      diff = { 
        x: e.pageX - this.dragCoords.page.x, 
        y: e.pageY - this.dragCoords.page.y
      };
      
      // Set a limit below which we consider the event to be a click rather than a drag
      if (Math.abs(diff.x) < 3 && Math.abs(diff.y) < 3) {
        this.clicking = true; // Chrome fires mousemove even when there has been no movement, so catch clicks here
      } else {
        range = this.vertical ? { r: diff.y, s: this.dragCoords.map.y } : { r: diff.x, s: this.dragCoords.map.x };
        
        this.makeZMenu(e, range);
        
        this.dragging = false;
        this.clicking = false;
      }
    }
  },
  
  drag: function (e) {
    var x      = e.pageX - this.dragCoords.offset.x;
    var y      = e.pageY - this.dragCoords.offset.y;
    var coords = {};
    
    switch (x < this.dragCoords.map.x) {
      case true:  coords.l = x; coords.r = this.dragCoords.map.x; break;
      case false: coords.r = x; coords.l = this.dragCoords.map.x; break;
    }
    
    switch (y < this.dragCoords.map.y) {
      case true:  coords.t = y; coords.b = this.dragCoords.map.y; break;
      case false: coords.b = y; coords.t = this.dragCoords.map.y; break;
    }
    
    if (this.vertical || x < this.dragRegion.l) {
      coords.l = this.dragRegion.l;
    }
    if (this.vertical || x > this.dragRegion.r) {
      coords.r = this.dragRegion.r;
    }
    
    if (!this.vertical || y < this.dragRegion.t) {
      coords.t = this.dragRegion.t;
    }
    if (!this.vertical || y > this.dragRegion.b) {
      coords.b = this.dragRegion.b;
    }
    
    this.highlight(coords, 'rubberband', this.dragRegion.a.href.split('|')[3]);
  },
  
  resize: function (width) {
    this.params.updateURL = Ensembl.updateURL({ image_width: width }, this.params.updateURL);
    this.getContent();
  },
  
  makeZMenu: function (e, coords) {
    var area = coords.r ? this.dragRegion : this.getArea(coords);
    
    if (!area || $(area.a).hasClass('label')) {
      return;
    }
    
    if ($(area.a).hasClass('nav')) {
      Ensembl.redirect(area.a.href);
      return;
    }
    
    var id = 'zmenu_' + area.a.coords.replace(/[ ,]/g, '_');
    var dragArea, range, location, fuzziness;
    
    if (e.shiftKey || $(area.a).hasClass('das') || $(area.a).hasClass('group')) {
      dragArea = this.dragRegion || this.getArea(coords, true);
      range    = dragArea ? dragArea.range : false;
      
      if (range) {
        location  = range.start + (range.scale * (range.vertical ? (coords.y - dragArea.t) : (coords.x - dragArea.l)));
        fuzziness = range.scale * 2; // Increase the size of the click so we can have some measure of certainty for returning the right menu
        
        coords.clickChr   = range.chr;
        coords.clickStart = Math.max(Math.floor(location - fuzziness), range.start);
        coords.clickEnd   = fuzziness > 1 ? Math.min(Math.ceil(location + fuzziness), range.end) : Math.max(coords.clickStart,Math.floor(location));
        
        id += '_multi';
      }
      
      dragArea = null;
    }
    
    Ensembl.EventManager.trigger('makeZMenu', id, { event: e, coords: coords, area: area, imageId: this.id, relatedEl: area.a.id ? $('.' + area.a.id, this.el) : false });
    
    this.zMenus[id] = 1;
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
    if (!this.draggables.length || this.vertical || imageNumber - this.imageNumber > 1 || imageNumber - this.imageNumber < 0) {
      return;
    }
    
    var i    = this.highlightRegions[speciesNumber].length;
    var link = true; // Defines if the highlighted region has come from another image or the url
    var highlight, coords;
    
    while (i--) {
      highlight = this.highlightRegions[speciesNumber][i];
      
      if (!highlight.region.a) {
        break;
      }
      
      // Highlighting base on self. Take start and end from Ensembl core parameters
      if (this.imageNumber === imageNumber) {
        // Don't draw the redbox on the first imagemap on the page
        if (this.imageNumber !== 1) {
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
      
      coords = {
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
    var originalClass, els;
    
    var style = {
      l: { left: coords.l, width: 1, top: coords.t, height: h },
      r: { left: coords.r, width: 1, top: coords.t, height: h },
      t: { left: coords.l, width: w, top: coords.t, height: 1, overflow: 'hidden' },
      b: { left: coords.l, width: w, top: coords.b, height: 1, overflow: 'hidden' }
    };
    
    if (typeof speciesNumber !== 'undefined') {
      originalClass = cl;
      cl            = cl + '_' + speciesNumber + (multi || '');
    }
    
    els = $('.' + cl, this.el);
    
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
    
    if (typeof speciesNumber !== 'undefined') {
      els.addClass(originalClass);
    }
    
    els = null;
  },
  
  getMapCoords: function (e) {
    this.imgOffset = this.imgOffset || this.elLk.img.offset();
    
    return {
      x: e.pageX - this.imgOffset.left, 
      y: e.pageY - this.imgOffset.top
    };
  },
  
  getArea: function (coords, draggables) {
    var test  = false;
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
  },
  
  positionToolbarPopup: function (el, link) {
    var toolbar = $(link.parentNode);
    el.css({ top: toolbar.hasClass('bottom') ? toolbar.offset().top - el.outerHeight() : this.elLk.img.offset().top });
    link = toolbar = null;
    return el;
  },
  
  getSpecies: function () {
    var species = $.map(this.draggables, function (el) { return el.a.href.split('|')[3]; });
    
    if (species.length) {
      var unique = {};
      unique[Ensembl.species] = 1;
      $.each(species, function () { unique[this] = 1; });
      species = $.map(unique, function (i, s) { return s });
    }
    
    return species.length > 1 ? species : undefined;
  },
  
  dropFileUpload: function () {
    var panel   = this;
    var el      = this.el[0];
    var reader  = new FileReader();
    var uploads = [];
    var r;
    
    function noop(e) {
      e.stopPropagation();
      e.preventDefault();
      return false;
    }
    
    function readFile(files) {
      if (!files.length) {
        if (r) {
          panel.hashChangeReload = true;
          Ensembl.updateLocation(r);
        }
        
        return;
      }
      
      var file = files.shift();
      
      if (file.size > 5 * Math.pow(1024, 2)) {
        return readFile(files);
      }
      
      reader.readAsText(file);
      
      reader.onloadend = function (e) {
        uploads.push($.ajax({
          url: '/' + Ensembl.species + '/UserData/DropUpload',
          data: { text: e.target.result, name: file.name },
          type: 'POST',
          success: function (response) {
            if (response) {
              r = response;
            }
            
            readFile(files);
          }
        }));
      };
    }
    
    el.addEventListener('dragenter', noop, false);
    el.addEventListener('dragexit',  noop, false);
    el.addEventListener('dragover',  noop, false);
    
    if ($('.drop_upload', this.el).length && !this.multi) {
      el.addEventListener('drop', function (e) {
        e.stopPropagation();
        e.preventDefault();
        readFile([].slice.call(e.dataTransfer.files).sort(function (a, b) { return a.name.toLowerCase() > b.name.toLowerCase(); }));
      }, false);
    } else {
      el.addEventListener('drop', noop, false);
    }
    
    el = null;
  }
});
