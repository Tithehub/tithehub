
(function() {
  var script = document.currentScript;
  var org = script.getAttribute('data-org') || 'your org';
  var url = script.getAttribute('data-url') || 'https://tithehub.github.io/';

  var button = document.createElement('button');
  button.innerHTML = '💛 Donate to ' + org;
  button.style.background = '#f2994a';
  button.style.color = 'white';
  button.style.padding = '12px 24px';
  button.style.fontSize = '1em';
  button.style.border = 'none';
  button.style.borderRadius = '6px';
  button.style.cursor = 'pointer';
  button.style.fontFamily = 'Arial, sans-serif';
  button.onclick = function() {
    window.open(url, '_blank');
  };

  script.parentNode.insertBefore(button, script);
})();
