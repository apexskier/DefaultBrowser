!function e(i,r,o){function n(s,a){if(!r[s]){if(!i[s]){var d="function"==typeof require&&require;if(!a&&d)return d(s,!0);if(t)return t(s,!0);var m=new Error("Cannot find module '"+s+"'");throw m.code="MODULE_NOT_FOUND",m}var f=r[s]={exports:{}};i[s][0].call(f.exports,function(e){var r=i[s][1][e];return n(r?r:e)},f,f.exports,e,i,r,o)}return r[s].exports}for(var t="function"==typeof require&&require,s=0;s<o.length;s++)n(o[s]);return n}({1:[function(e,i,r){!function(e,r){"undefined"!=typeof i&&i.exports?i.exports=r():"function"==typeof define&&define.amd?define(r):this[e]=r()}("bowser",function(){function e(e){function r(i){var r=e.match(i);return r&&r.length>1&&r[1]||""}function o(i){var r=e.match(i);return r&&r.length>1&&r[2]||""}var n,t=r(/(ipod|iphone|ipad)/i).toLowerCase(),s=/like android/i.test(e),a=!s&&/android/i.test(e),d=/CrOS/.test(e),m=r(/edge\/(\d+(\.\d+)?)/i),f=r(/version\/(\d+(\.\d+)?)/i),u=/tablet/i.test(e),c=!u&&/[^-]mobi/i.test(e);/opera|opr/i.test(e)?n={name:"Opera",opera:i,version:f||r(/(?:opera|opr)[\s\/](\d+(\.\d+)?)/i)}:/yabrowser/i.test(e)?n={name:"Yandex Browser",yandexbrowser:i,version:f||r(/(?:yabrowser)[\s\/](\d+(\.\d+)?)/i)}:/windows phone/i.test(e)?(n={name:"Windows Phone",windowsphone:i},m?(n.msedge=i,n.version=m):(n.msie=i,n.version=r(/iemobile\/(\d+(\.\d+)?)/i))):/msie|trident/i.test(e)?n={name:"Internet Explorer",msie:i,version:r(/(?:msie |rv:)(\d+(\.\d+)?)/i)}:d?n={name:"Chrome",chromeBook:i,chrome:i,version:r(/(?:chrome|crios|crmo)\/(\d+(\.\d+)?)/i)}:/chrome.+? edge/i.test(e)?n={name:"Microsoft Edge",msedge:i,version:m}:/chrome|crios|crmo/i.test(e)?n={name:"Chrome",chrome:i,version:r(/(?:chrome|crios|crmo)\/(\d+(\.\d+)?)/i)}:t?(n={name:"iphone"==t?"iPhone":"ipad"==t?"iPad":"iPod"},f&&(n.version=f)):/sailfish/i.test(e)?n={name:"Sailfish",sailfish:i,version:r(/sailfish\s?browser\/(\d+(\.\d+)?)/i)}:/seamonkey\//i.test(e)?n={name:"SeaMonkey",seamonkey:i,version:r(/seamonkey\/(\d+(\.\d+)?)/i)}:/firefox|iceweasel/i.test(e)?(n={name:"Firefox",firefox:i,version:r(/(?:firefox|iceweasel)[ \/](\d+(\.\d+)?)/i)},/\((mobile|tablet);[^\)]*rv:[\d\.]+\)/i.test(e)&&(n.firefoxos=i)):/silk/i.test(e)?n={name:"Amazon Silk",silk:i,version:r(/silk\/(\d+(\.\d+)?)/i)}:a?n={name:"Android",version:f}:/phantom/i.test(e)?n={name:"PhantomJS",phantom:i,version:r(/phantomjs\/(\d+(\.\d+)?)/i)}:/blackberry|\bbb\d+/i.test(e)||/rim\stablet/i.test(e)?n={name:"BlackBerry",blackberry:i,version:f||r(/blackberry[\d]+\/(\d+(\.\d+)?)/i)}:/(web|hpw)os/i.test(e)?(n={name:"WebOS",webos:i,version:f||r(/w(?:eb)?osbrowser\/(\d+(\.\d+)?)/i)},/touchpad\//i.test(e)&&(n.touchpad=i)):n=/bada/i.test(e)?{name:"Bada",bada:i,version:r(/dolfin\/(\d+(\.\d+)?)/i)}:/tizen/i.test(e)?{name:"Tizen",tizen:i,version:r(/(?:tizen\s?)?browser\/(\d+(\.\d+)?)/i)||f}:/safari/i.test(e)?{name:"Safari",safari:i,version:f}:{name:r(/^(.*)\/(.*) /),version:o(/^(.*)\/(.*) /)},!n.msedge&&/(apple)?webkit/i.test(e)?(n.name=n.name||"Webkit",n.webkit=i,!n.version&&f&&(n.version=f)):!n.opera&&/gecko\//i.test(e)&&(n.name=n.name||"Gecko",n.gecko=i,n.version=n.version||r(/gecko\/(\d+(\.\d+)?)/i)),n.msedge||!a&&!n.silk?t&&(n[t]=i,n.ios=i):n.android=i;var v="";n.windowsphone?v=r(/windows phone (?:os)?\s?(\d+(\.\d+)*)/i):t?(v=r(/os (\d+([_\s]\d+)*) like mac os x/i),v=v.replace(/[_\s]/g,".")):a?v=r(/android[ \/-](\d+(\.\d+)*)/i):n.webos?v=r(/(?:web|hpw)os\/(\d+(\.\d+)*)/i):n.blackberry?v=r(/rim\stablet\sos\s(\d+(\.\d+)*)/i):n.bada?v=r(/bada\/(\d+(\.\d+)*)/i):n.tizen&&(v=r(/tizen[\/\s](\d+(\.\d+)*)/i)),v&&(n.osversion=v);var l=v.split(".")[0];return u||"ipad"==t||a&&(3==l||4==l&&!c)||n.silk?n.tablet=i:(c||"iphone"==t||"ipod"==t||a||n.blackberry||n.webos||n.bada)&&(n.mobile=i),n.msedge||n.msie&&n.version>=10||n.yandexbrowser&&n.version>=15||n.chrome&&n.version>=20||n.firefox&&n.version>=20||n.safari&&n.version>=6||n.opera&&n.version>=10||n.ios&&n.osversion&&n.osversion.split(".")[0]>=6||n.blackberry&&n.version>=10.1?n.a=i:n.msie&&n.version<10||n.chrome&&n.version<20||n.firefox&&n.version<20||n.safari&&n.version<6||n.opera&&n.version<10||n.ios&&n.osversion&&n.osversion.split(".")[0]<6?n.c=i:n.x=i,n}var i=!0,r=e("undefined"!=typeof navigator?navigator.userAgent:"");return r.test=function(e){for(var i=0;i<e.length;++i){var o=e[i];if("string"==typeof o&&o in r)return!0}return!1},r._detect=e,r})},{}],2:[function(e,i,r){"use strict";function o(e){var i=e.getHours(),r=e.getMinutes(),o=e.getDay(),t=i>=12?"PM":"AM";return i%=12,i=i||12,r=10>r?"0"+r:r,o=n[o],o+" "+i+":"+r+" "+t}Object.defineProperty(r,"__esModule",{value:!0});var n=["Sun","Mon","Tue","Wed","Thu","Fri","Sat"];r["default"]=o},{}],3:[function(e,i,r){"use strict";function o(e){return e&&e.__esModule?e:{"default":e}}var n=e("bowser"),t=o(n),s=e("./date"),a=o(s),d=document.getElementById("menu-bar-date");window.setInterval(function(){function e(){d.textContent=(0,a["default"])(new Date)}return e(),e}(),1e3);var m=document.getElementById("menu-bar-active-app");m.textContent=t["default"].name||m.textContent;var f=document.getElementById("menu-bar-app-icon"),u=function(){return t["default"].chrome?"Chrome":t["default"].safari||t["default"].ios?"Safari":t["default"].firefox?"Firefox":t["default"].opera?"Opera":""}();f.firstChild.setAttribute("src","./media/DefaultBrowser"+u+"@2x.png")},{"./date":2,bowser:1}]},{},[2,3]);