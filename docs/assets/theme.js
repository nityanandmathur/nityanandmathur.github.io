/* research-docs — shared page behavior. Link once at end of <body>:
   <script src="assets/theme.js"></script>
   All handlers no-op when their target elements are absent, so the same
   file is safe on hub pages (with TOC) and plain report pages. */
(function () {
  // Top scroll-progress bar (add <div class="scroll-progress" id="scrollProgress"></div>)
  var sp = document.getElementById("scrollProgress");
  if (sp) {
    var onScroll = function () {
      var h = document.documentElement;
      var max = h.scrollHeight - h.clientHeight;
      sp.style.width = (max > 0 ? (h.scrollTop / max) * 100 : 0) + "%";
    };
    window.addEventListener("scroll", onScroll, { passive: true });
    onScroll();
  }

  // Sticky-TOC active-link highlighting (aside.toc a[href^="#"] -> section ids)
  var toc = document.querySelector("aside.toc");
  if (toc) {
    var links = Array.prototype.slice.call(toc.querySelectorAll('a[href^="#"]'));
    var sections = links
      .map(function (a) { return document.querySelector(a.getAttribute("href")); })
      .filter(Boolean);
    var update = function () {
      var cur = null;
      for (var i = 0; i < sections.length; i++) {
        if (sections[i].getBoundingClientRect().top < 100) cur = sections[i];
      }
      links.forEach(function (a) { a.classList.remove("active"); });
      if (cur) {
        var a = toc.querySelector('a[href="#' + cur.id + '"]');
        if (a) a.classList.add("active");
      }
    };
    document.addEventListener("scroll", update, { passive: true });
    update();
  }
})();
