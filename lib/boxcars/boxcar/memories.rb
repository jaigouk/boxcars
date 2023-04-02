# frozen_string_literal: true

# Boxcars is a framework for running a series of tools to get an answer to a question.
module Boxcars
  module Memories
    module ClassMethods
      MemoryError = Class.new(StandardError)

      def call(*args, **kw_args)
        new(*args, **kw_args).call
      end
    end

    def self.included(base)
      base.extend(ClassMethods)

      class << base
        private :new
      end
    end
  end
end

require_relative "memories/split_text"
