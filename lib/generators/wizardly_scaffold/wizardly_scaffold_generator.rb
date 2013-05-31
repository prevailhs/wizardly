require 'wizardly'

class WizardlyScaffoldGenerator < Rails::Generators::Base
  desc "Creates app scaffold for wizardly"
  source_root File.expand_path("../templates", __FILE__)
  argument :raw_controller_name, :type => :string, :required => true
  class_option :output, :type => :string, :default => 'html', :desc => "Generate scaffold for one of html/haml/ajax (default: html)"
  class_option :underscore, :type => :boolean, :default => false, :desc => "Append an underscore to front of each file"
  class_option :image_submit, :type => :boolean, :default => false, :desc => "Use image submit tags in forms"
  
  def add_views
    # layout
    template "layout.#{view_file_ext.first}", File.join('app/views/layouts', controller_class_path, "#{controller_name}.#{view_file_ext.last}")
    
    # views
    underscore = options[:underscore] ? '_' : ''
    pages.each do |id, @page|
      target = File.join('app', 'views', controller_class_path, controller_name, "#{underscore}#{id}.#{view_file_ext.last}")
      template "form.#{view_file_ext.first}", target
    end
  end
  
  def add_helper
    template "helper.rb.erb", File.join('app', 'helpers', controller_class_path, "#{controller_name}_helper.rb")
  end
  
  def add_stylesheet
    copy_file "style.css", "public/stylesheets/scaffold.css"
  end
  
  def add_images
    if options[:image_submit]
      %w(next skip back cancel finish).each do |fn|
        copy_file "images/#{fn}.png", "public/images/wizardly/#{fn}.png"
      end
    end
  end
  
  private
  
  def controller_class_name_without_nesting
    extract_modules[0].camelize
  end
  
  def controller_underscore_name
    extract_modules[0].underscore
  end
  
  def controller_class_path
    extract_modules[1]
  end
  
  def controller_file_path
    extract_modules[2]
  end
  
  def controller_class_nesting
    extract_modules[3]
  end
  
  def controller_class_nesting_depth
    extract_modules[4]
  end
  
  def controller_name
    controller_underscore_name.sub(/_controller$/, '')
  end
  
  def controller_class_name
    controller_class_nesting.empty? ? controller_class_name_without_nesting : "#{controller_class_nesting}::#{controller_class_name_without_nesting}"
  end
  
  def controller_class
    controller_class_name.constantize
  rescue Exception => e
    raise Wizardly::WizardlyScaffoldError, "No controller #{controller_class_name} found: " + e.message, caller
  end
  
  def wizard_config
    controller_class.wizard_config
  rescue Exception => e
    raise Wizardly::WizardlyScaffoldError, "#{controller_class_name} must contain a valid 'act_wizardly_for' or 'wizard_for_model' macro: " + e.message, caller
  end
  
  def pages
    wizard_config.pages
  end
  
  def model_name
    wizard_config.model
  end
  
  def submit_tag
    options[:image_submit] ? "wizardly_image_submit" : "wizardly_submit"
  end
  
  def view_file_ext
    options[:output] == 'haml' ? ["html.haml.erb", "html.haml"] : ["html.erb", "html.erb"]
  end
  
  def page
    @page
  end
  
  def extract_modules
    return @extract_modules if @extract_modules
    
    name    = raw_controller_name.sub(/^:/, '').underscore.sub(/_controller$/, '').camelize + 'Controller'
    
    modules = name.include?('/') ? name.split('/') : name.split('::')
    name    = modules.pop
    path    = modules.map { |m| m.underscore }
    file_path = (path + [name.underscore]).join('/')
    nesting = modules.map { |m| m.camelize }.join('::')
    @extract_modules = [name, path, file_path, nesting, modules.size]
  end
end
