class JiraClient < ApiClient
  API_BASE_URL = 'https://jobteaser.atlassian.net/rest/api/2'

  def initialize(config)
    super(config)

    @base_params = {
      headers: headers,
      basic_auth: {
        username: config['username'],
        password: config['password']
      }
    }
  end

  def create_worklog(task)

    # puts "creating entry #{description}, #{Utils.format_time(duration_sec)}, #{start_date}, #{type}"
    params = {
      timeSpentSeconds: task.duration,
      started: (task.day.to_time + 12 * 3600).strftime('%Y-%m-%dT%H:%M:%S.%3N%z'), #.iso8601
      comment: '[FTG]'
    }

    HTTParty.post("#{API_BASE_URL}/issue/#{task.jira_id}/worklog",
                  @base_params.merge({ body: params.to_json }))
  end

  def delete_worklog(task)
    result = HTTParty.delete("#{API_BASE_URL}/issue/#{task.jira_id}/worklog/#{task.jira_timelog_id}",
                    @base_params.merge({}))
    return 'ok' if result.nil?
    result
  end

  def jira_category(jt)
    get_jt_info(jt)['fields']['customfield_10400']['value'] rescue nil
  end

  def get_jt_info(jt)
    HTTParty.get(
      "#{API_BASE_URL}/issue/#{jt.upcase}",
      @base_params.merge({})
    )
  end
end