import { createServer } from "http";
import { readFile } from "fs/promises";
import { join } from "path";

createServer(async (req, res) => {
    const [
        html,
        render_buffer_source,
        sort_entities_source,
    ] = await Promise.all([
        readFile(join("wgsl_profiler.html"), "utf-8"),
        readFile(join("src", "wgsl", "render_buffer.wgsl"), "utf-8"),
        readFile(join("src", "wgsl", "sort_entities.wgsl"), "utf-8"),
    ]);

    const split_html = html.split("// insert wgsl source");
    const concated_html =
        split_html[0] + render_buffer_source +
        split_html[1] + sort_entities_source + split_html[2];

    res.writeHead(200, { "Content-Type": "text/html"});
    
    console.log(concated_html);
    console.log(`Injected ${split_html.length - 1} shaders`);

    res.end(concated_html);
}).listen(8408, "localhost", () => { console.log("running server on http://localhost:8408")});