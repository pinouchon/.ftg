class ApiClient

  def headers
    { 'Content-Type' => 'application/json' }
  end

  def initialize(config)
    require 'uri'
    require 'httparty'

    @config = config
  end

end