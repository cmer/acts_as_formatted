module ActiveRecord
  module ActsAsFormatted
    def self.append_features(base)
      super
      base.extend(ClassMethods)
    end
      
    module ClassMethods
      private      
      def acts_as_formatted(options = {})
        $actsasformatted_store = {} unless defined?($actsasformatted_store)

        all_string_columns = self.columns.select { |c| c.type == :string }
        all_text_columns = self.columns.select { |c| c.type == :text }
        strip_spaces = true
        casing = :none

        if options[:include_text]
          all_possible_columns = all_string_columns | all_text_columns
        else
          all_possible_columns = all_string_columns
        end

        columns_to_process = Array.new
        if options[:only]
          options[:only] = [options[:only]] unless options[:only].is_a?(Array)

          options[:only].each do | inc_col |
            col = all_possible_columns.detect { |c| c.name == inc_col.to_s }
            columns_to_process << col if col
          end
        else
          columns_to_process = all_possible_columns
        end

        if options[:except]
          options[:except] = [options[:except]] unless options[:except].is_a?(Array)

          options[:except].each do |exc_col|
            columns_to_process.delete_if { |c| c.name == exc_col.to_s }
          end
        end

        if options[:strip]
          strip_spaces = options[:strip]
        end

        if options[:case]
          casing = options[:case]

          if casing.class == 'String'
            casing.downcase!
            casing = casing.to_sym
          end

          if !(casing == :up || casing == :down || casing == :swap || casing == :capitalize || casing == :capitalize_words || casing == :none)
            casing = nil
            raise "Invalid casing.  Valid casing are:  :up, :down, :swap, :capitalize, :capitalize_words, :none" 
          end
        end

        columns_to_process.each do |col|
          value = [casing, strip_spaces]
          key = self.to_s + '|' + col.name
          $actsasformatted_store[key] = value
        end

        class_eval <<-EOV
          include ActiveRecord::ActsAsFormatted::InstanceMethods
          before_save :format_strings
        EOV
      end
    end # module ClassMethods
    
    module InstanceMethods
      private
      def format_strings
        actsasformatted_store = $actsasformatted_store
        if actsasformatted_store
          actsasformatted_store.each_key { |key|
            class_name, col_name = key.split('|')
            
            formatting = actsasformatted_store[key]
            casing = formatting[0]
            strip = formatting[1]
            
            if self.class.to_s == class_name
              unless self[col_name].nil?
                self[col_name].strip! if strip
            
                if casing == :down
                  self[col_name].downcase!
                elsif casing == :up
                  self[col_name].upcase!
                elsif casing == :swap
                  self[col_name].swapcase!              
                elsif casing == :capitalize
                  self[col_name].capitalize!
                elsif casing == :capitalize_words
                  self[col_name] = capitalize_words(self[col_name])
                end
              end
            end
          }
        end
      end # format_strings
            
      def capitalize_words(s)
        s.split(' ').each{|word| word.capitalize!}.join(' ')
      end   
      
    end # module InstanceMethods    
  end # module ActsAsFormatted
end # module ActiveRecord

ActiveRecord::Base.class_eval do 
  include ActiveRecord::ActsAsFormatted
end