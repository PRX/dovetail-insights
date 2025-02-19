task :lint do
  system("bundle exec standardrb")
  system('npx prettier --check "**/*.{json,yml}"')
  system('npx eslint "**/*.{js,mjs,ts}"')
end
