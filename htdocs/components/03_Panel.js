// $Revision$

Ensembl.Panel = Base.extend({  
  constructor: function (id, params) {
    if (typeof id != 'undefined') {
      this.id = id;
    }
    
    this.params = typeof params == 'undefined' ? {} : params;
    
    this.initialised = false;
  },
  
  destructor: function (action) {
    var el;
    
    if (action === 'empty') {
      $(this.el).empty();
    } else if (action !== 'cleanup') {
      $(this.el).remove();
    }
    
    for (el in this.elLk) {
      this.elLk[el] = null;
    }
    
    for (el in this.live) {
      this.live[el].die();
      this.live[el] = null;
    }
    
    this.el = null;
  },
  
  init: function () {
    var panel = this;
    
    if (this.initialised) {
      return false;
    }
    
    this.el = document.getElementById(this.id);
    
    if (this.el === null) {
      throw new Error('Could not find ' + this.id + ', perhaps DOM is not ready');
    }
    
    this.elLk = {};
    this.live = [];
    
    $('input.js_param', this.el).each(function () {
      if (!panel.params[this.name]) {
        panel.params[this.name] = this.value;
      }
    });
    
    this.initialised = true;
  },
    
  height: function (h) {
    if (typeof h == 'undefined') {
      return this.getStyle('height');
    } else {
      this.setDim(h);
    }
  },
  
  width: function (w) {
    if (typeof w == 'undefined') {
      return this.getStyle('width');
    } else {
      this.setDim(w);
    }
  },
  
  hide: function () {    
    this.el.style.display = 'none';
    this.visible = false;
  },
  
  show: function () {
    this.el.style.display = 'block';
    this.visible = true;
  },
  
  setDim: function (w, h) {
    if (typeof w != 'undefined') {
      if (typeof w != 'string') {
        w = w.toString() + 'px';
      }
      
      this.el.style.width = w;
    }
        
    if (typeof h != 'undefined') {
      if (typeof h != 'string') {
        h = h.toString() + 'px';
      }
      
      this.el.style.height = h;
    }
  },
  
  getStyle: function (styleProp) {
    var y = null;
    
    if (this.el.currentStyle) {
      y = this.el.currentStyle[styleProp];
    } else if (window.getComputedStyle) {
      y = document.defaultView.getComputedStyle(this.el, null).getPropertyValue(styleProp);
    }
    
    return y;
  }
});
