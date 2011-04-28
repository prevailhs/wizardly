#require 'wizardly'

class WizardlyAppGenerator < Rails::Generators::Base
  desc "Create wizardly rake tasks"
  source_root File.expand_path("../templates", __FILE__)
  
  def add_task
    template "wizardly.rake", "lib/tasks/wizardly.rake"
  end
end
