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
// 2) FilePond init për input-in e modalit
// ===============================
(function () {
    function initFilePondForInputWrapper(wrapperId) {
        var wrapper = document.getElementById(wrapperId);
        if (!wrapper) return;

        var input = wrapper.querySelector('input[type="file"]');
        if (!input) return;

        // mos e inicializo 2 herë
        if (input._pond) return;

        // register plugins nëse ekzistojnë
        if (window.FilePondPluginFileValidateType) {
            FilePond.registerPlugin(FilePondPluginFileValidateType);
        }
        if (window.FilePondPluginFileValidateSize) {
            FilePond.registerPlugin(FilePondPluginFileValidateSize);
        }

        var pond = FilePond.create(input, {
            allowMultiple: false,
            acceptedFileTypes: ['text/csv', 'application/vnd.ms-excel'],
            allowFileTypeValidation: true,

            maxFileSize: '25MB',
            allowFileSizeValidation: true,

            labelIdle:
                'Drag & Drop CSV ose <span class="filepond--label-action">Browse</span>'
        });

        input._pond = pond;
    }

    // Bootstrap modal: sapo hapet → init
    $(document).on('shown.bs.modal', function () {
        initFilePondForInputWrapper('csv_file_modal');
    });

    // Shiny mund të re-renderojë UI
    $(document).on('shiny:value', function () {
        initFilePondForInputWrapper('csv_file_modal');
    });

    // optional
    window.__initFilePond = initFilePondForInputWrapper;
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

