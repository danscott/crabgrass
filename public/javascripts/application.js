function quickRedReference() {
  window.open( 
    "/static/greencloth",
    "redRef",
    "height=600,width=750/inv,channelmode=0,dependent=0," +
    "directories=0,fullscreen=0,location=0,menubar=0," +
    "resizable=0,scrollbars=1,status=1,toolbar=0"
  );
  return false;
}

// toggle the visibility of another element based on if
// a checkbox is checked or not.
function checkbox_toggle_visibility(checkbox, element_id) {
  if (checkbox.checked) {$(element_id).show();}
  else {$(element_id).hide();}
}

// toggle all checkboxes of a particular css selected, based on the
// checked status of the checkbox passed in.
function toggle_all_checkboxes(checkbox, selector) {
  $$(selector).each(function(cb) {cb.checked = checkbox.checked})
}

function show_tab(tab_link, tab_content) {
  tabset = tab_link.parentNode.parentNode
  $$('ul.tabset a').each( function(elem) {
    if (tabset == elem.parentNode.parentNode) {
      elem.removeClassName('active');
    }
  })
  $$('.tab-content').each( function(elem) {
    elem.hide();
  })
  tab_link.addClassName('active');
  tab_content.show();
  tab_link.blur();
  return false;
}

// submits a form, from the onclick of a link. 
// use like <a href='' onclick='submit_form(this,"bob")'>bob</a>
// value is optional.
function submit_form(form_element, name, value) {
  e = form_element;
  form = null;
  do {
    if(e.tagName == 'FORM'){form = e; break}
  } while(e = e.parentNode)
  if (form) {
    input = document.createElement("input");
    input.name = name;
    input.type = "hidden";
    input.value = value;
    form.appendChild(input);
    if (form.onsubmit) {
      form.onsubmit(); // for ajax forms.
    } else {
      form.submit();
    }
  }
}

function replace_class_name(element, old_class, new_class) {
  element.removeClassName(old_class);
  element.addClassName(new_class);
}

/** editing textareas **/

/* element is a textarea object. value is some text */
function insertAtCursor(element_id, value) {
  var element = $(element_id);
  element.focus();
  if (document.selection) {
    //IE support
    sel = document.selection.createRange();
    sel.text = value;
  } else if (element.selectionStart || element.selectionStart == '0') {
    //Mozilla/Firefox/Netscape 7+ support
    var startPos = element.selectionStart;
    var endPos   = element.selectionEnd;
    element.value = element.value.substring(0, startPos) + value + element.value.substring(endPos, element.value.length);
    element.setSelectionRange(endPos+value.length, endPos+value.length);
  } else {
    element.value += value;
  }
}

function decorate_wiki_edit_links(ajax_link) {
  $$('.wiki h1 a.anchor, .wiki h2 a.anchor, .wiki h3 a.anchor, .wiki h4 a.achor').each(
    function(elem) {
      var heading_name = elem.href.replace(/^.*#/, '');
      var link = ajax_link.replace(/_change_me_/g, heading_name);
      elem.insert({after:link});
    }
  );
}

// returns true if the enter key was pressed
function enterPressed(event) {
  if(event.which) { return(event.which == 13); }
  else { return(event.keyCode == 13); }
}


/** menu navigation **/
/*
var SubMenu = Class.create({
  initialize: function(li) {
    if(!$(li)) return;
    this.trigger = $(li).down('em');
    if(!this.trigger) return;
    this.menu = $(li).down('ul');
    this.trigger.observe('click', this.respondToClick.bind(this));
    document.observe('click', function(){ this.menu.hide()}.bind(this));
  },
  
  respondToClick: function(event) {
    event.stop();
    $$('ul.submenu').without(this.menu).invoke('hide');
    this.menu.toggle()
  }
});


document.observe('dom:loaded', function() {
  new SubMenu("menu-me");
  new SubMenu("menu-people");
});
*/

/** finding position **/

function absolutePosition(obj) {
  var curleft = curtop = 0;
  if (obj.offsetParent) {
    do {
      curleft += obj.offsetLeft;
      curtop += obj.offsetTop;
    } while (obj = obj.offsetParent);
  }
  return [curleft,curtop];
}
function absolutePositionParams(obj) {
  obj_dims = absolutePosition(obj);
  page_dims = document.viewport.getDimensions();
  return 'position=' + obj_dims.join('x') + '&page=' + page_dims.width + 'x' + page_dims.height
}
