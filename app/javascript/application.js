// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails";
// eslint-disable-next-line import/no-unresolved
import "controllers";
import * as bootstrap from "bootstrap";

document.querySelectorAll("#filters select.token").forEach((el) => {
  // eslint-disable-next-line no-new, no-undef
  new SlimSelect({
    select: el,
  });
});
