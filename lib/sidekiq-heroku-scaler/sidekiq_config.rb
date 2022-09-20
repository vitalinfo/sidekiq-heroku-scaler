# frozen_string_literal: true

require 'erb'
require 'fileutils'
require 'optparse'
require 'sidekiq'

module SidekiqHerokuScaler
  class SidekiqConfig
    def initialize(commands = [])
      @commands = commands
    end

    def config
      @config ||= ActiveSupport::HashWithIndifferentAccess.new(setup_options(commands))
    end

    private

    attr_reader :commands

    def load_yaml(src)
      if Psych::VERSION > '4.0'
        YAML.safe_load(src, permitted_classes: [Symbol], aliases: true)
      else
        YAML.safe_load(src)
      end
    end

    def option_parser(opts)
      OptionParser.new do |o|
        o.on '-c', '--concurrency INT', 'processor threads to use' do |arg|
          opts[:concurrency] = Integer(arg)
        end

        o.on '-g', '--tag TAG', 'Process tag for procline' do |arg|
          opts[:tag] = arg
        end

        o.on '-q', '--queue QUEUE[,WEIGHT]', 'Queues to process with optional weights' do |arg|
          queue, weight = arg.split(',')
          parse_queue opts, queue, weight
        end

        o.on '-r', '--require [PATH|DIR]', 'Location of Rails application with jobs or file to require' do |arg|
          opts[:require] = arg
        end

        o.on '-C', '--config PATH', 'path to YAML config file' do |arg|
          opts[:config_file] = arg
        end
      end
    end

    def parse_config(path)
      erb = ERB.new(File.read(path))
      erb.filename = File.expand_path(path)
      opts = load_yaml(erb.result) || {}

      if opts.respond_to?(:deep_symbolize_keys!)
        opts.deep_symbolize_keys!
      else
        symbolize_keys_deep!(opts)
      end

      opts.delete(:strict)

      parse_queues(opts, opts.delete(:queues) || [])

      opts
    end

    def parse_queues(opts, queues_and_weights)
      queues_and_weights.each { |queue_and_weight| parse_queue(opts, *queue_and_weight) }
    end

    def parse_queue(opts, queue, weight = nil)
      opts[:queues] ||= []
      opts[:strict] = true if opts[:strict].nil?
      raise ArgumentError, "queues: #{queue} cannot be defined twice" if opts[:queues].include?(queue)

      opts[:queues] << queue.to_s
      opts[:strict] = false if weight.to_i.positive?
    end

    def parse_options(argv)
      opts = {}
      parser = option_parser(opts)
      parser.parse!(argv)
      opts
    end

    def setup_options(args)
      # parse CLI options
      opts = parse_options(args)

      unless opts[:config_file]
        config_dir = if File.directory?(opts[:require].to_s)
                       File.join(opts[:require], 'config')
                     else
                       File.join(Sidekiq[:require], 'config')
                     end

        %w[sidekiq.yml sidekiq.yml.erb].each do |config_file|
          path = File.join(config_dir, config_file)
          opts[:config_file] ||= path if File.exist?(path)
        end
      end

      # parse config file options
      opts = parse_config(opts[:config_file]).merge(opts) if opts[:config_file] && File.exist?(opts[:config_file])

      # set defaults
      opts[:queues] = ['default'] if opts[:queues].nil?
      opts[:concurrency] = Integer(ENV['RAILS_MAX_THREADS']) if opts[:concurrency].nil? && ENV['RAILS_MAX_THREADS']

      opts
    end

    def symbolize_keys_deep!(hash)
      hash.each_key do |k|
        symkey = k.respond_to?(:to_sym) ? k.to_sym : k
        hash[symkey] = hash.delete k
        symbolize_keys_deep! hash[symkey] if hash[symkey].is_a? Hash
      end
    end
  end
end
