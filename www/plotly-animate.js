(function () {
    if (window.__plotlyAnimFixV7VIS) return;
    window.__plotlyAnimFixV7VIS = true;

    const DEBUG = false;
    const log = (...a) => DEBUG && console.log("[plotly-animate]", ...a);

    const TAB_ID = "main_tabs";

    const WATCH = new Set([
        "eda_series",
        "roll_k",
        "rel_x",
        "rel_y",
        "stat_series",
        "model_series",
        "model_h",
        "forecast_series",
        "method",
        "h"
    ]);

    const INPUT_DELAY_MS = 120;
    const TAB_DELAY_MS = 160;
    const POLL_EVERY_MS = 140;
    const POLL_MAX = 80;
    const DEBOUNCE_MS = 260;

    const state = {
        epoch: 0,
        lastFire: Object.create(null),
        pollTimer: null,
        io: null
    };

    function debounced(key) {
        const now = Date.now();
        const prev = state.lastFire[key] || 0;
        if (now - prev < DEBOUNCE_MS) return true;
        state.lastFire[key] = now;
        return false;
    }

    function getScrollContainer() {
        return document.querySelector(".app-content") || window;
    }

    function isVisibleInContainer(el) {
        if (!el) return false;
        const r = el.getBoundingClientRect();
        if (r.width === 0 || r.height === 0) return false;

        const c = getScrollContainer();

        if (c === window) {
            const vh = window.innerHeight || document.documentElement.clientHeight;
            return r.top < vh && r.bottom > 0;
        }

        const cr = c.getBoundingClientRect();
        const top = Math.max(r.top, cr.top);
        const bottom = Math.min(r.bottom, cr.bottom);
        return bottom > top;
    }

    function ensureIntersectionObserver() {
        if (state.io || typeof IntersectionObserver !== "function") return;

        const sc = getScrollContainer();
        const rootEl = (sc === window) ? null : sc;

        state.io = new IntersectionObserver((entries) => {
            entries.forEach((entry) => {
                if (!entry.isIntersecting) return;

                const gd = entry.target;
                const ep = gd.__pendingEpoch;
                if (!ep) return;

                if (!gd.querySelector("svg")) return;
                if (gd.__animatedEpoch === ep) {
                    gd.__pendingEpoch = null;
                    return;
                }

                if (!isVisibleInContainer(gd)) return;

                gd.__animatedEpoch = ep;
                gd.__pendingEpoch = null;

                animatePlotSvg(gd);
                log("io animate", gd.id || "(no id)", { ep });
            });
        }, { root: rootEl, threshold: 0.18 });
    }

    function hasStroke(path) {
        const attr = path.getAttribute && path.getAttribute("stroke");
        if (attr && attr !== "none") return true;

        const st = path.style && path.style.stroke;
        if (st && st !== "none") return true;

        try {
            const cs = window.getComputedStyle(path);
            const cst = cs && cs.stroke;
            if (cst && cst !== "none" && cst !== "rgba(0, 0, 0, 0)") return true;
        } catch (_) { }

        return false;
    }

    function drawPath(el) {
        if (!el || typeof el.getTotalLength !== "function") return false;
        if (!hasStroke(el)) return false;

        let length = 0;
        try { length = el.getTotalLength(); } catch (e) { return false; }
        if (!isFinite(length) || length <= 0) return false;

        el.style.transition = "none";
        el.style.strokeDasharray = String(length);
        el.style.strokeDashoffset = String(length);
        el.style.opacity = "0";
        void el.getBoundingClientRect();

        requestAnimationFrame(() => {
            el.style.transition = "stroke-dashoffset 1.8s ease-out, opacity 1.0s ease-out";
            el.style.strokeDashoffset = "0";
            el.style.opacity = "1";
        });

        setTimeout(() => {
            el.style.transition = "";
            el.style.strokeDasharray = "";
            el.style.strokeDashoffset = "";
            el.style.opacity = "";
        }, 2000);

        return true;
    }

    function fadeIn(el) {
        if (!el) return;
        el.style.transition = "none";
        el.style.opacity = "0";
        void el.getBoundingClientRect();
        requestAnimationFrame(() => {
            el.style.transition = "opacity 0.9s ease-out";
            el.style.opacity = "1";
        });
    }

    function animatePlotSvg(gd) {
        const plotRoot = gd.querySelector(".main-svg g.plot") || gd.querySelector("svg");
        if (!plotRoot) return;

        const linePaths = gd.querySelectorAll(".scatterlayer .trace path.js-line");
        let didLine = 0;
        linePaths.forEach((p) => { if (drawPath(p)) didLine++; });

        const traces = gd.querySelectorAll("g.trace");
        traces.forEach((tr) => fadeIn(tr));

        log("animated", gd.id || "(no id)", { lines: didLine, traces: traces.length });
    }

    function hookPlot(gd) {
        if (!gd || gd.__animHooked) return;
        gd.__animHooked = true;

        ensureIntersectionObserver();
        if (state.io) state.io.observe(gd);

        const afterPlot = () => {
            const ep = gd.__pendingEpoch;
            if (!ep) return;

            if (!gd.querySelector("svg")) return;

            if (isVisibleInContainer(gd) && gd.__animatedEpoch !== ep) {
                gd.__animatedEpoch = ep;
                gd.__pendingEpoch = null;
                animatePlotSvg(gd);
                log("afterplot animate", gd.id || "(no id)", { ep });
            } else {
                log("afterplot ready waiting visibility", gd.id || "(no id)", { ep });
            }
        };

        if (typeof gd.on === "function") gd.on("plotly_afterplot", afterPlot);
        gd.addEventListener("plotly_afterplot", afterPlot);
    }

    function findPlotContainers(scope) {
        const a = Array.from(scope.querySelectorAll(".js-plotly-plot"));
        const b = Array.from(scope.querySelectorAll(".plotly.html-widget"));
        const out = [];
        const seen = new Set();
        [...a, ...b].forEach((el) => {
            if (!el || seen.has(el)) return;
            seen.add(el);
            out.push(el);
        });
        out.forEach(hookPlot);
        return out;
    }

    function stopPolling(reason, ep, tries) {
        if (state.pollTimer) {
            clearInterval(state.pollTimer);
            state.pollTimer = null;
        }
        log("stop polling", { reason, tries, epoch: ep });
    }

    function pollUntilDone(reason, ep) {
        if (state.pollTimer) {
            clearInterval(state.pollTimer);
            state.pollTimer = null;
        }

        let tries = 0;

        state.pollTimer = setInterval(() => {
            tries += 1;

            const plots = findPlotContainers(document);
            if (!plots.length) {
                if (tries >= POLL_MAX) stopPolling(reason, ep, tries);
                return;
            }

            plots.forEach((gd) => { gd.__pendingEpoch = ep; });

            let didAny = 0;
            plots.forEach((gd) => {
                if (!gd.querySelector("svg")) return;
                if (!isVisibleInContainer(gd)) return;
                if (gd.__animatedEpoch === ep) return;

                gd.__animatedEpoch = ep;
                gd.__pendingEpoch = null;
                animatePlotSvg(gd);
                didAny += 1;
            });

            if (didAny > 0 || tries >= POLL_MAX) {
                stopPolling(reason, ep, tries);
            }
        }, POLL_EVERY_MS);
    }

    function triggerTab(reason) {
        if (debounced(reason)) return;
        const ep = ++state.epoch;
        setTimeout(() => pollUntilDone(reason, ep), TAB_DELAY_MS);
    }

    function triggerInput(reason) {
        if (debounced(reason)) return;
        const ep = ++state.epoch;
        setTimeout(() => pollUntilDone(reason, ep), INPUT_DELAY_MS);
    }

    function getEventName(e) {
        if (!e) return null;
        if (typeof e.name === "string") return e.name;
        if (e.detail && typeof e.detail.name === "string") return e.detail.name;
        return null;
    }

    function bind() {
        function bindWithjQuery() {
            const $ = window.jQuery;

            $(document).off(".plotlyanim_v7vis");

            $(document).on("shiny:connected.plotlyanim_v7vis", function () {
                triggerTab("initial_load");
                setTimeout(() => triggerTab("initial_load_late"), 800);
            });

            $(document).on("shiny:inputchanged.plotlyanim_v7vis", function (e) {
                const name = getEventName(e);
                if (!name) return;

                if (name === TAB_ID) {
                    triggerTab("tab_changed");
                    return;
                }
                if (WATCH.has(name)) {
                    triggerInput("input_" + name);
                }
            });
        }

        (function waitJQ() {
            if (window.jQuery) {
                bindWithjQuery();
                return;
            }
            setTimeout(waitJQ, 60);
        })();

        if (typeof IntersectionObserver !== "function") {
            const sc = getScrollContainer();
            let ticking = false;

            const onScroll = () => {
                if (ticking) return;
                ticking = true;

                requestAnimationFrame(() => {
                    ticking = false;

                    const plots = findPlotContainers(document);
                    plots.forEach((gd) => {
                        const ep = gd.__pendingEpoch;
                        if (!ep) return;
                        if (gd.__animatedEpoch === ep) { gd.__pendingEpoch = null; return; }
                        if (!gd.querySelector("svg")) return;
                        if (!isVisibleInContainer(gd)) return;

                        gd.__animatedEpoch = ep;
                        gd.__pendingEpoch = null;
                        animatePlotSvg(gd);
                    });
                });
            };

            (sc === window ? window : sc).addEventListener("scroll", onScroll, { passive: true });
        }
    }

    bind();
})();
