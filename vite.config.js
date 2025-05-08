import { defineConfig } from "vite";

export default defineConfig({
    root: "./src",
    build: {
        outDir: "../dist",
        rollupOptions: {
            input: "./src/index.html",
        },
    },
});
