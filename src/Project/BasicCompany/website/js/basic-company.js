'use strict';

/**
 * NAVBAR
 */
document.addEventListener('DOMContentLoaded', function () {
  // Get all "navbar-burger" elements
  var $navbarBurgers = Array.prototype.slice.call(document.querySelectorAll('.navbar-burger'), 0);
  // Check if there are any navbar burgers
  if ($navbarBurgers.length > 0) {
    // Add a click event on each of them
    $navbarBurgers.forEach(function (el) {
      el.addEventListener('click', function () {
        // Get the target from the "data-target" attribute
        var target = el.dataset.target;
        var $target = document.getElementById(target);
        // Toggle the "is-active" class on both the "navbar-burger" and the "navbar-menu"
        el.classList.toggle('is-active');
        $target.classList.toggle('is-active');
      });
    });
  }
});

/**
 * ACCORDIONS
 */
document.addEventListener('DOMContentLoaded', function () {
  var isActive = 'is-active';
  var $accordions = Array.prototype.slice.call(document.querySelectorAll('.accordion'), 0);
  if ($accordions.length === 0) {
    return;
  }

  // iterate each accordion and track its active drawer
  $accordions.forEach(function (accordion) {
    var $activeItem = void 0;
    var $items = Array.prototype.slice.call(accordion.querySelectorAll('.accordion-item'), 0);
    if ($items.length === 0) {
      return;
    }

    // find the active accordion, if any, and attach click handlers to them all
    $items.forEach(function (el) {
      if (el.classList.contains(isActive)) {
        $activeItem = el;
      }

      el.addEventListener('click', function () {
        if (el === $activeItem) {
          // clicking the active accordion, close it
          el.classList.remove(isActive);
          $activeItem = null;
        } else {
          // change the active accordion
          el.classList.add(isActive);
          if ($activeItem) {
            $activeItem.classList.remove(isActive);
          }
          $activeItem = el;
        }
      });
    });
  });
});

document.addEventListener('DOMContentLoaded', function () {
  var $forms = Array.prototype.slice.call(document.querySelectorAll('.search-box'), 0);
  $forms.forEach(function (form) {
    var input = form.querySelector('.search-box-input');
    var dropdown = form.querySelector('.dropdown');
    var list = form.querySelector('.search-box-suggestions');
    var minChars = parseInt(form.dataset.minChars, 10) || 2;
    var max = parseInt(form.dataset.max, 10) || 5;
    var timer = null;
    var request = null;
    var activeIndex = -1;

    function open() {
      dropdown.classList.add('is-active');
      input.setAttribute('aria-expanded', 'true');
    }

    function close() {
      dropdown.classList.remove('is-active');
      input.setAttribute('aria-expanded', 'false');
      activeIndex = -1;
    }

    function options() {
      return Array.prototype.slice.call(list.querySelectorAll('a.dropdown-item'), 0);
    }

    function highlight(index) {
      options().forEach(function (el, i) {
        el.classList.toggle('is-active', i === index);
      });
      activeIndex = index;
    }

    function render(suggestions) {
      list.innerHTML = '';
      if (!suggestions.length) {
        var empty = document.createElement('div');
        empty.className = 'dropdown-item';
        empty.textContent = form.dataset.noResults;
        list.appendChild(empty);
      } else {
        suggestions.forEach(function (suggestion) {
          var link = document.createElement('a');
          link.className = 'dropdown-item';
          link.href = suggestion.url;
          link.textContent = suggestion.title;
          link.setAttribute('role', 'option');
          list.appendChild(link);
        });
      }
      activeIndex = -1;
      open();
    }

    function load(term) {
      if (request) {
        request.abort();
      }
      request = new AbortController();
      var url = form.dataset.suggestUrl + '?term=' + encodeURIComponent(term) + '&max=' + max;
      fetch(url, { signal: request.signal, credentials: 'same-origin', headers: { Accept: 'application/json' } })
        .then(function (response) {
          if (!response.ok) {
            throw new Error(response.status);
          }
          return response.json();
        })
        .then(function (data) {
          if (input.value.trim() === term) {
            render(data);
          }
        })
        .catch(function (error) {
          if (error.name !== 'AbortError') {
            close();
          }
        });
    }

    input.addEventListener('input', function () {
      clearTimeout(timer);
      var term = input.value.trim();
      if (term.length < minChars) {
        if (request) {
          request.abort();
        }
        close();
        return;
      }
      timer = setTimeout(function () {
        load(term);
      }, 250);
    });

    input.addEventListener('keydown', function (e) {
      var all = options();
      if (e.key === 'ArrowDown' && all.length) {
        e.preventDefault();
        open();
        highlight((activeIndex + 1) % all.length);
      } else if (e.key === 'ArrowUp' && all.length) {
        e.preventDefault();
        highlight(activeIndex <= 0 ? all.length - 1 : activeIndex - 1);
      } else if (e.key === 'Enter' && activeIndex >= 0 && all[activeIndex]) {
        e.preventDefault();
        window.location.href = all[activeIndex].href;
      } else if (e.key === 'Escape') {
        close();
      }
    });

    document.addEventListener('click', function (e) {
      if (!form.contains(e.target)) {
        close();
      }
    });
  });
});
