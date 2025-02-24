// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails";
// eslint-disable-next-line import/no-unresolved
import "controllers";

document.querySelectorAll("#filters select.token").forEach((el) => {
  new SlimSelect({
    select: el,
  });
});
