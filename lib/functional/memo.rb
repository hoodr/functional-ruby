require 'thread'

module Functional

  # @example
  #   class Factors
  #     include Functional::Memo
  #   
  #     def self.sum_of(number)
  #       of(number).reduce(:+)
  #     end
  #   
  #     def self.of(number)
  #       (1..number).select {|i| factor?(number, i)}
  #     end
  #   
  #     def self.factor?(number, potential)
  #       number % potential == 0
  #     end
  #   
  #     def self.perfect?(number)
  #       sum_of(number) == 2 * number
  #     end
  #   
  #     def self.abundant?(number)
  #       sum_of(number) > 2 * number
  #     end
  #   
  #     def self.deficient?(number)
  #       sum_of(number) < 2 * number
  #     end
  #   
  #     memoize(:sum_of)
  #     memoize(:of)
  #   end
  #
  # @see http://en.wikipedia.org/wiki/Memoization Memoization (Wikipedia)
  # @see http://clojuredocs.org/clojure_core/clojure.core/memoize Clojure memoize
  module Memo

    def self.extended(base)
      base.extend(ClassMethods)
      base.send(:__method_memos__=, {})
      super(base)
    end

    def self.included(base)
      base.extend(ClassMethods)
      base.send(:__method_memos__=, {})
      super(base)
    end

    # @!visibility private
    module ClassMethods

      # @!visibility private
      Memo = Struct.new(:function, :mutex, :cache, :max_cache) do
        def max_cache?
          max_cache > 0 && cache.size >= max_cache
        end
      end

      # @!visibility private
      attr_accessor :__method_memos__

      # Returns a memoized version of a referentially transparent function. The
      # memoized version of the function keeps a cache of the mapping from arguments
      # to results and, when calls with the same arguments are repeated often, has
      # higher performance at the expense of higher memory use.
      #
      # @param [Symbol] func the class/module function to memoize
      # @param [Hash] opts the options controlling memoization
      # @option opts [Fixnum] :at_most the maximum number of memos to store in the
      #   cache; a value of zero (the default) or `nil` indicates no limit
      #
      # @raise [ArgumentError] when the method has already been memoized
      # @raise [ArgumentError] when :at_most option is a negative number
      def memoize(func, opts = {})
        func = func.to_sym
        max_cache = opts[:at_most].to_i
        raise ArgumentError.new("method :#{func} has already been memoized") if __method_memos__.has_key?(func)
        raise ArgumentError.new(':max_cache must be > 0') if max_cache < 0
        __method_memos__[func] = Memo.new(method(func), Mutex.new, {}, max_cache.to_i)
        __define_memo_proxy__(func)
        nil
      end

      # @!visibility private
      def __define_memo_proxy__(func)
        self.class_eval <<-RUBY
          def self.#{func}(*args, &block)
            self.__proxy_memoized_method__(:#{func}, *args, &block)
          end
        RUBY
      end

      # @!visibility private
      def __proxy_memoized_method__(func, *args, &block)
        memo = self.__method_memos__[func]
        memo.mutex.lock
        if block_given?
          memo.function.call(*args, &block)
        elsif memo.cache.has_key?(args)
          memo.cache[args]
        else
          result = memo.function.call(*args)
          memo.cache[args] = result unless memo.max_cache?
        end
      ensure
        memo.mutex.unlock
      end
    end
  end
end