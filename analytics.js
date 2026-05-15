/**
 * Vercel Web Analytics Initialization
 * Implements the official Vercel Analytics pattern for static HTML sites
 * @see https://vercel.com/docs/analytics/quickstart
 */
(function() {
  'use strict';
  
  // Prevent double initialization
  if (window.vai) return;
  
  // Initialize the analytics queue function
  // This allows tracking calls before the main script loads
  window.va = window.va || function () {
    (window.vaq = window.vaq || []).push(arguments);
  };
  
  // Mark as initialized
  window.vai = true;
  
  // Set mode to production (can be overridden to 'development' for local testing)
  window.vam = 'production';
  
  // Create and inject the Vercel Analytics script
  var script = document.createElement('script');
  script.defer = true;
  script.src = '/_vercel/insights/script.js';
  
  // Insert the script into the document
  var firstScript = document.getElementsByTagName('script')[0];
  if (firstScript && firstScript.parentNode) {
    firstScript.parentNode.insertBefore(script, firstScript);
  } else {
    document.head.appendChild(script);
  }
})();
