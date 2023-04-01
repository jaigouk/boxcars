# frozen_string_literal: true

require 'rom'
require 'rom-sql'

# Boxcars is a framework for running a series of tools to get an answer to a question.
module Boxcars
  # A Boxcar that interprets a prompt and executes SQL code to get answers
  class Rom < EngineBoxcar
    # the description of this engine boxcar
    ROMDESC = "useful for when you need to query a database for an application named %<name>s."
    LOCKED_OUT_MODELS = %w[].freeze
    attr_accessor :container, :requested_models, :read_only, :approval_callback, :code_only
    attr_reader :except_models

    def initialize(requested_models: nil, code_only: false, db: nil, **kwargs)
      @requested_models = requested_models
      @code_only = code_only

      @db = db
      @config = default_rom_config

      kwargs[:name] ||= "Data"
      kwargs[:description] ||= format(ROMDESC, name: name)
      kwargs[:prompt] ||= my_prompt

      super(**kwargs)
    end

    def container
      @container ||= ROM.container(@config)
    end

    def default_rom_config
      ROM::Configuration.new(:sql, @db ? @db.opts[:orig_opts][:url] : 'sqlite::memory:')
    end


    # @return Hash The additional variables for this boxcar.
    def prediction_additional
      { model_info: model_info }.merge super
    end

    private

    def code_only?
      code_only
    end

    def check_models(models, exceptions)
      if models.is_a?(Array) && models.length.positive?
        @requested_models = models
        models.each do |m|
          raise ArgumentError, "model #{m} needs to be a ROM relation" unless m.is_a?(::ROM::Relation)
        end
      elsif models
        raise ArgumentError, "models needs to be an array of ROM relations"
      end
      @except_models = LOCKED_OUT_MODELS + exceptions.to_a
    end

    def wanted_models
      @wanted_models ||= begin
        the_models = requested_models || container.relations
        the_models.reject { |m| except_models.include?(m.name) }
      end
    end

    def models
      models = wanted_models.map(&:name)
      models.join(", ")
    end

    def model_info
      models = wanted_models
      models.inspect
    end

    def rollback_after_running
      result = nil
      runtime_exception = nil
      container.gateways[:default].connection.transaction do
        begin
          result = yield
        rescue SecurityError, ::NameError, ::Error => e
          Boxcars.error("Error while running code: #{e.message[0..60]} ...", :red)
            runtime_exception = e
            container.gateways[:default].connection.rollback!
        end
      end
      raise runtime_exception if runtime_exception
      result
    end

    def run_sql(sql)
      container.gateways[:default].connection.run(sql)
    end

    # This method is called when the user runs the Boxcars.
    def run_code(code)
      return if code_only?

      begin
        sql_code = eval(code)
        rollback_after_running do
          run_sql(sql_code)
        end
      rescue ::ROM::SQL::Error => e
        Boxcars.error("ROM SQL Error: #{e.message}", :run_code)
      end
    end

    # Generates the prompt for this boxcar
    def my_prompt
      "I need a #{name} using #{models}."
    end

    def approval_callback(proc)
      raise ArgumentError, "Approval callback must be a Proc" unless proc.is_a?(Proc)

      @approval_callback = proc
    end

    def run_approval_callback
      return true unless @approval_callback

      @approval_callback.call(self)
    end
  end
end
