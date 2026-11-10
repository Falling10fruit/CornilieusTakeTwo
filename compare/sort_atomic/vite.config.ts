import { defineConfig } from "vite";
import solidPlugin from "vite-plugin-solid"
import { linkBuildExtension } from "wesl-plugin";
import weslPlugin from "wesl-plugin/vite"

// https://vite.dev/config/
export default defineConfig(async () => ({
  plugins: [solidPlugin(), weslPlugin({ extensions: [linkBuildExtension] })],
  server: { port: 8404 }
}));
