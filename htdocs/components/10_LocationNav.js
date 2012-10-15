// $Revision$

Ensembl.Panel.LocationNav = Ensembl.Panel.extend({
  constructor: function (id, params) {
    this.base(id, params);
    
    Ensembl.EventManager.register('hashChange',  this, this.getContent);
    Ensembl.EventManager.register('changeWidth', this, this.resize);
    Ensembl.EventManager.register('imageResize', this, this.resize);
    
    if (!window.location.pathname.match(/\/Multi/)) {
      Ensembl.EventManager.register('ajaxComplete', this, function () { this.enabled = true; });
    }
  },
  
  init: function () {
    var panel = this;
    
    this.base();
    
    this.enabled = this.params.enabled || false;
    
    var sliderConfig = $('span.ramp', this.el).hide().children();
    var sliderLabel  = $('.slider_label', this.el);
    
    $('.slider_wrapper', this.el).children().css('display', 'inline-block');
    
    this.elLk.updateURL     = $('.update_url', this.el);
    this.elLk.locationInput = $('.location_selector', this.el);
    this.elLk.navbar        = $('.navbar', this.el);
    this.elLk.imageNav      = $('.image_nav', this.elLk.navbar);
    this.elLk.forms         = $('form', this.elLk.navbar);
    
    $('a.go-button', this.elLk.forms).on('click', function () {
      $(this).parents('form').trigger('submit');
      return false;
    });
    
    this.elLk.navLinks = $('a', this.elLk.imageNav).addClass('constant').on('click', function (e) {
      var newR;
      
      if (panel.enabled === true) {
        newR = this.href.match(Ensembl.locationMatch)[1];
        
        if (newR !== Ensembl.coreParams.r) {
          Ensembl.updateLocation(newR);
        }
        
        return false;
      }
    });
    
    this.elLk.slider = $('.slider', this.el).slider({
      value: sliderConfig.filter('.selected').index(),
      step:  1,
      min:   0,
      max:   sliderConfig.length - 1,
      force: false,
      slide: function (e, ui) {
        sliderLabel.html(sliderConfig[ui.value].name + ' bp').show();
      },
      change: function (e, ui) {
        var input = sliderConfig[ui.value];
        var url   = input.href;
        var r     = url.match(Ensembl.locationMatch)[1];
        
        sliderLabel.html(input.name + ' bp');
        
        input = null;
        
        if (panel.elLk.slider.slider('option', 'force') === true) {
          return false;
        } else if (panel.enabled === false) {
          Ensembl.redirect(url);
          return false;
        } else if (Ensembl.locationURL === 'hash' && !window.location.hash.match(Ensembl.locationMatch) && window.location.search.match(Ensembl.locationMatch)[1] === r) {
          return false; // when there's no hash, but the current location is the same as the new r
        } else if ((window.location[Ensembl.locationURL].match(Ensembl.locationMatch) || [])[1] === r) {
          return false;
        }
        
        Ensembl.updateLocation(r);
      },
      stop: function () {
        sliderLabel.hide();
        $('.ui-slider-handle', panel.elLk.slider).trigger('blur'); // Force the blur event to remove the highlighting for the handle
      }
    });
    
    this.resize();
  },
  
  getContent: function () {
    var panel = this;
    
    if (!this.elLk.updateURL.length) {
      return;
    }
    
    $.ajax({
      url: Ensembl.urlFromHash(this.elLk.updateURL.val() + ';update_panel=1'),
      dataType: 'json',
      success: function (json) {
        var sliderValue = json.shift();
        
        if (panel.elLk.slider.slider('value') !== sliderValue) {
          panel.elLk.slider.slider('option', 'force', true);
          panel.elLk.slider.slider('value', sliderValue);
          panel.elLk.slider.slider('option', 'force', false);
        }
      
        panel.elLk.updateURL.val(json.shift());
        panel.elLk.locationInput.val(json.shift());
        
        panel.elLk.navLinks.attr('href', function () {
          return this.href.replace(Ensembl.locationReplace, '$1' + json.shift() + '$2');
        });
      }
    });
  },
  
  resize: function () {
    var widths = {
      navbar: this.elLk.navbar.width(),
      slider: this.elLk.imageNav.width(),
      forms:  this.elLk.forms.width()
    };
    
    if (widths.navbar < widths.forms + widths.slider) {
      this.elLk.navbar.removeClass('narrow1').addClass('narrow2');
    } else if (widths.navbar < (widths.forms * this.elLk.forms.length) + widths.slider) {
      this.elLk.navbar.removeClass('narrow2').addClass('narrow1');
    } else {
      this.elLk.navbar.removeClass('narrow1 narrow2');
    }
  }
});
