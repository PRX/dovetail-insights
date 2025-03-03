`application.js` is pinned in `importmaps.rb`.

Stimulus files in `controllers/` are also all pinned in `importmaps.rb`.

Things that are pinned generally get included on webpages using `javascript_importmap_tags`, which will add a `<script>` tag for each file that has been pinned.

If, for example, you wanted to add some new files like `app/javascript/foo/model.js` and `app/javascript/foo/view.js`, you should pin them in `importmaps.rb` (whether you `pin` or `pin_all_from` will depend on the use case.)
