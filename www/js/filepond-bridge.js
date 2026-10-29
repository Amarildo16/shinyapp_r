// ===============================
// FilePond ↔ Shiny (Faza 7)
// ===============================
// Çdo fileInput i Shiny-t merr një FilePond te "<inputId>_pond_host"; skedarët e zgjedhur
// kalojnë te input-i i fshehur i Shiny-t (updatefiles → change).
// B-16 / B-21: instancat mbahen te `ponds` sipas inputId. Më parë kërkoheshin me
// getElementById(proxy)._pond, por FilePond ia kalon ID-në e proxy-t div-it të vet:
// instanca nuk gjendej, ndaj `shiny:bound` krijonte një FilePond të dytë mbi div-in
// (404 "/[object Object]" + "updatefiles sync failed") dhe `pond_clear` nuk pastronte listën.
(function () {
    const ponds = new Map();   // inputId -> { pond, cfg }

    // Tekstet sipas gjuhës (R26, V-23 b): vijnë nga R te window.APP_I18N.
    const T = Object.assign({
        "pond.drop": "Drop files here or",
        "pond.browse": "click to upload",
        "pond.type_not_allowed": "Ky fajll s'pranohet",
        "pond.only_csv": "Lejohet vetëm: .csv",
        "pond.only_images": "Lejohen vetëm: JPG, PNG, WEBP"
    }, window.APP_I18N || {});

    function getHost(inputId) {
        return document.getElementById(inputId + "_pond_host");
    }

    function detectConfig(shinyInput, inputId) {
        const accept = (shinyInput.getAttribute("accept") || "").toLowerCase();

        if (inputId === "datasets-csv_file_modal" || accept.includes("csv") || accept.includes(".csv")) {
            return {
                mode: "csv",
                acceptedFileTypes: ["text/csv"],
                expectedLabel: T["pond.only_csv"],
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
            inputId === "bg-media_upload" ||
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
                expectedLabel: T["pond.only_images"],
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

    // Instanca e gjallë për input-in: e regjistruar dhe ende në faqe (renderUI mund ta rikrijojë host-in).
    function livePond(inputId) {
        const entry = ponds.get(inputId);
        if (!entry) return null;
        if (entry.pond.element && document.body.contains(entry.pond.element)) return entry;
        try { entry.pond.destroy(); } catch (e) { }
        ponds.delete(inputId);
        return null;
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
        const isMulti = !!shinyInput.multiple;
        const accept = shinyInput.getAttribute("accept") || "";

        const entry = livePond(inputId);
        if (entry) {
            const old = entry.cfg;
            if (old.mode === cfg.mode && old.multiple === isMulti && old.accept === accept) return true;
            try { entry.pond.destroy(); } catch (e) { }
            ponds.delete(inputId);
        }

        host.innerHTML = "";
        const proxy = document.createElement("input");
        proxy.type = "file";
        proxy.id = inputId + "__pond_proxy";
        proxy.accept = accept;
        if (isMulti) proxy.multiple = true;
        host.appendChild(proxy);

        if (window.FilePondPluginFileValidateType) FilePond.registerPlugin(FilePondPluginFileValidateType);
        if (window.FilePondPluginFileValidateSize) FilePond.registerPlugin(FilePondPluginFileValidateSize);

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
                    ${T["pond.drop"]} <span class="filepond--label-action">${T["pond.browse"]}</span>.
                </div>
                </div>
            `,
            labelFileTypeNotAllowed: T["pond.type_not_allowed"],
            fileValidateTypeLabelExpectedTypes: cfg.expectedLabel,
            credits: false
        });

        pond.on("updatefiles", (fileItems) => {
            try {
                const dt = new DataTransfer();
                fileItems.forEach((fi) => {
                    if (fi && fi.file instanceof File) dt.items.add(fi.file);
                });

                try { shinyInput.value = ""; } catch (e) { }
                shinyInput.files = dt.files;

                shinyInput.dispatchEvent(new Event("change", { bubbles: true }));
            } catch (e) {
                console.warn("Pond -> Shiny updatefiles sync failed:", e);
            }
        });

        ponds.set(inputId, { pond, cfg: { mode: cfg.mode, multiple: isMulti, accept } });
        return true;
    }

    function initWithRetry(inputId, tries) {
        tries = tries || 25;
        if (initFilePondInput(inputId)) return;
        if (tries <= 0) return;
        setTimeout(function () { initWithRetry(inputId, tries - 1); }, 120);
    }

    // Zbraz listën e FilePond dhe input-in e Shiny-t (B-21).
    function clearPond(inputId) {
        const entry = livePond(inputId);
        if (entry) {
            try { entry.pond.removeFiles(); } catch (e) { }
        }

        const shinyInput = document.getElementById(inputId);
        if (shinyInput) {
            try { shinyInput.value = ""; } catch (e) { }
            try { shinyInput.files = new DataTransfer().files; } catch (e) { }
            shinyInput.dispatchEvent(new Event("change", { bubbles: true }));
        }
    }

    $(document).on("shown.bs.modal", "#datasets-main_modal_sm", function () {
        initWithRetry("datasets-csv_file_modal", 25);
    });

    $(document).on("shown.bs.modal", "#datasets-main_modal_fs, #bg-modal_fs", function () {
        initWithRetry("bg-media_upload", 25);
    });

    $(document).on("shiny:bound", function () {
        initWithRetry("datasets-csv_file_modal", 10);
    });

    if (window.Shiny) {
        Shiny.addCustomMessageHandler("pond_clear", function (msg) {
            const inputId = msg && msg.inputId;
            if (!inputId) return;
            clearPond(inputId);
        });
    }

    window.PondBridge = { clear: clearPond, find: (inputId) => (livePond(inputId) || {}).pond || null };
})();
