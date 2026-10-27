// ===============================
// 1) Global Preloader
// ===============================
(function () {
    function showLoader() {
        var el = document.getElementById('preloader');
        if (el) el.style.display = 'block';
    }
    function hideLoader() {
        var el = document.getElementById('preloader');
        if (el) el.style.display = 'none';
    }

    $(document).on('shiny:busy', function () {
        showLoader();
    });

    $(document).on('shiny:idle', function () {
        hideLoader();
    });

    window.__showLoader = showLoader;
    window.__hideLoader = hideLoader;
})();


// ===============================
// 2) FilePond init
// ===============================
(function () {
    function getHost(inputId) {
        if (inputId === "datasets-csv_file_modal") {
            return document.getElementById("datasets-csv_file_modal_pond_host");
        }
        if (inputId === "bg_media_upload") {
            return document.getElementById("bg_media_upload_pond_host");
        }
        return document.getElementById(inputId + "_pond_host");
    }

    function detectConfig(shinyInput, inputId) {
        const accept = (shinyInput.getAttribute("accept") || "").toLowerCase();

        if (inputId === "datasets-csv_file_modal" || accept.includes("csv") || accept.includes(".csv")) {
            return {
                mode: "csv",
                acceptedFileTypes: ["text/csv"],
                expectedLabel: "Lejohet vetëm: .csv",
                detectMime: (source, type) =>
                    new Promise((resolve) => {
                        const name = (source && source.name) ? String(source.name).toLowerCase() : "";
                        const ext = name.includes(".") ? name.split(".").pop() : "";
                        if (ext === "csv") return resolve("text/csv");
                        return resolve(type || "application/octet-stream");
                    })
            };
        }

        if (
            inputId === "bg_media_upload" ||
            accept.includes("image") ||
            accept.includes("png") ||
            accept.includes("jpeg") ||
            accept.includes("jpg") ||
            accept.includes("webp") ||
            accept.includes("gif") ||
            accept.includes("svg")
        ) {
            return {
                mode: "image",
                acceptedFileTypes: ["image/jpeg", "image/png", "image/webp"],
                expectedLabel: "Lejohen vetëm: JPG, PNG, WEBP",
                detectMime: (source, type) =>
                    new Promise((resolve) => {
                        const name = (source && source.name) ? String(source.name).toLowerCase() : "";
                        const ext = name.includes(".") ? name.split(".").pop() : "";
                        const map = {
                            png: "image/png",
                            jpg: "image/jpeg",
                            jpeg: "image/jpeg",
                            webp: "image/webp"
                        };
                        if (map[ext]) return resolve(map[ext]);
                        return resolve(type || "application/octet-stream");
                    })
            };
        }

        return {
            mode: "any",
            acceptedFileTypes: [],
            expectedLabel: "",
            detectMime: (source, type) => Promise.resolve(type || "application/octet-stream")
        };
    }

    function initFilePondInput(inputId) {
        const shinyInput = document.getElementById(inputId);
        if (!shinyInput) return false;

        if (shinyInput.tagName.toLowerCase() !== "input" || shinyInput.type !== "file") return false;
        if (!window.FilePond) return false;

        const host = getHost(inputId);
        if (!host) return false;

        const wrapper =
            shinyInput.closest(".shiny-input-container") ||
            shinyInput.closest(".form-group");
        if (wrapper) wrapper.classList.add("shiny-fileinput-hidden");

        const cfg = detectConfig(shinyInput, inputId);

        const proxyId = inputId + "__pond_proxy";
        let proxy = document.getElementById(proxyId);

        if (!proxy) {
            host.innerHTML = "";
            proxy = document.createElement("input");
            proxy.type = "file";
            proxy.id = proxyId;
            proxy.accept = shinyInput.getAttribute("accept") || "";
            if (shinyInput.multiple) proxy.multiple = true;
            host.appendChild(proxy);
        } else {
            proxy.accept = shinyInput.getAttribute("accept") || proxy.accept || "";
            proxy.multiple = !!shinyInput.multiple;
        }

        if (proxy._pond && proxy._pond_cfg) {
            const old = proxy._pond_cfg;
            const needRecreate =
                old.mode !== cfg.mode ||
                old.multiple !== !!shinyInput.multiple ||
                old.accept !== (proxy.accept || "");

            if (needRecreate) {
                try { proxy._pond.destroy(); } catch (e) { }
                proxy._pond = null;
                proxy._pond_cfg = null;
            }
        }

        if (proxy._pond) return true;

        if (window.FilePondPluginFileValidateType) FilePond.registerPlugin(FilePondPluginFileValidateType);
        if (window.FilePondPluginFileValidateSize) FilePond.registerPlugin(FilePondPluginFileValidateSize);

        const isMulti = !!shinyInput.multiple;

        const pond = FilePond.create(proxy, {
            allowMultiple: isMulti,
            maxFiles: isMulti ? 50 : 1,
            allowReplace: !isMulti,
            instantUpload: false,
            allowProcess: false,

            server: {
                process: null,
                revert: null,
                restore: null,
                fetch: null,
                load: (source, load, error, progress, abort) => {
                    console.log("POND server.load BLOCKED:", source);
                    abort();
                }
            },

            acceptedFileTypes: cfg.acceptedFileTypes,
            allowFileTypeValidation: cfg.acceptedFileTypes.length > 0,
            fileValidateTypeDetectType: cfg.detectMime,

            maxFileSize: "25MB",
            allowFileSizeValidation: true,

            labelIdle: `
                <div class="pond-idle">
                <i class="ri-upload-cloud-2-fill"></i>
                <div class="pond-text">
                    Drop files here or <span class="filepond--label-action">click to upload</span>.
                </div>
                </div>
            `,
            labelFileTypeNotAllowed: "Ky fajll s'pranohet",
            fileValidateTypeLabelExpectedTypes: cfg.expectedLabel,
            credits: false
        });

        pond.on("updatefiles", (fileItems) => {
            try {
                const dt = new DataTransfer();
                fileItems.forEach((fi) => {
                    if (fi && fi.file) dt.items.add(fi.file);
                });

                try { shinyInput.value = ""; } catch (e) { }
                shinyInput.files = dt.files;

                shinyInput.dispatchEvent(new Event("change", { bubbles: true }));
            } catch (e) {
                console.warn("Pond -> Shiny updatefiles sync failed:", e);
            }
        });

        proxy._pond = pond;
        proxy._pond_cfg = { mode: cfg.mode, multiple: isMulti, accept: proxy.accept || "" };
        return true;
    }

    function initWithRetry(inputId, tries) {
        tries = tries || 25;
        if (initFilePondInput(inputId)) return;
        if (tries <= 0) return;
        setTimeout(function () { initWithRetry(inputId, tries - 1); }, 120);
    }

    $(document).on("shown.bs.modal", "#datasets-main_modal_sm", function () {
        initWithRetry("datasets-csv_file_modal", 25);
    });

    $(document).on("shown.bs.modal", "#datasets-main_modal_fs, #bg_modal_fs", function () {
        initWithRetry("bg_media_upload", 25);
        setTimeout(function () {
            if ($.fn.dataTable) {
                $($.fn.dataTable.tables(true)).DataTable().columns.adjust();
            }
        }, 150);
    });

    $(document).on("shiny:bound", function () {
        initWithRetry("datasets-csv_file_modal", 10);
    });

    if (window.Shiny) {
        Shiny.addCustomMessageHandler("pond_clear", function (msg) {
            const inputId = msg && msg.inputId;
            if (!inputId) return;

            const proxy = document.getElementById(inputId + "__pond_proxy");
            if (proxy && proxy._pond) {
                try { proxy._pond.removeFiles(); } catch (e) { }
            }

            const shinyInput = document.getElementById(inputId);
            if (shinyInput) {
                try { shinyInput.value = ""; } catch (e) { }
                try { shinyInput.files = new DataTransfer().files; } catch (e) { }
                shinyInput.dispatchEvent(new Event("change", { bubbles: true }));
            }
        });
    }

})();

// ===============================
// 3) Ajax Modals
// ===============================
Shiny.addCustomMessageHandler('toggle_modal', function (msg) {
    const $m = $('#' + msg.id);
    if (!$m.length) return;
    if (msg.action === 'show') $m.modal('show');
    if (msg.action === 'hide') $m.modal('hide');
});

$(document).on("hidden.bs.modal", "#datasets-main_modal_sm", function () {
    const shinyInput = document.getElementById("datasets-csv_file_modal");
    const proxy = document.getElementById("datasets-csv_file_modal__pond_proxy");

    if (proxy && proxy._pond) {
        proxy._pond.removeFiles();
    }

    if (shinyInput) {
        try { shinyInput.value = ""; } catch (e) { }
        try { shinyInput.files = new DataTransfer().files; } catch (e) { }
        shinyInput.dispatchEvent(new Event("change", { bubbles: true }));
    }
});

(function () {

    function highlightSwatch(hex) {
        const grid = document.getElementById("bg_color_grid");
        if (!grid) return;

        grid.querySelectorAll(".bg-color-swatch").forEach((b) => {
            const c = (b.getAttribute("data-color") || "").toLowerCase();
            b.classList.toggle("is-selected", c === hex.toLowerCase());
        });
    }

    function updateHexText(hex) {
        const txt = document.getElementById("bg_color_hex_txt");
        if (txt) txt.textContent = (hex || "").toUpperCase();
    }

    function pushToShiny(hex) {
        if (window.Shiny && typeof Shiny.setInputValue === "function") {
            Shiny.setInputValue("bg_color", hex, { priority: "event" });
        }
    }

    function applyFromSwatch(hex) {
        const input = document.getElementById("bg_color");
        if (input) input.value = hex;
        highlightSwatch(hex);
        updateHexText(hex);
        pushToShiny(hex);
    }

    function applyFromPicker(hex) {
        highlightSwatch(hex);
        updateHexText(hex);
        pushToShiny(hex);
    }

    document.addEventListener("click", function (e) {
        const btn = e.target.closest(".bg-color-swatch");
        if (!btn) return;
        const hex = btn.getAttribute("data-color");
        if (hex) applyFromSwatch(hex);
    });

    document.addEventListener("input", function (e) {
        if (e.target && e.target.id === "bg_color") {
            applyFromPicker(e.target.value);
        }
    }, true);

    function syncOnce() {
        const input = document.getElementById("bg_color");
        if (!input) return;
        applyFromPicker(input.value || "#0b1c24");
    }

    document.addEventListener("DOMContentLoaded", syncOnce);

    document.addEventListener("shiny:value", function () {
        setTimeout(syncOnce, 50);
    });

    Shiny.addCustomMessageHandler("dt_adjust", function (id) {
        setTimeout(function () {
            var $host = $("#" + id);
            if (!$host.length) return;

            var $tbl = $host.is("table") ? $host : $host.find("table").first();
            if (!$tbl.length) $tbl = $host;

            if ($.fn.dataTable && $.fn.dataTable.isDataTable($tbl)) {
                $tbl.DataTable().columns.adjust().draw(false);
            }
        }, 180);
    });


})();
