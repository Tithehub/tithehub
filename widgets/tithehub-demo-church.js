(function(){
  var d=document;
  function ready(fn){ if(d.readyState!=='loading'){fn();} else {d.addEventListener('DOMContentLoaded',fn);} }
  ready(function(){
    var container = d.createElement('div');
    container.style.maxWidth='420px';
    container.style.margin='0 auto';
    container.style.border='1px solid #eee';
    container.style.borderRadius='12px';
    container.style.padding='16px';
    container.style.boxShadow='0 6px 20px rgba(0,0,0,0.07)';

    var h=d.createElement('h3'); h.textContent="TitheHub Demo Church"; h.style.marginTop='0'; container.appendChild(h);

    var a=d.createElement('a');
    a.href="https://tithehub.com/donate/tithehub-demo-church";
    a.target='_blank';
    a.rel='noopener';
    a.textContent='Open donation page';
    a.style.display='inline-block';
    a.style.padding='10px 14px';
    a.style.border='1px solid #ccc';
    a.style.borderRadius='8px';
    a.style.textDecoration='none';
    container.appendChild(a);

    var img=d.createElement('img');
    img.src="https://tithehub.com/qrs/tithehub-demo-church.png";
    img.alt='Donation QR';
    img.style.display='block';
    img.style.width='100%';
    img.style.maxWidth='360px';
    img.style.margin='12px auto 0';
    container.appendChild(img);

    (document.currentScript && document.currentScript.parentNode || d.body).appendChild(container);
  });
})();