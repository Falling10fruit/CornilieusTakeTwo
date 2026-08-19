import { createServer } from "http";
import { readFile } from "fs/promises";
import { join } from "path";

createServer(async (req, res) => {
    const concated_html = await return_html_with_file_paths([
        join("wgsl_profiler copy.html"),
        join("src", "wgsl", "render_buffer.wgsl"),
        join("src", "wgsl", "sort_entities copy.wgsl"),
    ]);
    
    res.writeHead(200, { "Content-Type": "text/html"});
    res.end(concated_html);
}).listen(8408, "localhost", () => { console.log("running server on http://localhost:8408")});

createServer(async (req, res) => {
    const concated_html = await return_html_with_file_paths([
        join("wgsl_profiler.html"),
        join("src", "wgsl", "render_buffer.wgsl"),
        join("src", "wgsl", "sort_entities.wgsl"),
    ]);

    res.writeHead(200, { "Content-Type": "text/html"});
    res.end(concated_html);
}).listen(8080, "localhost", () => { console.log("running server on http://localhost:8080")});

async function return_html_with_file_paths(file_paths) {
    const [
        html,
        render_buffer_source,
        sort_entities_source,
    ] = await Promise.all([
        readFile(file_paths[0], "utf-8"),
        readFile(file_paths[1], "utf-8"),
        readFile(file_paths[2], "utf-8"),
    ]);
    
    const split_html = html.split("// insert wgsl source");
    const prelog_html =
        split_html[0] + render_buffer_source +
        split_html[1] + sort_entities_source + split_html[2];

    const prelog_html_split = prelog_html.split("// console log shaders");
    const concated_html = prelog_html_split[0] + `
        console.table(${JSON.stringify(file_paths)});
    ` + prelog_html_split[1];

    return concated_html;
}