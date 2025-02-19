import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["durationRangesBuilder"];

  addRange(event) {
    event.preventDefault();

    // There's a list where each list item represents a range. There's always
    // one more range than defined indices (e.g., if there's 1 index, there
    // are 2 ranges).
    const list = this.element.querySelector("ul");

    const lastItem = list.querySelector("li:last-child");

    const newItem = document.createElement("li");
    newItem.innerHTML =
      "Greater Than Or Equal To: <input disabled> and less than <input data-action='data-explorer--group-chooser#changeRangeIndex'> <a href='#' data-action='data-explorer--group-chooser#removeRange'>X</a>";
    list.insertBefore(newItem, lastItem);

    this.changeRangeIndex();
  }

  removeRange(event) {
    event.preventDefault();

    // This event should have come from a <button>. Remove the <li> that
    // contained that button

    const ancestorListItem = event.target.closest("li");
    ancestorListItem.remove();

    this.changeRangeIndex();
  }

  changeRangeIndex() {
    // Collect all the indices. Find all inputs that aren't disabled and get
    // their values
    const indexInputs = Array.from(
      this.element.querySelectorAll("input:not(:disabled)"),
    );
    const indices = indexInputs.map((i) => i.value || "");

    // Each range uses the previous index as the displayed lower bound, so
    // fill in those inputs with the indices from the input boxes.
    const indexOuputs = Array.from(
      this.element.querySelectorAll("input:disabled"),
    );

    let i = 0;
    indexOuputs.forEach((el) => {
      el.value = indices[i];

      i += 1;
    });
  }
}
