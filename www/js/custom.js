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
    let lastInlineMsg = null;

    function getHost(inputId) {
        return (
            document.getElementById(inputId + "_pond_host") ||
            document.getElementById("csv_file_modal_pond_host")
        );
    }

    function getCurrentItemEl(host) {
        if (!host) return null;
        return host.querySelector(".filepond--item");
    }

    function ensureInlineBox(itemEl) {
        if (!itemEl) return null;

        const fileRoot = itemEl.querySelector(".filepond--file") || itemEl;
        const info = itemEl.querySelector(".filepond--file-info");

        let box = itemEl.querySelector(".pond-inline-preview");
        if (!box) {
            box = document.createElement("div");
            box.className = "pond-inline-preview";

            if (info && info.parentElement) {
                info.parentElement.insertAdjacentElement("afterend", box); // ✅ poshtë info-s
            } else {
                fileRoot.appendChild(box);
            }
        }
        return box;
    }

    function openInline(itemEl) {
        if (!itemEl) return;
        itemEl.classList.add("pond-inline-open");
    }

    function closeInline(itemEl) {
        if (!itemEl) return;
        itemEl.classList.remove("pond-inline-open");
    }

    function setInlineLoading(host) {
        const itemEl = getCurrentItemEl(host);
        if (!itemEl) return;
        const box = ensureInlineBox(itemEl);
        if (!box) return;

        box.innerHTML = "<div class='pond-inline-loading'>Po përgatis preview…</div>";
        openInline(itemEl);
    }

    function clearInline(host) {
        const itemEl = getCurrentItemEl(host);
        if (!itemEl) return;

        const box = itemEl.querySelector(".pond-inline-preview");
        if (box) box.remove();
        closeInline(itemEl);
    }

    function applyInlineFromMsg(msg) {
        const inputId = (msg && msg.inputId) ? msg.inputId : "csv_file_modal";
        const host = getHost(inputId);
        if (!host) return;

        const itemEl = getCurrentItemEl(host);
        if (!itemEl) {
            // s’ka item akoma, e ruajmë dhe e aplikojmë kur të shtohet file
            lastInlineMsg = msg;
            return;
        }

        const box = ensureInlineBox(itemEl);
        if (!box) return;

        const html = (msg && msg.html) ? msg.html : "";
        box.innerHTML = html;

        if (html && html.trim().length > 0) openInline(itemEl);
        else closeInline(itemEl);
    }

    // =========================
    // FilePond init
    // =========================
    function initFilePondInput(inputId) {
        const shinyInput = document.getElementById(inputId);
        if (!shinyInput) return false;

        if (shinyInput.tagName.toLowerCase() !== "input" || shinyInput.type !== "file") return false;
        if (!window.FilePond) return false;

        const host = getHost(inputId);
        if (!host) return false;

        const wrapper = shinyInput.closest(".shiny-input-container") || shinyInput.closest(".form-group");
        if (wrapper) wrapper.classList.add("shiny-fileinput-hidden");

        const proxyId = inputId + "__pond_proxy";
        let proxy = document.getElementById(proxyId);

        if (!proxy) {
            host.innerHTML = "";
            proxy = document.createElement("input");
            proxy.type = "file";
            proxy.id = proxyId;
            proxy.accept = shinyInput.getAttribute("accept") || ".csv";
            host.appendChild(proxy);
        }

        if (proxy._pond) return true;

        if (window.FilePondPluginFileValidateType) FilePond.registerPlugin(FilePondPluginFileValidateType);
        if (window.FilePondPluginFileValidateSize) FilePond.registerPlugin(FilePondPluginFileValidateSize);

        const pond = FilePond.create(proxy, {
            allowMultiple: false,
            allowReplace: true,
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

            acceptedFileTypes: ["text/csv"],
            allowFileTypeValidation: true,

            fileValidateTypeDetectType: (source, type) =>
                new Promise((resolve) => {
                    const name = (source && source.name) ? String(source.name).toLowerCase() : "";
                    const ext = name.includes(".") ? name.split(".").pop() : "";

                    console.log("POND FILE:", name, "EXT:", ext, "MIME:", type);

                    if (ext === "csv") return resolve("text/csv");
                    return resolve(type || "application/octet-stream");
                }),

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
            fileValidateTypeLabelExpectedTypes: "Lejohet vetëm: .csv",
            credits: false
        });

        pond.on("addfile", (err, item) => {
            console.log("POND addfile err:", err);
            if (err) return;

            // sapo shtohet file -> hap inline box me loading (animacion)
            setInlineLoading(host);

            try {
                try { shinyInput.value = ""; } catch (e) { }

                const dt = new DataTransfer();
                dt.items.add(item.file);
                shinyInput.files = dt.files;

                console.log("SHINY input.files:", shinyInput.files?.length);

                shinyInput.dispatchEvent(new Event("change", { bubbles: true }));
            } catch (e) {
                console.warn("Proxy -> Shiny DataTransfer failed:", e);
            }

            // nëse serveri na ka dërgu msg më herët, aplikoje tani
            if (lastInlineMsg) {
                applyInlineFromMsg(lastInlineMsg);
                lastInlineMsg = null;
            }
        });

        pond.on("removefile", () => {
            clearInline(host);

            try { shinyInput.value = ""; } catch (e) { }
            shinyInput.dispatchEvent(new Event("change", { bubbles: true }));
        });

        proxy._pond = pond;
        return true;
    }

    function initWithRetry(inputId, tries) {
        tries = tries || 25;
        if (initFilePondInput(inputId)) return;
        if (tries <= 0) return;
        setTimeout(function () { initWithRetry(inputId, tries - 1); }, 120);
    }

    // =========================
    // Shiny custom message: inline preview
    // =========================
    if (window.Shiny && Shiny.addCustomMessageHandler) {
        Shiny.addCustomMessageHandler("csv_inline_preview", function (msg) {
            applyInlineFromMsg(msg);
        });
    }

    // =========================
    // Modal hooks
    // =========================
    $(document).on("shown.bs.modal", "#main_modal_sm", function () {
        initWithRetry("csv_file_modal", 25);
    });

    $(document).on("hidden.bs.modal", "#main_modal_sm", function () {
        // pastro preview kur mbyllet modali
        const host = getHost("csv_file_modal");
        if (host) clearInline(host);
        lastInlineMsg = null;
    });

    $(document).on('shown.bs.modal', '#main_modal_fs', function () {
        setTimeout(function () {
            if ($.fn.dataTable) {
                $($.fn.dataTable.tables(true)).DataTable().columns.adjust();
            }
        }, 150);
    });

    $(document).on("shiny:bound", function () {
        initWithRetry("csv_file_modal", 10);
    });

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

$(document).on('click', '.ajax-modal-sm, .ajax-modal-fs', function (e) {
    e.preventDefault();
    const $btn = $(this);

    const modal = $btn.hasClass('ajax-modal-fs') ? 'fs' : 'sm';
    const type = $btn.data('modal') || 'upload';
    const title = $btn.data('title') || '';

    Shiny.setInputValue('ajax_modal_open', {
        modal: modal,
        type: type,
        title: title,
        nonce: Date.now()
    }, { priority: 'event' });
});

$(document).on("hidden.bs.modal", "#main_modal_sm", function () {
    const shinyInput = document.getElementById("csv_file_modal");
    const proxy = document.getElementById("csv_file_modal__pond_proxy");

    if (proxy && proxy._pond) {
        proxy._pond.removeFiles();
    }

    if (shinyInput) {
        try { shinyInput.value = ""; } catch (e) { }
        try { shinyInput.files = new DataTransfer().files; } catch (e) { }
        shinyInput.dispatchEvent(new Event("change", { bubbles: true }));
    }
});
