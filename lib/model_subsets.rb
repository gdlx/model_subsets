require "model_subsets/version"

module ModelSubsets

    # Includes class methods
    def self.included(base)
      base.extend ModelSubsets::ClassMethods
    end

    # Provides current subset fieldset list
    def fieldset
      self.class.subset_fieldset(self.subset)
    end

    # Whether a field is included in subset fieldset
    def has_field? field
      fieldset.include? field
    end

    # Whether subset has a fieldset
    def has_fieldset? fieldset
      return unless self.class.subsets.has_key? self.subset
      self.class.subsets[self.subset][:fieldsets].include? fieldset
    end

    def valid_subset?
      return true if self.class.subsets.keys.include? self.subset
      errors.add(:subset, :invalid) if self.respond_to? errors
      return false
    end

    module ClassMethods

      def fieldset *args
        fieldset = args.shift
        raise "fieldset id must be a Symbol (#{fieldset.class} given)" unless fieldset.is_a? Symbol
        raise "fieldset fields must be an Array (#{args.class} given)" unless args.is_a? Array
        args.each do |field|
          raise "field name must be an Symbol (#{field.class} given)" unless field.is_a? Symbol
        end
        @fieldsets ||= {}
        @fieldsets[fieldset] = args
      end

      # Provides subset fieldset list
      def subset_fieldset subset
        return unless subsets.has_key? subset
        subset_fields = []
        subsets[subset][:fieldsets].each do |fieldset|
          fieldset       = @fieldsets[fieldset].is_a?(Array) ? @fieldsets[fieldset] : [@fieldsets[fieldset]]
          subset_fields |= fieldset
        end
        subset_fields.uniq
      end

      def subset subset, options = {}
        raise "subset id must be a Symbol (#{subset.class} given)" unless subset.is_a? Symbol
        raise "subset options must be a Hash (#{options.class} given)" unless options.is_a? Hash
        @subsets_config ||= {}
        @subsets_config[subset] = options
      end

      # Provides subsets with builded extends & fieldsets
      def subsets options = {}
        @subsets_config ||= {}
        raise "subsets config must ba a Hash (#{@subsets_config.class} given)" unless @subsets_config.is_a? Hash

        # Cache builded subsets
        return @subsets unless @subsets.blank? || options[:purge]

        @subsets = {}

        @subsets_config.each do |subset, options|
          # Can't define same subset twice
          raise "subset '#{subset} is already defined" if @subsets.has_key? subset

          # Subset is an extension
          if options[:extends]

            # Force extends option to Array
            options[:extends] = [options[:extends]] unless options[:extends].is_a? Array
            options[:extends].each do |source_subset|
              next unless @subsets.has_key? source_subset
              source_options = @subsets[source_subset].clone
              source_options.delete  :abstract
              options = source_options.merge options
            end

            # Handle additional fieldsets list
            if options[:with]
              options[:with]       = [options[:with]] unless options[:with].is_a? Array
              options[:fieldsets] |= options[:with]
            end

          else
            # Include all fieldsets by default
            options[:fieldsets] = @fieldsets.keys
          end

          # Handle inclusion list
          if options[:only]
            options[:only]       = [options[:only]] unless options[:only].is_a? Array
            options[:fieldsets] &= options[:only]
          end

          # Handle exclusion list
          if options[:except]
            options[:except]     = [options[:except]] unless options[:except].is_a? Array
            options[:fieldsets] -= options[:except]
          end

          # Cleanup
          options[:fieldsets] = options[:fieldsets].uniq & @fieldsets.keys
          remove_options      = [:extends, :with, :only, :except]
          options             = options.clone
          options.delete_if{ |key, value| remove_options.include?(key) }
          @subsets[subset] = options
        end

        @subsets = @subsets.reject{|key, value| value[:abstract] == true}
      end

      # Provides subsets groups list formatted for use with grouped collection select
      def subsets_groups
        groups     = {}
        i18n_group = {}

        subsets.each do |subset, options|
          raise "subset id must be a Symbol (#{subset.class} given)" unless subset.is_a? Symbol

          # Set default group
          options[:group] = :default unless options[:group]

          raise "group id must be a Symbol (#{options[:group].class} given)" unless options[:group].is_a? Symbol

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
    end
end
