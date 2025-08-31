const errorBox = document.getElementById("error_box");
const header = errorBox.children[0];
const body = errorBox.children[1];
const close = errorBox.children[2];
const copy = errorBox.children[3];

window.fail = ({
    title = "huh.",
    message = "idk, shit happens ig",
    onclose = () => {}
}) => {
    header.innerText = title;
    body.innerText = message;
    
    close.onclick = closeBox;
    copy.onclick = copyText(message);
    
    errorBox.style.visibility = "visible";
    console.error(`${title}: ${message}`);
}

function closeBox () {
    errorBox.style.visibility = "hidden";
}

async function copyText (message) {
    try {
        await navigator.clipboard.writeText(message);
    } catch (err) {
        console.error("The window is likely unfocused and clipboard manipulation is unavailable");
        copy.style.visibility = "hidden";
    }
}