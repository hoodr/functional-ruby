require_relative 'abstract_struct'
require_relative 'type_check'

module Functional

  # @!macro record
  #
  # @see Functional::AbstractStruct
  # @see Functional::Union
  module Record
    extend self

    # Create a new record class with the given fields.
    #
    # @return [Functional::AbstractStruct] the new record subclass
    # @raise [ArgumentError] no fields specified
    def new(*fields, &block)
      raise ArgumentError.new('no fields provided') if fields.empty?
      build(fields, &block)
    end

    private

    # @!visibility private
    #
    # A set of restrictions governing the creation of a new record.
    class Restrictions
      include TypeCheck

      # Create a new restrictions object by processing the given
      # block. The block should be the DSL for defining a record class.
      def initialize(&block)
        @required = []
        @defaults = {}
        instance_eval(&block) if block_given?
        @required.freeze
        @defaults.freeze
        self.freeze
      end

      # DSL method for declaring one or more fields to be mandatory.
      #
      # @param [Symbol] fields zero or more mandatory fields
      def mandatory(*fields)
        @required.concat(fields.collect{|field| field.to_sym})
      end

      # DSL method for declaring a default value for a field
      #
      # @param [Symbol] field the field to be given a default value
      # @param [Object] value the default value of the field
      def default(field, value)
        @defaults[field] = value
      end

      # Clone a default value if it is cloneable. Else just return
      # the value.
      #
      # @param [Symbol] field the name of the field from which the
      #   default value is to be cloned.
      # @return [Object] a clone of the value or the value if uncloneable
      def clone_default(field)
        value = @defaults[field]
        value = value.clone unless uncloneable?(value)
      rescue TypeError
        # can't be cloned
      ensure
        return value
      end

      # Check the given data hash to see if it contains non-nil values for
      # all mandatory fields.
      #
      # @param [Hash] data the data hash
      # @raise [ArgumentError] if any mandatory fields are missing
      def check_mandatory!(data)
        if data.any?{|k,v| @required.include?(k) && v.nil? }
          raise ArgumentError.new('mandatory fields must not be nil')
        end
      end

      private

      # Is the given object uncloneable?
      #
      # @param [Object] object the object to check
      # @return [Boolean] true if the object cannot be cloned else false
      def uncloneable?(object)
        Type? object, NilClass, TrueClass, FalseClass, Fixnum, Bignum, Float
      end
    end

    # Use the given `AbstractStruct` class and build the methods necessary
    # to support the given data fields.
    #
    # @param [Array] fields the list of symbolic names for all data fields
    # @return [Functional::AbstractStruct] the record class
    def build(fields, &block)
      record, fields = define_class(fields)
      record.send(:datatype=, :record)
      record.send(:fields=, fields)
      record.class_variable_set(:@@restrictions, Restrictions.new(&block))
      define_initializer(record)
      fields.each do |field|
        define_reader(record, field)
      end
      record
    end

    # Define the new record class and, if necessary, register it with `Record`
    #
    # @param [Array] fields the list of symbolic names for all data fields
    # @return [Functional::AbstractStruct, Arrat] the new class and the
    #   (possibly) updated fields array
    def define_class(fields)
      record = Class.new{ include AbstractStruct }
      if fields.first.is_a? String
        self.const_set(fields.first, record)
        fields = fields[1, fields.length-1]
      end
      fields = fields.collect{|field| field.to_sym }.freeze
      [record, fields]
    end

    # Define an initializer method on the given record class.
    #
    # @param [Functional::AbstractStruct] record the new record class
    # @return [Functional::AbstractStruct] the record class
    def define_initializer(record)
      record.send(:define_method, :initialize) do |data = {}|
        restrictions = self.class.class_variable_get(:@@restrictions)
        data = fields.reduce({}) do |memo, field|
          memo[field] = data.fetch(field, restrictions.clone_default(field))
          memo
        end
        restrictions.check_mandatory!(data)
        set_data_hash(data)
        set_values_array(data.values)
        self.freeze
      end
      record
    end

    # Define a reader method on the given record class for the given data field.
    #
    # @param [Functional::AbstractStruct] record the new record class
    # @param [Symbol] field symbolic name of the current data field
    # @return [Functional::AbstractStruct] the record class
    def define_reader(record, field)
      record.send(:define_method, field) do
        to_h[field]
      end
      record
    end
  end
end
