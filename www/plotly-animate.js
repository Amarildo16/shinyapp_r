(function () {
    // Prevent double load
    if (window.__plotlyAnimFixV3) return;
    window.__plotlyAnimFixV3 = true;

    const DEBUG = false;
    const log = (...a) => DEBUG && console.log("[plotly-animate]", ...a);

    const TAB_ID = "main_tabs";
    const WATCH = new Set(["series", "scatter_x", "scatter_y", "show_points", "method", "h"]);

    // Timings
    const INPUT_DELAY_MS = 120;
    const TAB_DELAY_MS = 160;
    const POLL_EVERY_MS = 120;
    const POLL_MAX = 25; // ~3s
    const DEBOUNCE_MS = 180;

    const state = {
        epoch: 0,
        lastFire: Object.create(null),
        pollTimer: null,
    };

    function debounced(key) {
        const now = Date.now();
        const prev = state.lastFire[key] || 0;
        if (now - prev < DEBOUNCE_MS) return true;
        state.lastFire[key] = now;
        return false;
    }

    function getTabsRoot() {
        return document.getElementById(TAB_ID);
    }

    function activePane() {
        const root = getTabsRoot();
        if (!root) return null;
        return root.querySelector(".tab-pane.active");
    }

    function getScrollContainer() {
        // your app scrolls inside .app-content
        return document.querySelector(".app-content") || window;
    }

    function isVisibleInContainer(el) {
        if (!el) return false;

        const c = getScrollContainer();
        const r = el.getBoundingClientRect();

        if (c === window) {
            return r.top < window.innerHeight && r.bottom > 0;
        }

        const cr = c.getBoundingClientRect();
        const top = Math.max(r.top, cr.top);
        const bottom = Math.min(r.bottom, cr.bottom);
        return bottom > top; // intersects
    }

    function animateSvgIn(gd) {
        const els = gd.querySelectorAll("svg path, svg polygon");
        if (!els.length) return;

        els.forEach((el) => {
            try {
                if (typeof el.getTotalLength !== "function") return;

                const length = el.getTotalLength();
                const fill = el.getAttribute("fill");
                const isFill = fill && fill !== "none";

                el.style.transition = "none";

                if (!isFill) {
                    el.style.strokeDasharray = String(length);
                    el.style.strokeDashoffset = String(length);
                    el.style.opacity = "0";
                    void el.getBoundingClientRect();

                    requestAnimationFrame(() => {
                        el.style.transition = "stroke-dashoffset 1.8s ease-out, opacity 1.2s ease-out";
                        el.style.strokeDashoffset = "0";
                        el.style.opacity = "1";
                    });
                } else {
                    // for filled shapes: fade-in only (keep it subtle)
                    el.style.opacity = "0";
                    void el.getBoundingClientRect();

                    requestAnimationFrame(() => {
                        el.style.transition = "opacity 1.2s ease-out";
                        el.style.opacity = "1";
                    });
                }
            } catch (e) { }
        });
    }

    // Hook plotly_afterplot ONCE per div
    function hookPlot(gd) {
        if (!gd || gd.__animHooked) return;
        gd.__animHooked = true;

        gd.addEventListener("plotly_afterplot", function () {
            const pending = gd.__pendingEpoch;
            if (!pending) return;

            const pane = activePane();
            if (!pane || !pane.contains(gd)) return;

            if (!gd.querySelector("svg")) return;
            if (!isVisibleInContainer(gd)) return;

            // once per epoch
            if (gd.__animatedEpoch === pending) return;

            gd.__animatedEpoch = pending;
            gd.__pendingEpoch = null;

            log("animate afterplot", "epoch", pending, gd.id || "(no id)");
            animateSvgIn(gd);
        });

        log("hooked afterplot", gd.id || "(no id)");
    }

    function scanActivePlots() {
        const pane = activePane();
        if (!pane) return [];
        const plots = Array.from(pane.querySelectorAll(".js-plotly-plot"));
        plots.forEach(hookPlot);
        return plots;
    }

    function stopPolling(reason, ep, tries) {
        if (state.pollTimer) {
            clearInterval(state.pollTimer);
            state.pollTimer = null;
        }
        log("stop polling", { reason, tries, epoch: ep });
    }

    // mode: "tab" or "input"
    function pollUntilDone(reason, ep, mode) {
        // kill previous poll loop for prior epoch
        if (state.pollTimer) {
            clearInterval(state.pollTimer);
            state.pollTimer = null;
        }

        let tries = 0;

        state.pollTimer = setInterval(() => {
            tries += 1;

            const plots = scanActivePlots();

            // nothing to do
            if (!plots.length) {
                if (tries >= POLL_MAX) stopPolling(reason, ep, tries);
                return;
            }

            if (mode === "tab") {
                // tab-mode: animate directly when svg exists + visible
                let didAny = 0;
                let allVisibleDone = true;

                plots.forEach((gd) => {
                    const vis = isVisibleInContainer(gd);
                    if (!vis) return; // ignore not visible
                    if (!gd.querySelector("svg")) { allVisibleDone = false; return; }
                    if (gd.__animatedEpoch === ep) return;

                    gd.__animatedEpoch = ep;
                    log("animate tab", "epoch", ep, gd.id || "(no id)");
                    animateSvgIn(gd);
                    didAny += 1;
                });

                // stop when all visible plots are done or max tries
                if (allVisibleDone || didAny > 0 || tries >= POLL_MAX) {
                    stopPolling(reason, ep, tries);
                }
            } else {
                // input-mode: mark pending for ALL plots, then wait until ALL visible are animated
                plots.forEach((gd) => {
                    gd.__pendingEpoch = ep;
                });

                const visiblePlots = plots.filter((gd) => isVisibleInContainer(gd) && gd.querySelector("svg"));
                const allDone = visiblePlots.length
                    ? visiblePlots.every((gd) => gd.__animatedEpoch === ep)
                    : false;

                if (allDone || tries >= POLL_MAX) {
                    stopPolling(reason, ep, tries);
                }
            }
        }, POLL_EVERY_MS);
    }

    function triggerTab(reason) {
        if (debounced(reason)) return;

        state.epoch += 1;
        const ep = state.epoch;
        log("epoch++", ep, reason);

        setTimeout(() => pollUntilDone(reason, ep, "tab"), TAB_DELAY_MS);
    }

    function triggerInput(reason) {
        if (debounced(reason)) return;

        state.epoch += 1;
        const ep = state.epoch;
        log("epoch++", ep, reason);

        setTimeout(() => pollUntilDone(reason, ep, "input"), INPUT_DELAY_MS);
    }

    function getEventName(e) {
        if (!e) return null;
        if (typeof e.name === "string") return e.name;
        if (e.detail && typeof e.detail.name === "string") return e.detail.name;
        return null;
    }

    function bind() {
        // TAB: Shiny inputchanged for tabsetPanel (most reliable in Shiny)
        document.addEventListener(
            "shiny:inputchanged",
            (e) => {
                const name = getEventName(e);
                if (!name) return;

                if (name === TAB_ID) {
                    triggerTab("tab_changed");
                    return;
                }
                if (!WATCH.has(name)) return;

                triggerInput("input_" + name);
            },
            true
        );

        // Optional bootstrap tab event (safe fallback)
        if (window.jQuery) {
            jQuery(document).on(
                "shown.bs.tab",
                '#' + TAB_ID + ' a[data-toggle="tab"], #' + TAB_ID + ' a[data-bs-toggle="tab"]',
                function () {
                    triggerTab("tab_changed_bootstrap");
                }
            );

            // fallback change (in case some input doesn't emit shiny:inputchanged as expected)
            const sel = Array.from(WATCH).map((id) => "#" + id).join(",");
            jQuery(document).on("change", sel, function (ev) {
                const id = (ev.target && ev.target.id) ? ev.target.id : "unknown";
                if (!WATCH.has(id)) return;
                triggerInput("input_" + id);
            });
        }
    }

    window.addEventListener("load", function () {
        log("plotly-animate.js loaded!");
        bind();
        triggerTab("initial_load");
    });
})();
