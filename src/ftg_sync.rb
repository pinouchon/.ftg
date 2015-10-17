require 'uri'
require 'httparty'

class FtgSync
  TOGGL_API_TOKEN = '317c14d9c290d3c6cc1e4f35a2ad8c80'
  TIME_ENTRIES_URL = 'https://toggl.com/api/v8/time_entries'
  WORKSPACE_ID = 939576

  PIDS = {
    autres: 9800260,
    maintenance: 9800223,
    projects: 10669186,
    reu: 9800248,
    sprint: 9800218,
    support: 9800226,
    technical: 9800254
  }

  def initialize
    @headers = {
      'Content-Type' => 'application/json'
    }
    @credentials = {
      username: TOGGL_API_TOKEN,
      password: 'api_token'
    }
    @base_query = {
      user_agent: 'ftg',
      workspace_id: WORKSPACE_ID
    }

    @base_params = {
      headers: @headers,
      query: @base_query,
      basic_auth: @credentials
    }

    @base_params_jira = {
      headers: @headers,
      basic_auth: {
        username: 'benjamin.crouzier',
        password: 'morebabyplease'
      }
    }
  end

  def run
    # current_user_id = me['data']['id']
    abort('no')
    binding.pry


      # workspace_users

    # between_time_range
  end

  def create_entry(description, duration_sec, start_date, type)
    puts "creating entry #{description}, #{duration_sec}, #{start_date}, #{type}"
    params = { "time_entry" =>
                 { "description" => description, "tags" => [],
                   "duration" => duration_sec,
                   "start" => start_date.iso8601,
                   "pid" => PIDS[type],
                   "created_with" => "ftg"
                 }
    }
    HTTParty.post(TIME_ENTRIES_URL, @base_params.merge({body: params.to_json}))
  end

  def delete_entry

    response = HTTParty.delete(TIME_ENTRIES_URL + '/279467425', @base_params.merge({}))
  end

  def maintenance?(jt)
    get_jt_info(jt)['fields']['customfield_10400']['value'] == 'Maintenance' rescue nil
  end

  def get_jt_info(jt)
    HTTParty.get(
      "https://jobteaser.atlassian.net/rest/api/2/issue/#{jt.upcase}",
      @base_params_jira.merge({})
    )
  end

  def between_time_range
    start_date = Time.new(2014, 01, 01).iso8601
    end_date = Time.now.iso8601

    # URI.encode(...) does not escape ':' for some reason
    params = "?start_date=#{CGI.escape(start_date)}&end_date=#{CGI.escape(end_date)}"
    response = HTTParty.get(TIME_ENTRIES_URL + params, @base_params.merge({body: params.to_json}))
    binding.pry
  end

  def workspace_projects
    response = HTTParty.get(
      "https://toggl.com/api/v8/workspaces/#{WORKSPACE_ID}/projects",
      @base_params.merge({})
    )
  end

  def me
    HTTParty.get(
      'https://toggl.com/api/v8/me',
      @base_params.merge({})
    )
  end
end

# FtgSync.new.run