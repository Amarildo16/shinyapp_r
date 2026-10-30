// ===============================
// FilePond ↔ Shiny (Faza 7, V-29, V-33)
// ===============================
// Fotot e Galerisë dhe CSV-ja kalojnë nga e njëjta rrugë: FilePond-i i dërgon skedarët drejt
// e te serveri, secili me progresin, ndalimin dhe heqjen e vet. Host-i ka data-process-url
// (session$registerDataObj): POST me X-Pond-Op "process" (trupi = skedari, përgjigjja = id)
// ose "revert" (trupi = id). Ruajtja përfundimtare bëhet nga serveri.
(function () {
    // Tekstet sipas gjuhës (R26, V-23 b): vijnë nga R te window.APP_I18N.
    const T = Object.assign({
        "pond.drop": "Drop files here or",
        "pond.browse": "click to upload",
        "pond.type_not_allowed": "Ky fajll s'pranohet",
        "pond.only_csv": "Lejohet vetëm: .csv",
        "pond.only_images": "Lejohen vetëm: JPG, PNG, WEBP",
        "pond.too_large": "Skedari është shumë i madh",
        "pond.max_size": "Maksimumi: {filesize}"
    }, window.APP_I18N || {});

    // Tipi sipas prapashtesës: Windows-i shpesh nuk jep tip për CSV-të (B-25).
    const typeByExtension = (map) => (source, type) =>
        new Promise((resolve) => {
            const name = (source && source.name) ? String(source.name).toLowerCase() : "";
            const ext = name.includes(".") ? name.split(".").pop() : "";
            resolve(map[ext] || type || "application/octet-stream");
        });

    const MODES = {
        image: (maxMB) => ({
            accept: "image/jpeg,image/png,image/webp",
            options: {
                allowMultiple: true,
                maxFiles: 50,
                maxParallelUploads: 3,
                allowImagePreview: true,      // V-30: fotoja shihet para "Ruaj fotot"
                imagePreviewHeight: 170,
                acceptedFileTypes: ["image/jpeg", "image/png", "image/webp"],
                fileValidateTypeDetectType: typeByExtension({ png: "image/png", jpg: "image/jpeg", jpeg: "image/jpeg", webp: "image/webp" }),
                fileValidateTypeLabelExpectedTypes: T["pond.only_images"],
                labelIdle: `
                    <div class="pond-idle pond-idle--photos">
                        <i class="ri-image-add-line" aria-hidden="true"></i>
                        <div class="pond-title">${T["pond.img_title"]}</div>
                        <div class="pond-sub"><span class="filepond--label-action">${T["pond.img_browse"]}</span></div>
                        <div class="pond-hint">${String(T["pond.img_hint"]).replace("{mb}", maxMB)}</div>
                    </div>
                `
            }
        }),
        // B-25: FilePond-i e lexon `accept` të input-it: me vetëm ".csv", tipi "text/csv" nuk
        // përputhej kurrë dhe çdo CSV dilte "Ky fajll s'pranohet".
        csv: (maxMB) => ({
            accept: ".csv,text/csv",
            options: {
                allowMultiple: false,
                allowReplace: true,
                allowImagePreview: false,
                fileSizeBase: 1024,           // si madhësia te pamja e vogël dhe kufiri i serverit
                maxFileSize: maxMB * 1024 * 1024,
                acceptedFileTypes: ["text/csv"],
                fileValidateTypeDetectType: typeByExtension({ csv: "text/csv" }),
                fileValidateTypeLabelExpectedTypes: T["pond.only_csv"],
                labelIdle: `
                    <div class="pond-idle pond-idle--csv">
                        <img src="icons/excel.svg" alt="" aria-hidden="true">
                        <div class="pond-text">
                            ${T["pond.drop"]} <span class="filepond--label-action">${T["pond.browse"]}</span>.
                        </div>
                    </div>
                `
            }
        })
    };

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
        const modeName = host.getAttribute("data-pond-mode") || "image";
        const mode = MODES[modeName](maxMB);
        const input = document.createElement("input");
        input.type = "file";
        input.multiple = !!mode.options.allowMultiple;
        input.accept = mode.accept;
        host.innerHTML = "";
        host.appendChild(input);

        if (window.FilePondPluginFileValidateType) FilePond.registerPlugin(FilePondPluginFileValidateType);
        if (window.FilePondPluginFileValidateSize) FilePond.registerPlugin(FilePondPluginFileValidateSize);
        if (window.FilePondPluginImagePreview) FilePond.registerPlugin(FilePondPluginImagePreview);

        const pond = FilePond.create(input, Object.assign({
            instantUpload: true,
            allowRevert: true,
            styleButtonRemoveItemPosition: "right",   // V-32: kur dështon, X-i në qoshe
            server: { process: serverProcess(url), revert: serverRevert(url), load: null, fetch: null, restore: null },

            labelFileTypeNotAllowed: T["pond.type_not_allowed"],
            maxFileSize: maxMB + "MB",
            labelMaxFileSizeExceeded: T["pond.too_large"],
            labelMaxFileSize: T["pond.max_size"],

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
        }, mode.options));
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

        // V-33: CSV-ja s'ka foto: gjatë ngarkimit kartela ka lartësinë e zonës, që të nxërë
        // unazën; një skedar i refuzuar mbetet rresht i ngushtë.
        if (modeName === "csv") {
            const tallCard = (on) => pond.setOptions({ styleItemPanelAspectRatio: String((on ? 170 : 56) / host.clientWidth) });
            pond.on("addfile", (err) => tallCard(!err));
            pond.on("processfile", (err) => tallCard(!!err));
        }

        // Serveri mëson këtu kur skedari ka mbërritur.
        const uploadedInput = host.getAttribute("data-uploaded-input");
        if (uploadedInput) pond.on("processfile", (err, item) => {
            if (!err) Shiny.setInputValue(uploadedInput, item.serverId, { priority: "event" });
        });
        serverPonds.set(hostId, pond);
        return true;
    }

    function initServerPondWithRetry(hostId, tries) {
        if (initServerPond(hostId) || tries <= 0) return;
        setTimeout(() => initServerPondWithRetry(hostId, tries - 1), 120);
    }

    $(document).on("shown.bs.modal", "#datasets-main_modal_sm", function () {
        initServerPondWithRetry("datasets-csv_pond_host", 25);
    });
    $(document).on("shown.bs.modal", "#bg-modal_fs", function () {
        initServerPondWithRetry("bg-media_pond_host", 25);
    });
    $(document).on("shown.bs.tab", "#bg-modal_fs a[data-toggle='tab']", function () {
        initServerPondWithRetry("bg-media_pond_host", 10);
    });

    // "Ruaj" / "Anulo": serveri e ka zbrazur pritjen, ndaj lista hiqet pa revert.
    if (window.Shiny) {
        Shiny.addCustomMessageHandler("pond_server_clear", function (msg) {
            const pond = msg && serverPonds.get(msg.hostId);
            if (!pond) return;
            const host = document.getElementById(msg.hostId);
            if (!host || host.getAttribute("data-pond-mode") !== "csv") {
                try { pond.removeFiles({ revert: false }); } catch (e) { }
                return;
            }
            // V-34: zona e CSV-së fshihet pas ngarkimit, dhe një skedar i hequr kur zona nuk duket
            // lë një rresht të padukshëm që bllokon radhën e ngarkimeve: krijohet nga e para.
            // destroy() ndërpret edhe një ngarkim në mes, por mbaron me vonesë: zona e re krijohet
            // pasi e vjetra të ketë dalë nga faqja.
            const recreate = () => {
                if (document.body.contains(pond.element)) return setTimeout(recreate, 30);
                serverPonds.delete(msg.hostId);
                host.classList.remove("has-files");
                if ($(host).is(":visible")) initServerPond(msg.hostId);
            };
            pond.destroy();
            recreate();
        });
    }
})();
