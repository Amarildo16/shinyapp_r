(function () {
    if (window.__plotlyAnimFixV7VIS) return;
    window.__plotlyAnimFixV7VIS = true;

    const DEBUG = false;
    const log = (...a) => DEBUG && console.log("[plotly-animate]", ...a);

    const TAB_ID = "main_tabs";

    const WATCH = new Set([
        "stat_series",
        "model_series",
        "model_h",
        "forecast_series",
        "method",
        "h"
    ]);

    // Grafikët e moduleve kanë klasën "anim-plot" (ID me namespace, p.sh. "eda_ts-raw");
    // këtu mbeten vetëm grafikët e vjetër me ID globale.
    const ANIM_CLASS = "anim-plot";

    const AFFECTS = {
        stat_series: ["stat_diff_plot", "stat_acf_pacf"],
        model_series: ["model_plot"],
        model_h: ["model_plot"],
        forecast_series: ["forecast_plot"],
        method: ["forecast_plot"],
        h: ["forecast_plot"]
    };

    const ALL_TARGETS = uniq(Object.values(AFFECTS).reduce((acc, ids) => acc.concat(ids), []));

    function uniq(arr) {
        return Array.from(new Set(arr || []));
    }

    function getTargetsForInput(name) {
        return uniq(AFFECTS[name] || []);
    }

    const INPUT_DELAY_MS = 120;
    const TAB_DELAY_MS = 160;
    const DEBOUNCE_MS = 260;

    const state = {
        epoch: 0,
        lastFire: Object.create(null),
        pending: new Map(),
        fallbackTimers: Object.create(null),
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
                const id = getPlotOutputId(gd);
                if (!id) return;

                const ep = state.pending.get(id);
                if (!ep) return;

                if (!gd.querySelector("svg")) return;
                if (gd.__animatedEpoch === ep) {
                    state.pending.delete(id);
                    return;
                }

                if (!isVisibleInContainer(gd)) return;

                animateIfReady(id, "intersection", gd);
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
        if (!gd) return;

        const id = getPlotOutputId(gd);
        if (id) gd.__animOutputId = id;
        if (gd.__animHooked) return;
        gd.__animHooked = true;

        ensureIntersectionObserver();
        if (state.io) state.io.observe(gd);

        const afterPlot = () => {
            const outId = getPlotOutputId(gd);
            if (!outId || !state.pending.has(outId)) return;
            animateIfReady(outId, "afterplot", gd);
        };

        gd.__animAfterPlotHandler = afterPlot;
        if (typeof gd.on === "function") {
            gd.on("plotly_afterplot", afterPlot);
        } else if (typeof gd.addEventListener === "function") {
            gd.addEventListener("plotly_afterplot", afterPlot);
        }
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

    function animPlotIds() {
        return Array.from(document.querySelectorAll("." + ANIM_CLASS))
            .map((el) => el.id)
            .filter(Boolean);
    }

    function isKnownTarget(id) {
        if (!id) return false;
        if (ALL_TARGETS.indexOf(id) >= 0) return true;
        const el = document.getElementById(id);
        return !!(el && el.classList && el.classList.contains(ANIM_CLASS));
    }

    function getPlotOutputId(el) {
        if (!el) return null;
        if (el.__animOutputId && isKnownTarget(el.__animOutputId)) return el.__animOutputId;
        if (el.id && isKnownTarget(el.id)) return el.id;

        const host = el.closest && el.closest(".html-widget-output, .shiny-bound-output");
        if (host && host.id && isKnownTarget(host.id)) return host.id;

        return null;
    }

    function getPlotForOutput(id) {
        if (!isKnownTarget(id)) return null;

        const out = document.getElementById(id);
        if (!out) return null;
        if (out.classList && out.classList.contains("shiny-output-error")) return null;

        if (
            out.matches &&
            (out.matches(".js-plotly-plot") || out.matches(".plotly.html-widget"))
        ) {
            return out;
        }

        return out.querySelector(".js-plotly-plot, .plotly.html-widget");
    }

    function scheduleReadyCheck(id, delay) {
        if (!isKnownTarget(id)) return;

        const key = id + ":" + delay;
        if (state.fallbackTimers[key]) clearTimeout(state.fallbackTimers[key]);

        state.fallbackTimers[key] = setTimeout(() => {
            delete state.fallbackTimers[key];
            findPlotContainers(document);
            animateIfReady(id, "timer_" + delay);
        }, delay);
    }

    function markPending(ids, reason, delays) {
        const targets = uniq(ids).filter(isKnownTarget);
        if (!targets.length) return;

        const ep = ++state.epoch;
        targets.forEach((id) => {
            state.pending.set(id, ep);
        });

        if (Array.isArray(delays)) {
            targets.forEach((id) => {
                delays.forEach((delay) => scheduleReadyCheck(id, delay));
            });
        }

        log("pending plots", reason, targets, { ep });
    }

    function ensurePending(id, reason) {
        if (!isKnownTarget(id)) return;
        if (!state.pending.has(id)) markPending([id], reason);
    }

    function animateIfReady(id, reason, gd) {
        if (!isKnownTarget(id) || !state.pending.has(id)) return false;

        gd = gd || getPlotForOutput(id);
        if (!gd) return false;

        hookPlot(gd);

        const svg = gd.querySelector("svg");
        if (!svg) return false;
        if (!isVisibleInContainer(gd)) return false;

        const ep = state.pending.get(id);
        if (gd.__animatedEpoch === ep) {
            state.pending.delete(id);
            return true;
        }

        const now = Date.now();
        if (gd.__lastAnimAt && now - gd.__lastAnimAt < 90) return false;

        gd.__animatedEpoch = ep;
        gd.__lastAnimAt = now;
        state.pending.delete(id);
        animatePlotSvg(gd);
        log("animate ready", id, reason, { ep });
        return true;
    }

    function triggerTab(reason) {
        if (debounced(reason)) return;
        markPending(ALL_TARGETS.concat(animPlotIds()), reason, [TAB_DELAY_MS, TAB_DELAY_MS + 260]);
    }

    function triggerInput(name) {
        const reason = "input_" + name;
        if (debounced(reason)) return;

        const targets = getTargetsForInput(name);
        markPending(targets, reason);
    }

    function triggerOutput(id) {
        if (!isKnownTarget(id)) return;
        ensurePending(id, "output_" + id);
        scheduleReadyCheck(id, INPUT_DELAY_MS);
        scheduleReadyCheck(id, INPUT_DELAY_MS + 180);
    }

    function getEventName(e) {
        if (!e) return null;
        if (typeof e.name === "string") return e.name;
        if (e.detail && typeof e.detail.name === "string") return e.detail.name;
        return null;
    }

    function getOutputName(e) {
        const name = getEventName(e);
        if (name) return name;
        if (e && e.target && e.target.id) return e.target.id;
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

            $(document).on("shiny:value.plotlyanim_v7vis", function (e) {
                const id = getOutputName(e);
                if (!id) return;
                triggerOutput(id);
            });

            $(document).on("shiny:inputchanged.plotlyanim_v7vis", function (e) {
                const name = getEventName(e);
                if (!name) return;

                if (name === TAB_ID) {
                    triggerTab("tab_changed");
                    return;
                }
                if (WATCH.has(name)) {
                    triggerInput(name);
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
                        const id = getPlotOutputId(gd);
                        if (!id || !state.pending.has(id)) return;
                        animateIfReady(id, "scroll", gd);
                    });
                });
            };

            (sc === window ? window : sc).addEventListener("scroll", onScroll, { passive: true });
        }
    }

    bind();
})();
