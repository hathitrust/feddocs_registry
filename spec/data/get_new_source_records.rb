require 'json'
require 'mongo'
require 'dotenv'

Dotenv.load!

fin = open(File.dirname(__FILE__)+'/source_records.json')
sout = open(File.dirname(__FILE__)+'/new_sources.json', 'w')
rout = open(File.dirname(__FILE__)+'/new_regrecs.json', 'w')
mongo_uri = ENV['mongo_host']+':'+ENV['mongo_port']
Mongo::Logger.logger.level = ::Logger::FATAL
mc = Mongo::Client.new([mongo_uri], :database => ENV['mongo_db'])

fin.each do | line |
  rec = JSON.parse(line)
  source_id = rec['source_id']

  src = mc[:source_records].find({"source_id" => source_id}).first
  if src == nil
    next
  end
  src.delete("_id")
  sout.puts src.to_json

  mc[:registry].find({"source_record_ids" => source_id}).each do |rr|
    rr.delete("_id")
    rout.puts rr.to_json
  end
end

