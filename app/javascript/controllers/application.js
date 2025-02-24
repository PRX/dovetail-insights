import { Application } from "@hotwired/stimulus";

const application = Application.start();

// Configure Stimulus development experience
application.debug = false;
window.Stimulus = application;

// eslint-disable-next-line import/prefer-default-export
export { application };

// This file should only include code related Stimulus controllers. Don't use
// it as a catch-all for JavaScript code.
