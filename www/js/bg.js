(function () {
    const tabBackgrounds = {
        tab_settings: "images/image7.jpeg",
        tab_overview: "images/image0.jpeg",
        tab_eda_ts: "images/image1.jpeg",
        tab_eda_rel: "images/image2.jpeg",
        tab_stationary: "images/image3.jpeg",
        tab_modeling: "images/image4.jpeg",
        tab_forecast: "images/image5.jpeg",
    };

    const TRANSITION_MS = 1200;

    let currentSrc = null;
    let swapTimer = null;
    let bgState = null;

    function preloadImages(map) {
        Object.values(map).forEach((src) => {
            const img = new Image();
            img.src = src;
        });
    }

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

    function setBg(src) {
        if (!src) return;
        if (src === currentSrc) return;

        const { bgCurrent, bgNext } = getLayers();
        if (!bgCurrent || !bgNext) return;

        if (swapTimer) {
            clearTimeout(swapTimer);
            swapTimer = null;
        }

        const currentHasBg = !!bgCurrent.style.backgroundImage && bgCurrent.style.backgroundImage !== "none";
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
        const mode = bgState?.active_mode || "image";
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
        if (!tabId) return;

        const mode = bgState?.active_mode || "image";

        if (mode === "none") {
            clearBg();
            setLayerFilter("none");
            const { bgCurrent, bgNext } = getLayers();
            if (bgCurrent && bgNext) {
                bgCurrent.style.backgroundColor = "#0b1c24"; // ndryshoje po do transparent
                bgNext.style.backgroundColor = "#0b1c24";
            }
            return;
        }

        if (mode === "color") {
            clearBg();
            setLayerFilter("color");
            const color = bgState?.modes?.color?.value || "#0b1c24";
            const { bgCurrent, bgNext } = getLayers();
            if (bgCurrent && bgNext) {
                bgCurrent.style.backgroundColor = color;
                bgNext.style.backgroundColor = color;
            }
            return;
        }

        // image
        setLayerFilter("image");

        const imgMode = bgState?.modes?.image || {};
        const scope = imgMode?.active_scope || "custom";

        let src = null;

        if (scope === "global") {
            src = imgMode?.scopes?.global?.global || null;
        } else {
            const perTab = imgMode?.scopes?.custom?.per_tab || {};
            src = perTab?.[tabId] || tabBackgrounds[tabId] || tabBackgrounds.tab_overview;
        }

        if (!src) src = tabBackgrounds[tabId] || tabBackgrounds.tab_overview;

        setBg(withVersion(src));
    }

    function getName(e) {
        return e?.name || e?.detail?.name || e?.originalEvent?.detail?.name || null;
    }

    function getValue(e) {
        return e?.value || e?.detail?.value || e?.originalEvent?.detail?.value || null;
    }

    function applyStateNow() {
        applyBlurFromState();
        const tabId = currentTabFromShiny() || "tab_overview";
        setBgByTabValue(tabId);
    }

    document.addEventListener("DOMContentLoaded", function () {
        preloadImages(tabBackgrounds);

        setBg(tabBackgrounds.tab_overview);

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
