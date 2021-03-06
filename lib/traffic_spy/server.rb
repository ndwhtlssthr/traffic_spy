module TrafficSpy

  # Sinatra::Base - Middleware, Libraries, and Modular Apps
  #
  # Defining your app at the top-level works well for micro-apps but has
  # considerable drawbacks when building reusable components such as Rack
  # middleware, Rails metal, simple libraries with a server component, or even
  # Sinatra extensions. The top-level DSL pollutes the Object namespace and
  # assumes a micro-app style configuration (e.g., a single application file,
  # ./public and ./views directories, logging, exception detail page, etc.).
  # That's where Sinatra::Base comes into play:
  #
  class Server < Sinatra::Base
    set :views, 'lib/views'
    set :show_exceptions, false
    set :root, 'lib'

    configure do
      register Sinatra::Partial
      set :partial_template_engine, :erb
    end

    get '/' do
      erb :index
    end

    post '/sources' do
      return 400 unless params[:rootUrl] && params[:identifier]
      URL.add_new(params)
      return 200 if Source.create(params, URL.find_url(params[:rootUrl]).id)
      403
    end

    post '/sources/:identifier/data' do |identifier|
      payload = Hash[JSON.parse(params[:payload]).map{|(k,v)| [k.to_sym,v]}]
      return 400 unless Payload.invalid?(payload)
      return 200 if Payload.create(payload, identifier)
      403
    end

    get '/sources/:identifier' do |identifier|
      erb :app_details,
          locals: { identifier: identifier,
                    url_reqs: Payload.url_reqs(identifier),
                    screen_res_reqs: Payload.screen_res_reqs(identifier),
                    avg_response_times: Payload.avg_response_times(identifier),
                    browser_breakdowns: UserAgent.parse_browser(identifier),
                    os_breakdowns: UserAgent.parse_os(identifier)}
    end

    get '/sources/:identifier/urls/*' do
      root_url = URL.find_object(Source.find_object(params[:identifier]).url_id).url
      url = root_url + "/" + params[:splat].join("/")
      p url
      p URL.exists?(url)
      if URL.exists?(url)
        erb :url_details,
            locals: { path: params[:splat],
                    identifier: params[:identifier],
                    longest_resp_time: QueryHelper.longest_response_time(params[:identifier], url),
                    shortest_resp_time: QueryHelper.shortest_response_time(params[:identifier], url),
                    avg_resp_time: QueryHelper.average_response_time(params[:identifier], url),
                    popular_referrers: QueryHelper.popular_referrers(params[:identifier], url),
                    popular_user_agents: QueryHelper.popular_user_agents(params[:identifier], url),
                    http_verbs: QueryHelper.which_http_verbs(params[:identifier], url)}
      else
        puts "uh oh"
      end
    end

    error 200 do
      JSON.generate(Source.find_identifier(params[:identifier])) if params[:identifier]
    end

    error 403 do
      "Forbidden"
    end

    not_found do
      erb :error
    end
  end
end
