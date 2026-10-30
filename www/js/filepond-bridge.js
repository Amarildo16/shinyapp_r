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
        "pond.only_images": "Lejohen vetëm: JPG, PNG, WEBP",
        "pond.too_large": "Skedari është shumë i madh",
        "pond.max_size": "Maksimumi: {filesize}",
        "pond.upload_failed": "Ngarkimi dështoi"
    }, window.APP_I18N || {});

    // Kufiri i CSV-së vjen nga R (UPLOAD_MAX_MB, V-28 a); fotot mbeten 25 MB si më parë.
    const CSV_MAX_MB = (window.APP_CONFIG && window.APP_CONFIG.uploadMaxMB) || 150;

    function getHost(inputId) {
        return document.getElementById(inputId + "_pond_host");
    }

    function detectConfig(shinyInput, inputId) {
        const accept = (shinyInput.getAttribute("accept") || "").toLowerCase();

        if (inputId === "datasets-csv_file_modal" || accept.includes("csv") || accept.includes(".csv")) {
            return {
                mode: "csv",
                acceptedFileTypes: ["text/csv"],
                maxFileSize: CSV_MAX_MB + "MB",
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
                maxFileSize: "25MB",
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
            maxFileSize: "25MB",
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
        // B-25: FilePond-i e lexon `accept` të proxy-t në vend të acceptedFileTypes. Me vetëm
        // ".csv", tipi "text/csv" nuk përputhej kurrë dhe çdo CSV dilte "Ky fajll s'pranohet".
        proxy.accept = Array.from(new Set(accept.split(",").map((s) => s.trim())
            .concat(cfg.acceptedFileTypes).filter(Boolean))).join(",");
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

            maxFileSize: cfg.maxFileSize,
            allowFileSizeValidation: true,
            labelMaxFileSizeExceeded: T["pond.too_large"],
            labelMaxFileSize: T["pond.max_size"],

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

        // B-25: Shiny-t i kalojnë vetëm skedarët që kaluan kontrollet e tipit dhe madhësisë.
        // Sinkronizimi pret derisa të gjithë skedarët e shtuar të jenë kontrolluar.
        let syncTimer = null;
        const S = FilePond.FileStatus;
        const sync = () => {
            clearTimeout(syncTimer);
            syncTimer = setTimeout(() => {
                const items = pond.getFiles();
                if (items.some((fi) => fi.status === S.INIT || fi.status === S.LOADING)) return;
                try {
                    const dt = new DataTransfer();
                    items.forEach((fi) => {
                        if (fi.status !== S.LOAD_ERROR && fi.file instanceof File) dt.items.add(fi.file);
                    });

                    try { shinyInput.value = ""; } catch (e) { }
                    shinyInput.files = dt.files;

                    shinyInput.dispatchEvent(new Event("change", { bubbles: true }));
                } catch (e) {
                    console.warn("Pond -> Shiny sync failed:", e);
                }
            }, 30);
        };
        pond.on("addfile", sync);
        pond.on("removefile", sync);

        watchUploadError(inputId);
        ponds.set(inputId, { pond, cfg: { mode: cfg.mode, multiple: isMulti, accept } });
        return true;
    }

    // B-26: Shiny e shkruan gabimin e ngarkimit vetëm te shiriti i fshehur i fileInput-it
    // (klasa progress-bar-danger); këtu ai del si njoftim.
    function watchUploadError(inputId) {
        const bar = document.querySelector("#" + inputId + "_progress .progress-bar");
        if (!bar || bar._pondWatch) return;
        bar._pondWatch = true;
        new MutationObserver(() => {
            if (!bar.classList.contains("progress-bar-danger")) return;
            const msg = (bar.textContent || "").trim();
            if (!msg || bar._pondLastError === msg) return;
            bar._pondLastError = msg;
            setTimeout(() => { bar._pondLastError = null; }, 1000);
            const text = /maximum upload size/i.test(msg) ? T["pond.too_large"] : T["pond.upload_failed"] + ": " + msg;
            if (window.Shiny && Shiny.notifications) Shiny.notifications.show({ html: $("<span>").text(text).html(), type: "error", duration: 8000 });
        }).observe(bar, { attributes: true, attributeFilter: ["class"], childList: true, characterData: true, subtree: true });
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

    // ---- Fotot e Galerisë: FilePond-i i dërgon drejt e te serveri (V-29) ----------
    // Host-i ka data-process-url (session$registerDataObj): POST me X-Pond-Op "process"
    // (trupi = fotoja, përgjigjja = id) ose "revert" (trupi = id). Çdo foto ka progresin,
    // ndalimin dhe heqjen e vet; ruajtja te Galeria bëhet nga serveri me "Ruaj fotot".
    const serverPonds = new Map();   // hostId -> pond

    function serverProcess(url) {
        return (fieldName, file, metadata, load, error, progress, abort) => {
            const xhr = new XMLHttpRequest();
            xhr.open("POST", url);
            xhr.setRequestHeader("X-Pond-Op", "process");
            xhr.setRequestHeader("X-File-Name", encodeURIComponent(file.name));
            xhr.setRequestHeader("X-File-Type", file.type || "");
            xhr.upload.onprogress = (e) => progress(e.lengthComputable, e.loaded, e.total);
            xhr.onload = () => (xhr.status === 200 && xhr.getResponseHeader("X-Pond-Status") !== "error"
                ? load(xhr.responseText)
                : error(xhr.responseText || T["pond.error"]));
            xhr.onerror = () => error(T["pond.error"]);
            xhr.send(file);
            return { abort: () => { xhr.abort(); abort(); } };
        };
    }

    function serverRevert(url) {
        return (id, load, error) => {
            fetch(url, { method: "POST", headers: { "X-Pond-Op": "revert" }, body: id })
                .then((r) => (r.ok ? load() : error("")))
                .catch(() => error(""));
        };
    }

    function initServerPond(hostId) {
        const host = document.getElementById(hostId);
        if (!host || !window.FilePond) return false;
        const old = serverPonds.get(hostId);
        if (old && document.body.contains(old.element)) return true;
        if (old) { try { old.destroy(); } catch (e) { } serverPonds.delete(hostId); }

        const url = host.getAttribute("data-process-url");
        if (!url) return false;
        const maxMB = host.getAttribute("data-max-mb") || "5";
        const input = document.createElement("input");
        input.type = "file";
        input.multiple = true;
        input.accept = "image/jpeg,image/png,image/webp";
        host.innerHTML = "";
        host.appendChild(input);

        if (window.FilePondPluginFileValidateType) FilePond.registerPlugin(FilePondPluginFileValidateType);
        if (window.FilePondPluginFileValidateSize) FilePond.registerPlugin(FilePondPluginFileValidateSize);
        if (window.FilePondPluginImagePreview) FilePond.registerPlugin(FilePondPluginImagePreview);

        const cfg = detectConfig({ getAttribute: () => "image" }, "bg-images");
        const pond = FilePond.create(input, {
            allowMultiple: true,
            maxFiles: 50,
            maxParallelUploads: 3,
            instantUpload: true,
            allowRevert: true,
            styleButtonRemoveItemPosition: "right",   // V-32: kur dështon, X-i në qoshe
            allowImagePreview: true,      // V-30: fotoja shihet para "Ruaj fotot"
            imagePreviewHeight: 170,
            server: { process: serverProcess(url), revert: serverRevert(url), load: null, fetch: null, restore: null },

            acceptedFileTypes: cfg.acceptedFileTypes,
            fileValidateTypeDetectType: cfg.detectMime,
            labelFileTypeNotAllowed: T["pond.type_not_allowed"],
            fileValidateTypeLabelExpectedTypes: cfg.expectedLabel,
            maxFileSize: maxMB + "MB",
            labelMaxFileSizeExceeded: T["pond.too_large"],
            labelMaxFileSize: T["pond.max_size"],

            labelIdle: `
                <div class="pond-idle pond-idle--photos">
                    <i class="ri-image-add-line" aria-hidden="true"></i>
                    <div class="pond-title">${T["pond.img_title"]}</div>
                    <div class="pond-sub"><span class="filepond--label-action">${T["pond.img_browse"]}</span></div>
                    <div class="pond-hint">${String(T["pond.img_hint"]).replace("{mb}", maxMB)}</div>
                </div>
            `,
            labelFileLoading: T["pond.loading"],
            labelFileProcessing: T["pond.processing"],
            labelFileProcessingComplete: T["pond.complete"],
            labelFileProcessingAborted: T["pond.aborted"],
            labelFileProcessingError: (err) => (err && err.body) || T["pond.error"],
            labelTapToCancel: T["pond.tap_cancel"],
            labelTapToRetry: T["pond.tap_retry"],
            labelTapToUndo: T["pond.tap_undo"],
            labelButtonRemoveItem: T["pond.btn_remove"],
            labelButtonAbortItemProcessing: T["pond.btn_abort"],
            labelButtonUndoItemProcessing: T["pond.btn_undo"],
            labelButtonRetryItemProcessing: T["pond.btn_retry"],
            credits: false
        });
        // Kur ka foto, zona e lëshimit zvogëlohet dhe lista shfaqet si rrjetë (CSS: .has-files).
        pond.on("updatefiles", (items) => host.classList.toggle("has-files", items.length > 0));

        // V-32: gjatë ngarkimit, një unazë me X në mes të fotos dhe përqindja poshtë saj. X-i
        // ndal ngarkimin dhe e heq foton nga lista; unaza ikën kur ngarkimi mbaron ose dështon.
        const itemEl = (item) => host.querySelector(`.filepond--item[id$="-${item.id}"]`);
        const progressText = (pct) => `${T["pond.processing"]}… ${pct}%`;
        const setProgress = (el, value) => {
            const pct = Math.round((value || 0) * 100);
            el.style.setProperty("--p", pct);
            el.querySelector(".pond-progress-label").textContent = progressText(pct);
        };
        const addOverlay = (item) => {
            const el = itemEl(item);
            if (!el || el.querySelector(".pond-overlay")) return;
            const overlay = document.createElement("div");
            overlay.className = "pond-overlay";
            const ring = document.createElement("button");
            ring.type = "button";
            ring.className = "pond-ring";
            ring.setAttribute("aria-label", T["pond.btn_abort"]);
            ring.innerHTML = '<svg class="pond-ring-x" viewBox="0 0 24 24" aria-hidden="true"><path d="M7 7l10 10M17 7L7 17"/></svg>';
            ring.addEventListener("click", (e) => {
                e.stopPropagation();
                if (item.status === FilePond.FileStatus.PROCESSING) item.abortProcessing();
                else pond.removeFile(item.id);
            });
            const label = document.createElement("div");
            label.className = "pond-progress-label";
            overlay.append(ring, label);
            el.appendChild(overlay);
            setProgress(overlay, 0);
        };
        const dropOverlay = (item) => {
            const overlay = item && itemEl(item) && itemEl(item).querySelector(".pond-overlay");
            if (overlay) overlay.remove();
        };
        pond.on("addfile", (err, item) => { if (!err) addOverlay(item); });
        pond.on("processfilestart", addOverlay);    // edhe pas riprovimit
        pond.on("processfileprogress", (item, value) => {
            const overlay = itemEl(item) && itemEl(item).querySelector(".pond-overlay");
            if (overlay) setProgress(overlay, value);
        });
        pond.on("processfile", (err, item) => dropOverlay(item));
        pond.on("processfileabort", (item) => { dropOverlay(item); pond.removeFile(item.id); });
        serverPonds.set(hostId, pond);
        return true;
    }

    function initServerPondWithRetry(hostId, tries) {
        if (initServerPond(hostId) || tries <= 0) return;
        setTimeout(() => initServerPondWithRetry(hostId, tries - 1), 120);
    }

    $(document).on("shown.bs.modal", "#bg-modal_fs", function () {
        initServerPondWithRetry("bg-media_pond_host", 25);
    });
    $(document).on("shown.bs.tab", "#bg-modal_fs a[data-toggle='tab']", function () {
        initServerPondWithRetry("bg-media_pond_host", 10);
    });

    // "Ruaj fotot" / "Anulo": serveri e ka zbrazur pritjen, ndaj lista hiqet pa revert.
    if (window.Shiny) {
        Shiny.addCustomMessageHandler("pond_server_clear", function (msg) {
            const pond = msg && serverPonds.get(msg.hostId);
            if (pond) { try { pond.removeFiles({ revert: false }); } catch (e) { } }
        });
    }

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
