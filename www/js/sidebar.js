(function () {
    const root = document.documentElement;

    /* ======================================================
       1) SINGLE SOURCE OF TRUTH
       Harta tab -> buton vjen nga R (PAGES te config.R), përmes
       atributit data-nav-tab të butonave të sidebar-it (P-12).
    ====================================================== */
    let MAP = {};
    let BTN_TO_TAB = {};

    function buildMap() {
        MAP = {};
        document.querySelectorAll("[data-nav-tab]").forEach((el) => {
            if (el.id) MAP[el.getAttribute("data-nav-tab")] = "#" + el.id;
        });
        BTN_TO_TAB = Object.fromEntries(
            Object.entries(MAP).map(([tab, btn]) => [btn, tab])
        );
    }

    /* ======================================================
       2) SIDEBAR STATE
    ====================================================== */
    function isOpen() {
        return root.classList.contains("sidebar-open");
    }

    function openSidebar() {
        root.classList.add("sidebar-open");
        setTimeout(resizePlotlyVisible, 180);
    }

    function closeSidebar() {
        root.classList.remove("sidebar-open");
        setTimeout(resizePlotlyVisible, 180);
    }

    function toggleSidebar() {
        isOpen() ? closeSidebar() : openSidebar();
    }

    /* ======================================================
       3) ACTIVE STATE (UI)
    ====================================================== */
    function clearActive() {
        Object.values(MAP).forEach((sel) => {
            const el = document.querySelector(sel);
            if (el) el.classList.remove("is-active");
        });
    }

    function setActiveByTab(tabVal) {
        clearActive();
        const btnSel = MAP[tabVal];
        if (!btnSel) return;
        const btn = document.querySelector(btnSel);
        if (btn) btn.classList.add("is-active");
    }

    function setActiveByButton(btnSel) {
        clearActive();
        const btn = document.querySelector(btnSel);
        if (btn) btn.classList.add("is-active");
    }

    /* ======================================================
       4) PLOTLY RESIZE (when layout changes)
    ====================================================== */
    function resizePlotlyVisible() {
        window.dispatchEvent(new Event("resize"));
        document.querySelectorAll(".js-plotly-plot").forEach((gd) => {
            try {
                if (window.Plotly?.Plots?.resize) {
                    window.Plotly.Plots.resize(gd);
                }
            } catch (e) { }
        });
    }

    /* ======================================================
       5) SHINY HELPERS
    ====================================================== */
    function getShinyName(e) {
        return e?.detail?.name || e?.name || null;
    }

    function getShinyValue(e) {
        return e?.detail?.value || e?.value || null;
    }

    /* ======================================================
       6) INIT
    ====================================================== */
    document.addEventListener("DOMContentLoaded", function () {
        buildMap();
        closeSidebar();

        const firstTab = document.querySelector("#main_tabs li.active a, #main_tabs a.active");
        if (firstTab) setActiveByTab(firstTab.getAttribute("data-value"));

        document.addEventListener("click", function (e) {
            if (e.target.closest("#toggle_sidebar")) {
                toggleSidebar();
                return;
            }

            if (e.target.closest("#sidebar_backdrop")) {
                closeSidebar();
                return;
            }
        });


        document.addEventListener("keydown", function (e) {
            if (e.key === "Escape") closeSidebar();
        });

        if (window.jQuery) {
            const selectors = Object.values(MAP).join(",");

            jQuery(document).on("click", selectors, function (e) {
                e.preventDefault();
                const sel = "#" + this.id;

                const tabVal = BTN_TO_TAB[sel];
                if (tabVal && window.Shiny) {
                    Shiny.setInputValue(this.id, Date.now(), { priority: "event" });
                }

                if (tabVal) {
                    setActiveByButton(sel);
                    closeSidebar();
                    setTimeout(resizePlotlyVisible, 250);
                }
            });


            /* --------------------------------------------------
               SHINY TAB CHANGE
            -------------------------------------------------- */
            jQuery(document).on("shiny:inputchanged", function (e) {
                const name = getShinyName(e);
                if (name !== "main_tabs") return;

                const val = getShinyValue(e);
                if (val) {
                    setActiveByTab(val);
                    closeSidebar();
                }
            });
        }

        setTimeout(resizePlotlyVisible, 400);
    });
})();
