// ===============================
// 1) Global Preloader (Shiny busy/idle)
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

    // optional: ekspozo për thirrje manuale
    window.__showLoader = showLoader;
    window.__hideLoader = hideLoader;
})();


// ===============================
// 2) FilePond init (PROXY) për input-in e modalit
//    - FilePond punon mbi një input proxy (UI)
//    - Shiny upload punon mbi input-in real (csv_file_modal)
// ===============================
(function () {

    function getHost(inputId) {
        return (
            document.getElementById(inputId + "_pond_host") ||
            document.getElementById("csv_file_modal_pond_host")
        );
    }

    function initFilePondInput(inputId) {
        const shinyInput = document.getElementById(inputId);
        if (!shinyInput) return false;

        if (shinyInput.tagName.toLowerCase() !== "input" || shinyInput.type !== "file") return false;
        if (!window.FilePond) return false;

        const host = getHost(inputId);
        if (!host) return false;

        // ✅ fshi UI-n e vjetër të Shiny fileInput, por e lë input-in aty (për binding/upload)
        const wrapper = shinyInput.closest(".shiny-input-container") || shinyInput.closest(".form-group");
        if (wrapper) wrapper.classList.add("shiny-fileinput-hidden");

        // ✅ krijo / gjej input proxy ku do lidhet FilePond UI
        const proxyId = inputId + "__pond_proxy";
        let proxy = document.getElementById(proxyId);

        if (!proxy) {
            host.innerHTML = ""; // pastro host-in
            proxy = document.createElement("input");
            proxy.type = "file";
            proxy.id = proxyId;
            proxy.accept = shinyInput.getAttribute("accept") || ".csv";
            host.appendChild(proxy);
        }

        // mos e inicializo 2 herë
        if (proxy._pond) return true;

        // plugins
        if (window.FilePondPluginFileValidateType) FilePond.registerPlugin(FilePondPluginFileValidateType);
        if (window.FilePondPluginFileValidateSize) FilePond.registerPlugin(FilePondPluginFileValidateSize);

        const pond = FilePond.create(proxy, {
            allowMultiple: false,
            allowReplace: true,
            instantUpload: false,
            allowProcess: false,
            server: {
                // mos lejo ASNJË komunikim me server nga FilePond
                process: null,
                revert: null,
                restore: null,
                fetch: null,

                // kjo e ndal "GET /[object Object]" që po sheh ti
                load: (source, load, error, progress, abort) => {
                    console.log("POND server.load BLOCKED:", source);
                    abort();
                }
            },

            // validim
            acceptedFileTypes: [
                "text/csv",
                "application/csv",
                "text/plain",
                "application/vnd.ms-excel",
                "application/octet-stream"
            ],
            allowFileTypeValidation: false,

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

            labelIdle: "Drag & Drop CSV ose <span class=\"filepond--label-action\">Browse</span>",
            labelFileTypeNotAllowed: "Ky fajll s'pranohet",
            fileValidateTypeLabelExpectedTypes: "Lejohet vetëm: .csv",
            credits: false
        });

        // ✅ kur user shton file në FilePond, kopjoje te input-i real i Shiny-t
        pond.on("addfile", (err, item) => {
            console.log("POND addfile err:", err);
            if (err) return;

            try {
                // pastro input-in real
                try { shinyInput.value = ""; } catch (e) { }

                const dt = new DataTransfer();
                dt.items.add(item.file);
                shinyInput.files = dt.files;

                console.log("SHINY input.files:", shinyInput.files?.length);

                shinyInput.dispatchEvent(new Event("change", { bubbles: true }));
            } catch (e) {
                console.warn("Proxy -> Shiny DataTransfer failed:", e);
            }
        });

        pond.on("removefile", () => {
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

    // kur modali hapet
    $(document).on("shown.bs.modal", "#main_modal_sm", function () {
        initWithRetry("csv_file_modal", 25);
    });

    // kur Shiny lidhet me DOM elementet
    $(document).on("shiny:bound", function () {
        initWithRetry("csv_file_modal", 10);
    });

})();

// Server -> JS: show/hide modal
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

    // pastro FilePond UI
    if (proxy && proxy._pond) {
        proxy._pond.removeFiles();
    }

    // pastro input-in e Shiny-t
    if (shinyInput) {
        try { shinyInput.value = ""; } catch (e) { }
        try { shinyInput.files = new DataTransfer().files; } catch (e) { }
        shinyInput.dispatchEvent(new Event("change", { bubbles: true }));
    }
});
