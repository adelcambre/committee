require_relative "../test_helper"

describe Committee::Middleware::Stub do
  include Rack::Test::Methods

  def app
    @app
  end

  it "responds with a stubbed response" do
    @app = new_rack_app
    get "/apps/heroku-api"
    assert_equal 200, last_response.status
    data = JSON.parse(last_response.body)
    assert_equal ValidApp.keys.sort, data.keys.sort
  end

  it "responds with 201 on create actions" do
    @app = new_rack_app
    post "/apps"
    assert_equal 201, last_response.status
  end

  it "optionally calls into application" do
    @app = new_rack_app(call: true)
    get "/apps/heroku-api"
    assert_equal 200, last_response.status
    assert_equal ValidApp,
      JSON.parse(last_response.headers["Committee-Response"])
  end

  it "optionally returns the application's response" do
    @app = new_rack_app(call: true, suppress: true)
    get "/apps/heroku-api"
    assert_equal 429, last_response.status
    assert_equal ValidApp,
      JSON.parse(last_response.headers["Committee-Response"])
      assert_equal "", last_response.body
  end

  it "takes a prefix" do
    @app = new_rack_app(prefix: "/v1")
    get "/v1/apps/heroku-api"
    assert_equal 200, last_response.status
    data = JSON.parse(last_response.body)
    assert_equal ValidApp.keys.sort, data.keys.sort
  end

  it "warns when sending a deprecated string" do
    mock(Committee).warn_deprecated.with_any_args
    @app = new_rack_app(schema: File.read("./test/data/schema.json"))
    get "/apps/heroku-api"
    assert_equal 200, last_response.status
    data = JSON.parse(last_response.body)
    assert_equal ValidApp.keys.sort, data.keys.sort
  end

  it "allows the stub's response to be replaced" do
    response = { replaced: true }
    @app = new_rack_app(call: true, response: response)
    get "/apps/heroku-api"
    assert_equal 200, last_response.status
    assert_equal response, JSON.parse(last_response.body, symbolize_names: true)
  end

  private

  def new_rack_app(options = {})
    response = options.delete(:response)
    suppress = options.delete(:suppress)
    options = {
      schema: JSON.parse(File.read("./test/data/schema.json"))
    }.merge(options)
    Rack::Builder.new {
      use Committee::Middleware::Stub, options
      run lambda { |env|
        env["committee.response"] = response if response
        headers = { "Committee-Response" => JSON.generate(env["committee.response"]) }
        env["committee.suppress"] = suppress
        [429, headers, []]
      }
    }
  end
end
