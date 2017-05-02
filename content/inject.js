// Generated by CoffeeScript 1.10.0
console.log("[inject] init");

chrome.runtime.sendMessage({
  type: 'setting'
}, function(setting) {
  jQuery(document).bind('keyup', function(event) {
    if (utils.checkEventKey(event, setting.openSK1, setting.openSK2, setting.openKey)) {
      return chrome.runtime.sendMessage({
        type: 'look up',
        means: 'keyboard',
        text: window.getSelection().toString()
      });
    }
  });
  return jQuery(document).mouseup(function(event) {
    if (event.which === 1 && window.getSelection().toString()) {
      if (!setting.enableMouseSK1 || (setting.mouseSK1 && utils.checkEventKey(event, setting.mouseSK1))) {
        return chrome.runtime.sendMessage({
          type: 'look up',
          means: 'mouse',
          text: window.getSelection().toString()
        });
      }
    }
  });
});

chrome.runtime.sendMessage({
  type: 'injected',
  url: location.href
});
