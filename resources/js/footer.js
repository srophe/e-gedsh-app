const footerHTML = `<footer style="padding: 1em 0; margin: 0; width: 100%; display: flex; justify-content: center;">
<div style="width: 70%; text-align: center; margin: 0; padding: 0;">
<p style="color:#666">Copyright © 2011 Beth Mardutho: The Syriac Institute</p>
</p>
<p style="color:#666">The content of this site is licensed under a Creative Commons Attribution-NonCommercial 4.0 International License.</p>
<img alt="Creative Commons License" style="border-width:0" src="resources/img/cc.png" height="18px" /> 

</div>
</footer>`;

const bootstrapScript = document.createElement('script');
bootstrapScript.setAttribute('type', 'text/javascript');
bootstrapScript.setAttribute('src', '/resources/js/bootstrap.min.js');

const jqueryScript = document.createElement('script');
jqueryScript.setAttribute('type', 'text/javascript');
jqueryScript.setAttribute('src', '/resources/js/jquery.validate.min.js');

const mainScript = document.createElement('script');
mainScript.setAttribute('type', 'text/javascript');
mainScript.setAttribute('src', '/resources/js/main.js');
 
document.addEventListener('DOMContentLoaded', function() {
    document.body.insertAdjacentHTML('beforeend', footerHTML);
    document.body.appendChild(bootstrapScript);
    document.body.appendChild(jqueryScript);
    document.body.appendChild(mainScript);
});
