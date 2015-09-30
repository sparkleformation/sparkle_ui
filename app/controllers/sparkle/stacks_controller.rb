require 'tempfile'

class Sparkle::StacksController < ApplicationController

  helper_method :stacks_api

  if(defined?(SparkleBuilder))
    include SparkleBuilder::Persistence
  end

  # Decode stack id if found in parameters
  before_filter do
    if(params[:id])
      begin
        params[:id] = Base64.urlsafe_decode64(params[:id])
      rescue ArgumentError
        Rails.logger.warn "ID decoding failed for #{params[:id]} - #{e.class}: #{e}"
      end
    end
  end

  def index
    respond_to do |format|
      format.html do
        # This is super horrible, but we can make better later when we
        # get the caching support rolling again
        @children = stacks_api.stacks.all.map(&:nested_stacks).flatten.find_all{|x| x.data[:parent_stack]}.map(&:id)
        @stacks = stacks_api.stacks.all.find_all do |stk|
          !@children.include?(stk.id)
        end.sort do |x, y|
          if(x.created.nil?)
            1
          elsif(y.created.nil?)
            -1
          else
            y.created <=> x.created
          end
        end
        @stacks = @stacks.paginate(params)
      end
    end
  end

  def show
    respond_to do |format|
      format.html do
        @stack = stacks_api.connection.stacks.get(params[:id])
        unless(@stack)
          flash[:error] = "Failed to locate requested stack (ID: #{params[:id]})"
          redirect_to sparkle_stacks_path
        end
      end
    end
  end

  def new
    respond_to do |format|
      format.html do
        @templates = template_selection_list
        @template_file = params.fetch(:template_file,
          Rails.application.config.sparkle.fetch(:default_create_template,
            @templates.flatten.detect do |t|
              !t.split('/').last.start_with?('_') &&
                t.end_with?('.rb')
            end
          )
        )
        if(stack_name_auto_generated?)
          @stack_name = generate_stack_name(
            :template_file => @template_file,
            :user => current_user
          )
        end
        @template = load_template(@template_file)
        preprocess_template(@template)
      end
    end
  end

  def create
    respond_to do |format|
      format.html do
        begin
          template_file = params.delete(:template_file)
          template = load_template(template_file)
          parameters = Hash[
            params.map do |key, value|
              next unless key.start_with?('template_')
              [key.sub('template_', '').camelize, value]
            end.compact
          ]
          stack_arguments = Rails.application.config.sparkle.
            fetch(:stack_creation_defaults, {})
          stack_name = params.delete(:stack_name)
          KnifeCloudformation::Utils::StackParameterScrubber.scrub!(template)
          new_stack = stacks_api.stacks.new(
            stack_arguments.merge(
              :stack_name => stack_name,
              :parameters => parameters,
              :template => template.to_json
            )
          ).create
          stacks_api.update_stack_list!
          redirect_to wait_sparkle_stacks_path(:stack_name => new_stack.name)
        rescue => e
          Rails.logger.error "Stack creation failed! #{e.class}: #{e.message}"
          Rails.logger.debug "#{e.class}: #{e}\n#{e.backtrace.join("\n")}"
          flash[:error] = "Stack creation failed: #{e.message}"
          redirect_to sparkle_stacks_path
        end
      end
    end
  end

  def edit
    respond_to do |format|
      format.html do
        flash[:notice] = "Stack updates not currently supported"
        redirect_to sparkle_stacks_path
      end
    end
  end

  def update
    respond_to do |format|
      format.html do
        flash[:notice] = "Stack updates not currently supported"
        redirect_to sparkle_stacks_path
      end
    end
  end

  def wait
    @stack_name = params[:stack_name]
    respond_to do |format|
      format.js do
        if(@stack_name)
          @stack = stacks_api.stacks.detect{|s| s.name == @stack_name}
          unless(@stack)
            render :text => "Stack not found (#{@stack_name})", :status => 404
          end
        else
          render :text => 'No stack name provided!', :status => 400
        end
      end
      format.html do
        unless(@stack_name)
          flash[:error] = 'No stack name provided!'
          redirect_to sparkle_stacks_path
        end
      end
    end
  end

  def destroy
    @stack = stacks_api.stacks.get(params[:id])
    begin
      unless(SparkleUi.stack_modification_allowed?(current_user, @stack))
        raise "Current user is not allowed to modify this stack!"
      end
      @stack.destroy
      stacks_api.remove_stack(params[:id])
      result = "Stack has been destroyed: #{@stack.name}"
    rescue => error
      Rails.logger.error "Failed to destroy stack: #{error.class}: #{error}"
      Rails.logger.debug "#{error.class}: #{error}\n#{error.backtrace.join("\n")}"
      result = error.message
    end
    respond_to do |format|
      format.js do
        if(error)
          render :text => result, :status => 500
        else
          @result = result
        end
      end
      format.html do
        flash[error ? :error : :success] = result
        redirect_to sparkle_stacks_path
      end
    end
  end

  def events
    respond_to do |format|
      format.js do
        @stack = stacks_api.stack(params[:id])
        @events = @stack.events.all.slice(0, @stack.events.all.map(&:id).index(params[:event_id]).to_i)
      end
    end
  end

  def status
    respond_to do |format|
      format.js do
        @stacks = params[:stack_names].map{|s_name| stacks_api.stacks.get(s_name) }
        @removed_stacks = params[:stack_names] - @stacks.map(&:name)
      end
    end
  end

  private

  def stacks_api
    Rails.application.config.sparkle[:provider_api]
  end

  def template_selection_list
    {}.tap do |list|
      Dir.glob(File.join(SparkleFormation.sparkle_path, '**', '*.rb')).map do |file|
        file.sub!("#{SparkleFormation.sparkle_path}/", '')
        next if file =~ /(dynamics|components|registry)/
        file
      end.compact.map do |file|
        parts = file.split('/', 2)
        if(parts.size == 1)
          key = 'default'
          file_name = parts.first
        else
          key, file_name = parts
        end
        key = key.tr('-', '_').humanize
        list[key] ||= []
        list[key] << [file_name.tr('-', '_').sub(/\..+$/, '').humanize, file]
      end
      list.values.map do |ary|
        ary.sort! do |x, y|
          x.first <=> y.first
        end
      end
      add_builder_templates(list)
    end.to_a.sort do |x, y|
      x.first <=> y.first
    end
  end

  def add_builder_templates(list)
    if(respond_to?(:list_templates))
      list['User Built'] = list_templates.map(&:identity).map do |file|
        file = File.basename(file).sub(File.extname(file), '')
        [file.tr('-', '_').humanize, "BUILDER-#{file}"]
      end
    end
  end

  def stack_name_auto_generated?
    !!Rails.application.config.sparkle[:stack_name_generator]
  end

  def generate_stack_name(args={})
    Rails.application.config.sparkle[:stack_name_generator].call(args)
  end

  def load_template(file)
    if(file.start_with?('BUILDER-'))
      MultiJson.load(
        fetch_template(
          file.sub('BUILDER-', '')
        )
      )
    else
      SparkleFormation.compile(
        File.join(
          SparkleFormation.sparkle_path,
          file
        )
      )
    end
  end

  def preprocess_template(template)
    if(preprocess = Rails.application.config.sparkle[:stack_template_preprocessor])
      preprocess.call(:user => current_user, :template => template)
    end
    template
  end

end
