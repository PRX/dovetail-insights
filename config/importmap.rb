# Pin npm packages by running ./bin/importmap

pin "application"
pin "@hotwired/turbo-rails", to: "turbo.min.js"
pin "@hotwired/stimulus", to: "stimulus.min.js"
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js"
pin_all_from "app/javascript/controllers", under: "controllers"
pin "@rails/ujs", to: "@rails--ujs.js", preload: true # @7.0.4

pin "flatpickr", preload: true # @4.6.13
pin "bootstrap5-tags", to: "https://ga.jspm.io/npm:bootstrap5-tags@1.6.4/tags.js"
pin "slim-select", preload: true # @2.6.0

pin_all_from "app/javascript/controllers", under: "controllers"
pin_all_from "app/javascript/custom", under: "custom"
pin_all_from "app/javascript/util", under: "util"
