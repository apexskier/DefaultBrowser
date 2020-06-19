const days = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];

function formatDate(d) {
    let hours = d.getHours();
    let minutes = d.getMinutes();
    let day = d.getDay();
    const ampm = hours >= 12 ? "PM" : "AM";
    hours = hours % 12;
    hours = hours || 12; // the hour '0' should be '12'
    minutes = minutes < 10 ? "0" + minutes : minutes;
    day = days[day];
    return `${day} ${hours}:${minutes} ${ampm}`;
}

export default formatDate;
