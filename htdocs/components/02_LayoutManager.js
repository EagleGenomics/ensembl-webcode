// $Revision$

Ensembl.LayoutManager = new Base();

Ensembl.LayoutManager.extend({
  constructor: null,
  
  /**
   * Creates events on elements outside of the domain of panels
   */
  initialize: function () {
    this.id = 'LayoutManager';
    
    Ensembl.EventManager.register('reloadPage',    this, this.reloadPage);
    Ensembl.EventManager.register('validateForms', this, this.validateForms);
    Ensembl.EventManager.register('makeZMenu',     this, this.makeZMenu);
    Ensembl.EventManager.register('relocateTools', this, this.relocateTools);
    Ensembl.EventManager.register('hashChange',    this, this.hashChange);
    Ensembl.EventManager.register('toggleContent', this, this.toggleContent);
    Ensembl.EventManager.register('changeWidth',   this, this.changeWidth);
        
    $('#page_nav .tool_buttons > p').show();
    
    $('#header a:not(#tabs a)').addClass('constant');
    
    if (window.location.hash.match(Ensembl.locationMatch)) {
      $('.ajax_load').val(function (i, val) {
        return Ensembl.urlFromHash(val);
      });
      
      this.hashChange(Ensembl.urlFromHash(window.location.href, true));
    }
    
    $(document).on('click', '.modal_link', function () {
      if (Ensembl.EventManager.trigger('modalOpen', this)) {
        return false;
      }
    }).on('click', '.popup', function () {
      if (window.name.match(/^popup_/)) {
        return true;
      }
      
      window.open(this.href, 'popup_' + window.name, 'width=950,height=500,resizable,scrollbars');
      return false;
    }).on('click', 'a[rel="external"]', function () { 
      this.target = '_blank';
    });
    
    $('.modal_link').show();
    
    this.validateForms(document);
    
    // Close modal window if the escape key is pressed
    $(document).on({
      keyup: function (event) {
        if (event.keyCode === 27) {
          Ensembl.EventManager.trigger('modalClose', true);
        }
      },
      mouseup: function (e) {
        // only fired on left click
        if (!e.which || e.which === 1) {
          Ensembl.EventManager.trigger('mouseUp', e);
        }
      }
    });
    
    function popState() {
      if (
        // there is an r param in the hash/search EXCEPT WHEN the browser supports history API, and there is a hash which doesn't have an r param (ajax added content)
        (window.location[Ensembl.locationURL].match(Ensembl.locationMatch) && !(Ensembl.locationURL === 'search' && window.location.hash && !window.location.hash.match(Ensembl.locationMatch))) ||
        (!window.location.hash && Ensembl.hash.match(Ensembl.locationMatch)) // there is no location.hash, but Ensembl.hash (previous hash value) had an r param (going back from no hash url to hash url)
      ) {
        Ensembl.setCoreParams();
        Ensembl.EventManager.trigger('hashChange', Ensembl.urlFromHash(window.location.href, true));
      }
    }
    
    $(window).on({
      resize: function (e) {
        // jquery ui resizable events cause window.resize to fire (all events bubble to window)
        // if target has no tagName it is window or document. Don't resize unless this is the case
        if (!e.target.tagName) {
          var width = Ensembl.width;
          
          Ensembl.setWidth(undefined, Ensembl.dynamicWidth);
          
          Ensembl.EventManager.trigger('windowResize');
          
          if (Ensembl.dynamicWidth && Ensembl.width !== width) {
            Ensembl.LayoutManager.changeWidth();
            Ensembl.EventManager.trigger('imageResize');
          }
        }
      },
      hashchange: popState
    });
    
    window.onpopstate = popState;
    
    var userMessage = unescape(Ensembl.cookie.get('user_message'));
    
    if (userMessage) {
      userMessage = userMessage.split('\n');
      
      $([
        '<div class="hint right-margin left-margin">',
        ' <h3><img src="/i/close.png" alt="Hide" title="Hide" />', userMessage[0], '</h3>',
        ' <div class="message-pad">', userMessage[1], '</div>',
        '</div>'
      ].join('')).prependTo('#main').find('h3 img, a').on('click', function () {
        $(this).parents('div.hint').remove();
        Ensembl.cookie.set('user_message', '');
      });
    }
  },
  
  reloadPage: function (args, url) {
    if (typeof args === 'string') {
      Ensembl.EventManager.triggerSpecific('updatePanel', args);
    } else if (typeof args === 'object') {
      for (var i in args) {
        Ensembl.EventManager.triggerSpecific('updatePanel', i);
      }
    } else {
      return Ensembl.redirect(url);
    }
    
    $('#messages').hide();
  },
  
  validateForms: function (context) {
    $('form.check', context).validate().on('submit', function () {
      var form = $(this);
      
      if (form.parents('#modal_panel').length) {
        var panels = form.parents('.js_panel').map(function () { return this.id; }).toArray();
        var rtn;
        
        while (panels.length && typeof rtn === 'undefined') {
          rtn = Ensembl.EventManager.triggerSpecific('modalFormSubmit', panels.shift(), form);
        }
        
        return rtn;
      }
    });
  },
  
  makeZMenu: function (id, params) {
    if (!$('#' + id).length) {
      $([
        '<div class="info_popup floating_popup" id="', id, '">',
        ' <span class="close"></span>',
        '  <table class="zmenu" cellspacing="0">',
        '    <thead>', 
        '      <tr class="header"><th class="caption" colspan="2"><span class="title"></span></th></tr>',
        '    </thead>', 
        '    <tbody class="loading">',
        '      <tr><td><p class="spinner"></p></td></tr>',
        '    </tbody>',
        '    <tbody></tbody>',
        '  </table>',
        '</div>'
      ].join('')).draggable({ handle: 'thead' }).appendTo('body');
    }
    
    Ensembl.EventManager.trigger('addPanel', id, 'ZMenu', undefined, undefined, params, 'showExistingZMenu');
  },
  
  relocateTools: function (tools) {
    var toolButtons = $('#page_nav .tool_buttons');
    
    tools.each(function () {
      var a        = $(this).find('a');
      var existing = $('.additional .' + a[0].className.replace(' ', '.'), toolButtons);
      
      if (existing.length) {
        existing.replaceWith(a);
      } else {
        $(this).children().addClass('additional').appendTo(toolButtons).not('.hidden').show();
      }
      
      a = existing = null;
    }).remove();
    
    $('a.seq_blast', toolButtons).on('click', function () {
      $('form.seq_blast', toolButtons).submit();
      return false;
    });
  },
  
  hashChange: function (r) {
    if (!r) {
      return;
    }
    
    r = decodeURIComponent(r);
    
    var text = r.split(/\W/);
        text = text[0] + ': ' + Ensembl.thousandify(text[1]) + '-' + Ensembl.thousandify(text[2]);
    
    $('a:not(.constant)').attr('href', function () {
      var r;
      
      if (this.title === 'UCSC') {
        this.href = this.href.replace(/(&?position=)[^&]+(.?)/, '$1chr' + Ensembl.urlFromHash(this.href, true) + '$2');
      } else if (this.title === 'NCBI') {
        r = Ensembl.urlFromHash(this.href, true).split(/[:\-]/);
        this.href = this.href.replace(/(&?CHR=).+&BEG=.+&END=[^&]+(.?)/, '$1' + r[0] + '&BEG=' + r[1] + '&END=' + r[2] + '$2');
      } else {
        return Ensembl.urlFromHash(this.href);
      }
    });
    
    $('input[name=r]', 'form:not(#core_params)').val(r);
    
    $('h1.summary-heading').html(function (i, html) {
      return html.replace(/^(Chromosome ).+/, '$1' + text);
    });
    
    document.title = document.title.replace(/(Chromosome ).+/, '$1' + text);
  },
  
  toggleContent: function (rel) {
    if (rel) {
      $('a.toggle[rel="' + rel + '"]').toggleClass('open closed');
    }
  },
  
  changeWidth: function () {
    $('.navbar, div.info, div.hint, div.warning, div.error').not('.fixed_width').width(Ensembl.width);
  }
});

