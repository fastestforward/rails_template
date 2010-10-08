// Place your application-specific JavaScript functions and classes here
// This file is automatically included by javascript_include_tag :defaults
if (typeof console === 'undefined') { 
  console = {
    logs: [],
    infos: [],
    debugs: [],
    errors: [],
    log: function(message) {
      this.logs.push(String(message));
    },
    info: function(message) {
      this.infos.push(String(message));
    },
    debug: function(message) {
      this.debugs.push(String(message));
    },
    error: function(message) {
      this.errors.push(String(message));
    }
  };
};
