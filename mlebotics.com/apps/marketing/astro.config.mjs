import { defineConfig } from 'astro/config'
import react from '@astrojs/react'
import tailwind from '@astrojs/tailwind'

export default defineConfig({
  site: 'https://mlebotics.com',

  integrations: [
    react(),
    tailwind(),
  ],

  output: 'static',

  server: {
    port: 54321,
    host: true,
  },
})
