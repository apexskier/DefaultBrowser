import Bowser from "bowser";

// Manage date in menu bar
const dateOptions = {
    weekday: "short",
    month: "short",
    day: "numeric",
    hour: "numeric",
    minute: "2-digit",
};
const $date = document.getElementById("menu-bar-date");

function updateDate() {
    $date.textContent = new Intl.DateTimeFormat(undefined, dateOptions).format(
        new Date()
    );
}

updateDate();
setInterval(updateDate, 1000);

// Manage browser context
const browser = Bowser.getParser(window.navigator.userAgent);
const $activeAppName = document.getElementById("menu-bar-active-app");
$activeAppName.textContent =
    browser.getBrowserName() ?? $activeAppName.textContent;

const $appIcon = document.getElementById("menu-bar-app-icon");
const browserIcons = {
    chrome: "Chrome",
    safari: "Safari",
    ios: "Safari",
    firefox: "Firefox",
    opera: "Opera",
    waterfox: "Waterfox",
    vivaldi: "Vivaldi",
};

const icon =
    Object.entries(browserIcons).find(([key]) => browser.is(key))?.[1] ?? "";

$appIcon.setAttribute("src", `DefaultBrowser${icon}@2x.png`);
