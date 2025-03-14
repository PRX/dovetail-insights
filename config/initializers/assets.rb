# Be sure to restart your server when you modify this file.

# Version of your assets, change this if you want to expire all your assets.
Rails.application.config.assets.version = "1.0"

# Add additional assets to the asset load path.
# Rails.application.config.assets.paths << Emoji.images_path

# Files within asset paths are available via Propshaft (i.e., via `asset_path`,
# `image_tag`, `javascript_include_tag`, etc).
#
# Different types of files that are present under these paths (CSS, Sass,
# JavaScript, fonts, etc) are included on webpages in different ways. Having
# their file listed here only adds them to the pool of files that are available
# to other mechanisms, like importmap or assets:precompile.
#
# Note that after running `rails assets:precompile`, which is generally run
# for production Docker builds, all files under these paths will be copies to
# `public/assets`

Rails.application.config.assets.paths << Rails.root.join("node_modules/bootstrap-icons/font")
# Rails.application.config.assets.paths << Rails.root.join("node_modules/bootstrap/dist/js")
# I dont think this does anything Rails.application.config.assets.precompile << "bootstrap.bundle.min.js"

# Rails.application.config.assets.paths << Rails.root.join("node_modules/slim-select/dist")
# I dont think this does anything Rails.application.config.assets.precompile << "slimselect.bundle.min.js"

# Rails.application.config.assets.paths << Rails.root.join("node_modules/@popperjs/dist/esm")
