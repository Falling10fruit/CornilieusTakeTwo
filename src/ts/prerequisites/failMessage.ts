const errorBox = document.getElementById("error_box") as HTMLDivElement;
const header = errorBox.children[0] as HTMLHeadingElement;
const body = errorBox.children[1] as HTMLParagraphElement;
const closeButton = errorBox.children[2] as HTMLButtonElement;
const copyButton = errorBox.children[3] as HTMLButtonElement;

window.fail = (parameters: {
    title: string,
    message: unknown
}) => {
    const { title, message } = parameters;

    if (typeof message == "string") return displayMessage({ title, message });
    if (message instanceof Error) displayMessage({ title, message: (message.stack) as string});

    console.error("failed to set up: ", message)
}

function displayMessage (parameters: { title: string, message: string }) {
    const { title, message } = parameters;

    header.innerText = title;
    body.innerText = message;
    
    closeButton.onclick = closeBox;
    copyButton.onclick = copyText(message);
    
    errorBox.style.visibility = "visible";
    console.error(`${title}: ${message}`);

}

function closeBox () {
    errorBox.style.visibility = "hidden";
}

function copyText (message: string): any { 
    navigator.clipboard.writeText(message).catch((err) => {
        console.error("The window is likely unfocused and clipboard manipulation is unavailable: ", err);
        copyButton.style.visibility = "hidden";
    });
}