task :debug_server do
  system("bundle exec rdbg -O -n -c -- bin/rails server")
end

task dbs: :debug_server
