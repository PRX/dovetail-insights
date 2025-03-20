// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails";
// eslint-disable-next-line import/no-unresolved
import "controllers";
import { Tooltip } from "bootstrap";
// import SlimSelect from "slim-select";

(() => {
  document.addEventListener("DOMContentLoaded", () => {
    const tooltipTriggerList = document.querySelectorAll(
      '[data-bs-toggle="tooltip"]',
    );
    [...tooltipTriggerList].map(
      (tooltipTriggerEl) => new Tooltip(tooltipTriggerEl),
    );
  });
})();
