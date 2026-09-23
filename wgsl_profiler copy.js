import { createServer } from "http";
import { readFile } from "fs/promises";
import { join } from "path";

[
    {
        suffix: "master",
        use_interval: true
    },
    {
        suffix: "byte_digit_radix_16_256_variation",
        use_interval: true
    },
    {
        suffix: "radix_3_pass",
        use_interval: true
    }
].forEach((record, index) => {
    createServer(async (req, res) => {
        const concated_html = await return_html_with_file_paths({
            file_paths: [
                join("compare", "html", `wgsl_profiler ${record.suffix}.html`),
                join("src", "wgsl", "render_buffer.wgsl"),
                join("compare", "wgsl", `sort_entities ${record.suffix}.wgsl`),
            ],
            suffix: record.suffix, 
            use_interval: record.use_interval
        });
        
        res.writeHead(200, { "Content-Type": "text/html"});
        res.end(concated_html);
    }).listen(8400 + index, "localhost", () => { console.log(`${record.suffix} running on http://localhost:${8400 + index}`)});

})

async function return_html_with_file_paths(parameters) {
    const {suffix, file_paths, use_interval} = parameters;

    const [
        html,
        render_buffer_source,
        sort_entities_source,
    ] = await Promise.all([
        readFile(file_paths[0], "utf-8"),
        readFile(file_paths[1], "utf-8"),
        readFile(file_paths[2], "utf-8"),
    ]);

    return do_the_express_thing(html, {
        title: suffix,
        render_source: render_buffer_source,
        sort_source: sort_entities_source,
        use_interval
    });
}

function do_the_express_thing(html_text, key_data) {
    let keys = [];
    let content = [];
    html_text.split("<node_inject>").forEach((fragment, index) => {
        if (index == 0) { content.push(fragment); return }

        const [key, post_content] = fragment.split("</node_inject>");
        keys.push(key);
        content.push(post_content);
    });

    let final_cut = "";
    for (let i = 0; i < keys.length * 2 + 1; i++) {
        if (i % 2 == 0) { final_cut += content[i/2]; }
        else { final_cut += key_data[keys[i >> 1]];}
    }

    return final_cut;
}