// ===============================
// Modalet glass dhe DataTables (Faza 7)
// ===============================
// Modalet hapen e mbyllen vetëm me mesazhin "toggle_modal" (toggle_glass_modal() në R, P-08).
Shiny.addCustomMessageHandler('toggle_modal', function (msg) {
    const $m = $('#' + msg.id);
    if (!$m.length) return;
    if (msg.action === 'show') $m.modal('show');
    if (msg.action === 'hide') $m.modal('hide');
});

// Kur mbyllet modali i Upload-it, zbrazet FilePond-i dhe input-i i CSV-së.
$(document).on("hidden.bs.modal", "#datasets-main_modal_sm", function () {
    if (window.PondBridge) window.PondBridge.clear("datasets-csv_file_modal");
});

// DataTables brenda modaleve: kolonat rillogariten pasi modali shfaqet.
$(document).on("shown.bs.modal", "#datasets-main_modal_fs, #bg-modal_fs", function () {
    setTimeout(function () {
        if ($.fn.dataTable) {
            $($.fn.dataTable.tables(true)).DataTable().columns.adjust();
        }
    }, 150);
});

// Rillogaritja e kolonave të një DataTable sipas kërkesës së serverit (Përmbledhja).
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
