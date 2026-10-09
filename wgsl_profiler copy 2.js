import { exec }  from 'child_process';
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

})


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