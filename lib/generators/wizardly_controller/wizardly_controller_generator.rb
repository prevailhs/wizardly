require 'wizardly'

class WizardlyControllerGenerator < Rails::Generators::Base
  desc "Creates a wizardly controller"
  source_root File.expand_path("../templates", __FILE__)
  argument :controller_name, :type => :string, :required => true
  argument :model_name, :type => :string, :required => true
  class_option :completed_redirect, :type => :string, :required => false, :description => "URL to redirect to after completing the wizard"
  class_option :canceled_redirect, :type => :string, :required => false, :description => "URL to redirect to after canceling the wizard"
  
  def add_controller
    template "controller.rb.erb", "app/controllers/#{controller_name}_controller.rb"
  end
  
  def add_helper
    template "helper.rb.erb", "app/helpers/#{controller_name}_helper.rb"
  end
  
  private
  
    def wizard_config
      return @wizard_config if @wizard_config
      
      opts = {}
      opts[:completed] = options[:completed_redirect] if options[:completed_redirect]
      opts[:canceled] = options[:canceled_redirect] if options[:canceled_redirect]
      
      @wizard_config = Wizardly::Wizard::Configuration.new(controller_name, opts)
      @wizard_config.inspect_model!(model_name.to_sym)
      @wizard_config
    end
    
    def controller_class_name
      "#{controller_name.camelize}Controller"
    end
    
    def model_class_name
      model_name.camelize
    end
    
    def action_methods
      wizard_config.print_page_action_methods
    end
    
    def callback_methods
      wizard_config.print_callbacks
    end
    
    def helper_methods
      wizard_config.print_helpers
    end
    
    def callback_macro_methods
      wizard_config.print_callback_macros
    end
end
