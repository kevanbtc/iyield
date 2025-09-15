/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,
  swcMinify: true,
  experimental: {
    appDir: true,
  },
  env: {
    NEXT_PUBLIC_APP_NAME: 'iYield Protocol',
    NEXT_PUBLIC_APP_DESCRIPTION: 'Insurance Cash Surrender Value Tokenization Platform',
  },
}

module.exports = nextConfig