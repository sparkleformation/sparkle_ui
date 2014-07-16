var sparkle_ui = {display: {}, list: {}, show: {}, form: {}, create: {}, configuration: {}, load_messages: {}};

/**
 * Provide configuration value or default value
 *
 * @param key [String]
 * @param default_value [Object]
 * @return [Object]
 **/
sparkle_ui.config = function(key, default_value){
  if(sparkle_ui.configuration[key] == undefined){
    return default_value;
  } else {
    return sparkle_ui.configuration[key];
  }
}

/**
 * Highlight the element
 *
 * @param dom_id [String] DOM ID of the element
 * @param state [String] success, warning, danger (defaults warning)
 **/
sparkle_ui.display.highlight = function(dom_id, state){
  if(state == undefined){
    state = 'warning';
  }
  $('#' + dom_id).addClass('highlight-' + state);
  setTimeout(function(){
    $('#' + dom_id).removeClass('highlight-' + state);
  }, 2100);
}

/**
 * Start index list update via interval polling
 *
 * @return [null]
 * @note updates are 15 second intervals and is configurable via
 *  the `index_poll_interval` configuration value
 **/
sparkle_ui.list.poll = function(){
  if(sparkle_ui.list.in_progress().length > 0){
    setTimeout(
      sparkle_ui.list.poll_request,
      sparkle_ui.config('index_poll_interval', 15000)
    );
  }
}

/**
 * @return [jQuery::Elements] stack elements currently in progress
 **/
sparkle_ui.list.in_progress = function(){
  return $('#stack-listing .progress.active');
}

/**
 * @return [Array<String>] DOM IDs of stacks in progress
 **/
sparkle_ui.list.in_progress_ids = function(){
  return sparkle_ui.list.in_progress().map(
    function(){ return $(this).attr('id'); }
  ).toArray();
}

/**
 * @return [Array<String>] stack names of stacks in progress
 **/
sparkle_ui.list.in_progress_stack_names = function(){
  return sparkle_ui.list.in_progress().map(
    function(){ return $(this).attr('data-stack-name'); }
  ).toArray();
}

/**
 * Fire polling request to update stack list
 **/
sparkle_ui.list.poll_request = function(){
  $.get(
    $('#stack-info-list').attr('data-url'),
    $.param({stack_names: sparkle_ui.list.in_progress_stack_names()})
  ).fail(function(){
    window_rails.alert.open('Stack list update request failed!');
  }).always(function(){ sparkle_ui.list.poll(); });
}

/**
 * Start stack event list update via interval polling
 *
 * @return [null]
 * @note updates are 15 second intervals and is configurable via
 *  the `show_poll_interval` configuration value
 **/
sparkle_ui.show.poll = function(){
  if($('#stack-event-list').attr('data-state') == 'active'){
    setTimeout(
      sparkle_ui.show.poll_request,
      sparkle_ui.config('show_poll_interval', 15000)
    );
  }
}

/**
 * Fire polling request to update stack events list
 **/
sparkle_ui.show.poll_request = function(){
  $.get(
    $('#stack-event-list').attr('data-url')
  ).fail(function(){
    window_rails.alert.open({content: 'Stack event update request failed!'});
  }).always(function(){ sparkle_ui.show.poll(); });
}

/**
 * Poll for new stack availability
 *
 * @param url [String] polling endpoint URL
 **/
sparkle_ui.create.poll_availability = function(url, error_url){
  setTimeout(
    function(){
      $.get(url).success(
        function(){
          window_rails.loading.close();
          window_rails.info.open({content: 'Stack initialization complete! Loading details...'});
        }
      ).error(
        function(response, status){
          if(status == 404){
            sparkle_ui.create.poll_availability(url);
          } else {
            window_rails.loading.close();
            window_rails.alert.open({
              title: 'Initialization polling error',
              content: 'Unexpected error encountered: ' + response.responseText
            });
            error_redirect = sparkle_ui.config('create_poll_error_redirect_url', error_url);
            if(error_redirect){
              setTimeout(function(){window.document.location = error_redirect;}, 10000);
            }
          }
        }
      )
    },
    sparkle_ui.config('stack_initialize_poll', 15000)
  );
}

/**
 * Register select form fields that are AJAX updatable
 *
 * @param dom_id [String] DOM ID of the select element
 * @param args [Hash]
 * @option args [String] :message optional loading message
 * @option args [Object] :default_value value to default selection
 * @note default value will be selected dynamically after page load to trigger update event
 **/
sparkle_ui.form.register_updatable_select = function(dom_id, args){
  if(args.message){
    sparkle_ui.load_messages[dom_id] = args.message;
  }
  if(args.default_value){
    default_setter = function(){
      $('#' + dom_id).val(args.default_value).trigger('change');
    }
    $(document).ready(default_setter);
    $(document).on('page:load', default_setter);
  }
}

/**
 * Enable updatable form select elements
 **/
sparkle_ui.form.enable_updatable_selectors = function(){
  updater = function(){
    $('select[sparkle-url]').change(function(){
      args = sparkle_ui.load_messages[$(this).attr('id')] || {}
      if(!args.title && $(this).attr('sparkle-loading')){
        args.title = $(this).attr('sparkle-loading');
      }
      window_rails.loading.open({title: args.message});
      if($(this).attr('sparkle-serialize') == 'only-self'){
        data = $(this).serializeObject();
      } else {
        data = $(this).parents('form').serializeObject();
      }
      if($(this).attr('sparkle-ajax')){
        $.ajax({
          url: $(this).attr('sparkle-url'),
          type: (args.method || $(this).attr('sparkle-ajax') || 'post').toUpperCase(),
          data: data,
          dataType: 'script'
        }).done(function(){
          window_rails.loading.close();
        }).fail(function(){
          window_rails.loading.close();
          window_rails.alert.open({content: 'Error updating form!'});
        });
      } else {
        window.document.location = $(this).attr('sparkle-url') + '?' + $.param(data);
      }
    });
  }
  $(document).ready(updater);
  $(document).on('page:load', updater);
}
