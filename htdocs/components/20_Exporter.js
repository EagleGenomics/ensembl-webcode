// $Revision$

Ensembl.Panel.Exporter = Ensembl.Panel.ModalContent.extend({
  init: function () {
    var panel = this;
    
    this.base();
    
    this.config = {};
    
    $.each($('form.configuration', this.el).serializeArray(), function () { panel.config[this.name] = this.value; });
  },
  
  formSubmit: function (form) {
    var panel   = this;
    var checked = $.extend({}, this.config);
    var data    = {};
    var diff    = {};
    var i;
    
    $('input[type=hidden], input.as-param', form).each(function () { data[this.name] = this.value; });
    var skip     = {};
    $('input.as-param', form).each(function() { skip[this.name] = 1; });
    
    if (form.hasClass('configuration')) {
      $.each(form.serializeArray(), function () {
        if (!skip[this.name] && panel.config[this.name] !== this.value) {
          diff[this.name] = this.value;
        }
        
        delete checked[this.name];
      });
      
      // Add unchecked checkboxes to the diff
      for (i in checked) {
        diff[i] = 'no';
      }
      
      data.view_config = JSON.stringify(diff);
      
      $.extend(true, this.config, diff);
    }
    
    return this.base(form, data);
  }
});
