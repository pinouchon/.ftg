class TogglClient < ApiClient
  API_BASE_URL = 'https://toggl.com/api/v8'
  TIME_ENTRIES_URL = API_BASE_URL + '/time_entries'

  def initialize(config)
    super(config)

    @config = config
    @base_params = {
      headers: headers,
      query: {
        user_agent: 'ftg',
        workspace_id: @config['workspace_id']
      },
      basic_auth: {
        username: @config['api_token'],
        password: 'api_token'
      }
    }
  end

  def create_activity(description, duration_sec, start_date, type)
    # puts "creating entry #{description}, #{Utils.format_time(duration_sec)}, #{start_date}, #{type}"
    params = { 'time_entry' =>
                 { 'description' => description, 'tags' => [],
                   'duration' => duration_sec,
                   'start' => (start_date.to_time + 12 * 3600).iso8601,
                   'pid' => @config['project_ids'][type],
                   'created_with' => 'ftg'
                 }
    }
    HTTParty.post(TIME_ENTRIES_URL, @base_params.merge({ body: params.to_json }))
  end

  def delete_activity(activity_id)
    HTTParty.delete("#{TIME_ENTRIES_URL}/#{activity_id}", @base_params.merge({}))
  end

  # unused
  def between_time_range
    start_date = Time.new(2014, 01, 01).iso8601
    end_date = Time.now.iso8601

    # URI.encode(...) does not escape ':' for some reason
    params = "?start_date=#{CGI.escape(start_date)}&end_date=#{CGI.escape(end_date)}"
    response = HTTParty.get(TIME_ENTRIES_URL + params, @base_params.merge({ body: params.to_json }))
    binding.pry
  end

  # unused
  def workspace_projects
    response = HTTParty.get(
      "#{API_BASE_URL}/workspaces/#{@config['workspace_id']}/projects",
      @base_params.merge({})
    )
  end

  # unused
  def me
    HTTParty.get(
      "#{API_BASE_URL}/me",
      @base_params.merge({})
    )
  end

end