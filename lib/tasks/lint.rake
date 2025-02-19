task :lint do
  system("bundle exec standardrb")
  system("bundle exec erb_lint --lint-all --format compact")
  system('npx prettier --check "**/*.{json,yml}"')
  system('npx eslint "**/*.{js,mjs,ts}"')
end
