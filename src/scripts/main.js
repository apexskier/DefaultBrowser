import bowser from 'bowser';
import formatDate from './date';

// manage date in menu bar
const $date = document.getElementById('menu-bar-date');
window.setInterval((function() {
    function updateDate() {
        $date.textContent = formatDate(new Date());
    }
    updateDate();
    return updateDate;
})(), 1000);

// manage browser context
const $activeAppName = document.getElementById('menu-bar-active-app');
$activeAppName.textContent = bowser.name || $activeAppName.textContent;

const $appIcon = document.getElementById('menu-bar-app-icon');
const icon = (function() {
    if (bowser.chrome) {
        return 'Chrome';
    } else if (bowser.safari || bowser.ios) {
        return 'Safari';
    } else if (bowser.firefox) {
        return 'Firefox';
    } else if (bowser.opera) {
        return 'Opera';
    } else {
        return '';
    }
})();
$appIcon.firstChild.setAttribute('src', `./media/DefaultBrowser${icon}@2x.png`);
