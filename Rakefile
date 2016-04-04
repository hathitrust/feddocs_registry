require "bundler/gem_tasks"

task :default => [:test]

task :test do 
  Rake::Task["init"].invoke
  sh 'bundle exec rspec'
end

task :init do
  sh 'gunzip -k spec/data/source_records.json.gz'
  sh 'gunzip -k spec/data/registry_records.json.gz'
  #here be dragons
  sh 'mongo testing --eval "db.dropDatabase()"'
  sh 'mongoimport --db testing --collection source_records --file spec/data/source_records.json' 
  sh 'mongoimport --db testing --collection registry --file spec/data/registry_records.json'
end
