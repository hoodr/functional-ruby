require 'thread'

require 'functional/global_thread_pool'

module Functional

  IllegalMethodCallError = Class.new(StandardError)

  class Defer

    def initialize(operation = nil, callback = nil, errorback = nil, &block)
      raise ArgumentError.new('no operation given') if operation.nil? && ! block_given?
      raise ArgumentError.new('two operations given') if ! operation.nil? && block_given?

      @operation = operation || block
      @callback = callback
      @errorback = errorback

      if operation.nil?
        @running = false
      else
        self.go
      end
    end

    def then(&block)
      raise IllegalMethodCallError.new('a callback has already been provided') unless @callback.nil?
      raise ArgumentError.new('no block given') unless block_given?
      @callback = block
      return self
    end

    def rescue(&block)
      raise IllegalMethodCallError.new('a errorback has already been provided') unless @errorback.nil?
      raise ArgumentError.new('no block given') unless block_given?
      @errorback = block
      return self
    end
    alias_method :catch, :rescue
    alias_method :on_error, :rescue

    def go
      return nil if @running
      @running = true
      $GLOBAL_THREAD_POOL.post { fulfill }
      return nil
    end

    private

    # @private
    def fulfill # :nodoc:
      result = @operation.call
      @callback.call(result) unless @callback.nil?
    rescue Exception => ex
      @errorback.call(ex) unless @errorback.nil?
    end
  end
end

module Kernel

  def defer(*args, &block)
    return Functional::Defer.new(*args, &block)
  end
  module_function :defer
end
