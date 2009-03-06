# $Id$
# *****************************************************************************
# Copyright (C) 2005 - 2007 somewhere in .Net ltd.
# All Rights Reserved.  No use, copying or distribution of this
# work may be made except in accordance with a valid license
# agreement from somewhere in .Net LTD.  This notice must be included on
# all copies, modifications and derivatives of this work.
# *****************************************************************************
# $LastChangedBy$
# $LastChangedDate$
# $LastChangedRevision$
# *****************************************************************************
module MojarWorkflow

  module Common
    class FlowNotFound < Exception
      def initialize(p_domain, p_name, p_message = nil)
        super("flow - #{p_name} of domain #{p_domain} not exists - #{p_message}")
      end
    end

    class Flow
      attr_accessor :domain, :flow_id, :success, :failure

      def initialize()
        @domain = nil
        @flow_id = nil
        @success = nil
        @failure = nil
      end

      def to_s
        return %{
          Flow {
            domain = #{@domain},
            flow_id = #{@flow_id},
            success = #{@success},
            failure = #{@failure}            
          }
        }
      end

    end

    class ExecutionPoint
      attr_accessor :execute, :message, :status, :template, :redirect, :domain, :arguments

      def initialize(p_domain)
        @execute = nil
        @message = nil
        @status = 0
        @template = nil
        @redirect = nil
        @arguments = nil
        @domain = p_domain
      end

      def run(p_arguments = nil)
        # execute another flow if @execute is not null
        if !@execute.nil?
          flow = FlowManager.get_flow(@domain, @execute)
          raise FlowNotFound.new(@domain, @execute) if flow.nil?

          # add flow execution arguments
          if !arguments.nil?
            if p_arguments.nil?
              p_arguments = arguments

            elsif p_arguments.is_a?(Hash)
              arguments.each do |e_key, e_value|
                p_arguments[e_key] = e_value
              end

            elsif p_arguments.is_a?(Array)
              p_arguments << arguments
            else
              old_state = p_arguments
              p_arguments = {
                  :state => old_state,
                  :arguments => arguments}
            end
          end
          return MojarWorkflow::Core::Executor.execute(flow, p_arguments)
        end

        # return is message is not null
        if !@message.nil?
          return @message
        end

        # return (status, message) if status is not null or message is not defined.
        if @status != 0
          return @status, @message if !@message.nil?
          return @status, nil
        end
      end

      def to_s
        return %{ ExecutionPoint {
            execute = #{@execute},
            message = #{@message},
            status = #{@status},
            template = #{@template},
            redirect = #{@redirect}
          }
        }
      end

    end
  end

  module Core

    require "yaml"
    class ResourceReader

      public
      def self.load_yml(p_file_name)
        puts "Loading yml file from - #{p_file_name}"
        # load and read yaml file and cache the domain related flow
        workflow = read_yaml_file(p_file_name)
      end

      private
      def self.read_yaml_file(p_file_name)
        yaml = YAML.load_file(p_file_name)

        domains = []
        # find out top level domain name
        yaml.keys.each do |e_domain_name|
          # create instance for domain specific service
          flow_service_instance = Kernel.const_get("#{e_domain_name.strip.capitalize}Service").new
          # cache the instance of domain specific service
          FlowManager.cache_flow_service(e_domain_name, flow_service_instance)

          # build flow from the specific domain
          domain_flow = []
          action_ids_yaml = yaml[e_domain_name]
          if !action_ids_yaml.nil?
            action_ids_yaml.keys.each do |e_action_id|
              flow = build_flow_from_yaml_domain(e_domain_name, e_action_id, action_ids_yaml[e_action_id])
              if !flow.nil?
                domain_flow.push(flow)
                # cache domain name and flow
                FlowManager.cache_flow(e_domain_name, e_action_id, flow)
              end
            end
          end
          domains.push(domain_flow)
        end
        return domains
      end

      IF_SUCCESS = "if_success"
      IF_FAILURE = "if_failure"
      private
      def self.build_flow_from_yaml_domain(p_domain_name, p_flow_id, p_yaml_objects)
        if !p_yaml_objects.nil?
          flow = MojarWorkflow::Common::Flow.new
          flow.domain = p_domain_name
          flow.flow_id = p_flow_id
          flow.success = build_flow_action_from_yaml(p_domain_name, p_yaml_objects[IF_SUCCESS])
          flow.failure = build_flow_action_from_yaml(p_domain_name, p_yaml_objects[IF_FAILURE])
          return flow
        end
        return nil
      end

      ACTION_EXECUTE = "execute"
      ACTION_MESSAGE = "message"
      ACTION_TEMPLATE = "template"
      ACTION_STATUS = "status"
      ACTION_REDIRECT = "redirect"
      ACTION_ARGUMENTS = "arguments"

      private
      def self.build_flow_action_from_yaml(p_domain, p_objects)
        if !p_objects.nil?
          execution_point = MojarWorkflow::Common::ExecutionPoint.new(p_domain)
          execute = p_objects[ACTION_EXECUTE]
          message = p_objects[ACTION_MESSAGE]
          template = p_objects[ACTION_TEMPLATE]
          status = p_objects[ACTION_STATUS]
          redirect = p_objects[ACTION_REDIRECT]
          arguments = p_objects[ACTION_ARGUMENTS]

          execution_point.execute = execute unless execute.nil?
          execution_point.message = message unless message.nil?
          execution_point.status = status unless status.nil?
          execution_point.template = template unless template.nil?
          execution_point.redirect = redirect unless redirect.nil?
          execution_point.arguments = arguments unless arguments.nil?

          return execution_point
        end
        return nil
      end

      public
      def self.load_xml(p_file_name)
        raise "load_xml is not yet implemented."
      end

      public
      def self.load_rb(p_file_name)
        raise "load_rb is not yet implemented."
      end
    end

    class Executor
      def self.execute(p_flow, p_arguments = nil)
        domain = p_flow.domain
        flow_id = p_flow.flow_id
        puts "Executing workflow action - #{flow_id} of domain - #{domain} "

        # lookup bundled flow service class instance
        instance = FlowManager.get_flow_service(domain)

        # invoke method from flow service instance
        result = instance.send(flow_id, p_arguments)
        if result
          success_task = p_flow.success()
          if !success_task.nil?
            # invoke the success state
            return success_task.run(result)
          end
        else
          failure_task = p_flow.failure()
          if !failure_task.nil?
            # invoke the failure state
            return failure_task.run(result)
          end
        end
        return result
      end
    end

    class Resource

      DEFAULT_DIRECTORY = "#{RAILS_ROOT}/config/workflows/*/*.{yml,xml,rb}"
      DEFAULT_LIB_DIRECTORY = "#{RAILS_ROOT}/config/workflows/*/lib/*.rb"
      def self.discover
        puts "Loading workflows from directory - #{DEFAULT_DIRECTORY}"

        # include required library ruby files
        Dir.glob(DEFAULT_LIB_DIRECTORY).each do |e_lib_dir|
          require e_lib_dir
        end

        # load all yaml files.
        directories = Dir.glob(DEFAULT_DIRECTORY)
        directories.each do |e_file|
          puts "Loading workflow file - #{e_file}"
          if e_file.match(/^.+\.rb$/)
            ResourceReader.load_rb(e_file)
          elsif e_file.match(/^.+\.yml$/)
            ResourceReader.load_yml(e_file)
          else
            raise "Not supported yet"
          end
        end
      end
    end
  end

  class FlowManager
    @@CACHED_FLOWS = {}
    @@CACHED_SERVICE = {}

    public
    def self.get_flow(p_domain_name, p_flow_name)
      flow_name_with_domain_prefix = build_flow_name(p_domain_name, p_flow_name)
      flow_cache = @@CACHED_FLOWS[flow_name_with_domain_prefix]
    end

    public
    def self.get_flow_service(p_domain_name)
      return @@CACHED_SERVICE[p_domain_name.to_s]
    end

    public
    def self.cache_flow_service(p_domain_name, p_flow_service_instance)
      return @@CACHED_SERVICE[p_domain_name.to_s] = p_flow_service_instance
    end

    public
    def self.cache_flow(p_domain_name, p_flow_name, p_flow)
      flow_name_with_domain_prefix = build_flow_name(p_domain_name, p_flow_name)
      @@CACHED_FLOWS[flow_name_with_domain_prefix] = p_flow
    end

    public
    def self.remove_flow(p_domain_name, p_flow_name)
      flow_name_with_domain_prefix = build_flow_name(p_domain_name, p_flow_name)
      @@CACHED_FLOWS.delete(flow_name_with_domain_prefix)
    end

    private
    def self.build_flow_name(p_domain_name, p_flow_name)
      return "#{p_domain_name.to_s}_#{p_flow_name.to_s}".to_sym
    end
  end

  module Helpers
    module ControllerClassMethods
    end

    module CommonClassMethods
      def execute_flow(p_domain_name, p_flow_name, p_options = {})
        # flow name & domain must be persent otherwise kick the butt.
        raise ArgumentError.new("flow domain name must be defined.") if p_domain_name.nil?
        raise ArgumentError.new("flow name must be defined.") if p_flow_name.nil?

        # lookup flow from flow manager cache
        flow_cache = FlowManager.get_flow(p_domain_name, p_flow_name)

        # raise an exception if flow doesn't exists in cache.
        if flow_cache.nil?
          raise ArgumentError.new("flow name - '#{p_flow_name}' of domain - '#{p_domain_name}' doesn't exist.")
        end

        # find user defined arguments
        arguments = p_options[:arguments]

        # execute workflow
        return execute(flow_cache, arguments)
      end

      def execute(p_flow, p_arguments)
        MojarWorkflow::Core::Executor.execute(p_flow, p_arguments)
      end
    end
  end


end