import { defineConfig } from "vite";
import solidPlugin from "vite-plugin-solid"
import { linkBuildExtension } from "wesl-plugin";
import weslPlugin from "wesl-plugin/vite"

// https://vite.dev/config/
export default defineConfig(async () => ({
  plugins: [
    solidPlugin(),
    weslPlugin({
      extensions: [linkBuildExtension],
      weslToml: "./compare/sort_subgroup/wesl.toml"
    })
  ],
  server: { port: 8402 }
}));
