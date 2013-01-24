// $Revision$

Ensembl.Panel.ModalContent = Ensembl.Panel.LocalContext.extend({
  constructor: function () {
    this.base.apply(this, arguments);
    
    Ensembl.EventManager.register('modalFormSubmit', this, this.formSubmit);
  },
  
  init: function () {
    var panel = this;
    
    this.activeLink = false;
    
    this.base();
        
    this.elLk.content = $('.modal_wrapper', this.el);
    
    $('a', this.elLk.links).on('click', function () {
      if (!$(this).hasClass('disabled')) {
        var link = $(this).parent();
        
        if (!link.hasClass('active')) {
          panel.elLk.links.removeClass('active');
          panel.getContent(link.addClass('active'), this.href);
        }
        
        link = null;
      }
      
      return false;
    });
    
    this.elLk.links.on('click', function (e) {
      e.stopPropagation();
      return $(this).children('a').trigger('click');
    });
    
    this.elLk.content.on('click', 'a.delete_bookmark', function () {
      Ensembl.EventManager.trigger('deleteBookmark', this.href.match(/id=(\d+)\b/)[1]);
    }).on('click', 'form div.select_all input', function () {
      $(this).parents('fieldset').find('input[type=checkbox]').prop('checked', this.checked);
    }).on('click', 'form.wizard input.back', function () {
      $(this).parents('form.wizard').append('<input type="hidden" name="wizard_back" value="1" />').submit();
    });
    
    this.initialize();
  },
  
  initialize: function () {
    this.setSelectAll();
    
    this.elLk.dataTable = $('table.data_table', this.el);
    
    if (this.elLk.dataTable.length) {
      if (!this.dataTableInit) {
        $.extend(this, Ensembl.DataTable);
      }
      
      this.dataTableInit();
    }
    
    this.el.togglewrap();
    Ensembl.EventManager.trigger('validateForms', this.el);
    
    this.el.find('._ht').helptip();
    this.el.find('._stt').selectToToggle({}, this.el);
    
    this.addSubPanel();
  },
  
  getContent: function (link, url) {
    this.elLk.content.html('<div class="panel"><div class="spinner">Loading Content</div></div>');
    
    $.ajax({
      url: Ensembl.replaceTimestamp(url),
      dataType: 'json',
      context: this,
      success: function (json) {
        if (json.redirectURL) {
          return this.getContent(link, json.redirectURL);
        }
        
        // Avoid race conditions if the user has clicked another nav link while waiting for content to load
        if (typeof link === 'undefined' || link.hasClass('active')) {
          this.updateContent(json);
        }
      },
      error: function (e) {
        if (e.status !== 0) {
          this.displayErrorMessage();
        }
      }
    });
  },
  
  formSubmit: function (form, data) {
    data = data || form.serialize();
    
    $.ajax({
      url: form.attr('action'),
      type: form.attr('method'),
      data: data,
      dataType: 'json',
      context: this,
      iframe: true,
      form: form,
      success: function (json) {
        if (json.redirectURL && json.redirectType === 'modal') {
          return json.modalTab ? Ensembl.EventManager.trigger('modalOpen', { href: json.redirectURL, rel: json.modalTab }) : this.getContent(undefined, json.redirectURL);
        }
        
        if (json.success === true || json.redirectType === 'page') {
          Ensembl.EventManager.trigger('reloadPage', false, json.redirectType === 'page' ? json.redirectURL : false);
        } else if (this.el.is(':visible')) {
          this.updateContent(json);
        }
      },
      error: function (e) {
        if (e.status !== 0) {
          this.displayErrorMessage();
        }
      }
    });
    
    this.elLk.content.html('<div class="panel"><div class="spinner">Loading Content</div></div>');
    
    return false;
  },
  
  updateContent: function (json) {
    if (json.wrapper) {
      this.elLk.content.wrapInner(json.wrapper);
    }
  
    this.elLk.content.html(json.content);
       
    if ($('.modal_reload', this.el).length) {
      Ensembl.EventManager.trigger('queuePageReload', '', false, false, $('.modal_reload', this.el).attr('href'));
    }
    
    this.initialize();
  },
  
  addSubPanel: function () {
    var panel  = this;
    var params = [];
    
    $('.ajax', this.elLk.content).each(function () {
      params.push([ $(this).parents('.js_panel')[0].id, 'Content' ]);
    });
    
    $('.js_panel', this.elLk.content).each(function () {
      var panelType = $('input.subpanel_type', this).val();
      
      if (panelType && !(panel instanceof Ensembl.Panel[panelType])) {
        params.push([ this.id, panelType ]);
      }
    });
    
    for (var i in params) {
      Ensembl.EventManager.trigger('destroyPanel', params[i][0], 'empty');
      Ensembl.EventManager.trigger('createPanel',  params[i][0], params[i][1]);
    }
  },
  
  setSelectAll: function () {
    $('form div.select_all input', this.elLk.content).prop('checked', function () {
      return $(this).parents('fieldset').find('input[type=checkbox]:not(:checked)').length - 1 <= 0; // -1 for the select_all checkbox itself
    });
  },
  
  displayErrorMessage: function (message) {
    message = message || 'Sorry, the page request failed to load.';
    this.elLk.content.html('<div class="error ajax_error"><h3>Ajax error</h3><div class="error-pad"><p>' + message + '</p></div></div>');
  }
});
