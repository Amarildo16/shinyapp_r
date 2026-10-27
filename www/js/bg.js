(function () {
    const TRANSITION_MS = 1200;

    let currentSrc = null;
    let swapTimer = null;
    let bgState = null;

    const DEFAULT_COLOR = "#0b1c24";

    function withVersion(src) {
        const v = bgState?.version;
        if (!src || !v) return src;
        return src.includes("?") ? `${src}&v=${v}` : `${src}?v=${v}`;
    }

    function getLayers() {
        const bgCurrent = document.querySelector(".bg-layer.current");
        const bgNext = document.querySelector(".bg-layer.next");
        return { bgCurrent, bgNext };
    }

    function clearBg() {
        const { bgCurrent, bgNext } = getLayers();
        if (!bgCurrent || !bgNext) return;

        bgCurrent.style.backgroundImage = "none";
        bgNext.style.backgroundImage = "none";

        bgCurrent.style.backgroundColor = "";
        bgNext.style.backgroundColor = "";

        currentSrc = null;
    }

    function setLayerFilter(mode) {
        const { bgCurrent, bgNext } = getLayers();
        if (!bgCurrent || !bgNext) return;

        if (mode === "image") {
            bgCurrent.style.filter = "";
            bgNext.style.filter = "";
            return;
        }

        bgCurrent.style.filter = "none";
        bgNext.style.filter = "none";
        document.documentElement.style.setProperty("--bg-blur", "0px");
    }

    function setBgColor(color) {
        const c = color || bgState?.modes?.color?.value || DEFAULT_COLOR;

        clearBg();
        setLayerFilter("color");

        const { bgCurrent, bgNext } = getLayers();
        if (bgCurrent && bgNext) {
            bgCurrent.style.backgroundColor = c;
            bgNext.style.backgroundColor = c;
        }
    }

    function setBg(src) {
        if (!src) return;
        if (src === currentSrc) return;

        const { bgCurrent, bgNext } = getLayers();
        if (!bgCurrent || !bgNext) return;

        if (swapTimer) {
            clearTimeout(swapTimer);
            swapTimer = null;
        }

        const currentHasBg =
            !!bgCurrent.style.backgroundImage && bgCurrent.style.backgroundImage !== "none";

        if (!currentHasBg) {
            bgCurrent.style.backgroundImage = "url('" + src + "')";
            currentSrc = src;
            return;
        }

        bgNext.style.transition = "none";
        bgNext.style.opacity = 0;
        bgNext.style.backgroundImage = "url('" + src + "')";

        void bgNext.offsetHeight;

        bgNext.style.transition = `opacity ${TRANSITION_MS}ms ease`;
        bgNext.style.opacity = 1;

        swapTimer = setTimeout(() => {
            bgCurrent.style.backgroundImage = bgNext.style.backgroundImage;
            bgNext.style.opacity = 0;
            currentSrc = src;
            swapTimer = null;
        }, TRANSITION_MS);
    }

    function applyBlurFromState() {
        const mode = bgState?.active_mode || "color";
        if (mode !== "image") return;

        const blur = bgState?.modes?.image?.blur || {};
        const on = !!blur.on;
        const amount = Number.isFinite(+blur.amount) ? +blur.amount : 10;
        const px = on ? `${amount}px` : "0px";
        document.documentElement.style.setProperty("--bg-blur", px);
    }

    function currentTabFromShiny() {
        try {
            return window.Shiny?.shinyapp?.$inputValues?.main_tabs || null;
        } catch (e) {
            return null;
        }
    }

    function setBgByTabValue(tabId) {
        const mode = bgState?.active_mode || "color";

        if (!bgState) {
            setBgColor(DEFAULT_COLOR);
            return;
        }

        if (mode === "none") {
            setBgColor(bgState?.modes?.color?.value || DEFAULT_COLOR);
            return;
        }

        if (mode === "color") {
            setBgColor(bgState?.modes?.color?.value || DEFAULT_COLOR);
            return;
        }

        applyBlurFromState();
        setLayerFilter("image");

        const imgMode = bgState?.modes?.image || {};
        const scope = imgMode?.active_scope || "custom";

        let src = null;

        if (scope === "global") {
            src = imgMode?.scopes?.global?.global || null;
        } else {
            const perTab = imgMode?.scopes?.custom?.per_tab || {};
            src = perTab?.[tabId] || null;
        }

        if (!src) {
            setBgColor(bgState?.modes?.color?.value || DEFAULT_COLOR);
            return;
        }

        const { bgCurrent, bgNext } = getLayers();
        if (bgCurrent && bgNext) {
            bgCurrent.style.backgroundColor = "";
            bgNext.style.backgroundColor = "";
        }

        setBg(withVersion(src));
    }

    function getName(e) {
        return e?.name || e?.detail?.name || e?.originalEvent?.detail?.name || null;
    }

    function getValue(e) {
        return e?.value || e?.detail?.value || e?.originalEvent?.detail?.value || null;
    }

    // Faqja e parë e PAGES (Settings), lexuar nga sidebar-i (P-12).
    function firstPageTab() {
        const el = document.querySelector("[data-nav-tab]");
        return el ? el.getAttribute("data-nav-tab") : null;
    }

    function applyStateNow() {
        const tabId = currentTabFromShiny() || firstPageTab();
        setBgByTabValue(tabId);
    }

    document.addEventListener("DOMContentLoaded", function () {
        setBgColor(DEFAULT_COLOR);

        if (window.jQuery) {
            jQuery(document).on("shiny:inputchanged", function (e) {
                const name = getName(e);
                if (name === "main_tabs") setBgByTabValue(getValue(e));
            });

            jQuery(document).on("shiny:connected", function () {
                applyStateNow();
            });
        }

        if (window.Shiny && window.Shiny.addCustomMessageHandler) {
            window.Shiny.addCustomMessageHandler("bg_apply", function (st) {
                bgState = st || null;
                applyStateNow();
            });
        }
    });
})();
