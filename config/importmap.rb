# Pin npm packages by running ./bin/importmap

# Everything pinned here will be included in the importmap that's generated
# using `javascript_importmap_tags`, _and_ will have a `<script>` tag added to
# the page also by `javascript_importmap_tags`.
#
# If you just need code to be loaded on the page, pinning it here is
# sufficient—you do not need to `import` things in `application.js` unless
# you're actually using the imported modules somewhere in code.

# This is app/javascript/application.js
pin "application"

# These are modules provided by gems
pin "@hotwired/turbo-rails", to: "turbo.min.js"
pin "@hotwired/stimulus", to: "stimulus.min.js"
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js"

# Local modules
pin_all_from "app/javascript/controllers", under: "controllers"

pin "slim-select", to: "https://unpkg.com/slim-select@latest/dist/slimselect.es.js"
pin "bootstrap", to: "https://ga.jspm.io/npm:bootstrap@5.3.3/dist/js/bootstrap.esm.js"
pin "@popperjs/core", to: "https://ga.jspm.io/npm:@popperjs/core@2.11.8/lib/index.js"
