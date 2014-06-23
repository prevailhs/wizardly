module ValidationGroup
  module ActiveModel
    module Errors
      def add_with_validation_group(attribute, *args, &block)
          # jeffp: setting @current_validation_fields and use of should_validate? optimizes code
          add_error = @base.respond_to?(:should_validate?) ? @base.should_validate?(attribute.to_sym) : true
          add_without_validation_group(attribute, *args, &block) if add_error
      end

      def remove_on(attributes)
        return unless attributes

        attributes = [attributes] unless attributes.is_a?(Array)
        self.reject!{|k,v| !attributes.include?(k.to_sym)}
      end

      def self.included(base) #:nodoc:
        base.class_eval do
          alias_method_chain :add, :validation_group
        end
      end
    end
  end

  module InstanceMethods # included in every model which calls validation_group
    #needs testing
  #      def reset_fields_for_validation_group(group)
  #        group_classes = self.class.validation_group_classes
  #        found = ValidationGroup::Util.current_and_ancestors(self.class).find do |klass|
  #          group_classes[klass] && group_classes[klass].include?(group)
  #        end
  #        if found
  #          group_classes[found][group].each do |field|
  #            self[field] = nil
  #          end
  #        end
  #      end
    def enable_validation_group(group)
      # Check if given validation group is defined for current class or one of
      # its ancestors
      group_classes = self.class.validation_group_classes
      found = ValidationGroup::Util.current_and_ancestors(self.class).find do |klass|
        group_classes[klass] && group_classes[klass].include?(group)
      end
      if found
        @current_validation_group = group
        # jeffp: capture current fields for performance optimization
        @current_validation_fields = group_classes[found][group]
      else
        raise ArgumentError, "No validation group of name :#{group}"
      end
    end

    def disable_validation_group
      @current_validation_group = nil
      # jeffp: delete fields
      @current_validation_fields = nil
    end

    def reject_non_validation_group_errors
      return unless validation_group_enabled?
      self.errors.remove_on(@current_validation_fields)
    end

    # jeffp: optimizer for someone writing custom :validate method -- no need
    # to validate fields outside the current validation group note: could also
    # use in validation modules to improve performance
    def should_validate?(attribute)
      !self.validation_group_enabled? || (@current_validation_fields && @current_validation_fields.include?(attribute.to_sym))
    end

    def validation_group_enabled?
      respond_to?(:current_validation_group) && !current_validation_group.nil?
    end

    # Don't override valid? as that causes abnormal and hard to track down
    # behavior; instead provide a valid_for that ensures validation group is
    # enabled then disabled
    def valid_for_validation_group?(group)
      self.enable_validation_group(group)
      result = valid?
      self.disable_validation_group
      result
    end

    # Expose a hook to add more attributes to persist with wizardly
    def wizardly_attributes
      self.class.wizardly_attributes.inject(attributes) do |attrs, attr_name|
        attrs.merge(attr_name.to_s => send(attr_name))
      end.merge(self.class.wizardly_nested_attributes.inject({}) do |attrs, nested_name|
        i = 0
        attrs.merge("#{nested_name}_attributes" => send(nested_name).inject({}) do |h, obj|
          h.merge((i += 1).to_s => obj.wizardly_attributes)
        end)
      end)
    end
  end

  module ActsMethods # extends ActiveRecord::Base
    def self.extended(base)
      # Add class accessor which is shared between all models and stores
      # validation groups defined for each model
      base.class_eval do
        cattr_accessor :validation_group_classes
        self.validation_group_classes = {}

        def self.validation_group_order; @validation_group_order; end
        def self.validation_groups(all_classes = false)
          return (self.validation_group_classes[self] || {}) unless all_classes
          klasses = ValidationGroup::Util.current_and_ancestors(self).reverse
          hash = Hash.new

          klasses.each do |klass|
            hash.merge! self.validation_group_classes[klass]
          end
        end
      end
    end

    def validation_group(name, options={})
      self_groups = (self.validation_group_classes[self] ||= {})
      self_groups[name.to_sym] = case options[:fields]
      when Array then options[:fields]
      when Symbol, String then [options[:fields].to_sym]
      else []
      end
      # jeffp: capture the declaration order for this class only (no
      # superclasses)
      (@validation_group_order ||= []) << name.to_sym

      unless included_modules.include?(InstanceMethods)
        # jeffp: added reader for current_validation_fields
        attr_reader :current_validation_group, :current_validation_fields
        include InstanceMethods
      end
    end

    # TODO Consider making a more formal accessor for this class attribute
    def wizardly_attribute(name)
      attr_accessor name
      wizardly_attributes << name
    end

    def wizardly_attributes
      (@wizardly_attributes ||= [])
    end

    # Expose helper to declare a nested attribute that should come along with
    # the saved wizardly items
    def wizardly_nested_attributes_for(*names)
      wizardly_nested_attributes.concat(names)
    end

    def wizardly_nested_attributes
      (@wizardly_nested_attributes ||= [])
    end
  end

  module Util
    # Return array consisting of current and its superclasses down to and
    # including base_class.
    def self.current_and_ancestors(current)
      klasses = []

      klasses << current
      root = current.base_class
      until current == root
        current = current.superclass
        klasses << current
      end

      klasses
    end
  end
end

# jeffp:  moved from init.rb for gemification purposes --
# require 'validation_group' loads everything now, init.rb requires 'validation_group' only
ActiveRecord::Base.send(:extend, ValidationGroup::ActsMethods)
ActiveModel::Errors.send(:include, ValidationGroup::ActiveModel::Errors)
