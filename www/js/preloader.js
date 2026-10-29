// ===============================
// Preloader global (Faza 7, B-10)
// ===============================
// Shfaqet vetëm kur Shiny mbetet i zënë më shumë se PRELOADER_DELAY_MS (V-23 a):
// ndryshimet e shpejta (slider, ndërrim faqeje) nuk e errësojnë më ekranin.
(function () {
    var PRELOADER_DELAY_MS = 400;
    var timer = null;

    function showLoader() {
        var el = document.getElementById('preloader');
        if (el) el.style.display = 'block';
    }
    function hideLoader() {
        var el = document.getElementById('preloader');
        if (el) el.style.display = 'none';
    }

    $(document).on('shiny:busy', function () {
        if (timer) return;
        timer = setTimeout(function () {
            timer = null;
            showLoader();
        }, PRELOADER_DELAY_MS);
    });

    $(document).on('shiny:idle', function () {
        if (timer) {
            clearTimeout(timer);
            timer = null;
        }
        hideLoader();
    });

    window.__showLoader = showLoader;
    window.__hideLoader = hideLoader;
})();
