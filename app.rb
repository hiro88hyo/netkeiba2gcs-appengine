require 'sinatra'
require 'sinatra/reloader' if development?
require './RaceScraper'

helpers do
  include Rack::Utils
  alias_method :h, :escape_html
end

# 404 Not Found
not_found do
  @error_message = 'Page Not Found'
  erb :error
end

error do
  @error_message = h env['sinatra.error'].message
  erb :error
end

def write_file_gcs(path, filename, content)
  require "google/cloud/storage"

  storage = Google::Cloud::Storage.new(
    project_id: "pogz-276313"
  )
  bucket = storage.bucket "pogz-276313.appspot.com"
  bucket.create_file StringIO.new(content), "#{path}/#{filename}"

end

get '/raceinfo/:race_id' do
  race_id = params['race_id']

  raise race_id if !race_id.match(/\d{12}\z/)

  race_info, race_results = ScrapeRace(race_id.to_i)
  write_file_gcs("racedata", "raceinfo/#{race_id}-info.tsv", race_info)
  write_file_gcs("racedata", "raceresults/#{race_id}-results.tsv", race_results.join("\n"))

  vars = {
    :race_id => race_id,
    :race_info => race_info,
    :race_results => race_results.join("<br/>")
  }
  erb :raceinfo, :locals => vars
end

get '/hello/:message?' do

  raise params[:q] if params[:q]

  @ruby_desc = RUBY_DESCRIPTION

  if params['message'] != nil
    @message = params['message']
  else
    @message = 'Hello, world!'
  end


  require "google/cloud/storage"

  storage = Google::Cloud::Storage.new(
    project_id: "pogz-276313"
  )

  bucket = storage.bucket "pogz-276313.appspot.com"
  file = bucket.file "schema.json"
  puts file.name
  f = file.download
  c = ""
  f.each_line{|line|
    c += line
  }

  env = {
    :dev  => settings.development?,
    :prod => settings.production?,
    :test => settings.test?,
    :c    => c
  }
  erb :hello, :locals => env
end