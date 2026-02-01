(function () {
    const tabBackgrounds = {
        tab_overview: "images/image0.jpeg",
        tab_eda_ts: "images/image1.jpeg",
        tab_eda_rel: "images/image2.jpeg",
        tab_stationary: "images/image3.jpeg",
        tab_modeling: "images/image4.jpeg",
        tab_forecast: "images/image5.jpeg",
        tab_wrapup: "images/image6.jpeg",
    };


    const TRANSITION_MS = 1200;

    let currentSrc = null;
    let swapTimer = null;

    function preloadImages(map) {
        Object.values(map).forEach((src) => {
            const img = new Image();
            img.src = src;
        });
    }

    function setBg(src) {
        if (!src) return;
        if (src === currentSrc) return;

        const bgCurrent = document.querySelector(".bg-layer.current");
        const bgNext = document.querySelector(".bg-layer.next");
        if (!bgCurrent || !bgNext) return;

        if (swapTimer) {
            clearTimeout(swapTimer);
            swapTimer = null;
        }

        const currentHasBg = !!bgCurrent.style.backgroundImage;
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

    function setBgByTabValue(val) {
        if (!val) return;
        const src = tabBackgrounds[val];
        if (src) setBg(src);
    }

    function getName(e) {
        return (
            e?.name ||
            e?.detail?.name ||
            e?.originalEvent?.detail?.name ||
            null
        );
    }

    function getValue(e) {
        return (
            e?.value ||
            e?.detail?.value ||
            e?.originalEvent?.detail?.value ||
            null
        );
    }

    document.addEventListener("DOMContentLoaded", function () {
        preloadImages(tabBackgrounds);

        setBg(tabBackgrounds.tab_overview);

        document.addEventListener(
            "shiny:inputchanged",
            function (e) {
                const name = getName(e);
                if (name === "main_tabs") setBgByTabValue(getValue(e));
            },
            true
        );

        if (window.jQuery) {
            jQuery(document).on("shiny:inputchanged", function (e) {
                const name = getName(e);
                if (name === "main_tabs") setBgByTabValue(getValue(e));
            });

            jQuery(document).on("shiny:connected", function () {
                try {
                    const val = window.Shiny?.shinyapp?.$inputValues?.main_tabs;
                    if (val) setBgByTabValue(val);
                } catch (err) { }
            });
        }
    });
})();
