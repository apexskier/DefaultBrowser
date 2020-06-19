import Bowser from "bowser";

// manage date in menu bar
const dateOptions = {
    weekday: "short",
    month: "short",
    day: "numeric",
    hour: "numeric",
    minute: "2-digit",
};
const $date = document.getElementById("menu-bar-date");
window.setInterval(
    (function () {
        function updateDate() {
            $date.textContent = new Date().toLocaleDateString(
                undefined,
                dateOptions
            );
        }
        updateDate();
        return updateDate;
    })(),
    1000
);

// manage browser context
const browser = Bowser.getParser(window.navigator.userAgent);
const $activeAppName = document.getElementById("menu-bar-active-app");
$activeAppName.textContent =
    browser.getBrowserName() || $activeAppName.textContent;

const $appIcon = document.getElementById("menu-bar-app-icon");
const icon = (function () {
    if (browser.is("chrome")) {
        return "Chrome";
    } else if (browser.is("safari") || browser.is("ios")) {
        return "Safari";
    } else if (browser.is("firefox")) {
        return "Firefox";
    } else if (browser.is("opera")) {
        return "Opera";
    } else {
        return "";
    }
})();
$appIcon.setAttribute("src", `./media/DefaultBrowser${icon}@2x.png`);
