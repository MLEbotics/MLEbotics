import type { NextConfig } from 'next'

const config: NextConfig = {
  transpilePackages: ['@mlebotics/ui', '@mlebotics/utils', '@mlebotics/api'],
}

export default config
