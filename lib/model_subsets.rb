require "model_subsets/version"

module ModelSubsets

  extend ActiveSupport::Concern

  # Return current subset fieldsets list
  #
  # @return [ Array ]
  #
  # @since 0.0.2
  def fieldsets
    subset_content[:fieldsets] if valid_subset?
  end

  # Whether subset includes a fieldset
  #
  # @example Check if a user has fieldset :common
  #   user.has_fieldset? :common
  #
  # @param [ Symbol ] name The fieldset name
  #
  # @return  [ Boolean ]
  #
  # @since 0.0.2
  def has_fieldset? name
    fieldsets.include?(name) if valid_subset?
  end

  # Whether subset is included in a subsets scope
  #
  # @example Check if current subset is in :users subsets scope
  #   person.in_subset_scope? :users
  #
  # @param [ Symbol ] name The subsets scope name
  #
  # @return [ Boolean ]
  #
  # @since 0.0.4
  def in_subsets_scope? name
    self.class.subsets_scope(name).include? subset.to_sym
  end

  # Returns current subset content
  # An empty Hash is returned if subset is not defined
  #
  # @return [ Hash ]
  #
  # @since 0.0.2
  def subset_content
    self.class.subsets[subset.to_sym] if valid_subset? 
  end

  # Whether a subset fieldset includes a field
  # It only checks if the field is included in current subset fieldsets, not if the field is a column in the model
  #
  # @example Check if a user uses field :name
  #   user.has_field? :name
  #
  # @param [ Symbol ] name The field name
  #
  # @return [ Boolean ]
  #
  # @since 0.0.2
  def subset_field? name
    subset_fields.include?(name) if subset_fields
  end

  # Return current subset fields list
  #
  # @return [ Array ]
  #
  # @since 0.0.2
  def subset_fields
    self.class.subset_fields(subset.to_sym) if valid_subset?
  end

  # Whether current subset id is defined
  # 
  # @example Use valid_subset? as a model validation
  #   validate :valid_subset?
  #
  # @return [ Boolean ]
  #
  # @since 0.0.2
  def valid_subset?
    return true if self.class.subsets.keys.include?(subset.to_s.to_sym)
    errors.add(:subset, :invalid) if respond_to?(:errors)
    false
  end

  module ClassMethods

    # Defines a fieldset
    #
    # @example Define fieldset :login including fields :username and :password
    #   fieldset :login, :username, :password
    #
    # @param [ Symbol ] name    The fieldset name
    # @param [ Array ]  *args   Fields names
    # @param [ Hash ]   options The fieldset options
    #
    # @option options [ Boolean ] :opt_in Whether fieldset is NOT included by default in subsets (Default: false = opt-out)
    #
    # @since 0.0.2
    def fieldset name, *args
      options = args.last.is_a?(Hash) ? args.pop : {}

      @fieldsets     ||= {}
      @fieldsets[name] = { options: options, fields: args }
    end
    
    # Defines a subset
    # If no fieldset is included, all defined fieldsets will be included by default
    # If fieldsets are defined on an extended subset, parents fieldsets will be ignored
    #
    # @example Define subset :user, which is a person able to login
    #   subset :user, extends: :person, with: :login, scopes: :users
    #
    # @param [ Symbol ] name    The subset name
    # @param [ Hash ]   options The options to pass to the subset
    #
    # @option options [ Boolean ]       :template  Whether subset is a template (only used as an extend)
    # @option options [ Symbol ]        :group     Subset group name
    # @option options [ Symbol, Array ] :fieldsets Explicit fieldsets list. Overrides default list (all or herited)
    # @option options [ Symbol, Array ] :scopes    The scopes in which subset will be included
    # @option options [ Symbol, Array ] :extends   Parent subsets
    # @option options [ Symbol, Array ] :add       Fieldsets to be added to default of herited fieldsets
    # @option options [ Symbol, Array ] :only      Filters fieldsets to remove fielsets not being in this list
    # @option options [ Symbol, Array ] :except    Filters fieldsets to remove fieldsets being in this list
    #
    # @since 0.0.2
    def subset name, options = {}
      @subsets        ||= {}
      @subsets_scopes ||= {}

      options[:fieldsets] = [options[:fieldsets]] unless options[:fieldsets].blank? || options[:fieldsets].is_a?(Array)

      # Subset is an extension
      if options[:extends]
        # Force extends option to Array
        options[:extends] = [options[:extends]] unless options[:extends].is_a?(Array)
        options[:extends].each do |source_subset|
          next unless @subsets.has_key? source_subset
          source_options = @subsets[source_subset].clone
          source_options.delete :template
          options = source_options.merge options
          options[:scopes] = [source_options[:scopes], options[:scopes]].flatten.uniq if source_options[:scopes]
        end

      # Include all opt-out fieldsets by default
      elsif options[:fieldsets].blank?
        options[:fieldsets] = @fieldsets.reject{ |k,v| v[:options][:opt_in] }.keys
      end

      # Handle fieldsets restriction list
      if options[:only]
        options[:only] = [options[:only]] unless options[:only].is_a?(Array)
        options[:fieldsets] &= options[:only]
      end

      # Handle fieldsets exclusion list
      if options[:except]
        options[:except] = [options[:except]] unless options[:except].is_a?(Array)
        options[:fieldsets] -= options[:except]
      end

      # Handle additional fieldsets list
      if options[:add]
        options[:add] = [options[:add]] unless options[:add].is_a?(Array)
        options[:fieldsets] |= options[:add]
      end

      # Handle scopes
      options[:scopes] ||= []
      options[:scopes] = [options[:scopes]] unless options[:scopes].is_a?(Array)
      options[:scopes].each do |subset_scope|
        @subsets_scopes[subset_scope] ||= []
        @subsets_scopes[subset_scope] << name unless options[:template]
        scope subset_scope, where(:subset.in => @subsets_scopes[subset_scope])
      end

      # Cleanup
      options[:fieldsets] = options[:fieldsets].uniq & @fieldsets.keys
      remove_options      = [:extends, :add, :only, :except]
      options             = options.clone
      options.delete_if{ |key, value| remove_options.include?(key) }

      # Register subset
      @subsets[name] = options
    end

    # Return subset fields list
    #
    # @example Get fields included in subset :user of model Person
    #   Person.subset_fields :user
    #   => [ :name, :givenname, :username, :password ]
    #
    # @params [ Symbol ] name The subset name
    #
    # @returns [ Array ]
    #
    # @since 0.0.1
    def subset_fields name
      return unless subsets.has_key?(name) && subsets[name].has_key?(:fieldsets)
      subset_fields = []
      subsets[name][:fieldsets].each do |fieldset|
        fields   = @fieldsets[fieldset][:fields]
        fieldset = fields.is_a?(Array) ? fields : [fields]
        subset_fields |= fieldset
      end
      subset_fields.uniq
    end

    # Return builded subsets
    #
    # @return [ Hash ]
    #
    # @since 0.0.1
    def subsets
      @subsets.reject{ |name, options| options[:template] }
    end

    # Provides grouped subsets list, formatted for use with grouped collection select
    # 
    # @return [ Array ]
    #
    # @since 0.0.1
    def subsets_groups
      groups     = {}
      i18n_group = {}

      subsets.each do |subset, options|
        options[:group] = :default unless options[:group]
        i18n_subset                   = self.human_attribute_name("subsets.#{subset}")
        i18n_group[options[:group]] ||= self.human_attribute_name("subsets.#{options[:group]}")
        groups[i18n_group[options[:group]]] ||= [options[:group], {}]
        groups[i18n_group[options[:group]]].last[i18n_subset] = subset
      end

      # Rearrange groups
      groups = groups.sort
      groups.map do |group|
        [group.last.first, group.first, group.last.last.sort]
      end
    end

    # Return subsets included of a subsets scope
    # 
    # @return [ Array ]
    #
    # @since 0.0.2
    def subsets_scope name
      subsets_scopes[name] || []
    end

    # Return subsets scopes list
    # 
    # @return [ Array ]
    #
    # @since 0.0.2
    def subsets_scopes
      @subsets_scopes
    end
  end
end
