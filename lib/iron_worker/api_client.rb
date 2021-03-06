require 'time'
require 'iron_core'

module IronWorker
  class APIClient < IronCore::Client
    AWS_US_EAST_HOST = 'worker-aws-us-east-1.iron.io'

    def initialize(options = {})
      default_options = {
          :scheme => 'https',
          :host => IronWorker::APIClient::AWS_US_EAST_HOST,
          :port => 443,
          :api_version => 2,
          :user_agent => IronWorker.full_version
      }

      super('iron', 'worker', options, default_options, [:project_id, :token, :api_version])

      IronCore::Logger.debug 'IronWorker', "nhp.proxy: #{rest.wrapper.http.proxy_uri}" if defined? Net::HTTP::Persistent
      IronCore::Logger.debug 'IronWorker', "RestClient.proxy: #{RestClient.proxy}" if defined? RestClient
      IronCore::Logger.debug 'IronWorker', "InternalClient.proxy: #{Rest::InternalClient.proxy}" if defined? Rest::InternalClient

      IronCore::Logger.error 'IronWorker', "Token is not set", IronCore::Error if @token.nil?

      check_id(@project_id, 'project_id')
    end

    def headers
      super.merge({'Authorization' => "OAuth #{@token}"})
    end

    def base_url
      super + @api_version.to_s + '/'
    end

    def stacks_list
      parse_response(get("stacks"))
    end

    def codes_list(options = {})
      parse_response(get("projects/#{@project_id}/codes", options))
    end

    def codes_get(id)
      check_id(id)
      parse_response(get("projects/#{@project_id}/codes/#{id}"))
    end

    def codes_create(name, file, runtime, runner, options)
      parse_response(post_file("projects/#{@project_id}/codes", :file, File.new(file, 'rb'), :data, {:name => name, :runtime => runtime, :file_name => runner}.merge(options)))
    end

    def codes_delete(id)
      check_id(id)
      parse_response(delete("projects/#{@project_id}/codes/#{id}"))
    end

    def codes_revisions(id, options = {})
      check_id(id)
      parse_response(get("projects/#{@project_id}/codes/#{id}/revisions", options))
    end

    def codes_download(id, options = {})
      check_id(id)
      parse_response(get("projects/#{@project_id}/codes/#{id}/download", options), false)
    end

    def codes_pause_task_queue(id, options = {})
      check_id(id)
      parse_response(post("projects/#{@project_id}/codes/#{id}/pause_task_queue", options))
    end

    def codes_resume_task_queue(id, options = {})
      check_id(id)
      parse_response(post("projects/#{@project_id}/codes/#{id}/resume_task_queue", options))
    end

    def tasks_list(options = {})
      parse_response(get("projects/#{@project_id}/tasks", options))
    end

    def tasks_get(id)
      check_id(id)
      parse_response(get("projects/#{@project_id}/tasks/#{id}"))
    end

    def tasks_create(code_name, payload, options = {})
      parse_response(post("projects/#{@project_id}/tasks", {:tasks => [{:code_name => code_name, :payload => payload}.merge(options)]}))
    end

    def tasks_bulk_create(code_name, array_of_payloads, options)
      array_of_tasks = array_of_payloads.map! do |payload|
        {
          :code_name => code_name,
          :payload => payload.is_a?(String) ? payload : payload.to_json
        }.merge(options)
      end
      parse_response(post("projects/#{@project_id}/tasks", {:tasks => array_of_tasks}))
    end

    def tasks_cancel(id)
      check_id(id)
      parse_response(post("projects/#{@project_id}/tasks/#{id}/cancel"))
    end

    def tasks_cancel_all(id)
      check_id(id)
      parse_response(post("projects/#{@project_id}/codes/#{id}/cancel_all"))
    end

    def tasks_log(id)
      check_id(id)
      if block_given?
        stream_get("projects/#{@project_id}/tasks/#{id}/log") do |chunk|
          yield chunk
        end
      else
        parse_response(get("projects/#{@project_id}/tasks/#{id}/log"), false)
      end
    end

    def tasks_set_progress(id, options = {})
      check_id(id)
      parse_response(post("projects/#{@project_id}/tasks/#{id}/progress", options))
    end

    def tasks_retry(id, options = {})
      check_id(id)
      parse_response(post("projects/#{@project_id}/tasks/#{id}/retry", options))
    end

    def schedules_list(options = {})
      parse_response(get("projects/#{@project_id}/schedules", options))
    end

    def schedules_get(id)
      check_id(id)
      parse_response(get("projects/#{@project_id}/schedules/#{id}"))
    end

    def schedules_create(code_name, payload, options = {})
      options[:start_at] = options[:start_at].iso8601 if (not options[:start_at].nil?) && options[:start_at].respond_to?(:iso8601)
      options[:end_at] = options[:end_at].iso8601 if (not options[:end_at].nil?) && options[:end_at].respond_to?(:iso8601)

      parse_response(post("projects/#{@project_id}/schedules", {:schedules => [{:code_name => code_name, :payload => payload}.merge(options)]}))
    end

    def schedules_update(id, options = {})
      check_id(id)
      parse_response(put("projects/#{@project_id}/schedules/#{id}", options))
    end

    def schedules_cancel(id)
      check_id(id)
      parse_response(post("projects/#{@project_id}/schedules/#{id}/cancel"))
    end

    def projects_get
      parse_response(get("projects/#{@project_id}"))
    end
  end
end
