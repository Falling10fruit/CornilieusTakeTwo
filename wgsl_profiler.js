import { createServer } from "http";
import { readFile } from "fs/promises";
import { join } from "path";

createServer(async (req, res) => {
    const [
        html,
        render_buffer_source,
        
        chunk_count_source,
        chunk_prefix_source,
        chunk_prefix_workgroup_source,
        chunk_rescatter_source
    ] = await Promise.all([
        readFile(join("wgsl_profiler.html"), "utf-8"),
        readFile(join("src", "wgsl", "render_buffer.wgsl"), "utf-8"),

        readFile(join("src", "wgsl", "sort", "chunk_count.wgsl"), "utf-8"),
        readFile(join("src", "wgsl", "sort", "chunk_prefix.wgsl"), "utf-8"),
        readFile(join("src", "wgsl", "sort", "chunk_prefix_workgroup.wgsl"), "utf-8"),
        readFile(join("src", "wgsl", "sort", "chunk_rescatter.wgsl"), "utf-8"),
    ]);

    const split_html = html.split("// insert wgsl source");
    const concated_html =
        split_html[0] + render_buffer_source +
        split_html[1] + chunk_count_source +
        split_html[2] + chunk_prefix_source +
        split_html[3] + chunk_prefix_workgroup_source +
        split_html[4] + chunk_rescatter_source + split_html[5];

    res.writeHead(200, { "Content-Type": "text/html"});
    
    console.log(concated_html);
    console.log(`Injected ${split_html.length - 1} shaders`);

    res.end(concated_html);
}).listen(8408, "localhost", () => { console.log("running server on http://localhost:8408")});