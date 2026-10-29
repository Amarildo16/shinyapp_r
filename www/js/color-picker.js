// ===============================
// Ngjyra e background-it (Faza 7)
// ===============================
// Paleta (#bg-color_grid) dhe zgjedhësi (#bg-color) sinkronizohen dhe i dërgojnë
// ngjyrën Shiny-t si input$color i mod_background.
(function () {

    function highlightSwatch(hex) {
        const grid = document.getElementById("bg-color_grid");
        if (!grid) return;

        grid.querySelectorAll(".bg-color-swatch").forEach((b) => {
            const c = (b.getAttribute("data-color") || "").toLowerCase();
            b.classList.toggle("is-selected", c === hex.toLowerCase());
        });
    }

    function updateHexText(hex) {
        const txt = document.getElementById("bg-color_hex_txt");
        if (txt) txt.textContent = (hex || "").toUpperCase();
    }

    function pushToShiny(hex) {
        if (window.Shiny && typeof Shiny.setInputValue === "function") {
            Shiny.setInputValue("bg-color", hex, { priority: "event" });
        }
    }

    function applyFromSwatch(hex) {
        const input = document.getElementById("bg-color");
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
        if (e.target && e.target.id === "bg-color") {
            applyFromPicker(e.target.value);
        }
    }, true);

    function syncOnce() {
        const input = document.getElementById("bg-color");
        if (!input) return;
        applyFromPicker(input.value || "#0b1c24");
    }

    document.addEventListener("DOMContentLoaded", syncOnce);

    document.addEventListener("shiny:value", function () {
        setTimeout(syncOnce, 50);
    });

})();
