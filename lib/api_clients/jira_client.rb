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

  def create_entry(task)
    return unless task.jira_id

    # puts "creating entry #{description}, #{Utils.format_time(duration_sec)}, #{start_date}, #{type}"
    params = { newEstimate: '10m' }
    HTTParty.post("#{API_BASE_URL}/issue/#{task.jira_id}/worklog",
                  @base_params.merge({ body: params.to_json }))

  end

  def delete_entry

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